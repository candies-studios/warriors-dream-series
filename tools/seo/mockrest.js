/* Read-only stand-in for the Supabase REST API, answering from an export (used by prerender.js). */
module.exports = function (TABLES) {
function cmp(a, b) { return a == null ? (b == null ? 0 : -1) : b == null ? 1 : a < b ? -1 : a > b ? 1 : 0; }
function test(row, col, expr) {
  const m = /^(not\.)?(eq|neq|in|is|gt|gte|lt|lte)\.(.*)$/.exec(expr);
  if (!m) return true;
  const v = row[col]; let ok;
  const s = v == null ? null : String(v);
  switch (m[2]) {
    case 'eq': ok = s === m[3]; break;
    case 'neq': ok = s !== m[3]; break;
    case 'in': ok = m[3].replace(/^\(|\)$/g, '').split(',').includes(s); break;
    case 'is': ok = m[3] === 'null' ? v == null : String(v) === m[3]; break;
    case 'gt': ok = s > m[3]; break; case 'gte': ok = s >= m[3]; break;
    case 'lt': ok = s < m[3]; break; case 'lte': ok = s <= m[3]; break;
  }
  return m[1] ? !ok : ok;
}
function query(table, params) {
  let rows = (TABLES[table] || []).slice();
  for (const [k, v] of params) {
    if (['select', 'order', 'limit', 'offset'].includes(k)) continue;
    if (k === 'or') {
      const parts = v.replace(/^\(|\)$/g, '').split(',');
      rows = rows.filter(r => parts.some(p => { const i = p.indexOf('.'); return test(r, p.slice(0, i), p.slice(i + 1)); }));
    } else rows = rows.filter(r => test(r, k, v));
  }
  const order = params.get('order');
  if (order) {
    const keys = order.split(',').map(o => { const [c, ...f] = o.split('.'); return { c, desc: f.includes('desc'), nf: f.includes('nullsfirst') }; });
    rows.sort((a, b) => {
      for (const k of keys) {
        const av = a[k.c], bv = b[k.c];
        if (av == null || bv == null) { if (av == null && bv == null) continue; return (av == null) === k.nf ? -1 : 1; }
        const c = cmp(av, bv); if (c) return k.desc ? -c : c;
      }
      return 0;
    });
  }
  if (params.get('limit')) rows = rows.slice(0, +params.get('limit'));
  const sel = params.get('select');
  if (sel && sel !== '*') {
    const cols = sel.split(',');
    rows = rows.map(r => Object.fromEntries(cols.map(c => [c, r[c] === undefined ? null : r[c]])));
  }
  return rows;
}

  return { query };
};
