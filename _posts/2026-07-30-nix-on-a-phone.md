---
title: "Nix on a Phone, and the Trick That Makes It Work"
excerpt: "A full Nix userland on Android needs a reimplemented replaceDependencies — and a base-32-to-base-64 hash re-encoding to keep store paths byte-identical in length."
date: 2026-07-30 00:03:00 +0000
---

This is part of a series about the single Nix flake that describes every machine I run — see [The Infrastructure I Run](/the-infrastructure-i-run/) for the overview. One of the hosts in that flake is an Android phone, and it's the one that needed genuinely new machinery.

The phone runs a full Nix userland on Android, against a custom glibc 2.40 carrying Termux's kernel-compatibility patches, with a patched fakechroot as `/etc/ld.so.preload`. It has the same shell, the same editors, the same package set as every other host. I wrote this post on it.

## The constraint

Getting there required reimplementing nixpkgs' `replaceDependencies`, and the reason is a nice constraint.

Upstream patches a dependency out of an already-built closure by *binary string substitution* — it walks the NAR stream and rewrites store paths in place. Rewriting bytes inside a compiled ELF file means you cannot change how many bytes there are: shifting everything after the edit would break every offset in the file. So the old and new paths must be **byte-identical in length**.

That constraint fails twice on Android. Standard glibc and an Android-patched glibc don't have the same path length. And `/nix/store` doesn't exist at the real path on Android at all — the store lives under the app's data directory, which is a different length again.

## The trick

The solution is a three-layer rewrite, and the middle layer is the clever part. Every store path maps to a symlink whose basename is a *re-encoding of the same Nix hash*:

> The Nix store path already carries a 20-byte hash encoded in nix-base-32 as the first 32 chars of the basename. We re-encode it as base-64 URL-safe (27 chars for the same 160 bits — nix-base-32 is 5 bits/char, base-64 is 6) and take a prefix that makes the symlink path same total length as the original store path.

Base-32 spends five bits per character; base-64 spends six. The same 160-bit hash therefore fits in 27 characters instead of 32, and those five recovered characters are the budget you spend on a different path prefix — while keeping the total length identical, which is what the byte-level substitution demands.

It's a pleasing kind of solution: the information you need to preserve (160 bits of hash) and the constraint you have to satisfy (exact path length) turn out to be independent, once you stop assuming the hash has to stay in the encoding Nix chose for it. For a typical 44-character basename the crop lands at exactly 27 chars, so the full hash survives. At the pathological minimum it's 16 chars — still 96 bits, still collision-safe.

## The three layers

Layer one does OLD → SYMLINK, same-length by construction, as above.

Layer two does SYMLINK → REAL structurally rather than byte-wise: ELF interpreters, RPATHs, NAR symlink targets, script literals, shebangs. These are all length-agnostic — you're rewriting a field, not patching bytes in place — so the real path can be any length it likes. The glibc swap itself, being cross-length, rides this pass.

The result is that the whole *environment* gets patched at once. There are no per-package Android variants to maintain: packages come out of the ordinary binary cache and get rewritten on the way in, rather than being rebuilt from source for the platform. On a phone, that distinction is the difference between a working system and a battery-shaped space heater.

Everything above is why the Makefile in the blog you're reading can invoke a grafted Ruby 4.0 on a phone and have it behave like Ruby on a normal Linux box — the same `bundle exec jekyll build` as the CI runner, on the same flake, from a device in my pocket.
