"""A large library for the iPhone Duo harness: the owner's real make-up
(3,785 titles: 2,629 movies, 734 series, 37 anime, 385 animation), built from
the 14 fixture titles. The fixture titles keep their ids (their detail pages
still open); the rest are copies with new ids, numbered titles and the kind
flags of the bucket they fill. Switched on and off by the harness with
`POST /__mock/big-library?on=1|0`, so the default mock stays small.
"""

import copy

COUNTS = {"movie": 2629, "series": 734, "anime": 37, "animation": 385}
ENABLED = False


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
            for edition in item.get("editions", []):
                edition["id"] = next_edition
                next_edition += 1
            items.append(item)
            next_id += 1
    return items


def library(base):
    return expand(base) if ENABLED else base
