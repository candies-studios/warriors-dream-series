/*
 * WDS live content — fills the existing page markup from the shared database.
 *
 *  - Home:   "Upcoming" card + the Events archive grid
 *  - Events: "Upcoming" panel + the season schedule grid
 *  - Event:  pages/event.html?e=<slug> — status, details, fight card, final results
 *
 * Cards are cloned from the first card already in the page, so the design is
 * exactly the existing one. If the database cannot be reached, the static
 * content already in the HTML stays as it is.
 */
(function () {
  'use strict';
  if (!window.WDS || !window.WDS.enabled) return;
  var W = window.WDS;

  // Site root relative to this page ("" on the home page, "../" in /pages).
  var script = document.currentScript;
  var BASE = script ? (script.getAttribute('src') || '').replace(/js\/wds-live\.js(\?.*)?$/, '') : '';

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function asset(url) {
    if (!url) return BASE + 'assets/images/footer-fight.jpg';
    return /^(https?:|data:|\/)/.test(url) ? url : BASE + url;
  }
  function eventUrl(ev) {
    if (ev.page_url) return /^(https?:|\/)/.test(ev.page_url) ? ev.page_url : BASE + ev.page_url;
    return BASE + 'pages/event.html?e=' + encodeURIComponent(ev.slug);
  }
  function setText(el, value) { if (el && value != null) el.textContent = value; }
  // Replace only the leading text of a button/badge, keeping its icon markup.
  function setLeadText(el, value) {
    if (!el) return;
    var node = Array.prototype.find.call(el.childNodes, function (n) { return n.nodeType === 3 && n.textContent.trim(); });
    // Keep the node's own surrounding whitespace so markup stays identical.
    if (node) node.textContent = node.textContent.replace(/\S(?:[\s\S]*\S)?/, value);
    else el.insertBefore(document.createTextNode(value + ' '), el.firstChild);
  }
  function hasCard(ev, counts) { return (counts[ev.id] || 0) > 0 || !!ev.page_url; }

  // ---------------------------------------------------------------- cards
  function fillCard(card, ev, counts) {
    var img = card.querySelector('.ev-poster img');
    if (img) { img.src = asset(ev.poster_url); img.alt = ev.title; }
    setText(card.querySelector('.ev-status'), W.statusLabel(ev.status));
    setText(card.querySelector('.ev-tag'), W.seriesLabel(ev.series, ev));
    setText(card.querySelector('.ev-title'), ev.title);
    setText(card.querySelector('.ev-venue span'), W.formatVenue(ev) || 'To Be Announced');
    setText(card.querySelector('.ev-date span'), W.formatDate(ev) || 'Date TBA');
    if (card.hasAttribute('data-category') || card.closest('.archive-section')) card.setAttribute('data-category', ev.series);
    var btn = card.querySelector('.ev-btn');
    if (btn) {
      var internal = hasCard(ev, counts) || !ev.results_url;
      btn.href = internal ? eventUrl(ev) : ev.results_url;
      if (internal) { btn.removeAttribute('target'); btn.removeAttribute('rel'); }
      else { btn.target = '_blank'; btn.rel = 'noopener'; }
      setLeadText(btn, ev.status === 'completed' ? 'View Results' : ev.status === 'live' ? 'Live Fight Card' : 'Fight Card');
    }
    card.setAttribute('data-wds-event', ev.slug);
    return card;
  }

  function renderGrid(grid, list, counts) {
    var template = grid.__wdsTemplate || (grid.__wdsTemplate = grid.querySelector('.ev-card'));
    if (!template || !list.length) return;
    var frag = document.createDocumentFragment();
    list.forEach(function (ev) { frag.appendChild(fillCard(template.cloneNode(true), ev, counts)); });
    grid.innerHTML = '';
    grid.appendChild(frag);
    // Re-apply the active category filter (Home page).
    var active = document.querySelector('.event-filters button.active');
    if (active && active.dataset.filter && active.dataset.filter !== 'all') active.click();
  }

  // ---------------------------------------------------------------- "Upcoming" blocks
  function linkButton(existing, href, label, className) {
    var a = existing && existing.tagName === 'A' ? existing : document.createElement('a');
    a.className = className;
    a.href = href;
    a.textContent = label;
    if (existing && existing !== a) existing.replaceWith(a);
    return a;
  }

  function fillHomeUpcoming(card, ev, counts) {
    var badge = card.querySelector('.status-badge');
    if (badge) setLeadText(badge, ev.status === 'live' ? 'Live Now' : ev.status === 'completed' ? 'Event Ended' : 'Upcoming');
    if (badge) badge.classList.toggle('is-live', ev.status === 'live');
    setText(card.querySelector('.series-label'), W.seriesLabel(ev.series, ev));
    setText(card.querySelector('h2'), ev.title);
    var desc = card.querySelector('.upcoming-description');
    if (ev.description && desc) desc.innerHTML = esc(ev.description).replace(/\n/g, '<br>');
    var details = card.querySelectorAll('.upcoming-detail span');
    setText(details[0], W.formatDate(ev) || 'Coming Soon');
    setText(details[1], W.formatTime(ev) || 'TBA');
    setText(details[2], W.formatVenue(ev) || 'To Be Announced');
    var link = card.querySelector('.wds-card-link');
    if (hasCard(ev, counts) || ev.status === 'live') {
      if (!link) { link = document.createElement('a'); card.appendChild(link); }
      linkButton(link, eventUrl(ev), ev.status === 'live' ? 'Live Fight Card' : ev.status === 'completed' ? 'View Results' : 'View Fight Card', 'wds-card-link');
    } else if (link) {
      link.remove();
    }
  }

  function fillEventsUpcoming(section, ev, counts, opts) {
    var left = section.querySelector('.eu-left h2');
    var leftLabel = opts && opts.leftLabel ? opts.leftLabel(ev) : (ev.status === 'live' ? 'Live Now' : 'Upcoming');
    setText(left, leftLabel);
    setText(section.querySelector('.eu-title'), ev.title);
    var values = section.querySelectorAll('.eu-value');
    setText(values[0], (opts && opts.dateText ? opts.dateText(ev) : W.formatDate(ev)) || 'TBA');
    setText(values[1], W.formatTime(ev) || 'TBA');
    setText(values[2], W.formatVenue(ev) || 'TBA');
    var cta = section.querySelector('.eu-cta');
    if (!cta) {
      // Template band without a button: add one only when there is a card to show.
      if (!(hasCard(ev, counts) || ev.status === 'live') || (opts && opts.cta)) return;
      cta = document.createElement('a');
      var right = section.querySelector('.eu-right') || section;
      right.appendChild(cta);
    }
    if (opts && opts.cta) { opts.cta(cta); return; }
    if (hasCard(ev, counts) || ev.status === 'live') {
      linkButton(cta, eventUrl(ev), ev.status === 'live' ? 'Live Fight Card' : ev.status === 'completed' ? 'View Results' : 'View Fight Card', 'eu-cta');
    } else if (section.classList.contains('eu-live')) {
      cta.remove();
    } else {
      var span = document.createElement('span');
      span.className = 'eu-cta';
      span.textContent = ev.status === 'cancelled' ? 'Cancelled' : 'Coming Soon';
      cta.replaceWith(span);
    }
  }

  // ---------------------------------------------------------------- fight card
  function pointsBlock(p) {
    if (!p) return '';
    return '<span class="wds-points">' +
      '<span class="wds-points-how">' + esc(W.outcomeText(p)) + '</span>' +
      '<span class="wds-points-line">Method pts <strong>' + (p.outcome === 'W' ? '+' : '') + W.num(p.method_weight).toFixed(2) + '</strong>' +
      ' · Score <strong>' + W.num(p.score_after).toFixed(2) + '</strong> <em class="' +
      (W.num(p.score_change) < 0 ? 'is-down' : W.num(p.score_change) > 0 ? 'is-up' : '') + '">(' + W.signed(p.score_change) + ')</em></span>' +
      '<span class="wds-points-line">Record ' + p.wins_after + '-' + p.losses_after + (p.draws_after ? '-' + p.draws_after : '') + '</span>' +
      '</span>';
  }

  function boutRow(b, eventStatus, points) {
    points = points || {};
    var res = W.describeResult(b);
    var state = b.status === 'LIVE' ? 'Live'
      : b.result_status === 'final' ? 'Final'
      : b.result_status === 'pending' ? 'Result pending'
      : b.status === 'CANCELLED' ? 'Cancelled' : (eventStatus === 'completed' ? 'Result pending' : 'Scheduled');
    var tags = ['Bout ' + b.bout_number, b.weight_class || b.bout_name, (b.bout_type === 'AMATEUR' ? 'Amateur ' : 'Pro ') + (b.discipline || 'MMA')]
      .filter(Boolean).join(' · ');
    function corner(side, name, nick, id) {
      var winner = res && b.winner_id && b.winner_id === id;
      return '<div class="wds-corner wds-' + side + (winner ? ' is-winner' : '') + (res && b.winner_id && !winner ? ' is-loser' : '') + '">' +
        '<span class="wds-corner-label">' + (side === 'blue' ? 'Blue corner' : 'Red corner') + (winner ? ' · Winner' : '') + '</span>' +
        '<span class="wds-name">' + esc(name || 'To be announced') + '</span>' +
        (nick ? '<span class="wds-nick">“' + esc(nick) + '”</span>' : '') +
        (res ? pointsBlock(points[b.id + ':' + id]) : '') + '</div>';
    }
    return '<article class="wds-bout' + (b.status === 'LIVE' ? ' is-live' : '') + (res ? ' is-final' : '') + '">' +
      '<div class="wds-bout-head"><span class="ev-tag">' + esc(tags) + '</span><span class="wds-bout-state">' + esc(state) + '</span></div>' +
      '<div class="wds-bout-body">' + corner('blue', b.blue_name, b.blue_nickname, b.blue_fighter_id) +
      '<div class="wds-vs">VS</div>' + corner('red', b.red_name, b.red_nickname, b.red_fighter_id) + '</div>' +
      (res ? '<p class="wds-result">' + esc(res.winner ? res.winner + ' wins' : 'No winner') + ' <span>· ' + esc(res.method) + '</span></p>' : '') +
      '</article>';
  }

  function upcomingEvents(events) {
    var rank = { live: 0, scheduled: 1, announced: 2 };
    return events.filter(function (e) { return e.status in rank; }).sort(function (a, b) {
      if (rank[a.status] !== rank[b.status]) return rank[a.status] - rank[b.status];
      var ta = a.starts_at ? Date.parse(a.starts_at) : Infinity, tb = b.starts_at ? Date.parse(b.starts_at) : Infinity;
      return ta - tb;
    });
  }

  var NBSP = '\u00a0';
  function fillMeta(meta, value, sub) {
    if (!meta) return;
    setText(meta.querySelector('.wds-ue-value'), value);
    setText(meta.querySelector('.wds-ue-sub'), sub || NBSP);
  }

  // Home: <div class="wds-ue-list"> of <article class="wds-ue-event">
  function fillUeEvent(article, ev, counts) {
    setText(article.querySelector('.wds-ue-series'), W.seriesLabel(ev.series, ev));
    var linked = hasCard(ev, counts) || ev.status === 'live';
    var title = article.querySelector('.wds-ue-title');
    if (title) {
      if (linked) title.innerHTML = '<a href="' + esc(eventUrl(ev)) + '">' + esc(ev.title) + '</a>';
      else title.textContent = ev.title;
    }
    var desc = article.querySelector('.wds-ue-desc');
    if (desc) { desc.textContent = ev.description || ''; desc.hidden = !ev.description; }
    var link = article.querySelector('.wds-ue-link');
    if (linked) {
      if (!link) {
        link = document.createElement('a');
        link.className = 'wds-ue-link';
        (article.querySelector('.wds-ue-info') || article).appendChild(link);
      }
      link.href = eventUrl(ev);
      link.innerHTML = esc(ev.status === 'live' ? 'Live Fight Card' : ev.status === 'completed' ? 'View Results' : 'View Fight Card') + ' <span aria-hidden="true">›</span>';
    } else if (link) {
      link.remove();
    }
    var metas = article.querySelectorAll('.wds-ue-meta');
    var d = W.dateParts(ev);
    fillMeta(metas[0], d.value, d.sub);
    var time = W.formatTime(ev);
    fillMeta(metas[1], time || 'TBA', time ? 'Onwards' : '');
    fillMeta(metas[2], ev.venue || 'TBA', ev.city || '');
    article.setAttribute('data-wds-event', ev.slug);
    return article;
  }

  function renderUeList(listEl, list, counts) {
    var template = listEl.__wdsTemplate || (listEl.__wdsTemplate = listEl.querySelector('.wds-ue-event'));
    if (!template || !list.length) return;
    var frag = document.createDocumentFragment();
    list.forEach(function (ev) { frag.appendChild(fillUeEvent(template.cloneNode(true), ev, counts)); });
    listEl.innerHTML = '';
    listEl.appendChild(frag);
  }

  // Events page: one <section class="event-upcoming eu-live"> band per upcoming event
  function renderEuBands(list, counts) {
    var bands = Array.prototype.slice.call(document.querySelectorAll('.event-upcoming.eu-live'));
    if (!bands.length || !list.length) return;
    var holder = window.__wdsEuTemplate || (window.__wdsEuTemplate = bands[0].cloneNode(true));
    var anchor = bands[0];
    var frag = document.createDocumentFragment();
    list.forEach(function (ev) {
      var band = holder.cloneNode(true);
      band.className = 'event-upcoming eu-live';
      fillEventsUpcoming(band, ev, counts, { dateText: W.dateText });
      band.setAttribute('data-wds-event', ev.slug);
      frag.appendChild(band);
    });
    anchor.parentNode.insertBefore(frag, anchor);
    bands.forEach(function (b) { b.remove(); });
  }

  function latest(events) {
    return events.filter(function (e) { return e.status === 'completed' && e.event_date; })
      .sort(function (a, b) { return a.event_date < b.event_date ? 1 : -1; })[0] || null;
  }

  // ---------------------------------------------------------------- pages
  function homePage(events, counts) {
    var ueList = document.querySelector('.wds-ue-list');
    if (ueList) {
      var coming = upcomingEvents(events);
      renderUeList(ueList, coming.length ? coming : [latest(events)].filter(Boolean), counts);
    }
    var upcoming = document.querySelector('.upcoming-section .upcoming-card');
    var ev = W.featured(events);
    // Nothing announced yet: the card shows the latest event and its results.
    var shown = ev || latest(events);
    if (upcoming && shown) fillHomeUpcoming(upcoming, shown, counts);
    var grid = document.querySelector('.archive-section .ev-grid');
    if (grid) {
      var past = events.filter(function (e) { return e.status === 'completed' || (e.status === 'live' && e !== ev); });
      renderGrid(grid, past.slice(0, 5), counts);
    }
  }

  function eventsPage(events, counts) {
    var ev = W.featured(events);
    if (document.querySelector('.event-upcoming.eu-live')) {
      var coming = upcomingEvents(events);
      renderEuBands(coming.length ? coming : [latest(events)].filter(Boolean), counts);
    } else {
      // Original single "Upcoming" panel layout.
      var block = document.querySelector('.event-upcoming');
      var shown = ev || latest(events);
      if (block && shown) fillEventsUpcoming(block, shown, counts, ev ? null : {
        leftLabel: function () { return 'Latest'; },
      });
    }
    var grid = document.querySelector('.season-section .ev-grid');
    if (grid) {
      var year = new Date().getFullYear();
      var gridSection = grid.closest('.season-section');
      var gridTitle = gridSection && gridSection.querySelector('.season-title');
      var pastOnly = !!gridTitle && /past/i.test(gridTitle.textContent);
      var season = events.filter(function (e) {
        if (e === ev || e.status === 'cancelled') return false;
        if (pastOnly) return e.status === 'completed';
        var y = e.event_date ? +e.event_date.slice(0, 4) : year;
        return y === year || e.status !== 'completed';
      });
      renderGrid(grid, season, counts);
      var title = document.querySelector('.season-title');
      if (title && /\d{4}/.test(title.textContent)) title.textContent = title.textContent.replace(/\d{4}/, String(year));
    }
  }

  function eventPage() {
    var slug = new URLSearchParams(location.search).get('e');
    var root = document.getElementById('wds-fight-card');
    if (!slug || !root) return Promise.resolve();
    return W.eventBySlug(slug).then(function (ev) {
      if (!ev) { root.innerHTML = '<p class="wds-empty">This event could not be found.</p>'; return; }
      document.title = ev.title + ' — Warriors Dream Series';
      setText(document.querySelector('.page-hero h1'), ev.title);
      var hero = document.querySelector('.page-hero');
      if (hero && ev.poster_url) hero.style.backgroundImage = "url('" + asset(ev.poster_url) + "')";
      return Promise.all([W.card(ev.id), W.boutPoints(ev.id).catch(function () { return []; })]).then(function (r) {
        var bouts = r[0];
        var points = {};
        r[1].forEach(function (p) { points[p.bout_id + ':' + p.fighter_id] = p; });
        var block = document.querySelector('.event-upcoming');
        if (block) fillEventsUpcoming(block, ev, {}, {
          leftLabel: function (e) { return W.statusLabel(e.status) === 'Event Ended' ? 'Results' : W.statusLabel(e.status); },
          cta: function (cta) {
            if (ev.results_url && !bouts.length) linkButton(cta, ev.results_url, 'Full Results', 'eu-cta').target = '_blank';
            else { var s = document.createElement('span'); s.className = 'eu-cta'; s.textContent = W.seriesLabel(ev.series); cta.replaceWith(s); }
          },
        });
        var heading = document.querySelector('.wds-card-title');
        if (heading) heading.textContent = ev.status === 'completed' ? 'Results' : 'Fight Card';
        if (!bouts.length) {
          root.innerHTML = '<p class="wds-empty">' + (ev.status === 'completed'
            ? 'Results for this event are not available here yet.'
            : 'The fight card will be announced soon.') + '</p>';
          return;
        }
        root.innerHTML = bouts.map(function (b) { return boutRow(b, ev.status, points); }).join('');
      });
    });
  }

  function refresh() {
    var isEventPage = !!document.getElementById('wds-fight-card');
    if (isEventPage) return eventPage().catch(warn);
    return Promise.all([W.events(), W.cardCounts()]).then(function (r) {
      homePage(r[0], r[1]);
      eventsPage(r[0], r[1]);
    }).catch(warn);
  }
  function warn(e) { console.warn('[wds] showing saved page content:', e && e.message); }

  function start() {
    refresh();
    W.subscribe(document.getElementById('wds-fight-card') ? ['events', 'bout_points'] : ['events'], refresh);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
