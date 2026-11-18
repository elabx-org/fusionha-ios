#!/usr/bin/env python3
"""Write an AltStore-format source (which Feather reads) for one release.

Usage:
  make_source.py <ipa> <tag> <version> <build> <out.json>          (v1 only)
  make_source.py --tag <tag> --out <out.json> --app v1=<ipa>:<version>:<build>
                 [--carry <previous source.json>]

The feed URL users add is .../releases/latest/download/source.json, so each
release carries its own source.json pointing at its own IPA. Since the v2
cutover the source lists one app, "fusionha" (org.elabx.fusionha), carrying the
v2 build: Feather offers it as an update to v1. The separate "fusionha v2" app
(org.elabx.fusionha.v2) is no longer listed. --carry copies entries for apps
this run did not build from a previous source.json (none are left today).
"""
import argparse
import datetime
import json
import os
import sys

REPO = "elabx-org/fusionha-ios"
RAW = f"https://raw.githubusercontent.com/{REPO}/main"

# Every app the source can list, in the order it lists them.
APPS = {
    "v1": {
        "name": "fusionha",
        "bundleIdentifier": "org.elabx.fusionha",
        "ipa": "Fusionha.ipa",
        "subtitle": "Movies, series and anime, in 1080p and 4K",
        "localizedDescription": "SwiftUI client for your self-hosted fusionha server: library, queue, calendar, requests, widgets, Live Activities and push, built for iPhone Duo.",
        "icon": f"{RAW}/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
        "tintColor": "6366F1",
    },
}


def app_entry(key, ipa, tag, version, build, date):
    spec = APPS[key]
    download = f"https://github.com/{REPO}/releases/download/{tag}/{spec['ipa']}"
    size = os.path.getsize(ipa)
    notes = f"Build {build} from {os.environ.get('GITHUB_SHA', '')[:7]}".strip()
    entry = {
        "name": spec["name"],
        "bundleIdentifier": spec["bundleIdentifier"],
        "developerName": "elabx",
        "subtitle": spec["subtitle"],
        "localizedDescription": spec["localizedDescription"],
        "iconURL": spec["icon"],
        "tintColor": spec["tintColor"],
        "versions": [
            {
                "version": version,
                "buildVersion": build,
                "date": date,
                "localizedDescription": notes,
                "downloadURL": download,
                "size": size,
                "minOSVersion": "26.0",
            }
        ],
        # Legacy single-version fields, for older AltStore-format readers.
        "version": version,
        "versionDate": date,
        "versionDescription": notes,
        "downloadURL": download,
        "size": size,
        "appPermissions": {"entitlements": [], "privacy": {}},
    }
    print(f"{spec['name']}: {version} ({build}), {size} bytes -> {download}")
    return entry


def carried_entry(key, path):
    """The `key` app's entry from a previous source.json, or None."""
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path) as f:
            previous = json.load(f)
    except (OSError, ValueError) as error:
        print(f"carry: unreadable {path} ({error})")
        return None
    bundle = APPS[key]["bundleIdentifier"]
    apps = previous.get("apps", []) if isinstance(previous, dict) else []
    entry = next((a for a in apps if isinstance(a, dict) and a.get("bundleIdentifier") == bundle), None)
    if entry is None:
        print(f"carry: no {bundle} in {path}")
    else:
        print(f"carry: {APPS[key]['name']} {entry.get('version')} from {path}")
    return entry


def write_source(apps, out):
    source = {
        "name": "fusionha",
        "identifier": "org.elabx.fusionha.source",
        "subtitle": "Native iOS client for fusionha",
        "sourceURL": f"https://github.com/{REPO}/releases/latest/download/source.json",
        "iconURL": APPS["v1"]["icon"],
        "website": f"https://github.com/{REPO}",
        "apps": apps,
        "news": [],
    }
    with open(out, "w") as f:
        json.dump(source, f, indent=2)
    print(f"wrote {out}: {', '.join(str(a.get('name', a.get('bundleIdentifier'))) for a in apps)}")


def parse_app(value):
    key, sep, rest = value.partition("=")
    parts = rest.rsplit(":", 2)
    if not sep or key not in APPS or len(parts) != 3 or not all(parts):
        raise argparse.ArgumentTypeError(f"expected v1=<ipa>:<version>:<build>, got {value!r}")
    return key, parts


def main(argv):
    if argv and not argv[0].startswith("--"):
        # The original single-app form.
        ipa, tag, version, build, out = argv[:5]
        date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        write_source([app_entry("v1", ipa, tag, version, build, date)], out)
        return
    parser = argparse.ArgumentParser(description="Write the Feather/AltStore source for one release.")
    parser.add_argument("--tag", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--app", action="append", type=parse_app, default=[], help="v1=<ipa>:<version>:<build>")
    parser.add_argument("--carry", help="a previous source.json to copy apps from that this run did not build")
    args = parser.parse_args(argv)
    built = dict(args.app)
    if "v1" not in built:
        parser.error("--app v1=... is required")
    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    apps = []
    for key in APPS:
        if key in built:
            ipa, version, build = built[key]
            apps.append(app_entry(key, ipa, args.tag, version, build, date))
        else:
            entry = carried_entry(key, args.carry)
            if entry is not None:
                apps.append(entry)
    write_source(apps, args.out)


if __name__ == "__main__":
    main(sys.argv[1:])
