  // ---------------------------------------------------------------------------
  // Fighter profile: every bout of one fighter from the WDS database
  // (pages/fighter.html?id=<fighter id> or ?name=<fighter name>).
  // The Rankings page links here and passes the fighter's rank, division and score.
  // ---------------------------------------------------------------------------
  (function () {
    const params = new URLSearchParams(location.search);
    const root = document.getElementById('fighterRoot');
    // Site root relative to this page ("../" in /pages, "../../" on /fighters/<name>/).
    const dataScript = document.querySelector('script[src$="js/wds-data.js"]');
    const BASE = dataScript ? dataScript.getAttribute('src').replace(/js\/wds-data\.js$/, '') : '../';
    // Static profile pages carry the fighter id on <body data-fighter-id>.
    const STATIC_ID = document.body.getAttribute('data-fighter-id');
    const STATIC = window.WDS_STATIC || { events: {}, fighters: {} };
    const BACK = STATIC_ID ? { href: BASE + 'pages/events.html', text: 'Events' } : { href: BASE + 'pages/rankings.html', text: 'Rankings' };

    const RESULT_LABEL = {
      DECISION_UNANIMOUS: 'Decision - Unanimous', DECISION_SPLIT: 'Decision - Split', DECISION_MAJORITY: 'Decision - Majority',
      DRAW: 'Draw', MAJORITY_DRAW: 'Draw - Majority', SPLIT_DRAW: 'Draw - Split', KO_HEAD: 'KO', KO_BODY: 'KO (Body)', TKO: 'TKO',
      SUBMISSION: 'Submission', RNC: 'Submission', DOCTOR_STOPPAGE: 'TKO - Doctor Stoppage',
      CORNER_STOPPAGE: 'TKO - Corner Stoppage', DQ: 'Disqualification', NO_CONTEST: 'No Contest'
    };
    const KO = ['KO_HEAD', 'KO_BODY', 'TKO', 'DOCTOR_STOPPAGE', 'CORNER_STOPPAGE'];
    const SUB = ['SUBMISSION', 'RNC'];
    const DEC = ['DECISION_UNANIMOUS', 'DECISION_SPLIT', 'DECISION_MAJORITY', 'DQ'];
    // Same cut-out photos the Rankings page uses when the database has no photo.
    const FIGHTER_PHOTOS = {
      'jeko laishram': 'Jeko_Laishram.webp', 'gaganpal singh dua': 'Gaganpal_Singh.webp',
      'surbala devi laishram': 'Surbala_Laishram.webp', 'ashish rawat': 'Ashish_Rawat.webp',
      'ben holdsworth': 'Ben_Holdsworth.webp', 'bishal sahu': 'Bishal_Sahu.webp', 'edukondal rao': 'Edukondal_Rao.webp',
      'kimson tony': 'Kimson.webp', 'rohit raina': 'Rohit_Raina.webp', 'sagar ramdas dange': 'Sagar_Dange.webp',
      'sangramsingh godse': 'Sangramsingh_Godase.webp', 'thiaumuanlal guite': 'Thiaumuanlal_Guite.webp',
      'ajay singh dhoni': 'Ajay_Singh_Dhoni.webp'
    };
    const SILHOUETTE = '<svg viewBox="0 0 120 130" aria-hidden="true"><circle cx="60" cy="38" r="26" fill="currentColor"/><path d="M8 130c4-38 26-58 52-58s48 20 52 58z" fill="currentColor"/></svg>';
    const MONTHS = ['Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'Jun.', 'Jul.', 'Aug.', 'Sep.', 'Oct.', 'Nov.', 'Dec.'];

    const esc = v => String(v == null ? '' : v).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const norm = n => String(n || '').trim().toLowerCase().replace(/\s+/g, ' ');
    const clock = s => s == null ? '—' : Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
    const titleCase = s => String(s || '').toLowerCase().replace(/\b([a-z])/g, m => m.toUpperCase());
    function fmtDate(iso) {
      if (!iso) return 'Date TBA';
      const [y, m, d] = iso.split('-').map(Number);
      return `${MONTHS[m - 1]} ${d}, ${y}`;
    }
    function photoFor(name, url) {
      if (url) return url;
      const file = FIGHTER_PHOTOS[norm(name)];
      return file ? BASE + 'assets/images/' + file : null;
    }
    function profileUrl(id, name) {
      if (id && STATIC.fighters && STATIC.fighters[id]) return BASE + STATIC.fighters[id];
      return BASE + 'pages/fighter.html?' + (id ? 'id=' + encodeURIComponent(id) : 'name=' + encodeURIComponent(name));
    }
    function eventHref(x) {
      if (!x.slug) return '';
      if (x.status === 'completed' && STATIC.events && STATIC.events[x.slug]) return BASE + STATIC.events[x.slug];
      if (x.status !== 'completed' && x.pageUrl) return /^(https?:|\/)/.test(x.pageUrl) ? x.pageUrl : BASE + x.pageUrl;
      return BASE + 'pages/event.html?e=' + encodeURIComponent(x.slug);
    }
    let currentFilter = 'all';
    function showState(html) { root.innerHTML = `<div class="fp-state">${html}</div>`; }

    function loadFighter() {
      const W = window.WDS;
      if (!W || !W.enabled) return Promise.reject(new Error('offline'));
      const id = params.get('id') || STATIC_ID;
      const name = params.get('name');
      const query = id ? 'fighters?select=*&id=eq.' + encodeURIComponent(id)
                       : 'fighters?select=*&name_key=eq.' + encodeURIComponent(norm(name));
      if (!id && !name) return Promise.reject(new Error('missing'));
      return W.rest(query).then(rows => {
        if (!rows.length) throw new Error('not-found');
        const f = rows[0];
        return Promise.all([
          f,
          W.rest('public_bout_card?select=*&or=(red_fighter_id.eq.' + f.id + ',blue_fighter_id.eq.' + f.id + ')'),
          W.events()
        ]);
      });
    }

    // One row per bout, from this fighter's point of view.
    function toFights(f, bouts, events) {
      const eventsById = {};
      events.forEach(e => { eventsById[e.id] = e; });
      return bouts.map(b => {
        const isRed = b.red_fighter_id === f.id;
        const e = eventsById[b.event_id] || {};
        const final = b.result_status === 'final';
        let outcome = 'up';
        if (final) {
          if (b.result_type === 'NO_CONTEST') outcome = 'NC';
          else if (b.winner_id === f.id) outcome = 'W';
          else if (b.winner_id) outcome = 'L';
          else outcome = 'D';
        } else if (/COMPLETED/i.test(b.status || '') || b.result_status === 'provisional' || b.result_status === 'pending') {
          outcome = 'pending';
        }
        return {
          id: b.id,
          event: e.title || 'WDS event', slug: e.slug, status: e.status, pageUrl: e.page_url, date: e.event_date || b.bout_date || '',
          pro: b.bout_type === 'PROFESSIONAL', discipline: b.discipline || 'MMA',
          weightClass: b.weight_class || '', boutName: b.bout_name || '',
          opponent: isRed ? b.blue_name : b.red_name,
          opponentId: isRed ? b.blue_fighter_id : b.red_fighter_id,
          opponentPhoto: isRed ? b.blue_photo_url : b.red_photo_url,
          myPhoto: isRed ? b.red_photo_url : b.blue_photo_url,
          outcome, resultType: b.result_type, round: b.end_round, sec: b.end_time_sec, final
        };
      }).sort((a, b) => (b.date || '').localeCompare(a.date || '') || 0);
    }

    function record(fights) {
      const r = { W: 0, L: 0, D: 0, NC: 0, ko: 0, sub: 0, dec: 0, r1: 0 };
      fights.forEach(x => {
        if (!x.final) return;
        if (x.outcome in r) r[x.outcome]++;
        if (x.outcome === 'W') {
          if (KO.includes(x.resultType)) r.ko++;
          else if (SUB.includes(x.resultType)) r.sub++;
          else r.dec++;
          if (x.round === 1 && !DEC.includes(x.resultType)) r.r1++;
        }
      });
      r.text = `${r.W}-${r.L}-${r.D}` + (r.NC ? ` (${r.NC} NC)` : '');
      return r;
    }

    function headshot(name, url, plaque) {
      const photo = photoFor(name, url);
      const img = photo ? `<img src="${esc(photo)}" alt="${esc(name)}" loading="lazy" onerror="this.remove()">` : SILHOUETTE;
      return `<div class="fp-head">${img}${plaque || ''}</div>`;
    }

    function fightCard(f, x) {
      const plaqueMe = x.outcome === 'W' ? '<span class="fp-plaque">Win</span>'
        : x.outcome === 'D' ? '<span class="fp-plaque draw">Draw</span>'
        : x.outcome === 'NC' ? '<span class="fp-plaque nc">NC</span>' : '';
      const plaqueOpp = x.outcome === 'L' ? '<span class="fp-plaque">Win</span>' : '';
      const result = { W: 'Win', L: 'Loss', D: 'Draw', NC: 'No contest', up: 'Upcoming', pending: 'Result pending' }[x.outcome];
      const method = x.final ? (RESULT_LABEL[x.resultType] || titleCase(String(x.resultType || '').replace(/_/g, ' ')) || '—') : '—';
      const decision = /^DECISION|DRAW|NO_CONTEST/.test(x.resultType || '');
      const fightCardLink = x.slug ? `<a href="${esc(eventHref(x))}">Fight card ›</a>` : '';
      const oppLink = x.opponentId ? `<a href="${profileUrl(x.opponentId, x.opponent)}">${esc(x.opponent || 'TBA')}</a>` : esc(x.opponent || 'TBA');
      return `<article class="fp-fight" data-type="${x.pro ? 'pro' : 'am'}">
          <div class="fp-matchup">${headshot(f.name, x.myPhoto || f.photo_url, plaqueMe)}${headshot(x.opponent, x.opponentPhoto, plaqueOpp)}</div>
          <div>
            <h3 class="fp-fight-title"><span>${esc(f.name)}</span><span class="vs">vs</span>${oppLink}</h3>
            <p class="fp-fight-date">${esc(fmtDate(x.date))} · ${esc(x.event)}</p>
            <div class="fp-fight-tags">
              <span class="fp-chip result-${x.outcome === 'pending' ? 'up' : x.outcome}">${result}</span>
              <span class="fp-chip${x.pro ? ' pro' : ''}">${x.pro ? 'Professional' : 'Amateur'}${x.discipline !== 'MMA' ? ' ' + esc(x.discipline) : ''}</span>
              ${x.weightClass ? `<span class="fp-chip">${esc(x.weightClass)}</span>` : ''}
              ${/main event/i.test(x.boutName) ? `<span class="fp-chip">${esc(x.boutName)}</span>` : ''}
            </div>
            <div class="fp-results">
              <div><div class="fp-result-label">Round</div><div class="fp-result-text">${x.final && x.round ? x.round : '—'}</div></div>
              <div><div class="fp-result-label">Time</div><div class="fp-result-text">${x.final && x.sec != null && !(decision && !x.sec) ? clock(x.sec) : '—'}</div></div>
              <div><div class="fp-result-label">Method</div><div class="fp-result-text">${esc(method)}</div></div>
            </div>
          </div>
          <div class="fp-fight-links">${fightCardLink}</div>
        </article>`;
    }

    function bar(label, n, total) {
      const pct = total ? Math.round(100 * n / total) : 0;
      return `<div class="fp-bar"><div class="fp-bar-head"><span>${label}</span><span>${n} (${pct}%)</span></div>
        <div class="fp-bar-track"><div class="fp-bar-fill" style="width:${pct}%"></div></div></div>`;
    }

    function render(f, fights) {
      const pro = fights.filter(x => x.pro);
      const am = fights.filter(x => !x.pro);
      const proRec = record(pro);
      const amRec = record(am);
      const main = pro.some(x => x.final) ? proRec : amRec;           // hero stats: pro record when the fighter has one
      const mainLabel = main === proRec ? 'Pro' : 'Amateur';
      const done = fights.filter(x => x.final);
      const last = done[0];
      const next = fights.filter(x => x.outcome === 'up').sort((a, b) => (a.date || '').localeCompare(b.date || ''))[0];
      const rank = params.get('rank');
      const div = params.get('div') || f.weight_class || '';
      const score = params.get('score');
      const photo = photoFor(f.name, f.photo_url);
      if (!STATIC_ID) document.title = `${f.name} — Warriors Dream Series`;

      const tags = [];
      if (rank) tags.push(rank === 'C' ? `Champion · ${esc(div)}` : `#${esc(rank)} ${esc(div)}`);
      if (pro.length) tags.push('Professional');
      else if (am.length) tags.push('Amateur');
      if (f.public_id) tags.push(esc(f.public_id));

      const lastBox = last ? `<div class="fp-box">
          <p class="fp-box-label">Last fight · ${({ W: 'Win', L: 'Loss', D: 'Draw', NC: 'No contest' })[last.outcome]}</p>
          <p class="fp-box-title">${esc(f.name.split(' ').slice(-1)[0])}<span class="vs">vs</span>${esc((last.opponent || 'TBA').split(' ').slice(-1)[0])}</p>
          <p class="fp-box-meta">${esc(fmtDate(last.date))} · ${esc(last.event)}</p>
        </div>` : '';
      const nextBox = next ? `<div class="fp-box">
          <p class="fp-box-label">Upcoming fight</p>
          <p class="fp-box-title">${esc(f.name.split(' ').slice(-1)[0])}<span class="vs">vs</span>${esc((next.opponent || 'TBA').split(' ').slice(-1)[0])}</p>
          <p class="fp-box-meta">${esc(fmtDate(next.date))} · ${esc(next.event)}</p>
        </div>` : '';
      const scoreBox = score ? `<div class="fp-box"><p class="fp-box-label">WDS ranking score</p>
          <p class="fp-box-score"><strong>${esc(Number(score).toFixed(2))}</strong>${rank ? (rank === 'C' ? 'Champion' : 'Ranked #' + esc(rank)) + ' · ' + esc(div) : ''}</p></div>` : '';

      const total = main.ko + main.sub + main.dec;
      const filterBtns = (pro.length && am.length) ? `<div class="fp-filter" role="group" aria-label="Filter fights">
          <button type="button" data-filter="all">All (${fights.length})</button>
          <button type="button" data-filter="pro">Professional (${pro.length})</button>
          <button type="button" data-filter="am">Amateur (${am.length})</button></div>` : '';
      const social = f.social_url ? `<a href="${esc(f.social_url)}" target="_blank" rel="noopener">Profile ›</a>` : '';
      const info = [
        ['Status', 'Active'],
        ['Hometown', f.hometown ? titleCase(f.hometown) : ''],
        ['Trains at', f.team ? titleCase(f.team) : ''],
        ['Division', div],
        ['Pro record', pro.length ? proRec.text : ''],
        ['Amateur record', am.length ? amRec.text : ''],
        ['WDS debut', fights.length ? fmtDate(fights.filter(x => x.date).slice(-1)[0]?.date) : ''],
        ['Height', f.height || ''],
        ['Weight', f.weight || ''],
        ['Country', f.country || ''],
        ['Links', social]
      ].filter(r => r[1]);

      root.innerHTML = `
        <section class="fp-hero">
          <div class="fp-wrap">
            <div class="fp-hero-left">
              <a class="fp-back" href="${BACK.href}">‹ ${BACK.text}</a>
              <div class="fp-tags">${tags.map(t => `<span class="fp-tag">${t}</span>`).join('')}</div>
              ${f.nickname ? `<p class="fp-nick">"${esc(f.nickname)}"</p>` : ''}
              <h1 class="fp-name">${esc(f.name)}</h1>
              ${div ? `<p class="fp-division">${esc(div)} Division</p>` : ''}
              <p class="fp-record">${main.text} (W-L-D) · ${mainLabel}</p>
              <div class="fp-stats">
                <div class="fp-stat"><div class="fp-stat-num">${main.ko}</div><div class="fp-stat-label">Wins by<br>knockout</div></div>
                <div class="fp-stat"><div class="fp-stat-num">${main.sub}</div><div class="fp-stat-label">Wins by<br>submission</div></div>
              </div>
            </div>
            <div class="fp-photo${photo ? '' : ' no-photo'}">${photo ? `<img src="${esc(photo)}" alt="${esc(f.name)}" onerror="this.remove()">` : SILHOUETTE}</div>
            <div class="fp-hero-right">${lastBox}${nextBox}${scoreBox}<a class="fp-history-btn" href="#fight-history">View fight history</a></div>
          </div>
        </section>

        <div class="fp-wrap">
          <section class="fp-section">
            <h2 class="fp-h2">Stats &amp; Records</h2>
            <div class="fp-stats-grid">
              <div class="fp-card">
                <h3 class="fp-card-title">Win by method · ${mainLabel}</h3>
                ${bar('KO/TKO', main.ko, total)}${bar('Dec', main.dec, total)}${bar('Sub', main.sub, total)}
              </div>
              <div class="fp-card">
                <h3 class="fp-card-title">Record</h3>
                <div class="fp-split">
                  <div><p class="fp-big">${pro.length ? proRec.text : '—'}</p><p class="fp-big-label">Professional</p></div>
                  <div><p class="fp-big">${am.length ? amRec.text : '—'}</p><p class="fp-big-label">Amateur</p></div>
                </div>
              </div>
              <div class="fp-card">
                <h3 class="fp-card-title">Finishes · ${mainLabel}</h3>
                <div class="fp-split">
                  <div><p class="fp-big">${main.ko + main.sub}</p><p class="fp-big-label">Total finishes</p></div>
                  <div><p class="fp-big">${main.r1}</p><p class="fp-big-label">1st-round finishes</p></div>
                </div>
              </div>
            </div>
          </section>

          <section class="fp-section" id="fight-history">
            <h2 class="fp-h2">Athlete Record</h2>
            ${filterBtns}
            <div id="fpFights">${fights.length ? fights.map(x => fightCard(f, x)).join('') : '<p>No WDS fights recorded yet.</p>'}</div>
          </section>

          <section class="fp-section">
            <h2 class="fp-h2">Info</h2>
            <dl class="fp-info">${info.map(([k, v]) => `<div><dt>${k}</dt><dd>${k === 'Links' ? v : esc(v)}</dd></div>`).join('')}</dl>
          </section>
        </div>`;

      const applyFilter = want => {
        currentFilter = want;
        root.querySelectorAll('.fp-filter button').forEach(b => b.classList.toggle('active', b.dataset.filter === want));
        root.querySelectorAll('.fp-fight').forEach(el => { el.hidden = want !== 'all' && el.dataset.type !== want; });
      };
      root.querySelectorAll('.fp-filter button').forEach(btn => btn.addEventListener('click', () => applyFilter(btn.dataset.filter)));
      applyFilter(root.querySelector('.fp-filter') ? currentFilter : 'all');
    }

    function run() {
      return loadFighter().then(([f, bouts, events]) => render(f, toFights(f, bouts, events)));
    }

    document.addEventListener('DOMContentLoaded', () => {
      run()
        .then(() => window.WDS.subscribe && window.WDS.subscribe(['bouts', 'fighters', 'bout_points'], () => run().catch(() => {})))
        .catch(e => {
          const msg = e && e.message;
          if (msg === 'missing' || msg === 'not-found') {
            showState(`We couldn’t find that fighter. <a href="${BACK.href}">Back to ${BACK.text}</a>`);
          } else {
            showState(`Fighter records load from the WDS database and it can’t be reached right now. Please try again shortly. <a href="${BACK.href}">Back to ${BACK.text}</a>`);
          }
        });
    });
  })();
