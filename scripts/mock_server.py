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


# Titles the Discover fixtures treat as not yet in the library, so cards show
# the trending flame, request chips and the Preview's Add action.
NOT_IN_LIBRARY = {4, 7, 10, 13}
CAST = [("Timothée Chalamet", "Paul Atreides"), ("Rebecca Ferguson", "Lady Jessica"),
        ("Oscar Isaac", "Duke Leto"), ("Zendaya", "Chani"), ("Jason Momoa", "Duncan Idaho")]
TRAILER_KEYS = {4: "n9xhJrPXop4", 1: "vKQi3bBA1y8", 9: "KPLWWIOCOOQ", 8: "HhesaQXLuRY", 14: "LHtdKWJdif4", 2: "YoHD9XEInc0"}


def library_by_tmdb():
    return {item["tmdb_id"]: item for item in load("library.json")}


def row(item):
    owned = item["id"] not in NOT_IN_LIBRARY
    return {
        "tmdb_id": item["tmdb_id"] or item["id"],
        "title": item["title"],
        "year": item["year"],
        "kind": item["kind"],
        "is_anime": item["is_anime"],
        "overview": None,
        "in_library": owned,
        "library_item_id": item["id"] if owned else None,
        "poster_url": item["poster_url"],
        "backdrop_url": item["backdrop_url"],
        "date": f"{item['year']}-06-01" if item["year"] else None,
        "vote_average": 8.1,
    }


def discover_rows(query):
    kind = query.get("kind", ["all"])[0]
    lst = query.get("list", ["trending"])[0]
    items = load("library.json")
    if kind == "movie":
        items = [i for i in items if i["kind"] == "movie" and not i["is_anime"]]
    elif kind == "series":
        items = [i for i in items if i["kind"] == "series" and not i["is_anime"]]
    elif kind == "anime":
        items = [i for i in items if i["is_anime"]]
    shift = {"trending": 0, "popular": 2, "top_rated": 1, "upcoming": 3, "on_the_air": 3}.get(lst, 0)
    shift = shift % max(1, len(items))
    items = items[shift:] + items[:shift]
    if kind == "movie" and lst == "trending":
        items = sorted(items, key=lambda i: i["id"] not in NOT_IN_LIBRARY)
    return [row(i) for i in items]


def trailers(query):
    rows = []
    for r in discover_rows(query):
        if r["backdrop_url"]:
            rows.append({**r, "trailer_key": TRAILER_KEYS.get(r.get("library_item_id") or 0, "n9xhJrPXop4")})
    return rows


def collections():
    lib = {i["id"]: i for i in load("library.json")}
    return [
        {"collection_tmdb_id": 726871, "name": "Dune Collection", "poster_url": lib[4]["poster_url"],
         "backdrop_url": lib[4]["backdrop_url"], "owned_count": 1, "total_count": 2},
        {"collection_tmdb_id": 2344, "name": "The Matrix Collection", "poster_url": lib[1]["poster_url"],
         "backdrop_url": lib[1]["backdrop_url"], "owned_count": 1, "total_count": 4},
        {"collection_tmdb_id": 422837, "name": "Blade Runner Collection", "poster_url": lib[3]["poster_url"],
         "backdrop_url": lib[3]["backdrop_url"], "owned_count": 1, "total_count": 2},
    ]


def collection_detail(cid):
    summary = next((c for c in collections() if c["collection_tmdb_id"] == cid), collections()[0])
    parts = [{"tmdb_id": 438631, "title": "Dune", "year": 2021, "in_library": True},
             {"tmdb_id": 693134, "title": "Dune: Part Two", "year": 2024, "in_library": False}]
    return {**summary, "present_count": 1, "parts": parts}


