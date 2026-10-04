#!/usr/bin/env python3
"""A tiny stand-in for a fusionha server, used by CI to screenshot the app.

Serves responses captured from a fusionha demo library (scripts/mock/).
Calendar dates are moved into the current month and Discover rails are built
from the library, so every screen has something to show.

    python3 scripts/mock_server.py 8765
"""
import datetime as dt
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import mock_activity

MOCK = Path(__file__).resolve().parent / "mock"


def load(name):
    return json.loads((MOCK / name).read_text())


def calendar_this_month():
    entries = load("calendar_all.json")
    today = dt.date.today()
    start = today.replace(day=1)
    out = []
    for i, entry in enumerate(entries):
        day = start + dt.timedelta(days=(i * 3 + 1) % 28)
        out.append({**entry, "date": day.isoformat()})
    return out


def queue():
    library = {item["id"]: item for item in load("library.json")}
    items = []
    for n, (item_id, progress, phase) in enumerate([(8, 62.0, "downloading"), (4, 18.0, "downloading"), (13, 91.0, "importing")]):
        item = library[item_id]
        edition = next((e for e in item["editions"] if e["status"] == "grabbing"), item["editions"][0])
        items.append({
            "id": 100 + n,
            "title": item["title"],
            "episode_label": "S02E02 · Grilled" if item_id == 8 else None,
            "release_title": f"{item['title'].replace(' ', '.')}.2160p.WEB-DL-DEMO",
            "status": "downloading",
            "size": 8.4e9,
            "sizeleft": 8.4e9 * (1 - progress / 100),
            "progress": progress,
            "stalled": False,
            "needs_attention": False,
            "media_item_id": item_id,
            "edition_id": edition["id"],
            "tier": edition["tier"],
            "poster_url": item["poster_url"],
            "phase": phase,
            "step": None,
            "phase_percent": None,
        })
    return {"items": items, "total": len(items), "just_finished": []}


def discover():
    return [{
        "tmdb_id": item["tmdb_id"] or item["id"],
        "title": item["title"],
        "year": item["year"],
        "kind": item["kind"],
        "is_anime": item["is_anime"],
        "overview": None,
        "in_library": True,
        "library_item_id": item["id"],
        "poster_url": item["poster_url"],
        "backdrop_url": item["backdrop_url"],
        "date": None,
        "vote_average": 8.1,
    } for item in load("library.json")]


# library-shell: the shell's polls, settings, the Add flow's TVDB search and 4K check.
def library_attention():
    return {"editions": 1, "titles": 1, "items": [{"item_id": 3, "title": "Attention"}], "numbering_mismatches": 0,
            "metadata_removed": 0, "arr_scope_mismatches": 0}


def shell_settings():
    return {"library_rail_style": "current", "library_rail_consolidate": True, "metadata_provider": "tmdb",
            "default_movie_minimum_availability": "released", "animations_enabled": True}


def tvdb_search():
    return [{"tvdb_id": 81189 + i, "title": item["title"], "year": item["year"], "overview": None,
             "image_url": item["poster_url"], "tmdb_id": item["tmdb_id"], "imdb_id": None,
             "in_library": False, "library_item_id": None}
            for i, item in enumerate(load("library.json")) if item["kind"] == "series"][:6]


SHELL_ROUTES = {
    "/api/v1/library/attention": library_attention,
    "/api/v1/system/runs/attention": lambda: {"count": 0, "items": []},
    "/api/v1/system/indexers/unavailable": lambda: {"count": 0, "items": []},
    "/api/v1/system/commands": lambda: [],
    "/api/v1/settings": shell_settings,
    "/api/v1/search/tvdb": tvdb_search,
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        path = url.path.rstrip("/")
        query = parse_qs(url.query)
        hit = mock_activity.handle("GET", path, query)
        if hit is not None:
            return self.send_json(*hit)
        routes = {
            "/health": lambda: {"status": "ok", "version": "mock"},
            "/api/v1/setup-status": lambda: load("setup-status.json"),
            "/api/v1/auth/me": lambda: load("me.json"),
            "/api/v1/library": lambda: load("library.json"),
            "/api/v1/queue": queue,
            "/api/v1/history": lambda: load("history.json"),
            "/api/v1/blocklist": lambda: load("blocklist.json"),
            "/api/v1/calendar": calendar_this_month,
            "/api/v1/discover": discover,
            "/api/v1/search": discover,
            "/api/v1/requests": lambda: load("requests.json"),
            "/api/v1/qualityprofiles": lambda: load("qualityprofiles.json"),
            "/api/v1/rootfolders": lambda: load("rootfolders.json"),
            "/api/v1/config/add-defaults": lambda: load("add-defaults.json"),
        }
        if path == "/api/v1/wanted":
            state = query.get("state", ["missing"])[0]
            return self.send_json(load(f"wanted_{state}.json"))
        if path.startswith("/api/v1/library/") and path.rsplit("/", 1)[-1].isdigit():
            item = MOCK / "items" / f"{path.rsplit('/', 1)[-1]}.json"
            return self.send_json(json.loads(item.read_text())) if item.exists() else self.send_json({"detail": "Not Found"}, 404)
        if path in SHELL_ROUTES:
            return self.send_json(SHELL_ROUTES[path]())
        if path.startswith("/api/v1/system/runs/") and path.rsplit("/", 1)[-1].isdigit():
            return self.send_json({"id": int(path.rsplit("/", 1)[-1]), "status": "completed", "detail": None})
        if path in routes:
            return self.send_json(routes[path]())
        self.send_json({"detail": "Not Found"}, 404)

    def do_POST(self):
        hit = self.activity("POST")
        if hit:
            return self.send_json(*hit)
        path = urlparse(self.path).path.rstrip("/")
        if path == "/api/v1/discover/check-4k":
            return self.send_json({"dispatched": True, "queried_indexers": 3, "found_uhd": True, "seasons_seen": [1, 2],
                                   "best_release_name": "Demo.2160p.WEB-DL.DV.HDR10", "message": None,
                                   "format_tags": [{"label": "DV", "kind": "hdr"}, {"label": "HDR10", "kind": "hdr"}]})
        if path.startswith("/api/v1/library/") and path.endswith("/refresh"):
            return self.send_json({"run_id": 1})
        if path == "/api/v1/library":
            return self.send_json({"id": 1}, 201)
        self.send_json({})

    def do_PUT(self):
        self.send_json(*(self.activity("PUT") or ({},)))

    def do_DELETE(self):
        self.send_json(*(self.activity("DELETE") or ({},)))

    def activity(self, method):
        url = urlparse(self.path)
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)
        return mock_activity.handle(method, url.path.rstrip("/"), parse_qs(url.query))

    def send_json(self, body, status=200):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        sys.stderr.write("mock: " + fmt % args + "\n")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
