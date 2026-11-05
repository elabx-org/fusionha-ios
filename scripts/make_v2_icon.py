"""v2 icon: v1's F gradient-mapped to warm gold, and a small "2" in the empty corner."""
# Usage: python3 scripts/make_v2_icon.py App/Assets.xcassets/AppIcon.appiconset/icon-1024.png \
#        Shared/Fonts/MonaSansVF.ttf App/Assets.xcassets/AppIconV2.appiconset/icon-1024.png  (needs Pillow, numpy)
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

src, font, out = sys.argv[1:4]
rgb = np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255
lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
t = np.clip((lum - 0.05) / 0.80, 0, 1)[..., None]
stops = np.array([[0.30, 0.07, 0.04], [0.85, 0.33, 0.10], [0.99, 0.62, 0.22], [1.0, 0.86, 0.50]], dtype=np.float32)
pos = t * (len(stops) - 1)
i = np.clip(np.floor(pos).astype(int), 0, len(stops) - 2)[..., 0]
f = pos[..., 0] - i
warm = stops[i] * (1 - f)[..., None] + stops[i + 1] * f[..., None]
# The dark ground stays (its max channel is ~0.07); everything brighter is the F.
w = np.clip((rgb.max(axis=2) - 0.10) / 0.12, 0, 1)[..., None]
mixed = rgb * (1 - w) + warm * w
img = Image.fromarray((np.clip(mixed, 0, 1) * 255).astype(np.uint8), "RGB")

d = ImageDraw.Draw(img)
face = ImageFont.truetype(font, 260)
face.set_variation_by_axes([100, 900])
d.text((790, 790), "2", font=face, fill=(255, 236, 200), anchor="mm")
img.save(out, optimize=True)
