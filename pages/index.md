---
layout: page
title: Pages
excerpt: "An archive of page posts sorted by date."
permalink: /pages/
search_omit: true
---

<ul class="post-list">
{% for post in site.categories.pages %} 
  <li><article><a href="{{ post.url | relative_url }}">{{ post.title }} <span class="entry-date"><time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%B %d, %Y" }}</time></span>{% if post.excerpt %} <span class="excerpt">{{ post.excerpt | remove: '\[ ... \]' | remove: '\( ... \)' | markdownify | strip_html | strip_newlines | escape_once }}</span>{% endif %}</a></article></li>
{% endfor %}
</ul>
