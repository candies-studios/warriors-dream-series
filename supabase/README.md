# WDS ⇄ ScoreHUB ⇄ Rankings — shared database

One Supabase project (`qjqpquwcfarvyjzfzjcb`) is now the single source of truth for
**events, fighters, fights, judges' scores, results and rankings**. Nothing is copied
between sites any more:

```
 WDS admin dashboard ──► events / fighters / bouts / officials ──┐
                                                                 ▼
 ScoreHUB (judges, referee) ──► round scores ──► PROVISIONAL result      Supabase (Postgres + RLS + Realtime)
                                                                 │
 Management "Finalize" ──► FINAL result ──► rankings recomputed ─┤
                                                                 ▼
 WDS Home / Events / Event page / Rankings  ◄── read live (public, read-only)
```

## Event lifecycle

| Status | Set by | Public website | ScoreHUB |
| --- | --- | --- | --- |
| Draft | management | hidden | visible to officials |
| Announced | management (date/time/venue may be empty → "TBA") | shown as Upcoming | visible |
| Scheduled | **automatic** once an Announced event has date + start time + venue | Upcoming with details | visible |
| Live | **automatic** when the first bout starts in ScoreHUB | "Live Now" | scoring |
| Completed | **automatic** when no bout is scheduled/live any more | "Event Ended" / results | past |
| Cancelled | management | hidden from the schedule | — |

Each bout result is `none → provisional` (written by ScoreHUB when the last judge
submits or the referee records a stoppage) `→ final` (management clicks **Finalize**).
**Only final results** appear on the website and count for rankings. An admin can
**Reopen** a final result to correct it; rankings recompute automatically either way.

## Deploy (in this order)

1. **Database** — Supabase dashboard → SQL Editor, run in order:
   1. `supabase/migrations/20261001000100_wds_core_schema.sql`
   2. `supabase/migrations/20261001000200_wds_scoring_and_rankings.sql`
   3. `supabase/migrations/20261001000300_wds_seed_current_content.sql`

   Safe on the existing project: tables from the old dashboard/ScoreHUB schema with
   the same names are renamed to `legacy_<name>_<date>` (kept, never dropped). All
   three files can be re-run.
2. **Auth settings** — Authentication → Providers → Email: turn **off "Confirm email"**
   (officials set their PIN on first sign-in at the venue). Authentication → URL
   configuration: add `https://candies-studios.github.io` to the redirect URLs.
3. **First admin** — SQL Editor: `select public.bootstrap_admin('you@example.com', 'Your Name');`
   then log in to `admin-dashboard.html` with that email; the password you type the
   first time becomes yours.
4. **Deploy the WDS site** (this repo) and **ScoreHUB** (its repo) — plain file commits,
   no build step for either.

## Day-to-day

- **Officials:** dashboard → Officials → add name, email, role. They open ScoreHUB,
  type their name, pick their role and choose a PIN (6+ characters) on first sign-in.
- **New event:** dashboard → Events → title + status *Announced*. Add date/time/venue
  whenever known (Edit). Website and ScoreHUB update by themselves.
- **Fight card:** in the dashboard (Bouts) or ScoreHUB (league → fighters/bouts).
  Seat the three judges and the referee in ScoreHUB.
- **Fight night:** judges score in ScoreHUB; results land as *provisional*.
- **After the event:** dashboard → Bouts → *Finalize* each result, or Events →
  *Finalize results* for the whole card. Website and Rankings update immediately.

## Every change, by file

### Database (`supabase/migrations/`)
- `…0100_wds_core_schema.sql` — tables `profiles`, `official_invites`, `events`,
  `fighters`, `fighter_contacts` (private phone/DOB), `event_fighters`, `bouts`,
  `bout_judges`, `round_scores`, `fighter_rankings`; lifecycle triggers (slug,
  auto-Scheduled, auto-Live/Completed, protecting finalized history); public view
  `public_bout_card` (hides provisional results); Row Level Security on every table;
  media storage bucket `wds-media`.
- `…0200_wds_scoring_and_rankings.sql` — scoring RPCs used by ScoreHUB
  (`bout_start`, `bout_set_clock`, `bout_submit_round`, `bout_finish`,
  `bout_heartbeat`), the decision engine (identical to ScoreHUB's), management RPCs
  (`finalize_bout_result`, `finalize_event_results`, `reopen_bout_result`,
  `reset_bout`, `admin_recompute_rankings`), the ELO ranking engine (same algorithm
  as the Rankings page, final results only), `public_rankings` view, Realtime
  publication, `bootstrap_admin`.
- `…0300_wds_seed_current_content.sql` — the five past events, *WDS Rising Star 8*
  as Announced (no date), and the 34 fights from the Rankings page as final results
  under an unlisted "historical import" event.

### WDS website
| File | Change |
| --- | --- |
| `js/wds-config.js` | **new** — project URL, public anon key, ScoreHUB URL |
| `js/wds-data.js` | **new** — read-only data layer + live updates (Realtime, polling fallback) |
| `js/wds-live.js` | **new** — fills Home/Events/Event pages by cloning the existing cards |
| `css/wds-live.css` | **new** — fight-card rows and the "View Fight Card" button (site palette) |
| `pages/event.html` | **new** — event status, details, fight card, final results |
| `index.html`, `pages/events.html` | +4 script tags, +1 stylesheet (markup untouched) |
| `pages/rankings.html` | data now from `public_rankings`; original list kept as offline fallback; same render code |
| `js/main.js` | event filter looks up cards on click (so live cards filter too) |
| `admin-dashboard.html` | forms for the new workflow; inline script → `js/admin-dashboard.js` |
| `js/admin-dashboard.js` | rewritten for the shared schema (edit events, finalize/reopen, officials, read-only scorecards) |

With the seed data, Home, Events and Rankings render **identical HTML** to the
previous static pages; if the database is unreachable the static content stays.

### ScoreHUB (separate repo)
The live app bundle is not rebuilt (its newer source is not in GitHub).
`index.html` gets the Supabase URL/key in its config block and two script tags;
`supabase-bridge.js` (new) and `vendor/supabase.js` (new) answer ScoreHUB's built-in
API and live-sync socket from this database. See `SUPABASE-BRIDGE.md` in that repo.

## Security model (RLS)
- **Public (anon):** non-draft events, fighters (no phone/DOB), `public_bout_card`,
  `public_rankings`. Cannot read raw bouts, scorecards, officials or contacts; cannot write.
- **Judges / referees:** read events, cards, scorecards; change bouts **only** through
  the scoring RPCs, and only on bouts they are seated on / refereeing.
- **Promoter (management):** create/edit events, fighters, bouts, officials; finalize.
- **Admin:** everything, plus reopen finalized results, delete events, change roles.
- Roles come only from management invites — never from what a user types.

## Known follow-ups
- Some imported names are placeholders from the old Rankings page (`Opponent1…6`,
  `OpponentRS7-1…4`), and "Ashok Bagde"/"Ashok Bagade" are two spellings. Fix them in
  Fighters; rankings update by themselves.
- The footer "Rankings" link on Home/Events still points to the external fightrank site.
- ScoreHUB's earlier scorecards live only in each tablet's browser storage.
