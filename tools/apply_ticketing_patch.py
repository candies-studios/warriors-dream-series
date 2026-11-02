#!/usr/bin/env python3
"""
Adds the BOOK NOW buttons to the existing WDS pages.

Run from the root of the website repository (the folder with index.html):

    python3 tools/apply_ticketing_patch.py           # apply
    python3 tools/apply_ticketing_patch.py --check   # show what would change

It only inserts <script> tags before </body>; no other markup is touched.
Safe to run more than once (already-patched files are skipped).
"""
import pathlib
import sys

ROOT = pathlib.Path.cwd()
PAGES = {
    "index.html": "",
    "pages/events.html": "../",
    "pages/event.html": "../",
    "pages/wds-fight-night-19.html": "../",
}
MARK = "wds-tickets-cta.js"


def patch(path: pathlib.Path, prefix: str, check: bool) -> str:
    if not path.exists():
        return f"skip   {path} (not found)"
    html = path.read_text(encoding="utf-8")
    if MARK in html:
        return f"ok     {path} (already patched)"
    if "</body>" not in html:
        return f"skip   {path} (no </body>)"
    tags = []
    tags.append(f'<script src="{prefix}js/{MARK}"></script>')
    block = "\n".join(tags) + "\n"
    i = html.rfind("</body>")
    new = html[:i] + block + html[i:]
    if not check:
        path.write_text(new, encoding="utf-8")
    return ("would " if check else "patched ") + f"{path}: + " + ", ".join(t.split('"')[1] for t in tags)


def main() -> int:
    check = "--check" in sys.argv
    if not (ROOT / "index.html").exists() or not (ROOT / "js").is_dir():
        print("Run this from the website repository root (the folder that contains index.html and js/).")
        return 1
    for rel, prefix in PAGES.items():
        print(patch(ROOT / rel, prefix, check))
    return 0


if __name__ == "__main__":
    sys.exit(main())
