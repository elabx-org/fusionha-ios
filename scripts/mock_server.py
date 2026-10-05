#!/usr/bin/env python3
"""A tiny stand-in for a fusionha server, used by CI to screenshot the app.

Serves responses captured from a fusionha demo library (scripts/mock/).
Calendar dates are moved into the current month and Discover rails are built
from the library, so every screen has something to show.

    python3 scripts/mock_server.py 8765
"""
import datetime as dt
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import mock_activity
import mock_add
import mock_detail
import mock_shell

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
    # Like the server, Discover rows carry `in_library` but no `library_item_id`
    # (only /search fills it); the app resolves the id from its library list.
    return [{**row(i), "library_item_id": None, "_id": i["id"]} for i in items]


def trailers(query):
    rows = []
    for r in discover_rows(query):
        if r["backdrop_url"]:
            rows.append({**r, "trailer_key": TRAILER_KEYS.get(r["_id"] if r["in_library"] else 0, "n9xhJrPXop4")})
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


# These settings fixtures were captured at CAPTURED; their timestamps are shifted
# to "now" so countdowns, "last run" and NEW badges read the same on every run.
REBASED = {"indexers__stats.json", "system__tasks.json", "tokens.json"}
CAPTURED = dt.datetime(2026, 10, 4, 10, 54, 58)
_ISO = re.compile(r'"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?"')


def rebased(text):
    shift = dt.datetime.utcnow() - CAPTURED
    return _ISO.sub(lambda m: '"' + (dt.datetime.fromisoformat(m.group(1)) + shift).isoformat(timespec="seconds") + '"', text)


def api_fixture(path):
    """`/api/v1/a/b` -> scripts/mock/api/a__b.json, when it exists."""
    if not path.startswith("/api/v1/"):
        return None
    fixture = MOCK / "api" / (path[len("/api/v1/"):].replace("/", "__") + ".json")
    return fixture if fixture.exists() else None


# library-shell: the shell's polls, settings, the Add flow's TVDB search and 4K check.
def library_attention():
    return {"editions": 1, "titles": 1, "items": [{"item_id": 3, "title": "Attention"}], "numbering_mismatches": 0,
            "metadata_removed": 0, "arr_scope_mismatches": 0}


def shell_settings():
    full = json.loads((MOCK / "api" / "settings.json").read_text()) if (MOCK / "api" / "settings.json").exists() else {}
    return full | {"library_rail_style": "current", "library_rail_consolidate": True, "metadata_provider": "tmdb",
            "default_movie_minimum_availability": "released", "animations_enabled": True}


def tvdb_search():
    return [{"tvdb_id": 81189 + i, "title": item["title"], "year": item["year"], "overview": None,
             "image_url": item["poster_url"], "tmdb_id": item["tmdb_id"], "imdb_id": None,
             "in_library": False, "library_item_id": None}
            for i, item in enumerate(load("library.json")) if item["kind"] == "series"][:6]


# Notifications panel: the shared event matrix, Web Push, and native iOS push (APNs).
# The screenshot run sets FUSIONHA_SCREENSHOT_PUSH_TOKEN to MOCK_APNS_TOKEN so
# "This device" renders registered.
MOCK_APNS_TOKEN = "f" * 64


def apns_device(i, token, name, env="sandbox"):
    return {"id": i, "user_id": 1, "device_token": token, "environment": env, "device_name": name,
            "app_version": "1.0", "created_at": "2026-09-20T10:00:00", "last_seen_at": "2026-10-04T08:00:00",
            "last_success_at": "2026-10-04T08:05:00", "failure_count": 0, "last_error": None, "disabled": False}


APNS_SETTINGS = {"enabled": True, "configured": True, "key_id": "ABC123DEFG", "team_id": "TEAM123456",
                 "topic": "org.elabx.fusionha", "environment": "auto", "auth_key_set": True}

