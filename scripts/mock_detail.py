"""Item-detail routes for the mock server (scripts/mock_server.py).

Everything the detail page asks for beyond the item itself: the analysis pill,
search cooldowns, the settings it reads, the edition vocabulary, tags, the
Searches tab runs and a synthetic interactive-search release list.
"""
import datetime as dt
import json
import re
from pathlib import Path

MOCK = Path(__file__).resolve().parent / "mock"


def _item(item_id):
    path = MOCK / "items" / f"{item_id}.json"
    return json.loads(path.read_text()) if path.exists() else None


def _ago(**delta):
    return (dt.datetime.now(dt.timezone.utc) - dt.timedelta(**delta)).strftime("%Y-%m-%dT%H:%M:%S")


def _runs(item_id):
    item = _item(item_id) or {"title": "Title"}
    title = item["title"]
    rows = [
        ("rss_sync", "scheduled", "success", dict(minutes=12), 41, 1, 0),
        ("item_search", "manual", "success", dict(hours=3), 18, 0, 1),
        ("refresh_item", "manual", "success", dict(hours=9), 0, 0, 0),
        ("season_search", "scheduled", "success", dict(days=1, hours=2), 27, 1, 0),
        ("item_search", "added", "failed", dict(days=3), 0, 0, 0),
    ]
    out = []
    for n, (name, trigger, status, ago, releases, grabbed, upgraded) in enumerate(rows):
        out.append({
            "id": 900 + n, "name": name, "trigger": trigger, "status": status,
            "item_id": item_id, "scope": "item", "target_title": title,
            "target_summary": title, "started_at": _ago(**ago), "ended_at": _ago(**ago),
            "duration_ms": 1800 + n * 950, "releases": releases, "evaluated": releases,
            "grabbed": grabbed, "upgraded": upgraded, "rejected": max(releases - grabbed - upgraded, 0),
            "errors": 1 if status == "failed" else 0, "phase": None,
            "progress_current": None, "progress_total": None,
            "detail": "No indexers responded" if status == "failed" else None,
        })
    return out


def _releases(item_id, edition_id):
    item = _item(item_id)
    if not item:
        return []
    edition = next((e for e in item["editions"] if e["id"] == edition_id), item["editions"][0])
    uhd = edition["tier"] == "UHD-2160p"
    name = re.sub(r"[^A-Za-z0-9]+", ".", item["title"]).strip(".")
    year = item.get("year") or ""
    tag = "S01E01" if item["kind"] == "series" else str(year)
    res = "2160p" if uhd else "1080p"
    code = res.upper()
    rows = [
        (f"{name}.{tag}.{res}.WEB-DL.DDP5.1.H.265-NTb", f"WEBDL_{code}", "USENET", "NZBgeek", 6.2e9 if uhd else 2.9e9, 1650, "grab", None, 2, None),
        (f"{name}.{tag}.{res}.BluRay.REMUX.TrueHD.Atmos-FraMeSToR", f"REMUX_{code}", "TORRENT", "TorrentLeech", 58e9 if uhd else 31e9, 2400, "upgrade", "Better than the current file", 40, 212),
        (f"{name}.{tag}.{res}.WEBRip.x264-GalaxyRG", f"WEBRIP_{code}", "TORRENT", "1337x", 1.4e9, -10000, "reject", "Custom format score -10000 is below the minimum (0)", 5, 1300),
        (f"{name}.{tag}.720p.HDTV.x264-KILLERS", "HDTV_720P", "USENET", "DrunkenSlug", 0.9e9, 0, "reject", "Quality HDTV-720p is not allowed by the profile", 300, None),
        (f"{name}.{tag}.{res}.AMZN.WEB-DL.DDP5.1.H.264-FLUX", f"WEBDL_{code}", "USENET", "NZBgeek", 5.1e9 if uhd else 3.4e9, 1550, "skip", "Not an upgrade over the grabbed release", 9, None),
    ]
    out = []
    for n, (title, quality, proto, indexer, size, score, action, reason, age_days, seeders) in enumerate(rows):
        out.append({
            "guid": f"mock-{item_id}-{edition['id']}-{n}", "title": title, "quality": quality,
            "protocol": proto, "indexer_id": n + 1, "indexer_name": indexer, "size": size,
            "download_url": f"http://127.0.0.1/mock/{n}", "cf_score": score, "action": action,
            "reason": reason, "published_at": _ago(days=age_days), "age_seconds": age_days * 86400.0,
            "seeders": seeders, "release_group": title.rsplit("-", 1)[-1], "blocklisted": False,
            "low_confidence": False,
        })
    return out


def get(path, query):
    """The body for a detail GET route, or None when the path isn't one."""
    if path == "/api/v1/import/enrichment-status":
        return {"total_files": 214, "enriched_files": 214, "pending_files": 0, "issue_files": 0}
    if path == "/api/v1/settings":
        return {"season_search_interval_seconds": 5, "default_movie_minimum_availability": "released",
                "animations_enabled": True}
    if path == "/api/v1/config/editions":
        return [{"id": i + 1, "name": n, "enabled": True} for i, n in enumerate(
            ["Theatrical", "Director's Cut", "Extended", "IMAX", "Remastered", "Black & White"])]
    if path == "/api/v1/tags":
        return [{"id": 1, "label": "4k-wanted"}, {"id": 2, "label": "kids"}, {"id": 3, "label": "favourites"}]
    if path == "/api/v1/system/runs":
        item_id = int(query.get("touched_item", ["0"])[0] or 0)
        runs = _runs(item_id)
        return {"items": runs, "total": len(runs)}
    m = re.fullmatch(r"/api/v1/system/runs/(\d+)", path)
    if m:
        return {"id": int(m.group(1)), "name": "refresh_item", "status": "success",
                "rescan_summary": {"attached": 0, "flagged": 0, "removed": 0, "healed": 0, "dangling": 0, "probed": 2}}
    m = re.fullmatch(r"/api/v1/library/(\d+)/search-pauses", path)
    if m:
        return {"episodes": [], "seasons": [], "now": _ago()}
    m = re.fullmatch(r"/api/v1/library/(\d+)/releases", path)
    if m:
        edition_id = int(query.get("edition_id", ["0"])[0] or 0)
        return _releases(int(m.group(1)), edition_id)
    return None


def post(path):
    """The body for a detail POST route, or None when the path isn't one."""
    if re.fullmatch(r"/library/\d+/search", path):
        return []
    if re.fullmatch(r"/api/v1/library/\d+(/seasons/\d+)?/refresh", path):
        return {"run_id": 950}
    if re.fullmatch(r"/api/v1/library/\d+/check-4k", path):
        return {"dispatched": True, "queried_indexers": 3, "found_uhd": True,
                "best_release_name": "Title.2160p.WEB-DL.DDP5.1.DV.H.265-NTb",
                "message": "4K releases are available on 2 of 3 indexers."}
    return None
