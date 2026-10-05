"""Add title v2 mock routes (fusionha 0.4.127-0.4.139) for the CI screenshots.

The preview grows the fields the configure step reads: per-season aired /
recent counts with real episode counts, movie release dates and the grab-gate
estimate, and the next air date. Also the TVDB-only preview, "Use last
settings" and one upcoming movie (dated from today) so "When to grab it" has
a Today pill between its stops.
"""
import datetime as dt

# Real season lengths for the demo series (tmdb id -> [(season, episodes, aired)]).
# aired=None means every episode has aired.
SEASONS = {
    1396: [(1, 7, None), (2, 13, None), (3, 13, None), (4, 13, None), (5, 16, None)],
    1399: [(0, 12, None), (1, 10, None), (2, 10, None), (3, 10, None), (4, 10, None), (5, 10, None),
           (6, 10, None), (7, 7, None), (8, 6, None)],
    63639: [(1, 10, None), (2, 13, None), (3, 13, None), (4, 10, None), (5, 10, None), (6, 6, None)],
    66732: [(1, 8, None), (2, 9, None), (3, 8, None), (4, 9, None), (5, 8, 4)],
    30991: [(1, 26, None)],
    31911: [(1, 64, None)],
    1429: [(0, 8, None), (1, 25, None), (2, 12, None), (3, 22, None), (4, 30, None)],
}
ONGOING = {66732: "Returning Series"}

UPCOMING_TMDB = 1170608
LAST_ADDED = {
    "series": {"item_id": 9, "title": "Game of Thrones", "added_at": "2026-10-01T18:20:00",
               "versions": [{"tier": "HD-1080p", "root_folder_id": 7, "quality_profile_id": 15},
                            {"tier": "UHD-2160p", "root_folder_id": 8, "quality_profile_id": 16}],
               "monitor": "future", "minimum_availability": None, "series_type": "standard"},
    "movie": {"item_id": 5, "title": "Interstellar", "added_at": "2026-09-28T09:00:00",
              "versions": [{"tier": "HD-1080p", "root_folder_id": 5, "quality_profile_id": 15}],
              "monitor": "all", "minimum_availability": "inCinemas", "series_type": "standard"},
}


def _iso(days):
    return (dt.date.today() + dt.timedelta(days=days)).isoformat()


def enrich(body):
    """The Add v2 fields on a `MediaPreviewResult`."""
    if not body:
        return body
    tmdb_id = body.get("tmdb_id")
    if body.get("kind") == "series":
        plan = SEASONS.get(tmdb_id)
        if plan:
            body["seasons"] = [{"season_number": n, "episode_count": count,
                                "aired_count": count if aired is None else aired,
                                "recent_count": 0 if aired is None else min(aired, 4)}
                               for n, count, aired in plan]
        else:
            body["seasons"] = [{**s, "aired_count": s["episode_count"], "recent_count": 0}
                               for s in body.get("seasons") or []]
        if tmdb_id in ONGOING:
            body["status"] = ONGOING[tmdb_id]
            body["next_air_date"] = _iso(6)
    else:
        year = body.get("year") or 2000
        cinema = f"{year}-03-12"
        digital = f"{year}-06-02"
        body.update({"release_date": cinema, "in_cinemas": cinema, "digital_release": digital,
                     "physical_release": f"{year}-06-23",
                     "release_estimate": {"date": digital, "stage": "digital", "estimated": False}})
    return body


def upcoming(preview):
    """A movie that isn't out yet: in cinemas in ~11 weeks, home release estimated."""
    base = preview("movie", 438631)
    if not base:
        return None
    return {**base, "tmdb_id": UPCOMING_TMDB, "title": "Dune: Part Three", "year": int(_iso(75)[:4]),
            "in_library": False, "library_item_id": None, "imdb_id": "tt31378509", "status": "Post Production",
            "tagline": "The end of the prophecy.", "runtime": None, "vote_average": None, "certification": None,
            "release_date": _iso(75), "in_cinemas": _iso(75), "digital_release": None, "physical_release": None,
            "release_estimate": {"date": _iso(165), "stage": "digital", "estimated": True}}


def get(path, query, preview, tvdb_search):
    """(True, body) when this module serves `path`, else (False, None)."""
    if path == "/api/v1/discover/preview":
        tmdb_id = int(query.get("tmdb_id", ["0"])[0])
        if tmdb_id == UPCOMING_TMDB:
            return True, upcoming(preview)
        return True, enrich(preview(query.get("kind", ["movie"])[0], tmdb_id))
    if path.startswith("/api/v1/preview/tvdb/") and path.rsplit("/", 1)[-1].isdigit():
        tvdb_id = int(path.rsplit("/", 1)[-1])
        hit = next((r for r in tvdb_search() if r["tvdb_id"] == tvdb_id), None)
        body = enrich(preview("series", hit["tmdb_id"])) if hit else None
        if body:
            # The TVDB-only preview: no TMDB match, TVDB's own id.
            body = {**body, "tmdb_id": None, "tvdb_id": tvdb_id, "in_library": False, "library_item_id": None}
        return True, body
    if path == "/api/v1/library/last-added":
        if query.get("anime", ["false"])[0] == "true":
            return True, None
        return True, LAST_ADDED.get(query.get("kind", ["movie"])[0])
    return False, None
