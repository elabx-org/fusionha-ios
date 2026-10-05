"""App-shell fixtures for the `shell` mock mode (`mock_server.py 8767 shell`).

A bigger library spread across the alphabet (so the Library's scroll thumb and
jump-to-letter have something to scrub), title setups in flight
(`GET /api/v1/library/setups`), and the setup status for the Living-logo sign-in.
"""
import copy
import datetime as dt

# (title, year, base fixture id to borrow kind/versions/poster from)
EXTRA_TITLES = [
    ("Akira", 1988, 3), ("Alien", 1979, 2), ("Andor", 2022, 9), ("Arcane", 2021, 10),
    ("Barry", 2018, 8), ("Better Call Saul", 2015, 8), ("Chernobyl", 2019, 9), ("Children of Men", 2006, 2),
    ("Dark", 2017, 9), ("Death Note", 2006, 12), ("Everything Everywhere All at Once", 2022, 4),
    ("Fargo", 2014, 8), ("Frieren: Beyond Journey's End", 2023, 13), ("Gladiator", 2000, 5),
    ("Heat", 1995, 5), ("Hereditary", 2018, 4), ("Jujutsu Kaisen", 2020, 14), ("Knives Out", 2019, 5),
    ("Lost", 2004, 9), ("Mad Max: Fury Road", 2015, 2), ("Mr. Robot", 2015, 8), ("Nope", 2022, 4),
    ("Oppenheimer", 2023, 5), ("Parasite", 2019, 4), ("Perfect Blue", 1997, 7), ("Ran", 1985, 2),
    ("Severance", 2022, 9), ("Shōgun", 2024, 8), ("Succession", 2018, 8), ("Tenet", 2020, 5),
    ("True Detective", 2014, 9), ("Up", 2009, 2), ("Vertigo", 1958, 2), ("Whiplash", 2014, 4),
    ("Yellowjackets", 2021, 9), ("Zodiac", 2007, 5), ("1917", 2019, 5), ("Lioness", 2023, 8),
]

ANIME = {"Akira"}  # borrowed from a non-anime fixture, so flagged here

# The title whose setup is still running (its poster shows the shimmer + ring).
ACTIVE_SETUP_ID = 103  # Andor


def library(base):
    by_id = {item["id"]: item for item in base}
    out = list(base)
    next_edition = 9000
    for n, (title, year, src) in enumerate(EXTRA_TITLES):
        item = copy.deepcopy(by_id[src])
        item.update({"id": 101 + n, "title": title, "year": year, "tmdb_id": 900000 + n,
                     "added_at": "2026-09-01T10:00:00", "release_date": f"{year}-06-01", "has_attention": False})
        if title in ANIME:
            item["is_anime"] = True
        for edition in item["editions"]:
            edition["id"] = next_edition
            next_edition += 1
        out.append(item)
    return out


def _iso(delta):
    return (dt.datetime.utcnow() + delta).replace(microsecond=0).isoformat()


def setups():
    """One series mid-setup and one movie whose first search finished."""
    started = _iso(dt.timedelta(seconds=-40))
    running = {
        "item_id": ACTIVE_SETUP_ID, "title": "Andor", "poster_url": None,
        "steps": [
            {"key": "added", "label": "Added to library", "source": None, "status": "done", "detail": None},
            {"key": "tree", "label": "Seasons & episodes", "source": "TVDB", "status": "running",
             "detail": None},
            {"key": "airtimes", "label": "Air times", "source": "TVmaze", "status": "pending", "detail": None},
            {"key": "numbering", "label": "Episode numbering check", "source": "TVmaze", "status": "pending",
             "detail": None},
            {"key": "search", "label": "Searching for releases", "source": "indexers", "status": "pending",
             "detail": None},
        ],
        "result": None, "started_at": started, "finished_at": None,
    }
    finished = {
        "item_id": 101, "title": "Akira", "poster_url": None,
        "steps": [
            {"key": "added", "label": "Added to library", "source": None, "status": "done", "detail": None},
            {"key": "search", "label": "Searching for releases", "source": "indexers", "status": "done",
             "detail": None},
        ],
        "result": [
            {"version_id": 9000, "edition_id": 9000, "tier": "HD-1080p", "edition": None, "movie_edition": None,
             "grabs": [{"quality": "Bluray-1080p", "target": None, "release_title": "Akira.1988.1080p.BluRay.x264"}],
             "grab_count": 1},
            {"version_id": 9001, "edition_id": 9001, "tier": "UHD-2160p", "edition": None, "movie_edition": None,
             "grabs": [], "grab_count": 0},
        ],
        "started_at": _iso(dt.timedelta(minutes=-2)), "finished_at": _iso(dt.timedelta(seconds=-20)),
    }
    return {"setups": [running, finished], "next_rss_at": _iso(dt.timedelta(minutes=12)) + "Z"}


def setup_status(base):
    """The Living logo needs a connected server; `login_living_media` mirrors the web toggle."""
    return base | {"login_layout": "living", "login_living_media": False}


# The Library stats sheet's "In progress" + "Needs attention" sources.
def library_attention():
    items = [
        {"item_id": 9, "title": "Game of Thrones", "tier": "UHD-2160p", "edition": None, "movie_edition": None,
         "kind": "dead_link", "count": 2, "root_path": "/tv-4k",
         "message": "2 files point at a debrid link that no longer resolves."},
        {"item_id": 138, "title": "Lioness", "tier": "HD-1080p", "edition": None, "movie_edition": None,
         "kind": "not_found", "count": 1, "root_path": "/tv",
         "message": "1 file wasn't found on the last scan."},
    ]
    return {"editions": len(items), "versions": len(items), "titles": len(items), "items": items,
            "numbering_mismatches": 0, "metadata_removed": 0, "arr_scope_mismatches": 0}


def run_attention():
    return {"count": 1, "items": [{"run_id": 4412, "item_id": 104, "media_kind": "series", "scope": "item",
                                   "title": "Arcane", "releases": 14, "started_at": _iso(dt.timedelta(minutes=-30)),
                                   "reason": "14 releases found, none passed your profile (all below the cutoff)."}]}


def indexers_unavailable():
    return {"count": 1, "items": [{"indexer_id": 3, "name": "NZBgeek", "failure_count": 5,
                                   "disabled_till": _iso(dt.timedelta(minutes=18)) + "Z",
                                   "last_failure_at": _iso(dt.timedelta(minutes=-12)) + "Z",
                                   "reason": "HTTP 503 from the API"}]}


def commands():
    return [{"id": "c-rss-1", "name": "rss_sync", "started": _iso(dt.timedelta(seconds=-20)) + "Z",
             "status": "running", "message": "Checking 6 indexers", "progress": 0.4, "ended": None}]


def setting_up_detail(base):
    """Andor's title page mid-setup: the tree step is still running, so no seasons yet."""
    return base | {"id": ACTIVE_SETUP_ID, "title": "Andor", "year": 2022, "tvdb_id": 393189, "tmdb_id": 83867,
                   "overview": "The tale of the burgeoning rebellion against the Empire.",
                   "poster_url": None, "backdrop_url": None, "seasons": [], "history": [], "similar": [],
                   "cast": [], "trailer_key": None, "collection": None, "rescan_summary": None,
                   "numbering_mismatch": None}
