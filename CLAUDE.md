# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal Jekyll blog ("Wenri JUSHI" by Bingchen Gong), deployed to GitHub Pages at **www.wenri.me** (see `CNAME`). It is a **fork of the "So Simple" theme v3.2.0** by Michael Rose, with the theme files vendored directly into the repo (no `remote_theme`/gem install — `_layouts`, `_includes`, `_sass`, `assets` are all local and edited in place).

The repo root is simultaneously the theme source *and* the site source. Most of the prose blog content actually lives at the external site **s2.hk**; this repo is the landing page, `about/`, `search/`, and a single welcome post.

## Commands

```bash
bundle install                              # install Ruby gems (deps come from the .gemspec, via Gemfile's `gemspec`)
bundle exec jekyll serve                    # local dev server at http://localhost:4000
JEKYLL_ENV=production bundle exec jekyll build   # production build into _site/ (sets canonical URLs, enables analytics/comments)
purgecss -c purgecss.config.js              # strip unused CSS from _site/ (CI step; run after a build)
```

There are **no test or lint steps**. CI is Ruby 4.0.3 / Node 22, matching the local nix toolchain (see `Makefile` / `nix/shell.nix`).

### Deployment

`.github/workflows/jekyll.yml` auto-deploys on push to `main`: Jekyll production build → PurgeCSS → GitHub Pages. The default branch is `main`; open PRs against `main`.

## Architecture notes that aren't obvious from a single file

**JS is loaded as native ES modules via an import map — there is no bundler step.** `_includes/scripts.html` declares an `<script type="importmap">` mapping bare specifiers (`jquery`, `lity`, `jquery-smooth-scroll`) to **esm.sh** CDN URLs, then loads `assets/js/main.js` and `assets/js/plugins/table-of-contents.js` as `<script type="module">`. Those source files `import` the mapped specifiers directly. To add/change a JS dependency, edit the import map, not a build config.

**There is no JS build/bundler step.** JS ships as native ES modules via the import map above — no minifier, no `npm` build. The old uglify/`npm-run-all` pipeline (`package.json`, `package-lock.json`, `banner.js`, and the minified `main.min.js`) was removed once the import map replaced it. To add or change a JS dependency, edit the import map — don't reintroduce a bundler.

**All third-party libs come from privacy-friendly CDNs — nothing is vendored.** esm.sh (jQuery, Lity, smooth-scroll, MathJax), fonts.bunny.net (web fonts, in `_includes/head.html` — replaces Google Fonts), cdnjs (Font Awesome, lunr.js), unpkg (lunr-languages). There are no local copies of these libraries.

**Search is Lunr with a build-time index.** `assets/js/search-data.js` is a Liquid template (`layout: null`) that emits a `store` JS array of every doc (title/excerpt/categories/tags/url) at build time. `_includes/lunr-search-scripts.html` builds the Lunr index from `store` and wires the `#search` input — it is only included on `layout: search` pages. Excerpt length and full-content indexing are controlled by `search_full_content` in `_config.yml`.

**CSS:** SCSS in `assets/css/main.scss` + `_sass/` compiles to `main.css` (Jekyll, `style: compressed`), then PurgeCSS prunes it in CI against the built HTML/JS (`purgecss.config.js`). Three skins live in `assets/css/skins/`.

**MathJax** is enabled site-wide (`mathjax: true`). `_includes/scripts.html` loads tex-svg from esm.sh and includes a custom `renderActions.find` hook to convert kramdown's `<script type="math/tex">` blocks into MathJax items.

## Authoring content

- Posts go in `_posts/` as `YYYY-MM-DD-title.md`. Front-matter defaults (`layout: post`, `share: true`) are set in `_config.yml`, so a post only needs `title`/`excerpt`/`date`.
- Permalinks are `/:categories/:title/`. Markdown is kramdown (GFM input) with Rouge highlighting; auto-generated heading IDs and TOC (`toc_levels: 1..2`).
- Top-nav links are in `_data/navigation.yml`; author info in `_config.yml` and `_data/authors.yml`.

## Upstream-theme artifacts — not part of this blog

`README.md`, `README-OLD.md`, `CHANGELOG.md`, `jekyll-theme-so-simple.gemspec`, `Rakefile`, `screenshot*.{png,jpg}`, and the `docs/` and `example/` folders are inherited from the upstream theme and document/demo the *distributable theme*, not this site. They're excluded from the build via `exclude:` in `_config.yml`. In particular, **ignore README's "Development" section** — `rake preview` serves the `example/` demo, not this blog; use `bundle exec jekyll serve` instead.

## Config gotchas

- The legacy v2 `owner:` block is trimmed to its one live key: `owner.google.verify` (Google site verification, read by `_includes/head.html`). Dormant hooks that exist in the includes but have no config value: Disqus comments (`site.disqus.shortname`, used by `_layouts/post.html`), Google Analytics (`site.google_analytics`, production-only, in `_includes/scripts.html`), and Bing verification (`site.owner.bing-verify`, in `head.html`). Set the key to activate the hook.
- `plugins:` enables jekyll-sitemap and jekyll-feed, so `sitemap.xml` and `feed.xml` are generated (`head.html` emits the matching feed `<link>`). jekyll-paginate is a gemspec dependency but deliberately not enabled — nothing sets `paginate:` or `page.paginate`; the homepage uses `posts-limit.html` (`limit: 10` in `index.md`).
