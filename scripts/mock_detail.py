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


# Interactive-search fixture: (name tail, quality, protocol, indexer, GB, score,
# action, reason, age hours, seeders, flags, blocklisted). `{res}` / `{RES}` are the
# active edition's resolution, so the HD and 4K tabs each get a realistic list.
_RELEASE_ROWS = [
    ("{res}.BluRay.REMUX.AVC.TrueHD.Atmos.7.1-FraMeSToR", "REMUX_{RES}", "TORRENT", "BeyondHD", 34.8, 2150, "upgrade", "Upgrade from WEBDL-{res} to Bluray-{res} Remux", 410, 186, ["internal"], False),
    ("{res}.BluRay.x264.DTS-HD.MA.5.1-SWTYBLZ", "BLURAY_{RES}", "TORRENT", "TorrentLeech", 14.2, 1850, "upgrade", "Upgrade from WEBDL-{res} to Bluray-{res}", 1300, 64, [], False),
    ("{res}.AMZN.WEB-DL.DDP5.1.H.264-FLUX", "WEBDL_{RES}", "USENET", "NZBgeek", 7.9, 1700, "grab", "Grabbing WEBDL-{res} — no file for this edition yet", 52, None, [], False),
    ("{res}.MA.WEB-DL.DDP5.1.Atmos.H.264-CMRG", "WEBDL_{RES}", "USENET", "DrunkenSlug", 8.4, 1650, "grab", "Grabbing WEBDL-{res} — no file for this edition yet", 75, None, [], False),
    ("{res}.iT.WEB-DL.DD5.1.H.264-playWEB", "WEBDL_{RES}", "USENET", "NZBFinder", 6.1, 1550, "grab", "Grabbing WEBDL-{res} — no file for this edition yet", 140, None, [], False),
    ("{res}.BluRay.DDP5.1.x265.10bit-GalaxyRG265", "BLURAY_{RES}", "TORRENT", "1337x", 4.6, 1250, "upgrade", "Upgrade from WEBDL-{res} to Bluray-{res}", 2200, 1342, [], False),
    ("{res}.AMZN.WEB-DL.DDP5.1.H.264-NTb", "WEBDL_{RES}", "TORRENT", "IPTorrents", 7.7, 1650, "grab", "Grabbing WEBDL-{res} — no file for this edition yet", 30, 211, ["freeleech"], False),
    ("{res}.BluRay.x264-AMIABLE", "BLURAY_{RES}", "USENET", "NZBgeek", 10.9, 1200, "upgrade", "Upgrade from WEBDL-{res} to Bluray-{res}", 5200, None, [], False),
    ("{res}.WEBRip.x264.AAC5.1-YTS.MX", "WEBRIP_{RES}", "TORRENT", "1337x", 2.1, -10000, "reject", "Custom format score -10000 is below the profile minimum 0", 900, 4210, [], False),
    ("{res}.WEBRip.x265.10bit.AAC5.1-RARBG", "WEBRIP_{RES}", "TORRENT", "TorrentLeech", 2.6, -10000, "reject", "Custom format score -10000 is below the profile minimum 0", 3100, 96, [], False),
    ("{res}.HDTV.x264-CtrlHD", "HDTV_{RES}", "USENET", "DrunkenSlug", 4.4, 300, "grab", "Grabbing HDTV-{res} — no file for this edition yet", 8000, None, [], False),
    ("{res}.Hybrid.WEB-DL.DDP5.1.H.264-BLOOM", "WEBDL_{RES}", "USENET", "NZBgeek", 8.8, 1600, "grab", "Grabbing WEBDL-{res} — no file for this edition yet", 12, None, [], True),
    ("{res}.BluRay.REMUX.AVC.DTS-HD.MA.5.1-EPSiLON", "REMUX_{RES}", "USENET", "NZBFinder", 31.2, 2050, "upgrade", "Upgrade from WEBDL-{res} to Bluray-{res} Remux", 640, None, [], False),
    ("{res}.Remastered.BluRay.x264-SPARKS", "BLURAY_{RES}", "TORRENT", "IPTorrents", 12.0, 1100, "reject", "Release edition 'Remastered' does not match the tracked edition 'default'", 9000, 31, [], False),
    ("{res}.WEB-DL.DD5.1.H.264.German.DL-TVARCHiV", "WEBDL_{RES}", "USENET", "DrunkenSlug", 7.2, 900, "reject", "Release languages [German, English] do not include the wanted language English", 300, None, [], False),
    ("{res}.BluRay.x264-HDEX", "BLURAY_{RES}", "TORRENT", "TorrentLeech", 1.1, 1000, "reject", "Release rejected on size — 8 MB/min is outside the 17–400 window for Bluray-{res}", 1700, 12, [], False),
    ("{res}.WEB-DL.AAC2.0.H.264-EVO", "WEBDL_{RES}", "TORRENT", "1337x", 3.9, -50, "grab", "Grabbing WEBDL-{res} — no file for this edition yet", 4400, 388, [], False),
    ("{res}.BluRay.DTS.x264-CtrlHD", "BLURAY_{RES}", "USENET", "NZBgeek", 13.6, 1400, "upgrade", "Upgrade from WEBDL-{res} to Bluray-{res}", 7400, None, [], False),
    ("{res}.WEBRip.DDP5.1.x264-NTG", "WEBRIP_{RES}", "USENET", "NZBFinder", 6.9, 1450, "grab", "Grabbing WEBRip-{res} — no file for this edition yet", 210, None, [], False),
    ("{res}.BluRay.x265.HEVC.10bit.AAC.5.1-Tigole", "BLURAY_{RES}", "TORRENT", "1337x", 5.3, 1300, "upgrade", "Upgrade from WEBDL-{res} to Bluray-{res}", 3300, 147, [], False),
    ("720p.BluRay.x264-SPARKS", "BLURAY_720P", "TORRENT", "TorrentLeech", 5.5, 900, "reject", "Bluray-720p is not wanted in the quality profile", 9100, 44, [], False),
    ("720p.WEB-DL.DD5.1.H.264-NTb", "WEBDL_720P", "USENET", "NZBgeek", 3.2, 800, "reject", "WEBDL-720p is not wanted in the quality profile", 2600, None, [], False),
    ("720p.HDTV.x264-KILLERS", "HDTV_720P", "USENET", "DrunkenSlug", 1.4, 0, "reject", "HDTV-720p is not wanted in the quality profile", 8700, None, [], False),
    ("720p.BRRip.x264-YIFY", "BLURAY_720P", "TORRENT", "1337x", 0.8, -10000, "reject", "Custom format score -10000 is below the profile minimum 0", 8800, 2760, [], False),
    ("DVDRip.XviD-MAXSPEED", "DVD", "TORRENT", "1337x", 0.7, 0, "reject", "DVD is not wanted in the quality profile", 8900, 9, [], False),
    ("576p.BluRay.x264-HANDJOB", "BLURAY_576P", "USENET", "NZBFinder", 2.3, 0, "reject", "Bluray-576p is not wanted in the quality profile", 9050, None, [], False),
    ("{alt}.BluRay.REMUX.HEVC.DV.TrueHD.Atmos.7.1-FraMeSToR", "REMUX_{ALT}", "TORRENT", "BeyondHD", 64.3, 2400, "reject", "Bluray-{alt} Remux is not wanted in the quality profile", 380, 97, ["internal"], False),
    ("{alt}.WEB-DL.DDP5.1.Atmos.DV.HDR.H.265-FLUX", "WEBDL_{ALT}", "USENET", "NZBgeek", 18.7, 2100, "reject", "WEBDL-{alt} is not wanted in the quality profile", 46, None, [], False),
    ("{alt}.BluRay.x265.10bit.HDR.DDP5.1-SWTYBLZ", "BLURAY_{ALT}", "TORRENT", "IPTorrents", 21.4, 1900, "reject", "Bluray-{alt} is not wanted in the quality profile", 1250, 58, [], False),
    ("{res}.WEB-DL.DDP5.1.H.264-SiGMA", "WEBDL_{RES}", "USENET", "DrunkenSlug", 7.5, 1600, "grab", "Grabbing WEBDL-{res} — no file for this edition yet", 3, None, [], False),
    ("{res}.BluRay.x264-OFT", "BLURAY_{RES}", "TORRENT", "TorrentLeech", 9.8, 1150, "upgrade", "Upgrade from WEBDL-{res} to Bluray-{res}", 6100, 23, [], False),
    ("{res}.WEBRip.x264-ION10", "WEBRIP_{RES}", "TORRENT", "1337x", 1.9, 200, "grab", "Grabbing WEBRip-{res} — no file for this edition yet", 5000, 71, [], False),
    ("{res}.HMAX.WEB-DL.DD5.1.H.264-KHN", "WEBDL_{RES}", "USENET", "NZBgeek", 6.6, 1550, "grab", "Grabbing WEBDL-{res} — no file for this edition yet", 160, None, [], True),
    ("{res}.BluRay.DD5.1.x264-VietHD", "BLURAY_{RES}", "TORRENT", "BeyondHD", 15.1, 1350, "upgrade", "Upgrade from WEBDL-{res} to Bluray-{res}", 4800, 18, [], False),
]


