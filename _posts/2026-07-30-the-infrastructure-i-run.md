---
title: "The Infrastructure I Run"
excerpt: "One Nix flake, twenty-one hosts, five different operating-system situations — including a phone and a 2009 iMac. A tour of what's in it and what it cost to learn."
date: 2026-07-30
---

Everything I run — servers, workstations, a laptop, a WSL install, and the Android phone in my pocket — is described by a single Nix flake. Twenty-one hosts, one `hosts/default.nix` listing them, one `common/` directory holding everything they share. `make switch HOST=<name>` and the machine converges on what the repo says it should be.

This post is a tour of that repo. Not the tidy version — the interesting parts are all the places where the general mechanism didn't fit and something had to be built.

## The fleet

By type, as the flake partitions them:

| Type | Count | What they are |
|---|---|---|
| `server` | 12 | Cloud VMs and a couple of bare-metal boxes, spread across Asia, Europe and the US |
| `non-nixos` | 6 | Stock Ubuntu machines, plus one OpenVZ container, managed by home-manager alone |
| `desktop` | 1 | A 2009 iMac (yes, really — see below) |
| `wsl` | 1 | NixOS-WSL for Windows work |
| `android` | 1 | This phone |

Only fourteen of them run NixOS. That turns out to be the interesting thing about the setup: the engineering effort isn't in the NixOS hosts, it's in everything else. A NixOS module and a home-manager module that produce the same behaviour on stock Ubuntu need to agree, so the shared logic sits in pure-data modules underneath both — one source of truth, two renderers. When the Ubuntu box needs a firewall rule that its NixOS sibling gets from `networking.firewall`, the same data goes through a generator that writes a nushell script into `/etc/ufw/after.init` instead.

On those six non-NixOS hosts there's one decision worth stealing. `/nix/var/nix/profiles/default` points at root's home-manager profile, so `pkgs.nix` in root's `home.packages` *is* the machine's Nix, and its version is a property of `flake.lock`. The `nix-daemon` units are rendered by home-manager with a profile-indirect `ExecStart`. Upgrading Nix on a machine that doesn't run NixOS becomes `make home-root HOST=<h>` and a daemon restart.

## Seven nixpkgs, each for a reason

The flake tracks seven nixpkgs branches simultaneously. That sounds undisciplined until you read why each one is pinned — every input in `flake.nix` carries its justification inline:

- **26.05** — the default everywhere, Hydra-verified.
- **unstable** — opt-in per package via `pkgs.unstable.*`.
- **25.11** — glibc 2.40, because that's what the phone's runtime is built against.
- **24.11** — mesa 24.2, the last release with bundled `libgbm`.
- **24.05** — systemd 255, the last version whose `chase_and_open` still has a `name_to_handle_at` fallback. One host is an OpenVZ container on a 3.10 kernel that lacks the syscall.
- **22.11** — xorg-server 1.20, the newest X the NVIDIA 340.xx legacy driver can talk to.
- **22.05** — gcc-12 and a glibc 2.34 floor, for building release binaries that assume an older toolchain.

And one more that isn't a branch at all: a specific revision hash from `release-20.09`, frozen in 2022, kept alive because it's the last nixpkgs containing a `cudatoolkit_6_5` expression. 21.05 dropped CUDA older than 10. I have a GPU that needs 6.5.

None of these leak into each other. The CUDA one is the sharpest case: the override swaps a modern stdenv, modern dependencies and a rewrapped older gcc into the 2020-era recipe, so it evaluates against ancient expressions but *no 20.09 store path reaches the runtime closure*.

## Nix on a phone, and the trick that makes it work

The phone runs a full Nix userland on Android, against a custom glibc 2.40 carrying Termux's kernel-compatibility patches, with a patched fakechroot as `/etc/ld.so.preload`. It has the same shell, the same editors, the same package set as every other host. I wrote this post on it.

Getting there required reimplementing nixpkgs' `replaceDependencies`, and the reason is a nice constraint. Upstream patches a dependency out of a built closure by *binary string substitution* — it walks the NAR stream and rewrites store paths in place. That means the old and new paths must be **byte-identical in length**. Standard glibc and an Android-patched glibc are not the same length, and `/nix/store` doesn't exist at the real path on Android anyway.

The solution is a three-layer rewrite, and the middle layer is the clever part. Every store path maps to a symlink whose basename is a *re-encoding of the same Nix hash*:

> The Nix store path already carries a 20-byte hash encoded in nix-base-32 as the first 32 chars of the basename. We re-encode it as base-64 URL-safe (27 chars for the same 160 bits — nix-base-32 is 5 bits/char, base-64 is 6) and take a prefix that makes the symlink path same total length as the original store path.

Base-32 spends five bits per character; base-64 spends six. The same 160-bit hash therefore fits in 27 characters instead of 32, and those five recovered characters are the budget you spend on a different path prefix — while keeping the total length identical, which is what the byte-level substitution demands. For a typical 44-character basename the crop lands at exactly 27 chars, so the full hash survives. At the pathological minimum it's 16 chars, still 96 bits, still collision-safe.

Layer one does OLD → SYMLINK, same-length by construction. Layer two does SYMLINK → REAL structurally — ELF interpreters, RPATHs, NAR symlink targets, shebangs — where lengths no longer need to match. The glibc swap itself, being cross-length, rides the structural pass. The whole *environment* gets patched at once, so there are no per-package Android variants: packages come out of the ordinary binary cache and get rewritten on the way in, rather than rebuilt.