def preview(kind, tmdb_id):
    item = library_by_tmdb().get(tmdb_id)
    if item is None:
        return None
    detail = json.loads((MOCK / "items" / f"{item['id']}.json").read_text())
    owned = item["id"] not in NOT_IN_LIBRARY
    lib = load("library.json")
    similar = [{"tmdb_id": i["tmdb_id"], "title": i["title"], "year": i["year"], "poster_url": i["poster_url"],
                "kind": i["kind"], "in_library": i["id"] not in NOT_IN_LIBRARY}
               for i in lib if i["kind"] == item["kind"] and i["id"] != item["id"]][:6]
    seasons = [{"season_number": s["season_number"], "episode_count": max(len(s.get("episodes") or []), 8)}
               for s in detail.get("seasons") or []]
    return {
        "tmdb_id": tmdb_id, "title": item["title"], "year": item["year"], "kind": item["kind"],
        "is_anime": item["is_anime"], "in_library": owned, "library_item_id": item["id"] if owned else None,
        "tvdb_id": detail.get("tvdb_id"), "imdb_id": detail.get("imdb_id"),
        "poster_url": item["poster_url"], "backdrop_url": item["backdrop_url"],
        "overview": detail.get("overview"), "runtime": detail.get("runtime"), "status": detail.get("status"),
        "tagline": detail.get("tagline") or ("Beyond fear, destiny awaits." if item["id"] == 4 else None),
        "vote_average": detail.get("vote_average") or 7.9, "vote_count": detail.get("vote_count") or 12000,
        "certification": detail.get("certification") or "PG-13", "genres": detail.get("genres") or ["Science Fiction"],
        "cast": [{"name": n, "character": c, "profile_url": None, "order": k} for k, (n, c) in enumerate(CAST)],
        "studios": [], "trailer_key": TRAILER_KEYS.get(item["id"], "n9xhJrPXop4"),
        "similar": similar, "seasons": seasons if item["kind"] == "series" else [],
    }


def requests_rows(query):
    now = dt.datetime.utcnow()
    def ago(hours):
        return (now - dt.timedelta(hours=hours)).isoformat()
    rows = [
        {"id": 1, "user_id": 4, "tmdb_id": 438631, "kind": "movie", "media_item_id": None, "tier": "UHD-2160p",
         "editions": ["UHD-2160p"], "seasons": [], "episodes": [], "status": "pending", "reason": None,
         "note": "The 4K HDR release please", "requested_at": ago(2)},
        {"id": 2, "user_id": 4, "tmdb_id": 63639, "kind": "series", "media_item_id": None, "tier": "HD-1080p",
         "editions": ["HD-1080p"], "seasons": [1, 2], "episodes": [], "status": "pending", "reason": None,
         "note": None, "requested_at": ago(5)},
        {"id": 3, "user_id": 6, "tmdb_id": 372058, "kind": "movie", "media_item_id": None, "tier": "HD-1080p",
         "editions": ["HD-1080p", "UHD-2160p"], "seasons": [], "episodes": [], "status": "approved", "reason": None,
         "note": None, "requested_at": ago(30)},
        {"id": 4, "user_id": 4, "tmdb_id": 1399, "kind": "series", "media_item_id": 9, "tier": "HD-1080p",
         "editions": ["HD-1080p"], "seasons": [], "episodes": [], "status": "fulfilled", "reason": None,
         "note": None, "requested_at": ago(80)},
        {"id": 5, "user_id": 6, "tmdb_id": 31911, "kind": "series", "media_item_id": None, "tier": "UHD-2160p",
         "editions": ["UHD-2160p"], "seasons": [], "episodes": [], "status": "deferred", "reason": "not_available_yet",
         "note": None, "requested_at": ago(120)},
    ]
    status = query.get("status", [None])[0]
    return [r for r in rows if status is None or r["status"] == status]


