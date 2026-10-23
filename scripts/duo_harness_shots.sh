#!/bin/bash
# iPhone Duo harness screenshots (Spread, S1 and S2). CI cannot fold a Duo, so the
# DEBUG app renders itself inside a Duo-sized frame with a fake flat fold
# (App/Debug/DuoHarness.swift) on a large iPad simulator, and each shot is
# cropped to that frame. Files: duo-harness-<frame>-<layout>-<screen>.png.
#
#   scripts/duo_harness_shots.sh <app-path> <out-dir> <server-url> [name-regex]
#
# Frames: open 951x669 (fold top to bottom at x 475.5, the device kit's),
# portrait 669x951, folded 466x678. A red hairline marks the fold.
set -u
APP=$1
OUT=$2
S=$3
ONLY=${4:-}
mkdir -p "$OUT"

# The iPad must be wider than 951 pt in portrait: a 13-inch iPad (1032 x 1376).
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for rt, ds in sorted(json.load(sys.stdin)["devices"].items(), reverse=True) if "iOS-2" in rt for d in ds]
pick = next((d for d in devices if "13-inch" in d["name"]), None) or next((d for d in devices if "12.9-inch" in d["name"]), None)
print(pick["udid"] if pick else "")')
if [ -z "$UDID" ]; then echo "::warning::No 13-inch iPad simulator for the Duo harness"; exit 0; fi
echo "Duo harness device: $UDID"
xcrun simctl boot "$UDID" 2> /dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

size() {  # size <frame> -> "<width> <height>" in points
  case $1 in
    open) echo "951 669" ;;
    portrait) echo "669 951" ;;
    folded) echo "466 678" ;;
  esac
}

shoot() {  # shoot <name> <frame> [env…]
  local name=$1 frame=$2; shift 2
  if [ -n "$ONLY" ] && ! echo "$name" | grep -qE "$ONLY"; then return 0; fi
  env SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER="$S" SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_FRAME="$frame" "$@" \
    xcrun simctl launch --terminate-running-process "$UDID" org.elabx.fusionha > /dev/null
  sleep 10
  local raw="$OUT/.raw-$name.png"
  xcrun simctl io "$UDID" screenshot "$raw" > /dev/null
  # Crop the centred frame: points x the screenshot's scale (screen pixels / 1032 or 1024 points wide).
  read -r w h <<< "$(size "$frame")"
  local px scale
  px=$(sips -g pixelWidth "$raw" | awk '/pixelWidth/{print $2}')
  scale=$(python3 -c "import sys; px=int(sys.argv[1]); print(round(px / (1032 if px % 1032 == 0 else 1024)))" "$px")
  sips --cropToHeightWidth $((h * scale)) $((w * scale)) "$raw" --out "$OUT/$name.png" > /dev/null
  rm -f "$raw"
  echo "$name: $(sips -g pixelWidth -g pixelHeight "$OUT/$name.png" | awk '/pixel/{printf "%s ", $2}')"
}

