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

MOCK = Path(__file__).resolve().parent / "mock"


def load(name):
    return json.loads((MOCK / name).read_text())


# Day offsets from today for each calendar_all.json entry (same order), plus a
# UTC air time for episodes relative to now (hours; None = date only). Spreads the
# demo across this week and month so every view (Month, Week, Forecast, Day,
# Agenda) has aired, airing-soon and upcoming entries, a season drop and a "now" line.
CALENDAR_PLAN = [
    (-9, None), (-13, -320), (-6, -150), (-3, -76), (0, -5), (0, -2), (0, 3),
    (-2, -50), (-1, -25), (0, -1), (1, 22), (-4, None), (2, 48), (5, 120),
    (1, 20), (1, 20.5), (1, 21), (3, None), (4, 96), (6, 145), (-7, None),
    (-11, -260), (-5, -122), (8, 190), (9, 214), (2, None), (12, 290), (13, 314),
]
RELEASE_TYPES = {0: "digital", 11: "physical", 17: "theatrical", 20: None, 25: "digital"}


def calendar_range(start=None, end=None):
    entries = load("calendar_all.json")
    now = dt.datetime.now(dt.timezone.utc).replace(second=0, microsecond=0)
    today = dt.date.today()
    out = []
    for i, entry in enumerate(entries):
        offset, hours = CALENDAR_PLAN[i % len(CALENDAR_PLAN)]
        item = {**entry, "date": (today + dt.timedelta(days=offset)).isoformat()}
        if entry["type"] == "episode" and hours is not None:
            air = now + dt.timedelta(hours=hours)
            item["air_datetime"] = air.strftime("%Y-%m-%dT%H:%M:%SZ")
            item["date"] = air.date().isoformat()
            item["runtime"] = 24 if entry["is_anime"] else 50
        if entry["type"] == "movie":
            item["release_type"] = RELEASE_TYPES.get(i)
        if offset > 0:
            # Not out yet: nothing downloaded or grabbing for future entries.
            item["editions"] = [{**ed, "status": "wanted"} for ed in entry["editions"]]
        out.append(item)
    if start and end:
        out = [e for e in out if start <= e["date"] <= end]
    return sorted(out, key=lambda e: e["date"])


def settings():
    return {
        "first_day_of_week": 0,
        "calendar_default_view": "month",
        "calendar_week_card_style": "landscape",
        "voice_playful": True,
        "animations_enabled": True,
    }


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


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        path = url.path.rstrip("/")
        query = parse_qs(url.query)
        routes = {
            "/health": lambda: {"status": "ok", "version": "mock"},
            "/api/v1/setup-status": lambda: load("setup-status.json"),
            "/api/v1/auth/me": lambda: load("me.json"),
            "/api/v1/library": lambda: load("library.json"),
            "/api/v1/queue": queue,
            "/api/v1/history": lambda: load("history.json"),
            "/api/v1/blocklist": lambda: load("blocklist.json"),
            "/api/v1/calendar": lambda: calendar_range(query.get("start", [None])[0], query.get("end", [None])[0]),
            "/api/v1/settings": settings,
            "/api/v1/settings/api-key": lambda: {"api_key": "mock-app-api-key"},
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
        if path in routes:
            return self.send_json(routes[path]())
        self.send_json({"detail": "Not Found"}, 404)

    def do_POST(self):
        self.send_json({})

    def do_PUT(self):
        self.send_json(settings() if self.path.startswith("/api/v1/settings") else {})

    def do_PATCH(self):
        self.send_json({})

    def do_DELETE(self):
        self.send_response(204)
        self.end_headers()

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
