---
title: "Pins, Secrets, and Deploys That Can't Strand You"
excerpt: "Seven nixpkgs branches, each pinned for a stated reason; secrets without agenix or sops; and two mechanisms that stop a remote switch from bricking the machine."
date: 2026-07-30 00:04:00 +0000
---

This is part of a series about the single Nix flake that describes every machine I run — see [The Infrastructure I Run](/the-infrastructure-i-run/) for the overview and the host inventory.

This post is about the unglamorous half: how versions get pinned, how secrets move, and how a deploy avoids leaving a machine unreachable. None of it is clever in isolation. All of it is what makes the rest safe to touch.

## Seven nixpkgs, each for a reason

The flake tracks seven nixpkgs branches simultaneously. That sounds undisciplined until you read why each one is pinned — every input in `flake.nix` carries its justification inline:

- **26.05** — the default everywhere, Hydra-verified.
- **unstable** — opt-in per package via `pkgs.unstable.*`.
- **25.11** — glibc 2.40, because that's what [the phone's](/nix-on-a-phone/) runtime is built against.
- **24.11** — mesa 24.2, the last release with bundled `libgbm`.
- **24.05** — systemd 255, the last version whose `chase_and_open` still has a `name_to_handle_at` fallback. One host is an OpenVZ container on a 3.10 kernel that lacks the syscall.
- **22.11** — xorg-server 1.20, the newest X the NVIDIA 340.xx legacy driver can talk to.
- **22.05** — gcc-12 and a glibc 2.34 floor, for building release binaries that assume an older toolchain.

And one more that isn't a branch at all: a specific revision hash from `release-20.09`, frozen in 2022, kept alive because it's the last nixpkgs containing a `cudatoolkit_6_5` expression. 21.05 dropped CUDA older than 10. I have [a GPU that needs 6.5](/a-2009-imac-that-refuses-to-die/).

None of these leak into each other. The CUDA one is the sharpest case: the override swaps a modern stdenv, modern dependencies and a rewrapped older gcc into the 2020-era recipe, so it evaluates against ancient expressions but *no 20.09 store path reaches the runtime closure*.

The pattern worth stealing here isn't the number of pins — it's that each one names the specific artifact it exists for. A pin justified as "newer versions broke something" rots into a mystery within a year. A pin justified as "mesa 24.2, last release with bundled libgbm" tells you exactly what has to become true before you can delete it.

## Secrets

No agenix, no sops-nix. A private Git submodule is consumed as a flake input, which means it's pinned in `flake.lock` like anything else, and its contents arrive at modules as an ordinary function argument through `specialArgs`.

Two rules make it hold up. Secrets are passed to services **as files** — rendered with `writeText`, or staged out of band by the installer — never as literals on a command line where they'd show up in `ps`. And where a secret is owned by something outside Nix, it's resolved at *merge* time from that system's own env file rather than being copied into the repo, so it never enters the Nix store at all; a job whose key is missing is skipped with a warning rather than silently mis-deploying. Public keys, meanwhile, live in the open in a plain tracked file, because they're public.

The honest caveat: anything rendered into a unit file or a config is readable by whoever can read that file, and this scheme doesn't pretend otherwise. Where that exposure exists, the module says so in a comment rather than implying a guarantee it can't make. I'd rather have a documented boundary than an encrypted-at-rest story that quietly decrypts into a world-readable store path anyway.

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

That second property is the one I'd underline. The interesting question about a remote reinstall isn't whether the happy path works; it's what state the machine is in when the process dies halfway. Making the destructive step the *last* step, and keeping everything before it in RAM, converts "drive four hours to attach a console" into "cut the power and try again."