L="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library"
SP="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LAYOUT=spread"
WEB="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LAYOUT=web"
LIST="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_LIST=1"
DAY="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PALETTE=daylight"
# Titles: Blade Runner (3, HD + 4K), Breaking Bad (8, a series).
MOVIE="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=3"
SERIES="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8"
# Warm-up: the first launch against a fresh mock is still loading at 10s.
shoot duo-harness-warmup open $L $SP && rm -f "$OUT/duo-harness-warmup.png"
# Spread, Library: nothing picked (the grid spans both pages), then a title open.
shoot duo-harness-open-spread-library open $L $SP
shoot duo-harness-open-spread-library-title open $L $SP $SERIES
# Again from a cold launch: the title's hero must render every time (S1 review blocker).
shoot duo-harness-open-spread-library-title-2 open $L $SP $SERIES
# S2: the title page on the right page: a movie's HD and 4K cards, a series' seasons.
shoot duo-harness-open-spread-title-movie-versions open $L $SP $MOVIE SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DETAIL_SCROLL=editions
shoot duo-harness-open-spread-title-series-seasons open $L $SP $SERIES SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DETAIL_SCROLL=tabs
# S2: what the title opens presents on the right page (`duoPageSheet`), not over the fold.
shoot duo-harness-open-spread-title-search open $L $SP $MOVIE SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DETAIL_SHEET=search
shoot duo-harness-open-spread-title-edit open $L $SP $MOVIE SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DETAIL_SHEET=edit
# S2: the compact list: Spread keeps it on the left page; the Web layout splits its rows at the fold.
shoot duo-harness-open-spread-library-list open $L $SP $LIST
shoot duo-harness-open-web-library-list open $L $WEB $LIST
# S2: the light palette.
shoot duo-harness-open-spread-library-daylight open $L $SP $DAY
shoot duo-harness-open-spread-library-title-daylight open $L $SP $MOVIE $DAY
# Web layout with the same fold: the web-parity wide layout (fold-gutter fixes only).
shoot duo-harness-open-web-library open $L $WEB
shoot duo-harness-open-web-library-title open $L $WEB $SERIES
shoot duo-harness-open-web-title-edit open $L $WEB $MOVIE SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DETAIL_SHEET=edit
# A work screen in Spread: list on the left page, the right page's default.
shoot duo-harness-open-spread-activity open SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=activity $SP
# S3: Discover › Browse. Nothing picked: the header and rails span both pages,
# Trending 6 across (3 a side); Dune tapped: its preview on the right page,
# the grid on the left with Dune outlined. The Web layout keeps its one-row
# controls, rails and filters off the fold.
D="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=discover"
DUNE="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DISCOVER_OPEN=438631"
FILTERS="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DISCOVER_FILTERS=1 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DISCOVER_SCROLL=filters"
shoot duo-harness-open-spread-discover open $D $SP
shoot duo-harness-open-spread-discover-preview open $D $SP $DUNE
shoot duo-harness-open-spread-discover-filters open $D $SP $FILTERS
shoot duo-harness-open-spread-discover-daylight open $D $SP SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PALETTE=daylight
shoot duo-harness-open-spread-discover-preview-daylight open $D $SP $DUNE SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PALETTE=daylight
shoot duo-harness-open-web-discover open $D $WEB
shoot duo-harness-open-web-discover-filters open $D $WEB $FILTERS
shoot duo-harness-open-web-discover-preview open $D $WEB $DUNE
# S3: the request modal (title on the left page, options on the right) and
# the Add sheet (the right page), in both layouts.
REQ="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_REQUEST=movie/438631/Dune"
shoot duo-harness-open-spread-request open $D $SP $REQ
shoot duo-harness-open-web-request open $D $WEB $REQ
shoot duo-harness-open-spread-add open $D $SP SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD=1
# S3: unified search. Before typing (kind filter, recent, Trending spanning
# both pages), a term (the rows on the left page, the right page's kind filter
# and hint), a result's preview on the right page, and a library title open.
# The Web layout's list stays before the fold. Closed (folded) as the phone.
SE="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=search"
SQ="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_OMNI=a"
SPV="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SEARCH_PREVIEW=63639"
for theme in dark daylight; do
  T=""; SUF=""
  [ "$theme" = daylight ] && T=$DAY && SUF="-daylight"
  shoot duo-harness-open-spread-search-empty$SUF open $SE $SP $T
  shoot duo-harness-open-spread-search$SUF open $SQ $SP $T
  shoot duo-harness-open-spread-search-preview$SUF open $SQ $SPV $SP $T
  shoot duo-harness-folded-search-empty$SUF folded $SE $SP $T
  shoot duo-harness-folded-search$SUF folded $SQ $SP $T
  shoot duo-harness-folded-search-preview$SUF folded $SQ $SPV $SP $T
done
shoot duo-harness-open-spread-search-title open $SQ $SP SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8
shoot duo-harness-open-web-search open $SQ $WEB
shoot duo-harness-open-spread-library-daylight open $L $SP $DAY
# No top-to-bottom fold: Spread does not apply (inner portrait, folded).
shoot duo-harness-portrait-library portrait $L $SP
shoot duo-harness-folded-library folded $L $SP
# Layout A and the title page closed (the outer display), dark and Daylight.
shoot duo-harness-folded-library-daylight folded $L $SP $DAY
shoot duo-harness-folded-title folded $L $SP $SERIES
shoot duo-harness-folded-title-daylight folded $L $SP $SERIES $DAY
shoot duo-harness-open-spread-library-series-daylight open $L $SP $SERIES $DAY
# Requests 10b: Account and Watchlists & lists (the list, a source, Pick the
# right title). Open in a Spread, Account takes both pages and the page splits
# list | detail at the fold; the Web layout keeps the form sheet. Closed: the phone.
ACC="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ACCOUNT=1"
LISTS="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ACCOUNT=lists"
SRC="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_LISTS_SOURCE=letterboxd-watchlist"
PICK="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PICK=1"
for theme in dark daylight; do
  T=""; SUF=""
  [ "$theme" = daylight ] && T=$DAY && SUF="-daylight"
  for frame in open folded; do
    shoot duo-harness-$frame-spread-account$SUF $frame $L $SP $ACC $T
    shoot duo-harness-$frame-spread-lists$SUF $frame $L $SP $LISTS $T
    shoot duo-harness-$frame-spread-lists-source$SUF $frame $L $SP $LISTS $SRC $T
    shoot duo-harness-$frame-spread-lists-pick$SUF $frame $L $SP $LISTS $SRC $PICK $T
  done
done
shoot duo-harness-open-web-lists open $L $WEB $LISTS $SRC
xcrun simctl shutdown "$UDID" || true
ls -l "$OUT"/duo-harness-* 2> /dev/null || true
