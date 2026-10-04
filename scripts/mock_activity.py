"""Activity + Wanted routes for the CI mock server (scripts/mock_server.py).

Builds realistic Queue / History / Blocklist / Tasks / Audit / Indexers and
Wanted (totals + 4K available) payloads relative to "now", so the screenshots
show every section of those screens. `handle(method, path, query)` returns
`(body, status)` or None when the route is not ours.
"""
import datetime as dt
import json
from pathlib import Path

MOCK = Path(__file__).resolve().parent / "mock"


def _load(name):
    return json.loads((MOCK / name).read_text())


def _library():
    return {item["id"]: item for item in _load("library.json")}


def _ago(**kw):
    return (dt.datetime.utcnow() - dt.timedelta(**kw)).isoformat(timespec="seconds")


def _ahead(**kw):
    return (dt.datetime.utcnow() + dt.timedelta(**kw)).isoformat(timespec="seconds")


# MARK: Queue

def _queue_item(n, item, edition, **extra):
    base = {
        "id": 100 + n,
        "title": item["title"],
        "episode_label": None,
        "release_title": f"{item['title'].replace(' ', '.').replace(':', '')}.2160p.WEB-DL.DDP5.1-DEMO",
        "status": "downloading",
        "size": 8.4e9,
        "sizeleft": 3.1e9,
        "progress": 63.0,
        "stalled": False,
        "needs_attention": False,
        "media_item_id": item["id"],
        "edition_id": edition["id"],
        "tier": edition["tier"],
        "poster_url": item["poster_url"],
        "phase": None,
        "step": None,
        "phase_percent": None,
        "protocol": "usenet",
        "download_client": "SABnzbd",
        "indexer": "Demo Usenet",
        "grab_trigger": "search",
        "grabbed_at": _ago(minutes=12),
        "age_seconds": 3600 * 5,
    }
    base.update(extra)
    return base


def queue():
    lib = _library()
    items = [
        _queue_item(0, lib[8], lib[8]["editions"][0], episode_label="S02E02 · Grilled",
                    release_title="Breaking.Bad.S02E02.1080p.BluRay.x264-DEMO", sizeleft=1.2e9, size=2.9e9,
                    progress=59.0, grab_trigger="rss"),
        _queue_item(1, lib[4], lib[4]["editions"][1], size=58.2e9, sizeleft=40.1e9, progress=31.0,
                    protocol="torrent", download_client="qBittorrent", indexer="Demo Torrents"),
        _queue_item(2, lib[13], lib[13]["editions"][0], episode_label="S01E03 · City of Heresy",
                    release_title="Fullmetal.Alchemist.Brotherhood.S01E03.1080p.BluRay.Dual-Audio-DEMO",
                    status="completed", sizeleft=0, progress=100.0, phase="importing", step="Linking files",
                    phase_percent=70, grab_trigger="interactive"),
        _queue_item(3, lib[5], lib[5]["editions"][0], release_title="Interstellar.2014.1080p.BluRay.x264-SPARKS",
                    status="held", sizeleft=0, progress=100.0, held_reason="not_an_upgrade",
                    warning="Not an upgrade over the existing file", has_downloaded_file=True,
                    held_detail={"kind": "not_an_upgrade", "claimed_quality": "BLURAY_1080P",
                                 "probed_quality": "WEBDL_1080P", "probed_resolution": {"w": 1920, "h": 800},
                                 "mislabeled": False, "candidate_cf": 150, "current_quality": "BLURAY_1080P",
                                 "current_cf": 1850, "current_group": "FraMeSToR", "verdict": "keep_current"}),
        _queue_item(4, lib[11], lib[11]["editions"][0], episode_label="S04E02 · Vecna's Curse",
                    release_title="Stranger.Things.S04E02.1080p.WEB.H264-DEMO", status="queued", sizeleft=3.4e9,
                    size=3.4e9, progress=0.0),
    ]
    finished = [
        _queue_item(9, lib[12], lib[12]["editions"][0], episode_label="S01E04 · Gateway Shuffle",
                    release_title="Cowboy.Bebop.S01E04.1080p.BluRay.Dual-Audio-DEMO", status="completed",
                    sizeleft=0, progress=100.0, phase="complete", phase_terminal=True, outcome="imported",
                    finished_at=_ago(seconds=6)),
    ]
    return {"items": items, "total": len(items), "page": 1, "page_size": 50, "just_finished": finished}


