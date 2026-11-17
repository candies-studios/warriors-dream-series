# Search-friendly static pages (SEO)

The site's event results and fighter profiles are built as static pages so
Google can read them without running JavaScript:

- `events/<slug>/` — one page per finished event
- `fighters/<name>/` and `fighters/` — one page per fighter + an A–Z list
- `js/wds-static-urls.js` — tells the live scripts where those pages are
- `sitemap.xml`

Visitors still get live data: the pages run the same scripts as before and
refresh from the database. The static copy only needs rebuilding when new
events, results or fighters are added.

## Rebuild

1. Run `export.sql` in the Supabase SQL Editor (read-only) and download the
   result as CSV.
2. `python3 tools/seo/build.py <downloaded.csv>` (needs Python 3, Node.js and
   Playwright).
3. Upload the changed files.

This folder is not published on the website (see `_config.yml`).