def issues_rows(query):
    now = dt.datetime.utcnow()
    rows = [
        {"id": 1, "media_item_id": 8, "reporter_user_id": 4, "issue_type": "audio", "scope": "episode", "season": 2,
         "episode": 5, "description": "Audio drifts out of sync after ten minutes.", "status": "open", "resolved": False,
         "created_at": (now - dt.timedelta(hours=3)).isoformat(), "comment": None},
        {"id": 2, "media_item_id": 1, "reporter_user_id": 6, "issue_type": "playback", "scope": "item", "season": None,
         "episode": None, "description": None, "status": "open", "resolved": False,
         "created_at": (now - dt.timedelta(days=1)).isoformat(), "comment": None},
        {"id": 3, "media_item_id": 9, "reporter_user_id": 4, "issue_type": "subtitle", "scope": "season", "season": 1,
         "episode": None, "description": "No English subtitles.", "status": "resolved", "resolved": True,
         "created_at": (now - dt.timedelta(days=4)).isoformat(), "comment": "Grabbed a release with subs."},
    ]
    status = query.get("status", ["open"])[0]
    return [r for r in rows if r["status"] == status]


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
        routes = {
            "/health": lambda: {"status": "ok", "version": "mock"},
            "/api/v1/setup-status": lambda: load("setup-status.json"),
            "/api/v1/auth/me": lambda: load("me_requestor.json" if REQUESTOR else "me.json"),
            "/api/v1/library": lambda: load("library.json"),
            "/api/v1/queue": queue,
            "/api/v1/history": lambda: load("history.json"),
            "/api/v1/blocklist": lambda: load("blocklist.json"),
            "/api/v1/calendar": calendar_this_month,
            "/api/v1/discover": lambda: discover_rows(query),
            "/api/v1/discover/trailers": lambda: trailers(query),
            "/api/v1/discover/filter": lambda: discover_rows(query),
            "/api/v1/discover/genres": lambda: [{"id": 878, "name": "Science Fiction"}, {"id": 18, "name": "Drama"},
                                                {"id": 16, "name": "Animation"}, {"id": 28, "name": "Action"}],
            "/api/v1/discover/watch-providers": lambda: [{"id": 8, "name": "Netflix", "logo_url": None},
                                                         {"id": 337, "name": "Disney Plus", "logo_url": None}],
            "/api/v1/collections": collections,
            "/api/v1/search": discover,
            "/api/v1/requests": lambda: requests_rows(query),
            "/api/v1/requests/offerable": lambda: {"editions": ["HD-1080p", "UHD-2160p"], "mode": "choose", "auto_editions": []},
            "/api/v1/issues": lambda: issues_rows(query),
            "/api/v1/settings": lambda: {"metadata_provider": "tmdb", "default_movie_minimum_availability": "released",
                                         "tmdb_configured": True, "animations_enabled": True},
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
        if path == "/api/v1/discover/preview":
            body = preview(query.get("kind", ["movie"])[0], int(query.get("tmdb_id", ["0"])[0]))
            return self.send_json(body) if body else self.send_json({"detail": "Not Found"}, 404)
        if path.startswith("/api/v1/preview/"):
            parts = path.split("/")
            if len(parts) >= 8 and parts[6] == "season":
                return self.send_json([{"episode_number": e, "title": f"Chapter {e}", "air_date": None, "overview": None}
                                       for e in range(1, 9)])
            body = preview(parts[4], int(parts[5])) if len(parts) >= 6 and parts[5].isdigit() else None
            return self.send_json(body) if body else self.send_json({"detail": "Not Found"}, 404)
        if path.startswith("/api/v1/collections/") and path.rsplit("/", 1)[-1].isdigit():
            return self.send_json(collection_detail(int(path.rsplit("/", 1)[-1])))
        if path in SHELL_ROUTES:
            return self.send_json(SHELL_ROUTES[path]())
        if path.startswith("/api/v1/system/runs/") and path.rsplit("/", 1)[-1].isdigit():
            return self.send_json({"id": int(path.rsplit("/", 1)[-1]), "status": "completed", "detail": None})
        if path in routes:
            return self.send_json(routes[path]())
        self.send_json({"detail": "Not Found"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path.rstrip("/")
        if path == "/api/v1/discover/check-4k":
            return self.send_json({"dispatched": True, "queried_indexers": 3, "found_uhd": True, "seasons_seen": [1, 2],
                                   "best_release_name": "Demo.2160p.WEB-DL.DV.HDR10", "message": None,
                                   "format_tags": [{"label": "DV", "kind": "hdr"}, {"label": "HDR10", "kind": "hdr"}]})
        if path.startswith("/api/v1/library/") and path.endswith("/refresh"):
            return self.send_json({"run_id": 1})
        if path == "/api/v1/library":
            return self.send_json({"id": 1}, 201)
        if path.endswith("/check-4k"):
            return self.send_json({"dispatched": True, "queried_indexers": 3, "found_uhd": True, "seasons_seen": [],
                                   "format_tags": [], "message": ""})
        self.send_json({})

    def do_PUT(self):
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


REQUESTOR = False

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    # `requestor` serves a request-scoped account (Discover · My requests · You).
    REQUESTOR = len(sys.argv) > 2 and sys.argv[2] == "requestor"
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