# MARK: History / blocklist

def history_sparkline():
    today = dt.date.today()
    counts = [2, 0, 3, 5, 1, 0, 4, 6, 2, 3, 7, 1, 4, 5]
    return [{"date": (today - dt.timedelta(days=13 - i)).isoformat(), "count": c} for i, c in enumerate(counts)]


def blocklist():
    lib = _library()
    rows = [
        (8, 0, "Breaking.Bad.S02E03.1080p.WEB-DL-BROKEN", "Removed by download client (dead NZB)", "WEBDL_1080P", 2.1e9, "S02E03 · Bit by a Dead Bee"),
        (8, 0, "Breaking.Bad.S02E03.1080p.WEB-DL-BROKEN.REPACK", "Removed by download client (dead NZB)", "WEBDL_1080P", 2.2e9, "S02E03 · Bit by a Dead Bee"),
        (11, 0, "Stranger.Things.S04E01.1080p.WEB-BADRELEASE", "Download stalled", "WEBDL_1080P", 3.0e9, "S04E01 · The Hellfire Club"),
        (4, 1, "Dune.2021.2160p.WEB-DL.HDR.DV-FAKE", "Sample-only content: the archive had no real video", "WEBDL_2160P", 18.4e9, None),
        (1, 1, "The.Matrix.1999.2160p.UHD.BluRay.x265-NOGRP", "Manually blocklisted from the queue", "BLURAY_2160P", 41.0e9, None),
    ]
    items = []
    for n, (item_id, ed, title, reason, quality, size, ep) in enumerate(rows):
        item = lib[item_id]
        edition = item["editions"][min(ed, len(item["editions"]) - 1)]
        items.append({
            "id": 200 + n, "title": title, "reason": reason, "created_at": _ago(hours=3 + n * 9),
            "indexer": "Demo Usenet" if n % 2 == 0 else "Demo Torrents", "item_title": item["title"],
            "episode_label": ep, "poster_url": item["poster_url"], "guid": f"https://indexer.demo/details/{9000 + n}",
            "source": "download_client" if n < 3 else "manual", "protocol": "usenet" if n % 2 == 0 else "torrent",
            "media_item_id": item_id, "edition_id": edition["id"], "episode_id": None, "source_title": title,
            "quality": quality, "formats": ["DV", "HDR10"] if "2160" in quality else ["x264"], "size": size,
            "tier": edition["tier"],
        })
    return {"items": items, "total": len(items), "page": 1, "page_size": 50}


# MARK: Tasks

def _run(id, name, trigger, status, **extra):
    run = {
        "id": id, "name": name, "trigger": trigger, "status": status, "item_id": None, "media_kind": None,
        "scope": None, "target_title": None, "target_count": None, "target_summary": None,
        "started_at": _ago(minutes=2), "ended_at": None, "duration_ms": None, "releases": 0, "evaluated": 0,
        "grabbed": 0, "upgraded": 0, "rejected": 0, "errors": 0, "skipped_in_flight": False, "phase": None,
        "progress_current": None, "progress_total": None, "detail": None, "search": None,
    }
    run.update(extra)
    return run


