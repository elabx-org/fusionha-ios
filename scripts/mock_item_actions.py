"""Item-actions routes for the mock server (scripts/mock_server.py).

The detail rail's dialogs: the rename preview (one movable row and one the
server refuses), the per-item edition aliases and the episode-numbering diff.
"""
import re


def _rename(item_id):
    if item_id == 1:
        base = "The Matrix (1999)"
        return [
            {"file_id": 101, "version_id": 1, "from": f"{base}/The.Matrix.1999.1080p.BluRay.x264-DEMO.mkv",
             "to": f"{base}/{base} - BLURAY_1080P.mkv", "blocked": False, "reason": None},
            {"file_id": 102, "version_id": 2, "from": f"{base}/The.Matrix.1999.2160p.UHD.REMUX-DEMO.mkv",
             "to": f"{base}/{base} - BLURAY_1080P.mkv", "blocked": True, "reason": "duplicate_name",
             "blocked_by_file_id": 101, "blocked_by_path": f"{base}/The.Matrix.1999.1080p.BluRay.x264-DEMO.mkv"},
        ]
    show = "Game of Thrones (2011)"
    return [
        {"file_id": 201, "version_id": 12, "from": f"{show}/Season 01/got.s01e01.1080p.mkv",
         "to": f"{show}/Season 01/{show} - S01E01 - Winter Is Coming.mkv", "blocked": False, "reason": None},
        {"file_id": 202, "version_id": 12, "from": f"{show}/Season 01/got.s01e02.1080p.mkv",
         "to": f"{show}/Season 01/{show} - S01E02 - The Kingsroad.mkv", "blocked": False, "reason": None},
    ]


def _numbering(item_id):
    rows = [
        {"season": 1, "kind": "unchanged", "current_number": 1, "alternate_number": 1,
         "current_title": "Winter Is Coming", "alternate_title": "Winter Is Coming"},
        {"season": 1, "kind": "renumbered", "current_number": 2, "alternate_number": 3,
         "current_title": "The Kingsroad", "alternate_title": "The Kingsroad"},
        {"season": 1, "kind": "added", "current_number": None, "alternate_number": 2,
         "current_title": None, "alternate_title": "Unaired Pilot"},
    ]
    return {
        "item_id": item_id, "source": "tvmaze", "diff_hash": "demo-hash", "agrees": False,
        "active_queue_blocked": False, "rows": rows,
        "renumbered": [{"season": 1, "from_number": 2, "to_number": 3, "title": "The Kingsroad"}],
        "added": [{"season": 1, "number": 2, "title": "Unaired Pilot"}],
        "relinked": [{"media_file_id": 202, "path": "Game of Thrones (2011)/Season 01/got.s01e02.1080p.mkv",
                      "from_slots": [[1, 2]], "to_slots": [[1, 3]]}],
        "removed_phantoms": [], "kept_phantoms": [], "unparseable": [],
    }


def get(path, query):
    """The body for an item-actions GET route, or None when the path isn't one."""
    m = re.fullmatch(r"/api/v1/library/(\d+)/rename", path)
    if m:
        return _rename(int(m.group(1)))
    if re.fullmatch(r"/api/v1/library/\d+/edition-aliases", path):
        return [{"id": 1, "term": "Noir Cut", "edition": "Black & White", "guarded": False},
                {"id": 2, "term": "BW", "edition": "Black & White", "guarded": True}]
    m = re.fullmatch(r"/api/v1/library/(\d+)/numbering/preview", path)
    if m:
        return _numbering(int(m.group(1)))
    return None


def post(path):
    """The body for an item-actions POST route, or None when the path isn't one."""
    if re.fullmatch(r"/api/v1/library/\d+/rename", path):
        return {"applied": 1, "skipped": []}
    if re.fullmatch(r"/api/v1/library/\d+/numbering/apply", path):
        return {"run_id": 960}
    if re.fullmatch(r"/api/v1/library/\d+/edition-aliases", path):
        return {"id": 3, "term": "New", "edition": "Black & White", "guarded": False}
    return None
