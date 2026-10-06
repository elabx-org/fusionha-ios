#!/usr/bin/env python3
"""Checks screenshots taken mid A-Z scrub for blank or light frames.

Usage: frame_check.py [--strict] shot1.bmp [shot2.bmp ...]

Each argument is a small uncompressed BMP (CI makes them with
`sips -Z 400 -s format bmp`). The content band (between the top bar and the
tab bar) of a healthy frame is the dark page with posters on it. A frame is
LIGHT when most of that band is bright (the old scrub "white flash"), and
BLANK when it is one flat colour (no cards painted at all). Light frames fail
the run; blank-but-dark frames are reported only, unless --strict (the shot
right after a jump must already show the grid's silhouette).
"""
import struct
import sys


def read_bmp(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:2] != b"BM":
        raise ValueError(f"{path}: not a BMP")
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    bpp = struct.unpack_from("<H", data, 28)[0]
    if bpp not in (24, 32):
        raise ValueError(f"{path}: {bpp}-bit BMP")
    step = bpp // 8
    stride = (width * step + 3) & ~3
    top_down = height < 0
    height = abs(height)
    rows = []
    for r in range(height):
        src = r if top_down else height - 1 - r
        base = offset + src * stride
        row = []
        for c in range(width):
            b, g, rr = data[base + c * step], data[base + c * step + 1], data[base + c * step + 2]
            row.append(0.2126 * rr + 0.7152 * g + 0.0722 * b)
        rows.append(row)
    return rows


def verdict(rows):
    h = len(rows)
    band = [v for row in rows[int(h * 0.15):int(h * 0.80)] for v in row]
    mean = sum(band) / len(band)
    light = sum(1 for v in band if v > 180) / len(band)
    var = sum((v - mean) ** 2 for v in band) / len(band)
    if light > 0.35:
        return "LIGHT", mean, light, var ** 0.5
    if var ** 0.5 < 4:
        return "BLANK", mean, light, var ** 0.5
    return "ok", mean, light, var ** 0.5


def main(paths):
    strict = "--strict" in paths
    paths = [p for p in paths if p != "--strict"]
    lines = ["| frame | verdict | mean luma | light px | spread |", "|---|---|---|---|---|"]
    failed = False
    for path in paths:
        kind, mean, light, spread = verdict(read_bmp(path))
        failed |= kind == "LIGHT" or (strict and kind == "BLANK")
        name = path.rsplit("/", 1)[-1]
        lines.append(f"| {name} | {kind} | {mean:.0f} | {light:.0%} | {spread:.0f} |")
    print("\n".join(lines))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
