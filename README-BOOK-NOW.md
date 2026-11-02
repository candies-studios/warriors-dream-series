# WDS Fight Night 19 — Book Now page

Unzip into the **root of the website repo** (the folder with `index.html`, `pages/`, `js/`).
All files are new; nothing existing is replaced.

| File | Purpose |
| --- | --- |
| `tickets/wds-fight-night-19/index.html` | Event page at `/tickets/wds-fight-night-19/`: hero, countdown, BOOK NOW, event info, map, instructions, terms |
| `js/wds-book-now.js` | BOOK NOW form (name, email, mobile, city, state, emergency contact) and the redirect |
| `css/wds-tickets.css` | Styles (site colours and fonts) |
| `js/wds-tickets-cta.js` | Adds BOOK NOW buttons next to "View Fight Card" on Home / Events / fight card page, plus a "Tickets" menu item |
| `tools/apply_ticketing_patch.py` | Adds that script to those pages (one `<script>` tag each, safe to re-run) |

## How it works

1. Visitor clicks **BOOK NOW** and fills in the form.
2. On submit they are sent to the **booking link** from the administration, where
   ticket categories, seat prices and payment are handled.
3. Until that link exists, the form ends with "Booking opens shortly" and a
   button to join the Warrior Community.

The form details are checked in the browser but are **not stored or sent anywhere**,
and no personal details are added to the booking link.

## When the booking link arrives

Open `tickets/wds-fight-night-19/index.html` and paste the link into the `<body>` tag:

```html
<body class="tk-page" data-event="wds-fight-night-19" data-booking-url="https://…the link…">
```

It must start with `https://`. Commit and push; nothing else changes.

## Push steps

```bash
# from the website repo root, after unzipping
python3 tools/apply_ticketing_patch.py --check   # preview the 4 pages it will touch
python3 tools/apply_ticketing_patch.py
git add tickets js/wds-book-now.js js/wds-tickets-cta.js css/wds-tickets.css tools/apply_ticketing_patch.py index.html pages/
git commit -m "Add WDS Fight Night 19 Book Now page"
git push
```

To hide the BOOK NOW buttons on other pages later, remove the entry from `onsale`
at the top of `js/wds-tickets-cta.js`.
