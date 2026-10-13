# Store assets

The product page is a poster series, not a feature list. Most people decide
from the first three images in a search result, at thumbnail size, in a
second. Design the series like a campaign: one visual system, one promise
per panel, real UI.

## 1. What a great series does

Two references that get it right, and why:

- **Apple News+.** One saturated ground (News red) across every panel, a
  two-line white caption in SF Pro semibold at the top, the real UI on a
  real device below it, the device cropped by the bottom edge. Each panel
  shows a *different kind of content* (magazines, recipes, puzzles, sports,
  local), so the series proves range. Nothing else on the panel.
- **Five Minute Journal.** Panel one is a different colour (marigold) and
  is pure proof: the claim, the review count, the press logos. Every later
  panel is the same warm grey with a serif headline using **one italic word**
  ("Keep track of your *mood*."), and the UI is shown tilted, cropped, or as
  a single blown-up component instead of always the full phone.

## 2. Specs

| Store | Asset | Size | Mockup |
|---|---|---|---|
| App Store | iPhone screenshots, 6.9" class | 1320 x 2868 portrait (1290 x 2796 also accepted), up to 10 | `.panel[data-store="appstore"]` (440 x 956, shot at 3x) |
| Google Play | phone screenshots | 1080 x 1920 (9:16), 2 to 8; JPEG or 24-bit PNG, no alpha; at least 4 at 1080px or more to be eligible for featuring | `.panel[data-store="play"]` (360 x 640, shot at 3x) |
| Google Play | feature graphic | 1024 x 500, required | `.panel[data-store="feature"]` (512 x 250, shot at 2x) |
| Google Play | app icon | 512 x 512 | exported from the adaptive icon (imagery.md §5) |
| App Store | app icon | 1024 x 1024 | the `.app-icon` (imagery.md §4) |

shoot.mjs exports every panel at its exact size, opaque, into `panels/`,
fails a panel that comes out at the wrong size, and tiles the series into
`panels.png`. Check the specs in App Store Connect and the Play Console
before uploading: both change sizes from time to time.

Put the UI inside a panel with a device that clones the real screen:
`<div class="device" data-os="android" style="--device-scale:.7"><section
class="screen" data-clone="today-android"></section></div>`. device.js
copies the screen named "today-android" in, attributes and all, so the
panel always shows the current design. A screen inside a device is not
scanned again. Quotes and other content shown as content on a panel (a
review on a proof panel, a message) take `data-ugc`, so they are not
counted as caption words.

Two traps with panels and stages around cloned screens:
- **Style the panel with child combinators** (`.panel > h3`, `.stage > h2`):
  a descendant rule like `.panel h3` also restyles every h3 inside the
  cloned app.
- **Centre a device with a flex wrapper**, not `left: 50%` plus a
  transform: `.device` is sized with `zoom`, which a percentage transform
  misreads.

## 3. The series

1. **Panel 1 is the promise or the proof.** Either the single most
   impressive screen with the clearest one-line claim, or a proof panel
   (awards, press, ratings) if the app has real ones. Never invent proof.
2. **Panels 2 to 5: one benefit each,** in the order a new user cares
   about. The caption says the benefit in the user's words, the screen
   shows it happening. "Plan the week in one swipe", not "Powerful planning
   features".
3. **One visual system across all panels:** same ground (or a deliberate
   sequence of grounds), same caption position, same type, same device
   treatment. Then **break it once** for rhythm: a panel with the UI blown
   up past the frame, or a component floating alone, or a tilted phone.
4. **Show real, beautiful content** inside the UI: the best photos, the
   most interesting data, a full-looking state.
5. Dark and light: if the app has a stunning dark mode, give it a panel.

## 4. Both stores

- **Same campaign, each in its own device.** The Play series uses the
  Android screens in a Pixel, the App Store series the iPhone screens in an
  iPhone. Same captions, same grounds, same order.
- Play shows screenshots in a horizontal row on the listing; the first
  two or three must carry the pitch there too.
- **Play's metadata rules** reject ranking and price claims ("#1", "Top",
  "Best", "Free", "50% off") in the icon and title, and they read as cheap
  on panels anyway. Never put them on a panel unless they are true and
  current, and even then think twice.
- **The feature graphic** (Play) is a banner, often shown with a play
  button over its centre when there is a promo video, and cropped on some
  surfaces: keep the name and the key art away from the edges and out of
  the middle third if you add a video. It is a poster for the app: the
  ground, the mark, the name, perhaps one short line. No screenshots of
  lists, no device collage.
- **Preview videos:** App Store app previews must be captured from the
  real app (15 to 30 seconds), so a mockup reel cannot be one. Play's promo
  video is a YouTube link and can be the hero reel (motion.md §8).

## 5. Composition

- Caption at the top, about 120 to 180px from the edge at full size (40 to
  60px in the panel's own units), left-aligned or centred, **consistent**
  across the set.
- **Readable as a thumbnail:** the caption must read at about 150px wide.
  That means 2 lines, 5 to 8 words, a size of about a twentieth of the
  panel's width or more (22px and up on an App Store panel, 18px and up on
  a Play panel, in the panel's own units). The scan warns below that.
- Device below, often cropped by the bottom edge; this reads as more
  confident than a phone floating with margin all around.
- A phone frame is optional. Frameless UI with a large radius and a soft
  shadow is equally current. Pick one for the series.
- Never: starbursts, "NEW!" badges, laurels you did not win, five different
  background colours, clip-art arrows, feature bullet lists, the device at
  three random angles.

## 6. Captions

- Sentence case, benefit first, 5 to 8 words, two balanced lines.
- One emphasis device at most (an italic word, or one word in the accent).
- Written like a person (copy.md §4 and §6). The scan treats panels like
  any other copy: no em dashes, no slop words.
- Localise the captions, not just the UI.

## 7. Stages: launch and social visuals

A `.stage` is a composition for everywhere outside the stores: the launch
post, the website header, a story. 4:5 (1080 x 1350) for feeds, 9:16 (1080
x 1920) for stories and short video, 16:9 (1920 x 1080) for a site or a
video, 1:1 for avatars and carousels. Shot as a PNG by shoot.mjs, recorded
to MP4 by reel.mjs when it has `data-motion`.

What makes one work:

- **One idea:** the hero screen, or the two phones side by side, or one
  component blown up. Not a collage.
- **One line of type,** ten words at most, in the app's display face.
- **The app's ground and richness,** not a generic gradient backdrop.
- **Room at the edges:** feeds crop and overlay buttons near the bottom
  and the sides.
