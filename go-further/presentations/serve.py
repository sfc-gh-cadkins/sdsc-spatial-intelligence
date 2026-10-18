#!/usr/bin/env python3
"""Serve the workshop decks locally and autosave speaker-note edits.

Run from anywhere:

    python3 go-further/presentations/serve.py

Then open http://localhost:8000/workshop-intro/ (or any other deck), press N
for notes, and edit. Edits are written straight into that deck's index.html,
so commit the file afterwards to publish them.

Only listens on this machine (127.0.0.1). Saves are accepted only for an
existing <deck>/index.html inside this folder, and only from the deck page
itself (a custom header that other websites can't send).
"""

import argparse
import functools
import http.server
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MAX_BYTES = 5 * 1024 * 1024
SLIDE_START = re.compile(r'<section\b[^>]*\bclass="(?:[^"]*\s)?slide(?=[\s"])')
NOTES = re.compile(r'<aside class="notes">.*?</aside>', re.S)


def patch_notes(html, changed):
    """Swap changed slides' notes into the file text, leaving all other bytes alone.

    changed maps a 0-based slide index (as a string) to that slide's notes HTML.
    """
    starts = [m.start() for m in SLIDE_START.finditer(html)]
    edits = sorted(((int(k), v) for k, v in changed.items()), reverse=True)
    if any(i < 0 or i >= len(starts) for i, _ in edits):
        raise ValueError("slide index out of range")
    # Work from the last slide back so earlier offsets stay valid.
    for i, note in edits:
        start = starts[i]
        end = html.index("</section>", start)
        block = '<aside class="notes">' + note + "</aside>"
        found = NOTES.search(html, start, end)
        if found:
            html = html[:found.start()] + block + html[found.end():]
        elif note.strip():
            html = html[:end] + "  " + block + "\n  " + html[end:]
    return html


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Always serve the latest file so saved edits show on reload.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_PUT(self):
        if self.headers.get("X-Notes-Save") != "1":
            return self.send_error(403, "Missing save header")

        rel = self.path.split("?", 1)[0].split("#", 1)[0].lstrip("/")
        if not rel or rel.endswith("/"):
            rel += "index.html"
        target = (ROOT / rel).resolve()
        if ROOT not in target.parents or target.name != "index.html" or not target.is_file():
            return self.send_error(404, "Only existing deck index.html files can be saved")

        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > MAX_BYTES:
            return self.send_error(413, "Unexpected size")
        body = self.rfile.read(length)

        if self.headers.get("Content-Type", "").startswith("application/json"):
            # Note edits: patch only the <aside class="notes"> blocks.
            try:
                changed = json.loads(body)["notes"]
                if not isinstance(changed, dict) or not all(isinstance(v, str) for v in changed.values()):
                    raise ValueError("notes must map slide index to text")
                body = patch_notes(target.read_text(encoding="utf-8"), changed).encode("utf-8")
            except (ValueError, KeyError, TypeError) as e:
                return self.send_error(409, f"Couldn't apply notes: {e}")
        elif not body.lstrip().lower().startswith(b"<!doctype html"):
            # Slide edits: the whole page.
            return self.send_error(400, "Not an HTML document")

        tmp = target.with_suffix(".html.tmp")
        tmp.write_bytes(body)
        os.replace(tmp, target)
        self.send_response(204)
        self.end_headers()
        self.log_message("saved %s", target.relative_to(ROOT))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    handler = functools.partial(Handler, directory=str(ROOT))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Decks: http://localhost:{args.port}/  (Ctrl+C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
