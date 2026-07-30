---
title: "The Infrastructure I Run"
excerpt: "One Nix flake, twenty-one hosts, five different operating-system situations — including a phone and a 2009 iMac. An overview, and an index of the deep dives."
date: 2026-07-30 00:05:00 +0000
---

Everything I run — servers, workstations, a laptop, a WSL install, and the Android phone in my pocket — is described by a single Nix flake. Twenty-one hosts, one `hosts/default.nix` listing them, one `common/` directory holding everything they share. `make switch HOST=<name>` and the machine converges on what the repo says it should be.

This post is the overview: what's running, where you can reach it, and how the fleet is shaped. The parts that need real room to explain have their own posts, indexed at the bottom.

## Public entrypoints

Before the internals, the parts that answer on a public name.

Open to anyone:

| Entrypoint | What it is |
|---|---|
| [wenri.me](https://wenri.me) | This blog. Jekyll, built and deployed by GitHub Actions to Pages. |
| [s2.hk](https://s2.hk) | My academic site — publications, CV, news. |
| [matrix.s2.hk](https://matrix.s2.hk) | Matrix homeserver, federating as `s2.hk`. Synapse behind Traefik. |
| [element.s2.hk](https://element.s2.hk) | Element — the web client for that homeserver. |
| [b3.hk](https://b3.hk) | Self-hosted Bluesky PDS. It's the personal data server behind my `s2.hk` Bluesky handle. |
| [deb.s2.hk](https://deb.s2.hk) | A signed apt repository for vendor `.deb`s that ship no repo of their own — metadata only, pointing at upstream download URLs. |

Sign-in required — listed because a service you can't find is not a service you've secured:

| Entrypoint | What it is |
|---|---|
| [c.s2.hk](https://c.s2.hk) | Coder. The control plane for my dev workspaces; the machines that actually run them are elsewhere in the fleet. |
| [nm.wenri.org](https://nm.wenri.org) | Netmaker. The dashboard for the mesh VPN that connects the fleet. |
| [portainer.s2.hk](https://portainer.s2.hk) | Portainer, for the container stack on the host below. |
| [karakeep.s2.hk](https://karakeep.s2.hk) | Karakeep — bookmarks and read-later, self-hosted. |
| [stats.s2.hk](https://stats.s2.hk) | Grafana, watching everything else. |

Nearly all of that shares a single small container in Paris, which is a slightly absurd amount of load for an OpenVZ guest on a 3.10 kernel and works fine.

What's *not* in either table is the shell access: SSH to every host in the fleet reaches the internet only through Cloudflare tunnels, so there is no listening port to publish in the first place. That asymmetry is deliberate — the interesting engineering in this setup is in tunnels, meshes and grafting rather than virtual hosts.

## The fleet

By type, as the flake partitions them:

| Type | Count | What they are |
|---|---|---|
| `server` | 12 | Cloud VMs and a couple of bare-metal boxes, spread across Asia, Europe and the US |
| `non-nixos` | 6 | Stock Ubuntu machines, plus one OpenVZ container, managed by home-manager alone |
| `desktop` | 1 | A [2009 iMac](/a-2009-imac-that-refuses-to-die/) (yes, really) |
| `wsl` | 1 | NixOS-WSL for Windows work |
| `android` | 1 | This phone |

Only fourteen of them run NixOS. That turns out to be the interesting thing about the setup: the engineering effort isn't in the NixOS hosts, it's in everything else. A NixOS module and a home-manager module that produce the same behaviour on stock Ubuntu need to agree, so the shared logic sits in pure-data modules underneath both — one source of truth, two renderers. When the Ubuntu box needs a firewall rule that its NixOS sibling gets from `networking.firewall`, the same data goes through a generator that writes a nushell script into `/etc/ufw/after.init` instead.

On those six non-NixOS hosts there's one decision worth stealing. `/nix/var/nix/profiles/default` points at root's home-manager profile, so `pkgs.nix` in root's `home.packages` *is* the machine's Nix, and its version is a property of `flake.lock`. The `nix-daemon` units are rendered by home-manager with a profile-indirect `ExecStart`. Upgrading Nix on a machine that doesn't run NixOS becomes `make home-root HOST=<h>` and a daemon restart.

## Deep dives

Three parts of this needed more room than an overview allows:

- **[Nix on a Phone, and the Trick That Makes It Work](/nix-on-a-phone/)** — running a full Nix userland on Android, and the base-32-to-base-64 hash re-encoding that keeps store paths byte-identical in length while pointing somewhere else entirely.
- **[A 2009 iMac That Refuses to Die](/a-2009-imac-that-refuses-to-die/)** — inverted SSH ciphers on a CPU with no AES-NI, a measured 92 MiB kernel diet, an ext4 patch with an upstream submission kit, and swap over NVMe-over-TCP.
- **[Pins, Secrets, and Deploys That Can't Strand You](/pins-secrets-and-deploys/)** — seven nixpkgs branches each pinned for a stated reason, secrets without agenix, and two mechanisms that stop a remote switch from bricking the box.

Still to write: the cross-border connectivity layer — mesh VPN, reverse tunnels, multipath TCP — which is the other half of the repo.

## What the repo is actually for

The thing I'd most want to convey isn't any single mechanism. It's a habit: in this repo, comments don't say what the code does. They say what broke.

> matxs-hkg demonstrated exactly this ("Failed to open …/nix-daemon.socket" three seconds before nix.mount).

> 1690/1693 bin-farm symlinks are 60–90 B targets.

> measured: 0 `kvm:kvm_userspace_exit` in 10 s.

> the gate boot missed by EXACTLY TWO MESSAGES.

Every one of those is a debugging session someone (me) already paid for, written down at the exact line where the next person would otherwise repeat it. Nix is what makes the fleet reproducible. The comments are what make it *maintainable* — they're the difference between a configuration I can still change in two years and one I'd be afraid to touch.

That, more than the twenty-one hosts, is the infrastructure.
