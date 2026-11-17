/*
 * WDS — save the rendered content of the static pages into their HTML.
 *
 *   node tools/seo/prerender.js <normalized-export.json>      (run by build.py)
 *
 * Opens every generated page in a headless browser, answers the site's database
 * requests from the export (a small read-only stand-in for the Supabase REST API),
 * lets the site's own scripts render, then writes the rendered regions back
 * between their <!--PRE:name--> markers. Nothing is sent to the real database.
 */
const fs = require('fs');
const path = require('path');
const http = require('http');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..', '..');
const DATA = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const TABLES = {
  events: DATA.events, public_bout_card: DATA.bout_card, public_bout_points: DATA.bout_points,
  public_last_fights: DATA.last_fights, public_rankings: DATA.rankings, fighters: DATA.fighters,
};

const { query } = require('./mockrest')(TABLES);
const BLANK_GIF = Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64');

// ------------------------------------------------------------ static server
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.json': 'application/json' };
function serve() {
  return new Promise(res => {
    const srv = http.createServer((req, rsp) => {
      let p = decodeURIComponent(req.url.split('?')[0]);
      if (p.endsWith('/')) p += 'index.html';
      const f = path.join(ROOT, p);
      if (!f.startsWith(ROOT) || !fs.existsSync(f)) { rsp.writeHead(404); return rsp.end(); }
      rsp.writeHead(200, { 'content-type': TYPES[path.extname(f).toLowerCase()] || 'application/octet-stream' });
      fs.createReadStream(f).pipe(rsp);
    }).listen(0, '127.0.0.1', () => res(srv));
  });
}

function replaceRegion(html, name, inner) {
  const a = '<!--PRE:' + name + '-->', b = '<!--/PRE:' + name + '-->';
  const i = html.indexOf(a), j = html.indexOf(b);
  if (i < 0 || j < 0) throw new Error('marker ' + name + ' missing');
  return html.slice(0, i + a.length) + inner + html.slice(j);
}

(async () => {
  const srv = await serve();
  const base = 'http://127.0.0.1:' + srv.address().port + '/';
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 1366, height: 900 } });
  await ctx.route('**/*', route => {
    const url = route.request().url();
    const m = /\/rest\/v1\/([a-z_]+)\??(.*)$/.exec(url);
    if (m) return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(query(m[1], new URLSearchParams(m[2]))) });
    if (url.startsWith(base)) {
      if (/\/js\/main\.js$/.test(url)) return route.abort();
      return route.continue();
    }
    // Photos hosted elsewhere: answer with a blank image so the page keeps the <img>
    // (some images remove themselves on a load error). Other CDN/fonts/video are not needed.
    if (route.request().resourceType() === 'image') return route.fulfill({ status: 200, contentType: 'image/gif', body: BLANK_GIF });
    return route.abort();
  });

  const jobs = [];
  for (const d of fs.readdirSync(path.join(ROOT, 'events'))) jobs.push({ kind: 'event', rel: 'events/' + d + '/index.html' });
  for (const d of fs.readdirSync(path.join(ROOT, 'fighters'))) {
    if (fs.statSync(path.join(ROOT, 'fighters', d)).isDirectory()) jobs.push({ kind: 'fighter', rel: 'fighters/' + d + '/index.html' });
  }
  jobs.push({ kind: 'home', rel: 'index.html' }, { kind: 'events', rel: 'pages/events.html' });

  let done = 0;
  const workers = Array.from({ length: 6 }, async () => {
    while (jobs.length) {
      const job = jobs.shift();
      const page = await ctx.newPage();
      if (job.kind === 'home' || job.kind === 'events') {
        await page.route(/wds-tickets-cta\.js$/, r => r.abort());
      }
      await page.goto(base + job.rel.replace(/index\.html$/, ''), { waitUntil: 'load' });
      let regions;
      if (job.kind === 'event') {
        await page.waitForFunction(() => !/Loading/.test(document.getElementById('wds-fight-card').textContent));
        await page.waitForTimeout(300);
        regions = await page.evaluate(() => ({
          hero: document.querySelector('.page-hero').outerHTML,
          upcoming: document.querySelector('.event-upcoming').outerHTML,
          cardtitle: document.querySelector('.wds-card-title').outerHTML,
          card: document.getElementById('wds-fight-card').outerHTML,
        }));
      } else if (job.kind === 'fighter') {
        await page.waitForFunction(() => !document.getElementById('fpState') || !/Loading/.test(document.getElementById('fpState').textContent));
        if (!(await page.$('#fighterRoot .fp-hero'))) throw new Error('fighter did not render: ' + job.rel);
        regions = await page.evaluate(() => ({ fighter: document.getElementById('fighterRoot').outerHTML }));
      } else {
        await page.waitForLoadState('networkidle');
        await page.waitForTimeout(800);
        regions = await page.evaluate(kind => kind === 'home' ? {
          'home-upcoming': document.querySelector('section.wds-upcoming-events').outerHTML,
          'home-archive': document.querySelector('section.archive-section').outerHTML,
        } : {
          'events-bands': Array.from(document.querySelectorAll('.event-upcoming.eu-live')).map(n => n.outerHTML).join('\n'),
          'events-grid': Array.from(document.querySelectorAll('.season-section')).find(n => n.querySelector('.ev-grid')).outerHTML,
        }, job.kind);
      }
      const file = path.join(ROOT, job.rel);
      let html = fs.readFileSync(file, 'utf8');
      for (const [name, inner] of Object.entries(regions)) html = replaceRegion(html, name, inner);
      fs.writeFileSync(file, html);
      await page.close();
      if (++done % 50 === 0) console.log('rendered', done);
    }
  });
  await Promise.all(workers);
  console.log('rendered', done, 'pages');
  await browser.close();
  srv.close();
})().catch(e => { console.error(e); process.exit(1); });