Everything above is why the Makefile in the blog you're reading can invoke a grafted Ruby 4.0 on a phone and have it behave like Ruby on a normal Linux box.

## A 2009 iMac that refuses to die

One host is a Core 2 Duo iMac with 3.8 GiB of RAM and a GeForce 9400M. Its notes file is the longest in the repo, and it has an `evidence/` directory of GPU-freeze forensics. A sample of what keeping it useful actually involves:

**Inverted cipher preferences.** The Penryn CPU has no AES-NI and no PCLMULQDQ, so AES is software and GCM's GHASH is table-driven. Measured on the box: ChaCha20-Poly1305 costs 4.7 CPU-seconds per GB, AES-256-GCM costs 8.3. This host wants the *opposite* SSH cipher order from the rest of the fleet, whose cloud CPUs all have AES-NI — so the setting is host-scoped with a comment forbidding anyone from hoisting it into the shared module.

**A ~92 MiB kernel memory diet**, itemised and measured rather than guessed: printk shift, BTF off, the ftrace family off, the kexec family off, a smaller `swiotlb`. Verified across a reboot — reserved memory went from 275,960K to 204,260K.

**An ext4 patch with an upstream submission kit.** Kernel-side creation of inline-data symlinks was removed upstream; on this machine that's a real cost, because a measurement of the Nix bin farm found 1690 of 1693 symlinks have 60–90 byte targets — one 4 KiB block and one cold seek each on a spinning disk. The patch re-adds it, the on-disk format matches `e2fsck` 1.47.4's validation *exactly* (a mismatch would make fsck deallocate the symlinks, and this host boots with `fsck.repair=yes`), and the tree carries a cover letter, a documentation patch and an fstests case.

**Swap over the network.** It swaps to a 16 GB NVMe-over-TCP device exported by a workstation elsewhere. The lease protocol is my favourite thing in the repo: a client hands the daemon a **pidfd over a Unix socket with `SCM_RIGHTS`**, then `execv`s its real payload after closing everything. The daemon polls the pidfd, which becomes readable on any exit — including `SIGKILL`, and immune to PID reuse. Nothing is inherited into the payload process, concurrent users refcount naturally, and the whole thing is crash-safe by construction. Because it's socket-activated, no client path needs sudo, polkit or systemctl: access control *is* the socket's file mode.

## Deploying without losing the machine

Two safety mechanisms I'd recommend to anyone administering remote machines.

First, every `switch` runs inside a transient system-level systemd unit, so an SSH disconnect can't kill a half-applied configuration change. The invocation looks over-engineered and each layer was earned:

```
systemd-run --pty --pipe --wait --collect --same-dir \
  env --ignore-signal=SIGHUP --ignore-signal=SIGINT \
  script -qefc "<cmd>" /tmp/<unit>.log
```

`systemd-run` moves the work off the SSH connection's lifetime. The `script(1)` wrapper is there because when the client dies, the outer pty hangs up and *every later write fails with EIO even with SIGHUP ignored* — a bare `--pty` command dies mid-switch. `script` absorbs the EIO while the command's inner pty stays healthy, which keeps live colour output and progress bars working. (`nohup` can't substitute: with a tty stdout it redirects to `nohup.out` and you lose the live view.)

Second, reinstalling a box whose only access path is a reverse SSH tunnel. A stock kexec image would sever that tunnel and strand the machine. So the installer image **inherits the target's own SSH host key and uses it as a client identity** to dial back out to a relay, re-exposing its sshd there. Two properties fall out of that: the image contains no secrets, so it can be cached and shared freely; and until `disko` actually partitions anything, kexec is RAM-only — a power cycle falls back to the untouched old system, which restores the original tunnel. A failed phone-home is recoverable without console access.

## Secrets

No agenix, no sops-nix. A private Git submodule is consumed as a flake input, which means it's pinned in `flake.lock` like anything else, and its contents arrive at modules as an ordinary function argument through `specialArgs`.

Two rules make it hold up. Secrets are passed to services **as files** — rendered with `writeText`, or staged out of band by the installer — never as literals on a command line where they'd show up in `ps`. And where a secret is owned by something outside Nix, it's resolved at *merge* time from that system's own env file rather than being copied into the repo, so it never enters the Nix store at all; a job whose key is missing is skipped with a warning rather than silently mis-deploying. Public keys, meanwhile, live in the open in a plain tracked file, because they're public.

I'll write separately about the cross-border connectivity layer — mesh VPN, reverse tunnels, multipath TCP — which is the other half of the repo and needs its own post.

## What the repo is actually for

The thing I'd most want to convey isn't any single mechanism. It's a habit: in this repo, comments don't say what the code does. They say what broke.

> matxs-hkg demonstrated exactly this ("Failed to open …/nix-daemon.socket" three seconds before nix.mount).

> 1690/1693 bin-farm symlinks are 60–90 B targets.

> measured: 0 `kvm:kvm_userspace_exit` in 10 s.

> the gate boot missed by EXACTLY TWO MESSAGES.

Every one of those is a debugging session someone (me) already paid for, written down at the exact line where the next person would otherwise repeat it. Nix is what makes the fleet reproducible. The comments are what make it *maintainable* — they're the difference between a configuration I can still change in two years and one I'd be afraid to touch.

That, more than the twenty-one hosts, is the infrastructure.
