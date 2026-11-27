/*
 * WDS Broadcast — live ScoreHUB data for the broadcaster's laptop.
 *
 * Read-only. Uses the website's public connection (js/wds-config.js) and the
 * views published for broadcast (broadcast_bouts, broadcast_round_scores),
 * plus the public fight card and fighter profiles. Polls every 1.5 seconds,
 * so it works on venue Wi-Fi that blocks live websockets.
 */
(function () {
  'use strict';

  var CFG = window.WDS_CONFIG || {};
  var FAST = 1500;          // live state + scores
  var SLOW = 60000;         // fight card, fighter profiles, event list
  var RECENT_RESULT_MS = 10 * 60 * 1000;  // a result stays "current" for 10 minutes

  var METHOD = {
    DECISION_UNANIMOUS: 'Unanimous decision', DECISION_SPLIT: 'Split decision', DECISION_MAJORITY: 'Majority decision',
    KO_HEAD: 'KO', KO_BODY: 'KO (body)', TKO: 'TKO', SUBMISSION: 'Submission', RNC: 'Submission',
    DOCTOR_STOPPAGE: 'TKO (doctor stoppage)', CORNER_STOPPAGE: 'TKO (corner stoppage)', DQ: 'Disqualification',
    NO_CONTEST: 'No contest', DRAW: 'Draw', MAJORITY_DRAW: 'Majority draw', SPLIT_DRAW: 'Split draw', UNANIMOUS_DRAW: 'Draw'
  };

  // ------------------------------------------------------------------ helpers
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function rest(path) {
    return fetch(CFG.supabaseUrl + '/rest/v1/' + path, {
      headers: { apikey: CFG.supabaseAnonKey, Authorization: 'Bearer ' + CFG.supabaseAnonKey },
      cache: 'no-store'
    }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status + ' on ' + path.split('?')[0]);
      return r.json();
    });
  }
  function mmss(sec) {
    sec = Math.max(0, Math.round(sec));
    return Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0');
  }
  function methodLabel(t) {
    if (!t) return '';
    return METHOD[t] || t.replace(/_/g, ' ').toLowerCase().replace(/^./, function (c) { return c.toUpperCase(); });
  }
  function isDecision(t) { return /DECISION|DRAW/.test(t || ''); }
  function fmtDate(iso) {
    if (!iso) return '';
    var d = new Date(iso + 'T00:00:00');
    return d.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' });
  }

  // Country name -> flag image (Twemoji), built from the browser's own country names.
  var COUNTRY = {};
  (function () {
    try {
      var names = new Intl.DisplayNames(['en'], { type: 'region' });
      for (var a = 65; a <= 90; a++) for (var b = 65; b <= 90; b++) {
        var code = String.fromCharCode(a) + String.fromCharCode(b);
        var n = names.of(code);
        if (n && n !== code) COUNTRY[n.toLowerCase()] = code;
      }
    } catch (e) { /* very old browser: no flags */ }
    var alias = { usa: 'US', 'united states of america': 'US', uk: 'GB', england: 'GB', 'great britain': 'GB',
      uae: 'AE', russia: 'RU', 'south korea': 'KR', korea: 'KR', iran: 'IR', vietnam: 'VN', 'czech republic': 'CZ',
      turkey: 'TR', 'türkiye': 'TR', 'kyrgyz republic': 'KG', burma: 'MM', 'ivory coast': 'CI' };
    Object.keys(alias).forEach(function (k) { COUNTRY[k] = alias[k]; });
  })();
  function flagUrl(country) {
    var code = COUNTRY[String(country || '').trim().toLowerCase()];
    if (!code) return '';
    var cp = code.split('').map(function (ch) { return (0x1f1e6 + ch.charCodeAt(0) - 65).toString(16); }).join('-');
    return 'https://cdn.jsdelivr.net/gh/jdecked/twemoji@15.1.0/assets/svg/' + cp + '.svg';
  }
  function photoUrl(u) {
    if (!u) return '';
    return String(u).replace('https://candies-studios.github.io/warriors-dream-series/', 'https://wdsmma.com/');
  }

  // ------------------------------------------------------------------ store
  var S = {
    events: [], event: null, card: [], fighters: {}, live: {}, scores: {},
    clockOffset: 0, lastOk: 0, error: '', pinned: null, listeners: []
  };

  function pickEvent(slug) {
    if (slug) return S.events.find(function (e) { return e.slug === slug; }) || null;
    var d = new Date(Date.now() - 86400000);   // keep yesterday's event until the next day ends (late finishes)
    var t = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    var upcoming = S.events.filter(function (e) { return e.status !== 'completed' && (!e.event_date || e.event_date >= t); })
      .sort(function (a, b) { return (a.event_date || '9999').localeCompare(b.event_date || '9999'); });
    if (upcoming.length) return upcoming[0];
    var live = S.events.filter(function (e) { return e.status !== 'completed'; });
    return live[0] || S.events[0] || null;
  }

  function loadEvents() {
    return rest('events?select=id,slug,title,event_date,end_date,start_time,venue,city,status,poster_url' +
                '&is_listed=eq.true&status=neq.draft&order=event_date.desc').then(function (rows) { S.events = rows; });
  }
  function loadCard() {
    if (!S.event) return Promise.resolve();
    return rest('public_bout_card?event_id=eq.' + S.event.id + '&order=bout_number').then(function (rows) {
      S.card = rows;
      var ids = [];
      rows.forEach(function (b) { [b.blue_fighter_id, b.red_fighter_id].forEach(function (i) { if (i && ids.indexOf(i) < 0) ids.push(i); }); });
      if (!ids.length) return;
      return rest('fighters?select=id,name,nickname,country,declared_record,height,team&id=in.(' + ids.join(',') + ')')
        .then(function (fx) { fx.forEach(function (f) { S.fighters[f.id] = f; }); });
    });
  }
  function loadLive() {
    if (!S.event) return Promise.resolve();
    var sent = Date.now();
    return rest('broadcast_bouts?event_id=eq.' + S.event.id).then(function (rows) {
      var got = Date.now();
      var map = {};
      rows.forEach(function (r) { map[r.id] = r; });
      S.live = map;
      if (rows.length && rows[0].server_now) {
        S.clockOffset = Date.parse(rows[0].server_now) - (sent + got) / 2;
      }
      var cur = current();
      var ids = [];
      if (cur) ids.push(cur.id);
      var res = lastResult();
      if (res && ids.indexOf(res.id) < 0) ids.push(res.id);
      if (!ids.length) return;
      return rest('broadcast_round_scores?bout_id=in.(' + ids.join(',') + ')&order=round_number,seat').then(function (sc) {
        ids.forEach(function (id) { S.scores[id] = []; });
        sc.forEach(function (x) { (S.scores[x.bout_id] = S.scores[x.bout_id] || []).push(x); });
      });
    });
  }

  // A bout with its live state, fighters and scores merged in.
  function bout(b) {
    if (!b) return null;
    var l = S.live[b.id] || {};
    return Object.assign({}, b, {
      status: l.status || b.status,
      current_round: l.current_round || 0,
      total_rounds: l.total_rounds || b.total_rounds || 3,
      round_duration: l.round_duration || 300,
      round_started_at: l.round_started_at || null,
      started_at: l.started_at || null,
      completed_at: l.completed_at || null,
      result_type: l.result_type || b.result_type || null,
      winner_id: l.winner_id || b.winner_id || null,
      end_round: l.end_round || b.end_round || null,
      end_time_sec: l.end_time_sec != null ? l.end_time_sec : b.end_time_sec,
      result_status: l.result_status || null,
      blue: Object.assign({ id: b.blue_fighter_id, name: b.blue_name, photo: photoUrl(b.blue_photo_url) }, S.fighters[b.blue_fighter_id] || {}),
      red: Object.assign({ id: b.red_fighter_id, name: b.red_name || 'TBA', photo: photoUrl(b.red_photo_url) }, S.fighters[b.red_fighter_id] || {}),
      scores: S.scores[b.id] || []
    });
  }
  function all() { return S.card.map(bout); }

  function current() {
    var list = all();
    if (S.pinned) { var p = list.find(function (b) { return b.id === S.pinned; }); if (p) return p; }
    var live = list.filter(function (b) { return b.status === 'LIVE'; });
    if (live.length) {
      live.sort(function (a, b) { return String(b.round_started_at || b.started_at || '').localeCompare(String(a.round_started_at || a.started_at || '')); });
      return live[0];
    }
    var res = lastResult();
    if (res && res.completed_at && now() - Date.parse(res.completed_at) < RECENT_RESULT_MS) return res;
    return next();
  }
  function next(after) {
    var list = all().filter(function (b) { return b.status === 'SCHEDULED' && (!after || b.bout_number > after.bout_number); });
    return list[0] || null;
  }
  function lastResult() {
    var done = all().filter(function (b) { return b.status === 'COMPLETED' && b.completed_at; });
    done.sort(function (a, b) { return b.completed_at.localeCompare(a.completed_at); });
    return done[0] || null;
  }
  function now() { return Date.now() + S.clockOffset; }

  // Round clock: counts down from the round length while ScoreHUB's clock runs.
  function clock(b) {
    if (!b) return { text: '', running: false, label: '' };
    var dur = b.round_duration || 300;
    if (b.status === 'COMPLETED') return { text: '', running: false, label: 'Final' };
    if (b.status !== 'LIVE') return { text: mmss(dur), running: false, label: 'Up next' };
    if (b.round_started_at) {
      var left = dur - (now() - Date.parse(b.round_started_at)) / 1000;
      return { text: mmss(left), sec: left, running: left > 0, label: left > 0 ? 'Round ' + b.current_round : 'End of round ' + b.current_round };
    }
    var doneRounds = roundsScored(b);
    return { text: mmss(dur), running: false,
      label: doneRounds >= b.current_round && b.current_round > 0 ? 'End of round ' + b.current_round : (b.current_round > 1 ? 'Round ' + b.current_round + ' · ready' : 'Round 1 · ready') };
  }
  // Rounds whose cards are locked (every judge in): ScoreHUB moves to the next round.
  function roundsScored(b) {
    if (!b) return 0;
    if (b.status === 'COMPLETED') return isDecision(b.result_type) ? b.total_rounds : Math.max(0, (b.end_round || 1) - 1);
    return Math.max(0, (b.current_round || 1) - 1);
  }

  // Judges x rounds table + totals.
  function scorecard(b) {
    var judges = {}, rounds = 0;
    (b && b.scores || []).forEach(function (s) {
      var j = judges[s.seat] = judges[s.seat] || { seat: s.seat, name: s.judge_name, rounds: {}, blue: 0, red: 0 };
      j.rounds[s.round_number] = s;
      j.blue += s.blue_score; j.red += s.red_score;
      rounds = Math.max(rounds, s.round_number);
    });
    var list = Object.keys(judges).map(function (k) { return judges[k]; }).sort(function (a, b) { return a.seat - b.seat; });
    return { judges: list, rounds: Math.max(rounds, b ? Math.min(b.total_rounds, Math.max(1, roundsScored(b))) : 0) };
  }

  function winnerSide(b) {
    if (!b || !b.winner_id) return null;
    return b.winner_id === b.blue.id ? 'blue' : b.winner_id === b.red.id ? 'red' : null;
  }
  function resultLine(b) {
    if (!b || b.status !== 'COMPLETED' || !b.result_type) return '';
    var m = methodLabel(b.result_type);
    if (isDecision(b.result_type) || b.result_type === 'NO_CONTEST') return m;
    var parts = [m];
    if (b.end_round) parts.push('Round ' + b.end_round);
    if (b.end_time_sec != null) parts.push(mmss(b.end_time_sec));
    return parts.join(' · ');
  }
  function boutLabels(b) {
    var name = (b && b.bout_name) || '';
    var parts = name.split('·').map(function (x) { return x.trim(); }).filter(Boolean);
    var tag = parts.length && /event/i.test(parts[0]) ? parts.shift() : '';
    return { tag: tag, weight: parts.join(' · ') || (b && b.weight_class) || '', number: b ? b.bout_number : '' };
  }

  // ------------------------------------------------------------------ loop
  function emit() { S.listeners.forEach(function (fn) { try { fn(S); } catch (e) { console.error(e); } }); }
  var started = false;
  function start(opts) {
    opts = opts || {};
    if (started) return;
    started = true;
    function slow() {
      return loadEvents().then(function () {
        var ev = pickEvent(opts.event);
        if (ev && (!S.event || S.event.id !== ev.id)) { S.event = ev; S.card = []; S.live = {}; S.scores = {}; }
        else if (ev) S.event = ev;
        return loadCard();
      }).then(function () { S.error = ''; S.lastOk = Date.now(); emit(); })
        .catch(function (e) { S.error = e.message || 'Connection problem'; emit(); });
    }
    function fast() {
      return loadLive().then(function () { S.error = ''; S.lastOk = Date.now(); emit(); })
        .catch(function (e) { S.error = e.message || 'Connection problem'; emit(); })
        .then(function () { setTimeout(fast, FAST); });
    }
    slow().then(fast);
    setInterval(slow, SLOW);
    setInterval(emit, 250);   // smooth clock between polls
  }
  function setEvent(slug) {
    var ev = pickEvent(slug);
    if (!ev) return;
    S.event = ev; S.card = []; S.live = {}; S.scores = {}; S.pinned = null;
    loadCard().then(loadLive).then(emit);
  }

  window.WDSBroadcast = {
    S: S, start: start, setEvent: setEvent, on: function (fn) { S.listeners.push(fn); },
    all: all, current: current, next: next, lastResult: lastResult, clock: clock, scorecard: scorecard,
    roundsScored: roundsScored, winnerSide: winnerSide, resultLine: resultLine, boutLabels: boutLabels,
    methodLabel: methodLabel, isDecision: isDecision, flagUrl: flagUrl, esc: esc, mmss: mmss, fmtDate: fmtDate,
    pin: function (id) { S.pinned = id || null; emit(); }
  };
})();