def runs():
    targets = [
        {"group": "Breaking Bad", "tier": "HD-1080p", "label": "S02E02", "state": "grabbed"},
        {"group": "Breaking Bad", "tier": "HD-1080p", "label": "S02E03", "state": "no_release"},
        {"group": "Stranger Things", "tier": "HD-1080p", "label": "S04E01", "state": "searching"},
        {"group": "Stranger Things", "tier": "HD-1080p", "label": "S04E02", "state": "queued"},
        {"group": "Cowboy Bebop", "tier": "HD-1080p", "label": "S01E05", "state": "queued"},
        {"group": "Attack on Titan", "tier": "HD-1080p", "label": "S02E01", "state": "queued"},
    ]
    items = [
        _run(51, "Missing search", "scheduled", "running", started_at=_ago(minutes=4), phase="searching",
             search={"processed": 2, "total": 6, "current": "Stranger Things · S04E01", "grabbed": 1, "no_release": 1,
                     "queued": 3, "last_progress_at": _ago(seconds=20), "stopped": False, "stuck": False,
                     "stalled_seconds": None, "targets": targets}),
        _run(50, "Search", "manual", "completed", item_id=4, media_kind="movie", target_title="Dune",
             started_at=_ago(minutes=18), ended_at=_ago(minutes=17), releases=24, evaluated=24, grabbed=1, rejected=19),
        _run(49, "RSS Sync", "rss", "completed", started_at=_ago(minutes=31), ended_at=_ago(minutes=31),
             releases=112, evaluated=112, grabbed=2, rejected=4),
        _run(48, "Search", "manual", "completed", item_id=11, media_kind="series", target_title="Stranger Things",
             started_at=_ago(hours=1), ended_at=_ago(hours=1), releases=9, evaluated=9),
        _run(47, "RSS Sync", "rss", "completed", started_at=_ago(hours=1, minutes=1), ended_at=_ago(hours=1),
             releases=98, evaluated=98),
        _run(46, "RSS Sync", "rss", "completed", started_at=_ago(hours=1, minutes=31), ended_at=_ago(hours=1, minutes=31),
             releases=104, evaluated=104, grabbed=1),
        _run(45, "Search", "search_on_add", "failed", item_id=10, media_kind="series", target_title="The Expanse",
             started_at=_ago(hours=3), ended_at=_ago(hours=3), errors=2),
    ]
    return {"items": items, "total": len(items), "page": 1, "page_size": 200}


def run_detail(run_id):
    candidates = [
        {"id": 1, "release_title": "Dune.2021.2160p.UHD.BluRay.REMUX.HDR.DV-FraMeSToR", "release_group": "FraMeSToR",
         "size": 72.4e9, "protocol": "usenet", "indexer": "Demo Usenet", "quality": "REMUX_2160P", "cf_score": 3150,
         "action": "GRAB", "reason": "Best custom-format score", "blocklisted": False},
        {"id": 2, "release_title": "Dune.2021.1080p.WEB-DL.DDP5.1-DEMO", "release_group": "DEMO", "size": 6.2e9,
         "protocol": "usenet", "indexer": "Demo Usenet", "quality": "WEBDL_1080P", "cf_score": 0,
         "action": "REJECT", "reason": "Not wanted in the quality profile", "blocklisted": False},
        {"id": 3, "release_title": "Dune.2021.1080p.WEB-DL.DDP5.1-DEMO", "release_group": "DEMO", "size": 6.2e9,
         "protocol": "torrent", "indexer": "Demo Torrents", "quality": "WEBDL_1080P", "cf_score": 0,
         "action": "REJECT", "reason": "Not wanted in the quality profile", "blocklisted": False},
        {"id": 4, "release_title": "Dune.2021.2160p.WEB-DL.HDR.DV-FAKE", "release_group": "FAKE", "size": 18.4e9,
         "protocol": "torrent", "indexer": "Demo Torrents", "quality": "WEBDL_2160P", "cf_score": -10000,
         "action": "REJECT", "reason": "Blocklisted release", "blocklisted": True},
        {"id": 5, "release_title": "Dune.2021.2160p.WEB-DL.DDP5.1.HDR-NTb", "release_group": "NTb", "size": 21.0e9,
         "protocol": "usenet", "indexer": "Demo Usenet", "quality": "WEBDL_2160P", "cf_score": 1200,
         "action": "SKIP", "reason": "Not an upgrade for the existing REMUX-2160p file", "blocklisted": False},
    ]
    return {"id": run_id, "candidates": candidates, "status": "completed", "phase": None,
            "progress_current": None, "progress_total": None, "detail": None}


