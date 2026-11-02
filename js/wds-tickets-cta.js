/*
 * WDS site extras (included on Home, Events, event and fight card pages):
 *
 *  1. BOOK NOW buttons for the events listed in `onsale`, placed in a row next
 *     to the event's "View Fight Card" link (Home card, Events page band), and
 *     under the heading of the event's own fight card page.
 *  2. Event image overrides from `images`: a separate hero banner (event page)
 *     and card thumbnail (Home / Events lists) per event.
 *
 * Cards are rebuilt from the database by js/wds-live.js, so this watches the
 * page and re-applies after every render.
 *
 * Include before </body>:  <script src="js/wds-tickets-cta.js"></script>
 *                (in /pages: <script src="../js/wds-tickets-cta.js"></script>)
 */
(function () {
  'use strict';

  var script = document.currentScript;
  var BASE = script ? (script.getAttribute('src') || '').replace(/js\/wds-tickets-cta\.js(\?.*)?$/, '') : '';

  // Events with BOOK NOW. Remove an entry to hide its buttons.
  var onsale = [{ slug: 'wds-fight-night-19', title: 'WDS Fight Night 19', page_url: 'pages/wds-fight-night-19.html' }];

  // Per-event images (paths from the site root). `title` must match the event title.
  var images = [{
    slug: 'wds-rising-star-8',
    title: 'WDS Rising Star 8',
    hero: 'assets/images/wds-rising-star-8-hero.jpg',
    thumb: 'assets/images/wds-rising-star-8.jpg'
  }];

  function css() {
    if (document.getElementById('wds-tk-cta-css')) return;
    var s = document.createElement('style');
    s.id = 'wds-tk-cta-css';
    s.textContent =
      '.wds-cta-row{display:flex;flex-wrap:wrap;align-items:center;gap:12px}' +
      '.wds-cta-row>*{margin:0!important}' +
      // Default: sits level with the site's red "View Fight Card" button on Home.
      '.wds-buy-tickets{display:inline-flex;align-items:center;gap:8px;background:#fff;color:#d7272a!important;' +
      'font-family:Oswald,sans-serif;font-weight:600;font-size:.8rem;letter-spacing:2.3px;line-height:19.2px;text-transform:uppercase;' +
      'padding:10px 22px;margin:16px 0 0 10px;border-radius:0;text-decoration:none;' +
      'box-shadow:inset 0 0 0 2px #d7272a;transition:background .2s,color .2s}' +
      '.wds-buy-tickets:hover{background:#d7272a;color:#fff!important}' +
      '.wds-buy-tickets svg{width:15px;height:15px}' +
      // On the red Events page band: same size as its white "View Fight Card" button.
      '.wds-buy-tickets--band{background:#111;color:#fff!important;box-shadow:none;padding:16px 40px;font-size:.88rem;font-weight:700;letter-spacing:3px;line-height:normal}' +
      '.wds-buy-tickets--band:hover{background:#fff;color:#c00101!important}' +
      // Fight card page, under the heading.
      '.wds-buy-tickets--hero{background:#d7272a;color:#fff!important;font-size:1rem;padding:14px 30px;margin:18px 0 6px;box-shadow:0 10px 26px -10px rgba(215,39,42,.9)}' +
      '.wds-buy-tickets--hero:hover{background:#fff;color:#050505!important}';
    document.head.appendChild(s);
  }

  function ticketUrl(ev) { return BASE + 'tickets/' + encodeURIComponent(ev.slug) + '/'; }

  function pointsTo(a, ev) {
    var href = a.getAttribute('href') || '';
    if (!href || a.classList.contains('wds-buy-tickets')) return false;
    if (href.indexOf('event.html?e=' + ev.slug) !== -1) return true;
    var page = ev.page_url ? ev.page_url.split('/').pop() : ev.slug + '.html';
    return href.split('?')[0].split('#')[0].split('/').pop() === page;
  }

  function button(ev, extra) {
    var a = document.createElement('a');
    a.className = 'wds-buy-tickets' + (extra ? ' ' + extra : '');
    a.href = ticketUrl(ev);
    a.setAttribute('data-event', ev.slug);
    a.setAttribute('aria-label', 'Book tickets for ' + ev.title);
    a.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M3 7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v3a2 2 0 0 0 0 4v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-3a2 2 0 0 0 0-4V7zm6 0v10h2V7H9z"/></svg><span>Book Now</span>';
    return a;
  }

  /* Put the existing link and BOOK NOW side by side in one row. */
  function addBeside(a, ev) {
    var parent = a.parentElement;
    if (!parent || parent.classList.contains('wds-cta-row')) return;
    var cs = getComputedStyle(a);
    var row = document.createElement('div');
    row.className = 'wds-cta-row';
    row.style.marginTop = cs.marginTop;
    var centred = getComputedStyle(parent).textAlign === 'center';
    row.style.justifyContent = centred ? 'center' : 'flex-start';
    parent.insertBefore(row, a);
    row.appendChild(a);
    row.appendChild(button(ev, a.classList.contains('eu-cta') ? 'wds-buy-tickets--band' : ''));
  }

  /* A card cloned from one that had our row may carry a button for the wrong event. */
  function tidy() {
    document.querySelectorAll('.wds-cta-row').forEach(function (row) {
      var link = row.querySelector('a:not(.wds-buy-tickets)');
      var btn = row.querySelector('.wds-buy-tickets');
      var ev = btn && onsale.filter(function (e) { return e.slug === btn.getAttribute('data-event'); })[0];
      if (link && ev && pointsTo(link, ev)) return;
      if (btn) btn.remove();
      if (link) row.parentElement.insertBefore(link, row);
      row.remove();
    });
  }

  function applyImages() {
    images.forEach(function (im) {
      var thumb = BASE + im.thumb;
      document.querySelectorAll('img').forEach(function (img) {
        if ((img.getAttribute('alt') || '').trim().toLowerCase() !== im.title.toLowerCase()) return;
        if (!img.closest('.ev-poster, .ev-card, .event-card')) return;
        if (img.getAttribute('src') !== thumb) img.setAttribute('src', thumb);
      });
      var onEventPage = /event\.html$/.test(location.pathname) &&
        new URLSearchParams(location.search).get('e') === im.slug;
      var hero = onEventPage && document.querySelector('.page-hero');
      var bg = "url('" + BASE + im.hero + "')";
      if (hero && hero.style.backgroundImage !== bg) hero.style.backgroundImage = bg;
    });
  }

  function apply() {
    applyImages();
    if (!onsale.length) return;
    css();
    tidy();
    onsale.forEach(function (ev) {
      document.querySelectorAll('a[href]').forEach(function (a) {
        if (!pointsTo(a, ev)) return;
        if (a.closest('.site-nav, .footer-nav, h1, h2, h3, h4')) return; // titles and menus keep their plain link
        addBeside(a, ev);
      });
      var onPage = location.pathname.split('/').pop() === (ev.page_url || '').split('/').pop();
      var heading = onPage && document.querySelector('.fn19-heading, .event-hero .hero-inner, main h1');
      if (heading && !document.querySelector('.wds-buy-tickets--hero')) {
        var target = heading.matches('h1') ? heading : heading.lastElementChild || heading;
        target.insertAdjacentElement('afterend', button(ev, 'wds-buy-tickets--hero'));
      }
    });
  }

  var queued = false;
  function schedule() {
    if (queued) return;
    queued = true;
    setTimeout(function () { queued = false; apply(); }, 120);
  }

  apply();
  new MutationObserver(function (muts) {
    for (var i = 0; i < muts.length; i++) {
      var m = muts[i];
      if (m.type === 'attributes') { schedule(); return; }
      for (var j = 0; j < m.addedNodes.length; j++) {
        var n = m.addedNodes[j];
        if (n.nodeType === 1 && !n.classList.contains('wds-buy-tickets') && !n.classList.contains('wds-cta-row')) { schedule(); return; }
      }
    }
  }).observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['src', 'style'] });
})();
