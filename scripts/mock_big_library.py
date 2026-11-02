"""A large library for the iPhone Duo harness: the owner's real make-up
(3,785 titles: 2,629 movies, 734 series, 37 anime, 385 animation), built from
the 14 fixture titles. The fixture titles keep their ids (their detail pages
still open); the rest are copies with new ids, numbered titles and the kind
flags of the bucket they fill. Switched on and off by the harness with
`POST /__mock/big-library?on=1|0`, so the default mock stays small.

`&art=unique` (the perf job) also gives every copy its own poster URL, served
by the mock from the fixture's TMDB art (`art()`), so the app decodes, caches
and blurs one poster per title as it does with a real library, instead of
reusing the 14 fixtures' bitmaps, and leaves some titles unmonitored (1 in
13) and some flagged (1 in 29), as in a real library.
"""

import copy
import re
import threading
import urllib.request

COUNTS = {"movie": 2629, "series": 734, "anime": 37, "animation": 385}
ENABLED = False
# The mock's own origin (e.g. http://127.0.0.1:8765) when copies get unique art.
ART_BASE = None
_ART = {}
_ART_LOCK = threading.Lock()


def bucket(item):
    if item.get("is_anime"):
        return "anime"
    if item.get("is_animation"):
        return "animation"
    return item["kind"]


def expand(base):
    items = list(base)
    have = {k: 0 for k in COUNTS}
    for item in base:
        have[bucket(item)] += 1
    next_id, next_edition = 100000, 500000
    for kind, want in COUNTS.items():
        # Animation and anime films copy the fixture movies; anime series copy series.
        sources = [i for i in base if i["kind"] == ("series" if kind == "series" else "movie") and not i["is_anime"]]
        for n in range(want - have[kind]):
            src = sources[n % len(sources)]
            item = copy.deepcopy(src)
            item["id"] = next_id
            item["title"] = f"{src['title']} {n + 2}"
            item["is_anime"] = kind == "anime"
            item["is_animation"] = kind == "animation"
            item["kind"] = "series" if kind == "series" else "movie"
            if ART_BASE and item.get("poster_url"):
                item["poster_url"] = re.sub(r"^https://image\.tmdb\.org", f"{ART_BASE}/__mock/art/{next_id}",
                                            item["poster_url"])
                # A real library's mix: some titles unmonitored, a few flagged.
                if n % 13 == 5:
                    item["monitored"] = False
                    for edition in item.get("editions", []):
                        edition["monitored"] = False
                if n % 29 == 7:
                    item["has_attention"] = True
                    item["editions"][0]["attention"] = True
                    item["editions"][0]["unresolved_file_count"] = 1
            for edition in item.get("editions", []):
                edition["id"] = next_edition
                next_edition += 1
            items.append(item)
            next_id += 1
    return items


def library(base):
    return expand(base) if ENABLED else base


def art(path):
    """`/__mock/art/<n>/t/p/<size>/<file>`: the TMDB image `/t/p/<size>/<file>`
    (fetched once, then from memory) as (bytes, content type), or None."""
    m = re.match(r"^/__mock/art/\d+(/t/p/[a-z0-9]+/[^/]+)$", path)
    if not m:
        return None
    key = m.group(1)
    with _ART_LOCK:
        hit = _ART.get(key)
    if hit is None:
        try:
            with urllib.request.urlopen("https://image.tmdb.org" + key, timeout=20) as res:
                hit = (res.read(), res.headers.get("Content-Type", "image/jpeg"))
        except Exception:
            return None
        with _ART_LOCK:
            _ART[key] = hit
    return hit
