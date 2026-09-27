# Warriors Dream Series — Website

A clean, static rebuild of the [warriorsdreamseries.com](https://warriorsdreamseries.com) front end: plain HTML, CSS and vanilla JS, no build step, no CMS dependency. Ready to push to GitHub and deploy on GitHub Pages, Netlify, Vercel or any static host.

## Structure

```
.
├── index.html              Home page
├── pages/
│   ├── events.html          Full events / season schedule
│   ├── about.html           About, mission, story, team
│   ├── contact.html         Contact info + message form
│   └── media-room.html      Press videos + news mentions
├── css/style.css            Shared stylesheet (dark theme, red accent)
├── js/main.js               Mobile nav, event filters, countdown, form handler
└── assets/images/           All site imagery
```

## Running it locally

No build tools needed — just serve the folder statically, e.g.:

```bash
python3 -m http.server 8080
# then open http://localhost:8080
```

or open `index.html` directly in a browser (a couple of relative links assume a server, but most of the site works fine from the filesystem too).

## Deploying

- **GitHub Pages**: push to a repo, then enable Pages on the `main` branch (root).
- **Netlify / Vercel**: drag-and-drop the folder or connect the repo — no build command needed, publish directory is `/`.

## Hero background video

The home page hero now plays a looping YouTube video (`https://youtu.be/F2Uu6WP3tu0`) as its background, with a dark overlay behind the headline for readability — see `.hero-video-bg` / `.hero-overlay` in `css/style.css` and the `<iframe>` in `index.html`. A few notes:

- It's muted and set to autoplay + loop (`mute=1&loop=1&playlist=<id>`), which is required for autoplay to work in every modern browser — YouTube (and browsers generally) block unmuted autoplay.
- It's a live YouTube embed, not a self-hosted file, so it needs the visitor's browser to reach youtube.com — it won't preview inside offline/sandboxed tools, but will play normally on a real site visit.
- To swap in a different video, just change the video ID in the `src` (both the `embed/<id>` and `playlist=<id>` parts need to match).
- If you'd rather self-host the video (faster load, no YouTube branding flash, works without third-party cookies), replace the `<iframe>` with a plain `<video autoplay muted loop playsinline>` tag pointing at an `.mp4` in `assets/`.

## Things worth doing before this replaces the live site

- **Contact form**: the form on `pages/contact.html` is currently a static form with a placeholder JS handler (see `js/main.js`) — it doesn't send anywhere yet. Wire it up to a form backend such as [Formspree](https://formspree.io), [Netlify Forms](https://docs.netlify.com/forms/setup/), or a small serverless function that emails `support@warriorsdreamseries.com`.
- **Footer contact details**: the live site's footer currently shows placeholder text left over from the page-builder template (a San Francisco address, `+88 (0) 101 0000 000`, and `info@yourdomain.com`). This rebuild carries the same placeholders forward — swap in the real address/phone once you have them.
- **Social links**: the header/footer social icons (Instagram, Facebook, LinkedIn, YouTube) point to `#` — drop in the real profile URLs.
- **Team photos**: two team members without a photo on the live site (Sejal Doshi, Piyush Agarwal) show initials instead of a picture — same as the original. A few of the other team photos on the live site couldn't be matched to a name with full confidence from the page source, so they're labelled `team-member-2.jpg` through `team-member-8.jpg` in `assets/images/` — rename them to the correct person once you confirm which is which (Sudhanshu Srivastav, Satish Mishra, Sairaj Yermal, Tanmay Gurjar, Dipesh Rasal, Sumit Jadhav, Sushil Chandanshive) and update the `src` in `pages/about.html`.
- **Images optimized for the web**: most photos were re-compressed to reasonable web sizes (max ~1400px, JPEG quality ~0.8) while pulling them from the live site, so file sizes are much smaller than the originals. The logo was kept at full, lossless quality. If you want a specific photo at full original resolution, re-export it from your WordPress media library.
- **Rankings, testimonials, "recent blog"**: the fighter rankings and testimonials are carried over as static content, matching what's on the live site today — update them by hand when they change, or wire the page up to a small data file / CMS if they'll change often.
- **Copy**: the long-form paragraphs (About Us, Mission, Story, team bios) have been lightly reworded from the live site rather than copied verbatim — read them over and adjust the voice/wording to match how you'd want it phrased.

## Notes on fidelity

This is a from-scratch rebuild, not a scrape of the WordPress/Elementor markup — the goal was to reproduce the same sections, content, structure and visual style (dark background, red accent `#d7272a`, Teko + Oswald type) using plain, maintainable code instead of a page-builder's generated HTML. Fonts are loaded from Google Fonts; all images are stored locally under `assets/images/`.
