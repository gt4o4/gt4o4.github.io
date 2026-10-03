const portfolioLink = document.querySelector('[data-portfolio-link]');

if (portfolioLink) {
  const portfolioOriginHash = 'ff706c9166929b5cb1056c3a90e8cc45aa87e5f8dff6b06090fb97a026f952bc';
  const storageKey = 'wenri:portfolio-origin';

  async function verifiedOrigin(value) {
    try {
      const origin = new URL(value).origin;
      const digest = await window.crypto.subtle.digest('SHA-256', new TextEncoder().encode(origin));
      const hash = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
      return hash === portfolioOriginHash ? origin : null;
    } catch {
      // Missing or malformed URLs and unavailable Web Crypto keep the default link.
      return null;
    }
  }

  let portfolioOrigin = await verifiedOrigin(document.referrer);

  try {
    if (portfolioOrigin) {
      window.localStorage.setItem(storageKey, portfolioOrigin);
    } else {
      portfolioOrigin = await verifiedOrigin(window.localStorage.getItem(storageKey));
    }
  } catch {
    // When storage is blocked, a recognized arrival still works on this page.
  }

  if (portfolioOrigin) {
    portfolioLink.href = `${portfolioOrigin}/`;
  }
}
