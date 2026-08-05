# Makefile for building the blog locally — `make help` lists targets.
#
# The toolchain comes from the Android host's own nix configuration:
# nix/pkgs.nix imports the flake at ~/.config/nix-on-droid and mirrors
# its package set (nixpkgs-26_05 pin — glibc 2.42 to match the device's
# Android-patched glibc — plus its overlay stack); nix/shell.nix
# assembles the build shell from it.
#
# Environment quirks handled below: C.UTF-8 keeps Ruby in UTF-8 without
# needing a locale archive. Gems live on the native filesystem via the
# gitignored .bundle/config (the repo's /storage FUSE mount is noexec).
# Gemfile.lock is gitignored in this repo (theme-repo convention), so
# the bundle is not frozen — `make deps` resolves it fresh.
# CI has its own path and does not use this file
# (.github/workflows/jekyll.yml: Ruby 4.0.3 build + PurgeCSS + Pages).

RUBY ?= ruby_4_0
HOST ?= 127.0.0.1
PORT ?= 4000

BUILD_ENV := LC_ALL=C.UTF-8 LANG=C.UTF-8

# Evaluated from the host-config dir: the flake's relative
# `git+file:./submodules/secrets` input resolves against the process CWD
# (nix#12281), so a fresh evaluation launched from this repo can't find
# it (bit the main site 2026-07-30 after a host-config merge invalidated
# the eval cache).  Each --run command cds back to the repo.
NIX_SHELL = cd $(HOME)/.config/nix-on-droid && nix-shell $(CURDIR)/nix/shell.nix --argstr rubyAttr $(RUBY)

.DEFAULT_GOAL := build
.PHONY: help deps build purge serve clean distclean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

deps: ## Install/refresh the gem bundle
	$(NIX_SHELL) --run 'cd $(CURDIR) && bundle install'

build: ## Production build into _site/ (JEKYLL_ENV=production, like CI)
	$(NIX_SHELL) --run 'cd $(CURDIR) && $(BUILD_ENV) JEKYLL_ENV=production bundle exec jekyll build'

purge: build ## Build, then strip unused CSS from _site/ (CI's PurgeCSS step; uses system node)
	npx --yes purgecss -c purgecss.config.js

serve: ## Serve at http://127.0.0.1:4000/ (HOST=/PORT= to override; polling watcher — inotify is dead on FUSE)
	$(NIX_SHELL) --run 'cd $(CURDIR) && $(BUILD_ENV) bundle exec jekyll serve --host $(HOST) --port $(PORT) --force_polling'

clean: ## Remove generated site and build caches
	rm -rf _site .jekyll-cache

distclean: clean ## Also remove the installed gem bundle (path matches .bundle/config)
	rm -rf ~/.cache/wenri-blog/bundle
