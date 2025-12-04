/*!
 * Table of Contents Toggle
 * https://github.com/smithtimmytim/brightlycolored.org
 * Copyright (c) 2017 Timothy B. Smith
 * Licensed MIT
 */

const tocToggle = document.getElementById('toc-toggle');
const tableOfContents = document.getElementById('markdown-toc');

function showToc(elem) {
  const getHeight = () => {
    elem.style.display = 'block';
    const height = elem.scrollHeight + 'px';
    elem.style.display = '';
    return height;
  };

  const height = getHeight();
  elem.classList.add('js-toc-is-open');
  elem.style.height = height;

  setTimeout(() => {
    elem.style.height = '';
  }, 350);
}

function hideToc(elem) {
  elem.style.height = elem.scrollHeight + 'px';

  setTimeout(() => {
    elem.style.height = '0';
  }, 1);

  setTimeout(() => {
    elem.classList.remove('js-toc-is-open');
  }, 350);
}

function toggleToc(elem) {
  tocToggle.classList.toggle('js-toc-is-open');

  if (elem.classList.contains('js-toc-is-open')) {
    hideToc(elem);
    return;
  }

  showToc(elem);
}

if (tocToggle) {
  tocToggle.addEventListener('click', () => {
    toggleToc(tableOfContents);
  });
}
