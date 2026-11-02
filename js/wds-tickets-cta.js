/*
 * WDS ticketing — adds BOOK NOW buttons across the existing site.
 *
 * Works with the database-driven cards (js/wds-live.js re-renders them), so it
 * watches the page and re-adds buttons after every render. Buttons appear only
 * for events whose ticket sales are switched on in the ticketing admin, next to
 * links that point at that event's page (Home card, Events page, fight card
 * page),
 *
 * Include before </body>:  <script src="js/wds-tickets-cta.js"></script>
 */
(function () {
  'use strict';

  var script = document.currentScript;
  var BASE = script ? (script.getAttribute('src') || '').replace(/js\/wds-tickets-cta\.js(\?.*)?$/, '') : '';
  // Events with BOOK NOW. Remove an entry to hide its buttons.
  var onsale = [{ slug: 'wds-fight-night-19', title: 'WDS Fight Night 19', page_url: 'pages/wds-fight-night-19.html' }];

  function css() {
    if (document.getElementById('wds-tk-cta-css')) return;
    var s = document.createElement('style');
    s.id = 'wds-tk-cta-css';
    s.textContent =
      // Sized to sit level with the site's own red "View Fight Card" button.
      '.wds-buy-tickets{display:inline-flex;align-items:center;align-self:flex-start;gap:8px;background:#fff;color:#d7272a!important;' +
      'font-family:Oswald,sans-serif;font-weight:600;font-size:.8rem;letter-spacing:2.3px;line-height:19.2px;text-transform:uppercase;' +
      'padding:10px 22px;margin:16px 0 0 10px;border-radius:0;text-decoration:none;vertical-align:baseline;' +
      'box-shadow:inset 0 0 0 2px #d7272a;transition:background .2s,color .2s}' +
      '.wds-buy-tickets:hover{background:#d7272a;color:#fff!important}' +
      '.wds-buy-tickets svg{width:15px;height:15px}' +
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
    a.setAttribute('aria-label', 'Book tickets for ' + ev.title);
    a.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M3 7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v3a2 2 0 0 0 0 4v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-3a2 2 0 0 0 0-4V7zm6 0v10h2V7H9z"/></svg><span>Book Now</span>';
    return a;
  }

  function apply() {
    if (!onsale.length) return;
    css();
    onsale.forEach(function (ev) {
      // 1. Next to "View Fight Card" style links in event cards / lists.
      document.querySelectorAll('a[href]').forEach(function (a) {
        if (!pointsTo(a, ev)) return;
        if (a.closest('.site-nav, .footer-nav, h1, h2, h3, h4')) return; // titles/nav keep their plain link
        var holder = a.parentElement;
        if (!holder || holder.querySelector(':scope > .wds-buy-tickets')) return;
        a.insertAdjacentElement('afterend', button(ev));
      });
      // 2. On the event's own fight card page, under the heading.
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
  // Cards are rebuilt from the database by wds-live.js; re-apply after each render.
  new MutationObserver(function (muts) {
    for (var i = 0; i < muts.length; i++) {
      var n = muts[i].addedNodes;
      for (var j = 0; j < n.length; j++) {
        if (n[j].nodeType === 1 && !(n[j].classList && n[j].classList.contains('wds-buy-tickets'))) { schedule(); return; }
      }
    }
  }).observe(document.body, { childList: true, subtree: true });
})();