NOTIFICATION_ROUTES = {
    "/api/v1/notifications/preferences": lambda: {"principal_id": 1, "preferences": [
        {"event_kind": k, "enabled": k not in ("upgrade", "issue_reported", "retargeted")}
        for k in ("grab", "import", "upgrade", "manual_required", "failed", "needs_attention", "issue_reported",
                  "retargeted", "request_available", "request_made")]},
    "/api/v1/notifications/webpush/subscriptions": lambda: [
        {"id": 4, "user_id": 1, "endpoint": "https://web.push.apple.com/x", "device_id": "d1",
         "device_label": "MacBook Air", "user_agent": "Mozilla/5.0 (Macintosh)", "created_at": "2026-09-01T10:00:00",
         "last_seen_at": "2026-10-03T21:00:00", "last_success_at": "2026-10-03T21:00:00", "failure_count": 0,
         "disabled": False}],
    "/api/v1/notifications/webpush/settings": lambda: {
        "enabled": True, "grouping": "group_by_title", "quiet_hours_enabled": True, "quiet_hours_start": "23:00",
        "quiet_hours_end": "07:00", "vapid_subject": "mailto:admin@fusionha.app", "vapid_public_key": "BMock",
        "vapid_private_set": True},
    "/api/v1/notifications/apns/status": lambda: {"configured": True, "enabled": True, "topic": "org.elabx.fusionha",
                                                  "environment": "auto", "missing": [], "message": None},
    "/api/v1/notifications/apns/settings": lambda: APNS_SETTINGS,
    "/api/v1/notifications/apns/devices": lambda: [apns_device(1, MOCK_APNS_TOKEN, "iPhone 17 Pro"),
                                                   apns_device(2, "e" * 64, "iPad Air", "production")],
}

NOTIFICATION_POSTS = {
    "/api/v1/notifications/apns/devices": lambda: (apns_device(1, MOCK_APNS_TOKEN, "iPhone 17 Pro"), 201),
    "/api/v1/notifications/apns/test": lambda: ({"sent": 1, "delivered": 1, "devices": [
        {"id": 1, "device_label": "iPhone 17 Pro", "ok": True, "detail": "delivered"}]}, 200),
    "/api/v1/notifications/webpush/test": lambda: ({"sent": 1, "delivered": 1, "devices": []}, 200),
}


SHELL_ROUTES = {
    "/api/v1/library/attention": library_attention,
    "/api/v1/system/runs/attention": lambda: {"count": 0, "items": []},
    "/api/v1/system/indexers/unavailable": lambda: {"count": 0, "items": []},
    "/api/v1/system/commands": lambda: [],
    "/api/v1/settings": shell_settings,
    "/api/v1/search/tvdb": tvdb_search,
}