def _releases(item_id, edition_id):
    item = _item(item_id)
    if not item:
        return []
    edition = next((e for e in item["editions"] if e["id"] == edition_id), item["editions"][0])
    uhd = edition["tier"] == "UHD-2160p"
    name = re.sub(r"[^A-Za-z0-9]+", ".", item["title"]).strip(".")
    tag = "S01E01" if item["kind"] == "series" else str(item.get("year") or "")
    res, alt = ("2160p", "1080p") if uhd else ("1080p", "2160p")
    out = []
    for n, row in enumerate(_RELEASE_ROWS):
        tail, quality, proto, indexer, gb, score, action, reason, hours, seeders, flags, blocked = row
        fill = dict(res=res, RES=res.upper(), alt=alt, ALT=alt.upper())
        title = f"{name}.{tag}.{tail.format(**fill)}"
        size = int(gb * (2.4 if uhd and "{res}" in tail else 1) * 1024 ** 3)
        out.append({
            "guid": f"mock-{item_id}-{edition['id']}-{n}", "title": title, "quality": quality.format(**fill),
            "protocol": proto, "indexer_id": n % 7 + 1, "indexer_name": indexer, "size": size,
            "download_url": f"http://127.0.0.1/mock/{n}", "cf_score": score, "action": action,
            "reason": reason.format(**fill), "published_at": _ago(hours=hours), "age_seconds": hours * 3600,
            "seeders": seeders, "release_group": title.rsplit("-", 1)[-1], "flags": flags,
            "blocklisted": blocked, "match_score": 100, "match_reason": "matched via TMDB id",
            "low_confidence": False,
        })
    return out