def tasks():
    return [
        {"name": "rss-sync", "interval_seconds": 900, "running": False, "last_run": _ago(minutes=31),
         "last_duration": 4.2, "last_result": "2 grabbed", "next_run": _ahead(minutes=13, seconds=36)},
        {"name": "air-times", "interval_seconds": 21600, "running": False, "last_run": _ago(hours=5),
         "last_duration": 1.1, "last_result": "ok", "next_run": _ahead(minutes=48)},
        {"name": "metadata-refresh-active", "interval_seconds": 43200, "running": False, "last_run": _ago(hours=9),
         "last_duration": 22.0, "last_result": "ok", "next_run": _ahead(hours=2, minutes=5)},
        {"name": "media-enrichment", "interval_seconds": 300, "running": True, "last_run": _ago(minutes=4),
         "last_duration": None, "last_result": None, "next_run": _ahead(minutes=1)},
    ]


def enrichment():
    return {"total_files": 26, "enriched_files": 17, "pending_files": 9, "issue_files": 1, "subtasks": []}


def settings():
    return {"voice_playful": True, "animations_enabled": True, "uhd_available_observer_enabled": True,
            "season_search_interval_seconds": 5}


# MARK: Audit / indexers

def audit(query):
    rows = [
        ("user:1:admin", "POST /api/v1/library/{item_id}/editions", "Dune"),
        ("user:1:admin", "PUT /api/v1/settings", None),
        ("user:2:elmer:pat", "POST /api/v1/requests/{request_id}/approve", "Interstellar"),
        ("instance:radarr-4k", "POST /api/v1/library", "Blade Runner"),
        ("user:1:admin", "DELETE /api/v1/blocklist/{entry_id}", "Breaking Bad"),
        ("user:7", "DELETE /api/v1/library/{item_id}", "The Expanse"),
        ("trusted-key", "POST /api/v1/command/rss-sync", None),
    ]
    if query.get("before_id"):
        return []
    return [{"id": 300 - n, "actor": actor, "action": action, "target": target, "at": _ago(hours=n * 4 + 1)}
            for n, (actor, action, target) in enumerate(rows)]


