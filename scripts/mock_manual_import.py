"""Manual Import for the CI screenshots: the held Office S06 pack (download 77)
from the kit's bulk-decide test fixture, so the shots and the tests read the
same scan. Every write answers with that scan; the decide with its answer."""
import json
from pathlib import Path

FIXTURE = (Path(__file__).resolve().parent.parent / "Packages" / "FusionhaKit" / "Tests" / "FusionhaKitTests"
           / "Fixtures" / "manual-import-decide.json")


def handle(method, path):
    """Returns the body for a `/api/v1/manualimport/*` route, or None."""
    if not path.startswith("/api/v1/manualimport/"):
        return None
    data = json.loads(FIXTURE.read_text())
    if method == "POST" and path.endswith("/decide"):
        return data["decide"]
    return data["scan"]
