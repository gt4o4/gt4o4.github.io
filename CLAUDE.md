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

There are **no test or lint steps**. CI is Ruby 3.3.5 / Node 20.

### Deployment

`.github/workflows/jekyll.yml` auto-deploys on push to `main` (or `master`): Jekyll production build → PurgeCSS → GitHub Pages. The default branch is `main`; open PRs against `main`.

## Architecture notes that aren't obvious from a single file

**JS is loaded as native ES modules via an import map — there is no bundler step.** `_includes/scripts.html` declares an `<script type="importmap">` mapping bare specifiers (`jquery`, `lity`, `jquery-smooth-scroll`) to **esm.sh** CDN URLs, then loads `assets/js/main.js` and `assets/js/plugins/table-of-contents.js` as `<script type="module">`. Those source files `import` the mapped specifiers directly. To add/change a JS dependency, edit the import map, not a build config.

**The old npm/uglify build pipeline is dead — do not run it.** `package.json`'s `build:js`/`uglify` scripts and `banner.js` reference `assets/js/plugins/lity.js`, `jquery.smooth-scroll.js`, and `main.min.js`, none of which still exist (only `table-of-contents.js` remains in `plugins/`). Nothing in the templates references `main.min.js`. Ignore these; the import-map setup replaced them.

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

- `_config.yml` mixes the theme's v3 `author:` block with a legacy v2 `owner:` block. Some legacy keys don't map to the current includes — e.g. the Disqus include reads `site.disqus.shortname`, but the config only defines `owner.disqus-shortname`, so comments aren't actually wired up. Don't assume an `owner.*` value is live; check the include that consumes it.
- Plugins are listed under the deprecated `gems:` key (jekyll-sitemap, jekyll-feed, jekyll-paginate). Analytics and Disqus only render when `JEKYLL_ENV=production`.
