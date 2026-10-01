/*
 * WDS shared data layer (public website).
 *
 * Reads the single source of truth (Supabase) over its REST API and, when the
 * Supabase client script is present, subscribes to live changes so pages update
 * by themselves when management edits an event or results are finalized.
 * Nothing here can write: the public anon key only has read access through RLS.
 *
 * Usage: <script src="js/wds-config.js"></script> <script src="js/wds-data.js"></script>
 */
(function () {
  'use strict';
  var cfg = window.WDS_CONFIG || {};
  var TZ = cfg.timezone || 'Asia/Kolkata';
  var enabled = !!(cfg.supabaseUrl && cfg.supabaseAnonKey);

  function rest(path) {
    if (!enabled) return Promise.reject(new Error('WDS database not configured'));
    return fetch(cfg.supabaseUrl.replace(/\/+$/, '') + '/rest/v1/' + path, {
      headers: { apikey: cfg.supabaseAnonKey, Authorization: 'Bearer ' + cfg.supabaseAnonKey },
    }).then(function (r) {
      if (!r.ok) throw new Error('WDS database request failed (' + r.status + ')');
      return r.json();
    });
  }

  var EVENT_COLS = 'id,slug,title,series,status,event_date,end_date,start_time,timezone,venue,city,' +
    'description,poster_url,results_url,starts_at,card_updated_at';

  // ---- formatting (matches the site's existing copy, e.g. "25th - 26th July, 2026")
  var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  function ordinal(n) {
    var s = ['th', 'st', 'nd', 'rd'], v = n % 100;
    return n + (s[(v - 20) % 10] || s[v] || s[0]);
  }
  function parts(dateStr) {
    var p = String(dateStr).split('-');
    return { y: +p[0], m: +p[1] - 1, d: +p[2] };
  }
  function formatDate(ev) {
    if (!ev || !ev.event_date) return null;
    var a = parts(ev.event_date);
    if (!ev.end_date || ev.end_date === ev.event_date) return ordinal(a.d) + ' ' + MONTHS[a.m] + ', ' + a.y;
    var b = parts(ev.end_date);
    if (a.m === b.m && a.y === b.y) return ordinal(a.d) + ' - ' + ordinal(b.d) + ' ' + MONTHS[a.m] + ', ' + a.y;
    return ordinal(a.d) + ' ' + MONTHS[a.m] + ' - ' + ordinal(b.d) + ' ' + MONTHS[b.m] + ', ' + b.y;
  }
  function formatTime(ev) {
    if (!ev || !ev.start_time) return null;
    var t = String(ev.start_time).split(':');
    var h = +t[0], m = t[1] || '00';
    return ((h % 12) || 12) + ':' + m + ' ' + (h < 12 ? 'AM' : 'PM');
  }
  function formatVenue(ev) {
    if (!ev) return null;
    return [ev.venue, ev.city].filter(Boolean).join(', ') || null;
  }

  var SERIES = { 'championship': 'Championship Series', 'rising-star': 'Rising Star Series', other: 'WDS' };
  var STATUS = { draft: 'Draft', announced: 'Upcoming', scheduled: 'Upcoming', live: 'Live Now', completed: 'Event Ended', cancelled: 'Cancelled' };

  var RESULT_LABEL = {
    DECISION_UNANIMOUS: 'Unanimous decision', DECISION_SPLIT: 'Split decision', DECISION_MAJORITY: 'Majority decision',
    DRAW: 'Draw', MAJORITY_DRAW: 'Majority draw', KO_HEAD: 'KO (head)', KO_BODY: 'KO (body)', TKO: 'TKO',
    SUBMISSION: 'Submission', RNC: 'Verbal submission', DOCTOR_STOPPAGE: 'Doctor stoppage',
    CORNER_STOPPAGE: 'Corner stoppage', DQ: 'Disqualification', NO_CONTEST: 'No contest',
  };
  function clock(sec) {
    if (sec == null) return '';
    return Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0');
  }
  function describeResult(b) {
    if (b.result_status !== 'final' || !b.result_type) return null;
    var how = RESULT_LABEL[b.result_type] || b.result_type;
    var when = b.end_round && !/^DECISION|DRAW/.test(b.result_type)
      ? ' · R' + b.end_round + (b.end_time_sec != null ? ' ' + clock(b.end_time_sec) : '') : '';
    var winner = b.winner_id === b.blue_fighter_id ? b.blue_name : b.winner_id === b.red_fighter_id ? b.red_name : null;
    return { winner: winner, method: how + when };
  }

  // ---- queries
  function events() {
    return rest('events?select=' + EVENT_COLS + '&is_listed=eq.true&status=neq.draft&order=event_date.desc.nullsfirst,created_at.desc');
  }
  function eventBySlug(slug) {
    return rest('events?select=' + EVENT_COLS + '&slug=eq.' + encodeURIComponent(slug) + '&limit=1')
      .then(function (r) { return r[0] || null; });
  }
  function card(eventId) {
    return rest('public_bout_card?event_id=eq.' + encodeURIComponent(eventId) + '&order=bout_number');
  }
  function cardCounts() {
    return rest('public_bout_card?select=event_id').then(function (rows) {
      var c = {};
      rows.forEach(function (r) { c[r.event_id] = (c[r.event_id] || 0) + 1; });
      return c;
    });
  }
  function rankings() {
    return rest('public_rankings?select=*&order=division_key,division_rank');
  }

  // The headline event: live > next scheduled > announced (undated last).
  function featured(list) {
    var open = list.filter(function (e) { return ['live', 'scheduled', 'announced'].indexOf(e.status) >= 0; });
    var rank = { live: 0, scheduled: 1, announced: 2 };
    open.sort(function (a, b) {
      if (rank[a.status] !== rank[b.status]) return rank[a.status] - rank[b.status];
      var ta = a.starts_at ? Date.parse(a.starts_at) : Infinity, tb = b.starts_at ? Date.parse(b.starts_at) : Infinity;
      return ta - tb;
    });
    return open[0] || null;
  }

  // ---- live updates: Supabase Realtime when available, polling otherwise
  var client = null;
  function realtimeClient() {
    if (client || !enabled || !window.supabase || !window.supabase.createClient) return client;
    client = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    return client;
  }
  function subscribe(tables, onChange) {
    if (!enabled) return function () {};
    var timer = null;
    var fire = function () { clearTimeout(timer); timer = setTimeout(onChange, 400); };
    var c = realtimeClient();
    var channel = null;
    if (c) {
      channel = c.channel('wds-public-' + tables.join('-') + '-' + Math.random().toString(36).slice(2, 7));
      tables.forEach(function (t) { channel.on('postgres_changes', { event: '*', schema: 'public', table: t }, fire); });
      channel.subscribe();
    }
    // Safety net (and the only mechanism if Realtime is blocked).
    var poll = setInterval(onChange, c ? 120000 : 45000);
    return function () { clearInterval(poll); if (channel) c.removeChannel(channel); };
  }

  window.WDS = {
    enabled: enabled,
    config: cfg,
    timezone: TZ,
    rest: rest,
    events: events,
    eventBySlug: eventBySlug,
    card: card,
    cardCounts: cardCounts,
    rankings: rankings,
    featured: featured,
    subscribe: subscribe,
    formatDate: formatDate,
    formatTime: formatTime,
    formatVenue: formatVenue,
    describeResult: describeResult,
    seriesLabel: function (s) { return SERIES[s] || SERIES.other; },
    statusLabel: function (s) { return STATUS[s] || s; },
  };
})();