# `shell` mode: the Library stats sheet's attention + operations sources.
SHELL_SHEET_ROUTES = {
    "/api/v1/library/attention": mock_shell.library_attention,
    "/api/v1/system/runs/attention": mock_shell.run_attention,
    "/api/v1/system/indexers/unavailable": mock_shell.indexers_unavailable,
    "/api/v1/system/commands": mock_shell.commands,
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        path = url.path.rstrip("/")
        query = parse_qs(url.query)
        served, body = mock_add.get(path, query, preview, tvdb_search)
        if served:
            return self.send_json(body) if body is not None or "preview" not in path else self.send_json({"detail": "Not Found"}, 404)
        hit = mock_activity.handle("GET", path, query)
        if SHELL and path in SHELL_SHEET_ROUTES:
            return self.send_json(SHELL_SHEET_ROUTES[path]())
        if SHELL and path == "/api/v1/settings":
            base = hit[0] if hit is not None else shell_settings()
            return self.send_json(base | {"login_layout": "living", "login_living_media": False})
        if hit is not None:
            return self.send_json(*hit)
        routes = {
            "/health": lambda: {"status": "ok", "version": "mock"},
            "/api/v1/setup-status": lambda: load("setup-status.json"),
            "/api/v1/auth/me": lambda: load("me_requestor.json" if REQUESTOR else "me.json"),
            "/api/v1/library": lambda: load("library.json"),
            "/api/v1/queue": queue,
            "/api/v1/history": lambda: load("history.json"),
            "/api/v1/blocklist": lambda: load("blocklist.json"),
            "/api/v1/calendar": lambda: calendar_range(query.get("start", [None])[0], query.get("end", [None])[0]),
            "/api/v1/settings": settings,
            "/api/v1/settings/api-key": lambda: {"api_key": "mock-app-api-key"},
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
            # Requester names for the widget's Requests & issues view.
            "/api/v1/users": lambda: [{"id": 1, "username": "admin", "is_admin": True},
                                      {"id": 4, "username": "maya (plex:4471)", "is_admin": False},
                                      {"id": 6, "username": "theo", "is_admin": False}],
            "/api/v1/qualityprofiles": lambda: load("qualityprofiles.json"),
            "/api/v1/rootfolders": lambda: load("rootfolders.json"),
            "/api/v1/config/add-defaults": lambda: load("add-defaults.json"),
        }
        if path == "/api/v1/wanted":
            state = query.get("state", ["missing"])[0]
            return self.send_json(load(f"wanted_{state}.json"))
        if SHELL and path == f"/api/v1/library/{mock_shell.ACTIVE_SETUP_ID}":
            return self.send_json(mock_shell.setting_up_detail(json.loads((MOCK / "items" / "8.json").read_text())))
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
        if path == "/api/v1/library/setups":
            return self.send_json(mock_shell.setups() if SHELL else {"setups": [], "next_rss_at": None})
        if SHELL and path == "/api/v1/library":
            return self.send_json(mock_shell.library(load("library.json")))
        if SHELL and path == "/api/v1/setup-status":
            return self.send_json(mock_shell.setup_status(load("setup-status.json")))
        if path in SHELL_ROUTES:
            return self.send_json(SHELL_ROUTES[path]())
        if path in NOTIFICATION_ROUTES:
            return self.send_json(NOTIFICATION_ROUTES[path]())
        if path.startswith("/api/v1/system/runs/") and path.rsplit("/", 1)[-1].isdigit():
            return self.send_json({"id": int(path.rsplit("/", 1)[-1]), "status": "completed", "detail": None})
        if path in routes:
            return self.send_json(routes[path]())
        if (body := mock_detail.get(path, query)) is not None:
            return self.send_json(body)
        fixture = api_fixture(path)
        if fixture:
            text = fixture.read_text()
            return self.send_json(json.loads(rebased(text) if fixture.name in REBASED else text))
        self.send_json({"detail": "Not Found"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path.rstrip("/")
        # Ahead of the activity routes, whose catch-all `/check-4k` has no counts.
        if path == "/api/v1/discover/check-4k":
            return self.send_json({"dispatched": True, "queried_indexers": 3, "found_uhd": True, "seasons_seen": [1, 2],
                                   "best_release_name": "Demo.2160p.WEB-DL.DV.HDR10", "message": None,
                                   "format_tags": [{"label": "DV", "kind": "hdr"}, {"label": "HDR10", "kind": "hdr"}]})
        hit = self.activity("POST")
        if hit:
            return self.send_json(*hit)
        path = urlparse(self.path).path.rstrip("/")
        if path in NOTIFICATION_POSTS:
            return self.send_json(*NOTIFICATION_POSTS[path]())
        if path.startswith("/api/v1/library/") and path.endswith("/refresh"):
            return self.send_json({"run_id": 1})
        if path == "/api/v1/library":
            return self.send_json({"id": 1}, 201)
        if path.endswith("/check-4k"):
            return self.send_json({"dispatched": True, "queried_indexers": 3, "found_uhd": True, "seasons_seen": [],
                                   "format_tags": [], "message": ""})
        body = mock_detail.post(path)
        self.send_json({} if body is None else body)

    def do_PUT(self):
        path = urlparse(self.path).path.rstrip("/")
        if path in ("/api/v1/notifications/apns/settings", "/api/v1/notifications/webpush/settings",
                    "/api/v1/notifications/preferences"):
            self.rfile.read(int(self.headers.get("Content-Length") or 0))
            return self.send_json(NOTIFICATION_ROUTES[path]())
        hit = self.activity("PUT")
        if hit:
            return self.send_json(*hit)
        self.send_json(settings() if self.path.startswith("/api/v1/settings") else {})

    def do_PATCH(self):
        self.send_json({})

    def do_PATCH(self):
        self.send_json({})

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


REQUESTOR = False
SHELL = False

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    # `requestor` serves a request-scoped account (Discover · My requests · You).
    REQUESTOR = len(sys.argv) > 2 and sys.argv[2] == "requestor"
    # `shell` serves a bigger A–Z library, title setups in flight and the Living-logo sign-in.
    SHELL = len(sys.argv) > 2 and sys.argv[2] == "shell"
    # `perf` serves Activity / Wanted at volume (1000 history events, 600 blocklist
    # entries, 400 task runs, 20 live downloads) for the perf job.
    mock_activity.VOLUME = len(sys.argv) > 2 and sys.argv[2] == "perf"
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