def indexer_stats(query):
    rng = query.get("range", ["7d"])[0]
    series = {"24h": [3, 8, 4, 9, 12, 6, 14], "30d": [40 + (i * 7) % 30 for i in range(30)]}.get(rng, [120, 98, 143, 160, 131, 177, 152])
    indexers = [
        ("Demo Usenet", "usenet", "healthy", 38, 610, 0.97),
        ("Demo Torrents", "torrent", "healthy", 17, 402, 0.93),
        ("NZB Planet", "usenet", "backoff", 6, 211, 0.71),
        ("AnimeTosho", "torrent", "healthy", 9, 118, 0.99),
    ]
    rows = [{
        "id": n + 1, "name": name, "protocol": proto, "health": {"state": state, "failure_count": 3 if state == "backoff" else 0,
                                                                  "last_failure_reason": "HTTP 503" if state == "backoff" else None},
        "grabs_range": grabs, "queries_range": queries, "success_rate_range": rate, "queries_today": queries // 7,
        "activity_series": [v // 4 for v in series],
    } for n, (name, proto, state, grabs, queries, rate) in enumerate(indexers)]
    return {"indexers": rows, "summary": {
        "range": rng, "indexers": 4, "healthy": 3, "backoff": 1, "off": 0, "grabs_range": 70, "queries_range": 1341,
        "avg_success_range": 0.92, "activity_series": series,
    }}


# MARK: Wanted

def wanted(query):
    state = query.get("state", [""])[0]
    if state:
        page = _load(f"wanted_{state}.json")
    else:
        page = dict(_load("wanted_missing.json"))
        page["total"] = 13
        page["items"] = page["items"][:1]
    size = int(query.get("page_size", ["50"])[0])
    if size < len(page["items"]):
        page = {**page, "items": page["items"][:size]}
    return page


def fourk_available(query):
    lib = _library()
    got = lib[9]
    items = [
        {"id": 9, "title": got["title"], "kind": "series", "is_anime": False, "poster_url": got["poster_url"],
         "hd_edition_id": 12, "seen_count": 7, "best_release_name": "Game.of.Thrones.S01.2160p.UHD.BluRay.REMUX.HDR.DV-FraMeSToR",
         "best_quality": "REMUX_2160P", "best_size": 312e9, "last_seen_at": _ago(hours=6), "source": "rss",
         "sources": ["rss", "observed"], "format_tags": [{"label": "Remux", "kind": "quality"}, {"label": "DV HDR10", "kind": "hdr"},
                                                         {"label": "TrueHD Atmos", "kind": "audio"}, {"label": "FraMeSToR", "kind": "group"}],
         "total_seasons": 8, "hd_owned_seasons": 8, "uhd_available_seasons": 3,
         "seasons": [
             {"season_number": 1, "seen_count": 3, "best_release_name": "Game.of.Thrones.S01.2160p.UHD.BluRay.REMUX.HDR.DV-FraMeSToR", "best_quality": "REMUX_2160P", "source": "rss"},
             {"season_number": 2, "seen_count": 2, "best_release_name": "Game.of.Thrones.S02.2160p.WEB-DL.DDP5.1.HDR-NTb", "best_quality": "WEBDL_2160P", "source": "observed"},
             {"season_number": 3, "seen_count": 2, "best_release_name": None, "best_quality": "WEBDL_2160P", "source": "observed"},
         ]},
        {"id": 2, "title": lib[2]["title"], "kind": "movie", "is_anime": False, "poster_url": lib[2]["poster_url"],
         "hd_edition_id": 3, "seen_count": 4, "best_release_name": "Inception.2010.2160p.UHD.BluRay.x265.HDR-DEMO",
         "best_quality": "BLURAY_2160P", "best_size": 58e9, "last_seen_at": _ago(days=2), "source": "observed",
         "sources": ["observed", "manual"], "format_tags": [{"label": "HDR10", "kind": "hdr"}, {"label": "DTS-HD MA", "kind": "audio"}],
         "total_seasons": None, "hd_owned_seasons": None, "uhd_available_seasons": None, "seasons": []},
    ]
    size = int(query.get("page_size", ["50"])[0])
    return {"items": items[:size], "total": len(items), "page": 1, "page_size": size, "fourk_available_count": len(items)}



# MARK: Volume mode (`mock_server.py <port> perf`) for the Activity perf job:
# a large, realistic library history so paging, polling and scrolling are
# exercised at the sizes a real server reaches.

VOLUME = False
_CACHE = {}


def _page(rows, query, default_size=50):
    page = int(query.get("page", ["1"])[0])
    size = int(query.get("page_size", [str(default_size)])[0])
    q = query.get("q", [""])[0].strip().lower()
    if q:
        rows = [r for r in rows if q in (r.get("item_title") or r.get("title") or "").lower()
                or q in (r.get("source_title") or "").lower()]
    return {"items": rows[(page - 1) * size: page * size], "total": len(rows), "page": page, "page_size": size}


def _volume_history():
    if "history" in _CACHE:
        return _CACHE["history"]
    lib = list(_library().values())
    groups = ["NTb", "FLUX", "FraMeSToR", "DON", "SPARKS", "EDITH", "playWEB", "BeatriceRaws"]
    sources = ["WEB-DL", "BluRay", "Remux", "WEBRip"]
    events = []
    minutes = 3
    for n in range(580):
        item = lib[n % len(lib)]
        ed = item["editions"][(n // len(lib)) % len(item["editions"])]
        uhd = "2160" in ed["tier"]
        series = item["kind"] == "series"
        name = item["title"].replace(" ", ".").replace(":", "")
        ep = f".S{n % 6 + 1:02d}E{n % 13 + 1:02d}.Chapter.{n % 9 + 1}" if series else f".{1990 + n % 33}"
        group = groups[n % len(groups)]
        source = sources[n % len(sources)]
        release = f"{name}{ep}.{'2160p' if uhd else '1080p'}.{source}.DDP5.1.Atmos.H.265-{group}"
        quality = ("WEBDL_2160P" if uhd else "WEBDL_1080P") if source.startswith("WEB") else ("BLURAY_2160P" if uhd else "BLURAY_1080P")
        chips = [{"kind": "group", "label": group}, {"kind": "source", "label": source},
                 {"kind": "range", "label": "DV HDR10"} if uhd else {"kind": "edition", "label": "Standard"},
                 {"kind": "audio", "label": "DDP 5.1 Atmos"}, {"kind": "size", "label": f"{4 + n % 30}.2 GB"}]
        common = {
            "media_item_id": item["id"], "edition_id": ed["id"], "episode_id": 5000 + n if series else None,
            "item_title": item["title"], "tier": ed["tier"], "poster_url": item["poster_url"],
            "indexer": "Demo Usenet" if n % 3 else "Demo Torrents", "download_client": "SABnzbd" if n % 3 else "qBittorrent",
            "protocol": "usenet" if n % 3 else "torrent", "quality": quality, "cf_score": 1200 + (n * 37) % 2400,
            "size": (4 + n % 30) * 1.07e9, "source_title": release, "chips": chips, "blocklistable": True,
            "grab_trigger": ["rss", "search", "upgrade", "interactive", "requested"][n % 5], "data": {},
        }
        dl = f"perf-dl-{n}"
        kind = n % 10
        def ev(event_type, at, **extra):
            e = dict(common)
            e.update({"event_type": event_type, "created_at": _ago(minutes=at), "download_id": dl})
            e.update(extra)
            events.append(e)
        if kind <= 5:
            ev("IMPORTED", minutes, data={"import_mode": "symlink"})
            ev("GRABBED", minutes + 14)
        elif kind == 6:
            ev("IMPORTED", minutes, data={"import_mode": "symlink"})
            ev("DELETED", minutes + 1, quality="WEBRIP_1080P", cf_score=400, data={"reason": "UPGRADE"})
            ev("GRABBED", minutes + 20)
        elif kind == 7:
            ev("GRAB_FAILED", minutes, download_id=None, data={"error": "Indexer returned HTTP 503 while fetching the NZB"})
        elif kind == 8:
            ev("DOWNLOAD_FAILED", minutes, data={"error": "Download stalled: no seeders for 6 hours", "reason": "stalled"})
        else:
            ev("RENAMED", minutes, download_id=None, data={})
        minutes += 37
    events.sort(key=lambda e: e["created_at"], reverse=True)
    for i, e in enumerate(events):
        e["id"] = 100000 - i
    _CACHE["history"] = events
    return events


def _volume_blocklist():
    if "blocklist" in _CACHE:
        return _CACHE["blocklist"]
    lib = list(_library().values())
    reasons = ["Removed by download client (dead NZB)", "Download stalled", "Manually blocklisted from the queue",
               "Sample-only content: the archive had no real video", "Release rejected: wrong episode"]
    rows = []
    for n in range(600):
        item = lib[n % len(lib)]
        ed = item["editions"][n % len(item["editions"])]
        uhd = "2160" in ed["tier"]
        title = f"{item['title'].replace(' ', '.').replace(':', '')}.{'2160p' if uhd else '1080p'}.WEB-DL-BAD{n % 17}"
        rows.append({
            "id": 50000 - n, "title": title, "reason": reasons[n % len(reasons)], "created_at": _ago(minutes=11 + n * 53),
            "indexer": "Demo Usenet" if n % 2 == 0 else "Demo Torrents", "item_title": item["title"],
            "episode_label": f"S0{n % 5 + 1}E0{n % 9 + 1} · Chapter" if item["kind"] == "series" else None,
            "poster_url": item["poster_url"], "guid": f"https://indexer.demo/details/{90000 + n}",
            "source": "download_client" if n % 3 else "manual", "protocol": "usenet" if n % 2 == 0 else "torrent",
            "media_item_id": item["id"], "edition_id": ed["id"], "episode_id": None, "source_title": title,
            "quality": "WEBDL_2160P" if uhd else "WEBDL_1080P", "formats": ["DV", "HDR10"] if uhd else ["x264"],
            "size": (2 + n % 40) * 1.1e9, "tier": ed["tier"],
        })
    _CACHE["blocklist"] = rows
    return rows


def _volume_queue():
    import time
    lib = list(_library().values())
    now = time.time()
    phases = [None] * 14 + ["importing", "linking", "caching", "probing", "queued", "error"]
    items = []
    for n in range(20):
        item = lib[n % len(lib)]
        ed = item["editions"][n % len(item["editions"])]
        size = (3 + n * 1.7) * 1e9
        pct = ((now * (0.6 + n * 0.05)) + n * 13) % 100
        phase = phases[n]
        extra = {"phase": phase, "phase_percent": int(pct) if phase else None,
                 "step": "Linking files" if phase else None}
        if phase is None:
            extra.update(sizeleft=size * (1 - pct / 100), progress=pct)
        else:
            extra.update(status="completed", sizeleft=0, progress=100.0)
        if n % 7 == 3:
            extra.update(stalled=True)
        items.append(_queue_item(n, item, ed, size=size,
                                 episode_label=f"S0{n % 4 + 1}E0{n % 9 + 1} · Chapter" if item["kind"] == "series" else None,
                                 protocol="torrent" if n % 3 == 0 else "usenet",
                                 download_client="qBittorrent" if n % 3 == 0 else "SABnzbd", **extra))
    finished = [_queue_item(40 + n, lib[n], lib[n]["editions"][0], status="completed", sizeleft=0, progress=100.0,
                            phase="complete", phase_terminal=True, outcome="imported", finished_at=_ago(seconds=6 + n * 9))
                for n in range(4)]
    return {"items": items, "total": len(items), "page": 1, "page_size": 50, "just_finished": finished}


def _volume_runs():
    if "runs" not in _CACHE:
        rows = []
        for n in range(400):
            rid = 9000 - n
            if n % 3 == 0:
                rows.append(_run(rid, "RSS Sync", "rss", "completed", started_at=_ago(minutes=15 * n + 1),
                                 ended_at=_ago(minutes=15 * n), releases=90 + n % 40, evaluated=90 + n % 40, grabbed=n % 3))
            elif n % 3 == 1:
                rows.append(_run(rid, "Search", "manual", "completed", item_id=1 + n % 14, media_kind="movie",
                                 target_title=f"Title {n}", started_at=_ago(minutes=15 * n + 2), ended_at=_ago(minutes=15 * n + 1),
                                 releases=20 + n % 9, evaluated=20 + n % 9, grabbed=n % 2, rejected=n % 7))
            else:
                rows.append(_run(rid, "Search", "search_on_add", "failed" if n % 11 == 0 else "completed", item_id=1 + n % 14,
                                 media_kind="series", target_title=f"Series {n}", started_at=_ago(minutes=15 * n + 3),
                                 ended_at=_ago(minutes=15 * n + 2), errors=1 if n % 11 == 0 else 0))
        _CACHE["runs"] = rows
    live = runs()["items"][:1]
    return live + _CACHE["runs"]


def _volume_audit(query):
    limit = int(query.get("limit", ["100"])[0])
    before = query.get("before_id", [None])[0]
    top = int(before) if before else 3001
    actions = ["POST /api/v1/library/{item_id}/editions", "PUT /api/v1/settings", "DELETE /api/v1/blocklist/{entry_id}",
               "POST /api/v1/command/rss-sync", "POST /api/v1/requests/{request_id}/approve"]
    rows = []
    for i in range(top - 1, max(top - 1 - limit, 2400), -1):
        rows.append({"id": i, "actor": "user:1:admin" if i % 3 else "instance:radarr-4k", "action": actions[i % len(actions)],
                     "target": ["Dune", "Interstellar", None, "Breaking Bad"][i % 4], "at": _ago(minutes=(3001 - i) * 17)})
    return rows


def _volume_wanted(query):
    state = query.get("state", [""])[0]
    base = _load("wanted_missing.json")
    if not state:
        return {**base, "items": base["items"][:1], "total": 900, "missing_titles": 300, "cutoff_unmet_titles": 300,
                "upcoming_titles": 300}
    src = _load(f"wanted_{state}.json")["items"] or base["items"]
    rows = []
    for n in range(300):
        item = json.loads(json.dumps(src[n % len(src)]))
        item["id"] = 20000 + n
        item["title"] = f"{item['title']} {n}"
        rows.append(item)
    page = _page(rows, query)
    return {**base, **page}


def volume_handle(method, path, query):
    if method != "GET":
        return None
    if path == "/api/v1/history":
        return _page(_volume_history(), query), 200
    if path == "/api/v1/blocklist":
        return _page(_volume_blocklist(), query), 200
    if path == "/api/v1/queue":
        return _volume_queue(), 200
    if path == "/api/v1/system/runs":
        return _page(_volume_runs(), query, 200), 200
    if path == "/api/v1/audit":
        return _volume_audit(query), 200
    if path == "/api/v1/wanted":
        return _volume_wanted(query), 200
    return None

def handle(method, path, query):
    """Returns (body, status) for an Activity / Wanted route, or None."""
    if VOLUME and (hit := volume_handle(method, path, query)) is not None:
        return hit
    if method == "GET":
        if path == "/api/v1/queue":
            return queue(), 200
        if path == "/api/v1/history/sparkline":
            return history_sparkline(), 200
        if path == "/api/v1/blocklist":
            return blocklist(), 200
        if path == "/api/v1/system/runs":
            return runs(), 200
        if path.startswith("/api/v1/system/runs/") and path.rsplit("/", 1)[-1].isdigit():
            return run_detail(int(path.rsplit("/", 1)[-1])), 200
        if path == "/api/v1/system/tasks":
            return tasks(), 200
        if path == "/api/v1/import/enrichment-status":
            return enrichment(), 200
        if path == "/api/v1/settings":
            return settings(), 200
        if path == "/api/v1/audit":
            return audit(query), 200
        if path == "/api/v1/indexers/stats":
            return indexer_stats(query), 200
        if path == "/api/v1/wanted":
            return wanted(query), 200
        if path == "/api/v1/wanted/4k-available":
            return fourk_available(query), 200
        return None
    if method == "POST":
        if path == "/api/v1/queue/process":
            return {"in_flight": 4, "imported": 1, "resolved": 0, "left": 3, "skipped": False, "skip_reason": None}, 200
        if path.endswith("/check-4k"):
            return {"found_uhd": True, "message": "Found 2 genuine 2160p releases."}, 200
        if path.endswith("/search/gradual"):
            return {"run_id": 60, "total": 4, "already_running": False}, 200
        return None
    if method in ("PUT", "DELETE"):
        if path == "/api/v1/blocklist/all":
            return {"deleted": 5}, 200
        return {}, 200
    return None