def _scope_status(item_id, edition_id):
    """Auto-search paused on the 4K edition, so its strip shows; idle otherwise."""
    item = _item(item_id) or {"editions": []}
    edition = next((e for e in item["editions"] if e["id"] == edition_id), None)
    paused = bool(edition and edition["tier"] == "UHD-2160p")
    resume = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=2)).strftime("%Y-%m-%dT%H:%M:%S")
    return {
        "backoff_active": paused, "backoff_next_eligible_at": resume if paused else None,
        "backoff_consecutive_empty": 3 if paused else 0, "failed_download_count": 0,
        "failed_grab_cooldown_active": False, "failed_grab_cooldown_until": None,
        "last_run_at": _ago(hours=5), "last_run_releases": 18, "last_run_grabbed": 0,
        "last_run_rejected": 18, "now": _ago(),
    }


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
    m = re.fullmatch(r"/api/v1/library/(\d+)/releases/scope-status", path)
    if m:
        return _scope_status(int(m.group(1)), int(query.get("edition_id", ["0"])[0] or 0))
    m = re.fullmatch(r"/api/v1/library/(\d+)/releases", path)
    if m:
        edition_id = int(query.get("edition_id", ["0"])[0] or 0)
        return _releases(int(m.group(1)), edition_id)
    return None


def post(path):
    """The body for a detail POST route, or None when the path isn't one."""
    if re.fullmatch(r"/api/v1/library/\d+/releases/grab", path):
        return {"id": 77, "status": "queued", "grab_trigger": "interactive"}
    if re.fullmatch(r"/library/\d+/search", path):
        return []
    if re.fullmatch(r"/api/v1/library/\d+(/seasons/\d+)?/refresh", path):
        return {"run_id": 950}
    if re.fullmatch(r"/api/v1/library/\d+/check-4k", path):
        return {"dispatched": True, "queried_indexers": 3, "found_uhd": True,
                "best_release_name": "Title.2160p.WEB-DL.DDP5.1.DV.H.265-NTb",
                "message": "4K releases are available on 2 of 3 indexers."}
    return None
