---
title: "A 2009 iMac That Refuses to Die"
excerpt: "Inverted SSH ciphers, a measured 92 MiB kernel diet, an ext4 patch with an upstream submission kit, and swap over NVMe-over-TCP."
date: 2026-07-30 00:02:00 +0000
---

This is part of a series about the single Nix flake that describes every machine I run — see [The Infrastructure I Run](/the-infrastructure-i-run/) for the overview.

Exactly one host in that flake is a desktop, and it's a 2009 iMac: Core 2 Duo, 3.8 GiB of RAM, a GeForce 9400M. Its notes file is the longest in the repo, and it has an `evidence/` directory of GPU-freeze forensics. It's also the reason the flake carries [a nixpkgs revision frozen in 2022](/pins-secrets-and-deploys/) — the last one that still packages CUDA 6.5.

Keeping a sixteen-year-old machine genuinely useful, rather than nominally booting, turns out to be a series of specific fights. Here are four.

## Inverted cipher preferences

The Penryn CPU has no AES-NI and no PCLMULQDQ, so AES is software and GCM's GHASH is table-driven. Measured on the box: ChaCha20-Poly1305 costs 4.7 CPU-seconds per GB, AES-256-GCM costs 8.3.

This host therefore wants the *opposite* SSH cipher order from the rest of the fleet, whose cloud CPUs all have AES-NI and for which the ordering is reversed. So the setting is host-scoped, with a comment forbidding anyone from hoisting it into the shared module — because the shared module is exactly where a well-meaning future me would put it.

This is the general shape of the problem with old hardware in a fleet: the correct configuration isn't a worse version of the modern one, it's a different one, and the abstraction that serves twenty homogeneous machines actively fights the twenty-first.

## A ~92 MiB kernel memory diet

On a machine with 3.8 GiB, kernel overhead is real. The diet was itemised and measured rather than guessed: printk shift, BTF off, the ftrace family off, the kexec family off, a smaller `swiotlb`.

Verified across a reboot — reserved memory went from 275,960K to 204,260K. Every item in that list was checked live before it was changed, which matters, because roughly half of the "obvious" savings I expected turned out to be worth nothing on this kernel.

## An ext4 patch with an upstream submission kit

Kernel-side creation of inline-data symlinks was removed upstream. On this machine that's a measurable cost, because a survey of the Nix bin farm found **1690 of 1693 symlinks have 60–90 byte targets** — small enough to live in the inode, but instead each one gets a 4 KiB block and a cold seek on a spinning disk.

The patch re-adds it. Two details made it more than a local hack: the on-disk format matches `e2fsck` 1.47.4's validation *exactly* — a mismatch would make pass 2 deallocate the symlinks, and this host boots with `fsck.repair=yes`, so getting it subtly wrong would eat the filesystem rather than merely fail — and the tree carries a cover letter, a documentation patch and an fstests case, ready to send.

## Swap over the network

It swaps to a 16 GB NVMe-over-TCP device exported by a workstation elsewhere on the network.

The lease protocol is my favourite thing in the repo. A client hands the daemon a **pidfd over a Unix socket with `SCM_RIGHTS`**, then `execv`s its real payload after closing everything. The daemon polls that pidfd, which becomes readable on any exit — including `SIGKILL`, and immune to PID reuse, which a bare PID check is not.

The properties fall out for free rather than being enforced: nothing is inherited into the payload process, so it can't leak the lease; concurrent users refcount naturally; and the whole thing is crash-safe by construction rather than by cleanup handler. Because it's socket-activated, no client path needs sudo, polkit or systemctl — access control *is* the socket's file mode. It tears itself down after a grace period and exits.

## Why bother

The machine owes me nothing. But every one of these fights produced something reusable: the cipher lesson applies to any heterogeneous fleet, the ext4 patch is going upstream, and the swap lease is a pattern I'd use anywhere I needed a crash-safe resource handoff between unprivileged processes.

Old hardware is a good teacher because it refuses to let you paper over inefficiency with headroom.
