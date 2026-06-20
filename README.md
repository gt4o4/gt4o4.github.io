# Wenri JUSHI

Personal blog of Bingchen Gong — published at **[www.wenri.me](http://www.wenri.me)**.

Built with [Jekyll](https://jekyllrb.com/) on a customized fork of the [So Simple](https://github.com/mmistakes/so-simple-theme) theme, and deployed to GitHub Pages. Longer-form writing lives at **[s2.hk](https://s2.hk)**.

## Local development

Requires Ruby + Bundler (and Node for the CSS-purge step).

```bash
bundle install
bundle exec jekyll serve   # serves at http://localhost:4000
```

## Build & deploy

Pushing to `main` triggers [`.github/workflows/jekyll.yml`](.github/workflows/jekyll.yml), which:

1. builds with `JEKYLL_ENV=production bundle exec jekyll build`,
2. strips unused CSS via PurgeCSS (`purgecss.config.js`), and
3. publishes `_site/` to GitHub Pages (custom domain set by `CNAME`).

To reproduce the production build locally:

```bash
JEKYLL_ENV=production bundle exec jekyll build
purgecss -c purgecss.config.js
```

## Writing posts

Posts live in `_posts/` as `YYYY-MM-DD-title.md`. Defaults (`layout: post`, social sharing) come from `_config.yml`, so front matter stays minimal:

```yaml
---
title: "Post title"
excerpt: "One-line summary used in listings and search."
date: 2024-12-02
---
```

Markdown is kramdown (GitHub-flavored) with Rouge highlighting, auto heading IDs, and an optional table of contents (`{% include toc %}`). MathJax is enabled site-wide. Top-nav links are in `_data/navigation.yml`.

## How it's wired

- **No JS bundler.** Scripts load as native ES modules through an import map in [`_includes/scripts.html`](_includes/scripts.html); `assets/js/main.js` imports jQuery, Lity, and smooth-scroll by bare specifier.
- **No vendored dependencies.** Libraries and fonts come from privacy-friendly CDNs (esm.sh, fonts.bunny.net, cdnjs, unpkg) rather than local files or Google Fonts.
- **Search** is [Lunr](https://lunrjs.com/) over a build-time index (`assets/js/search-data.js`), loaded only on the `/search/` page.
- **Styles** are SCSS (`assets/css/main.scss` + `_sass/`), compiled by Jekyll and pruned by PurgeCSS in CI.

See [`CLAUDE.md`](CLAUDE.md) for a fuller architecture tour and gotchas.

## Credits & license

Theme: [So Simple](https://github.com/mmistakes/so-simple-theme) by [Michael Rose](https://mademistakes.com), used under the MIT license — see [`LICENSE`](LICENSE). The theme's own documentation is upstream; a copy of its v2 docs remains in [`README-OLD.md`](README-OLD.md), and the `docs/` and `example/` folders hold the theme's demo content (excluded from the build).
