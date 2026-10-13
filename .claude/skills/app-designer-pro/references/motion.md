# Motion and feel

Screenshots win the click. Motion and feel win the award. Apple Design Award
juries use the app; the thing they remember is how it *responded*.

## 1. What motion is for

Motion explains a change of state. Every animation answers one of:

- **Where did that come from / go?** (navigation, a sheet, a zoom from a
  thumbnail into a detail)
- **What just happened?** (a check, a save, a number changing)
- **What can I do?** (a drag affordance, a rubber band at a limit)
- **How did that feel?** (a reward at a real milestone)

If an animation answers none of these, delete it. Nothing moves on a screen
that did not change. No staggered fade-up entrances on every screen.

## 2. Springs, not curves

iOS motion is spring-based, interruptible, and velocity-preserving. Use
springs everywhere; never linear, never 300ms ease-in-out by habit.

| Use | SwiftUI | Character |
|---|---|---|
| Most UI changes | `.smooth` / `.spring(duration: 0.35, bounce: 0)` | settles without overshoot |
| Quick toggles, selection | `.snappy` / `.spring(duration: 0.25, bounce: 0.1)` | fast, crisp |
| Tossed or celebrated objects | `.bouncy` / `.spring(duration: 0.5, bounce: 0.3)` | playful overshoot |
| Big transitions, sheets | `.spring(duration: 0.5, bounce: 0.05)` | weighty |

Durations: feedback 100 to 200ms, small changes 250 to 350ms, navigation 400
to 500ms. Longer than 600ms feels slow on a phone unless it is a moment.

On Android the same jobs use Material's spring tokens (android.md §7):
expressive spatial fast (damping 0.6, stiffness 800) for small things,
default (0.8, 380) for most moves, slow (0.8, 200) for full-screen ones,
and effects springs (damping 1.0) for colour and opacity, which never
overshoot.

In mockups, device.css carries both platforms' springs as easings,
computed from the real physics, each with the duration it needs:

| Token | Duration | Is |
|---|---|---|
| `--spring-ios-smooth` | 700ms | SwiftUI `.smooth` (no bounce) |
| `--spring-ios-snappy` | 660ms | `.snappy` (a hint of overshoot) |
| `--spring-ios-bouncy` | 740ms | `.bouncy` (overshoots about 4.5%) |
| `--spring-m3-fast` | 370ms | Material expressive fast spatial: the bounciest of all (about 9%), for small things |
| `--spring-m3-default` | 430ms | expressive default spatial: calmer than iOS `.bouncy` (about 1.5%) |
| `--spring-m3-slow` | 590ms | expressive slow spatial, full-screen moves |
| `--spring-m3-effects` | 240ms | effects spring: colour and opacity, never overshoots |

Use them through the custom property (`animation: arrive 430ms
var(--spring-m3-default)`): some toolchains drop a literal `linear()`
written inside a shorthand. Each phone on a stage uses its own platform's
springs.

Animate only `transform` and `opacity` (and `clip-path`). Never `all`.
Use `--spring-smooth` for most moves on both platforms, `--spring-bouncy`
for tossed or celebrated objects (and for Android's expressive fast
spring), and a plain `ease-out` only for fades.

## 3. The native vocabulary (use it before inventing)

- **Zoom navigation:** `.navigationTransition(.zoom(sourceID:in:))` with
  `.matchedTransitionSource` on the thumbnail. Tapping a card grows it into
  the detail view, and a swipe pulls it back. This alone makes an app feel
  premium.
- **Matched geometry:** `matchedGeometryEffect` to move an element between
  two layouts.
- **Numbers:** `.contentTransition(.numericText())` so digits roll.
- **Symbols:** `.symbolEffect(.bounce)`, `.replace`, `.wiggle`, `.breathe`;
  `.contentTransition(.symbolEffect(.replace))` when an icon swaps.
- **Scroll:** `.scrollTransition` for items easing in/out at edges, used
  subtly. `.scrollTargetBehavior(.viewAligned)` for paging carousels.
- **Glass:** `GlassEffectContainer` + `.glassEffectID` so toolbar buttons merge
  and split as liquid.
- **Phase / keyframe:** `PhaseAnimator` and `KeyframeAnimator` for the one
  choreographed moment.

On Android the vocabulary is the container transform (a card grows into
its detail), predictive back (the screen shrinks as the back swipe starts
and the destination peeks behind it), shape morphing on state changes, and
the morphing loading indicator. android.md §7.

## 4. Haptics

Haptics are half of feel and almost always forgotten. On Android use the
platform's own constants (`CONFIRM`, `REJECT`, `SEGMENT_TICK`,
`TOGGLE_ON`...), not a generic buzz (android.md §7).

- `.sensoryFeedback(.selection, trigger:)` on pickers, segmented choices,
  snapping.
- `.impact(weight: .light)` when something lands or docks.
- `.success` on completion, `.warning` and `.error` when something fails.
- **Never** on every tap. Haptics on everything is the motion equivalent of
  every button being purple.

Write the haptic next to every interaction in the spec.

## 5. Direct manipulation

The step from good to award-level is usually here: things follow the finger.

- Drag to dismiss, drag to reorder, drag to scrub.
- Elements track the finger 1:1, then hand off to a spring with the release
  velocity.
- Rubber-band at limits, never a hard stop.
- Long-press lifts (scale 1.03 to 1.05, a soft shadow) before a context menu
  or drag.
- Press states on everything tappable: scale 0.97 or a dim, 100ms in, spring
  out.

## 6. The signature

Every award app has **one interaction people describe to a friend**: the
Flighty departure board, the Halide focus dial, the Things checkmark, the
(Not Boring) weather toy, Crouton's hands-free cooking. Design yours on
purpose:

1. It lives on the core action (the thing done every day), not in a
   corner.
2. It comes from the concept sentence. A "train departure board" app has
   flapping digits. A "pocket notebook" app has a pen stroke. A "seed packet"
   app has something that grows.
3. It is short (under a second), interruptible, has a haptic, and stays
   delightful on the 100th time. If it gets in the way by day three, it is a
   gimmick.
4. Write it as a storyboard in DIRECTION.md: trigger, frames, timing,
   haptic, reduced-motion fallback.
5. Show it: in mockups as 3 to 4 frames of the sequence side by side, or as a
   working HTML prototype.

### Showing it in a mockup

- **By default, 2 or 3 full frames:** real screens frozen at the beats of
  the moment (`data-freeze`), side by side in the sheet. They are readable,
  scanned and judged like any screen.
- A storyboard panel with `.mini` frames (device.css) only when the moment
  is purely about shape and position, three frames in one row at a scale
  of 0.3 or more. At mini scale text is unreadable and unscanned.
- `data-freeze="ms"` pauses a screen's CSS animations at a time. Springs are
  front-loaded: a smooth spring is ~90% of the way there at half its
  duration, so freeze at 25 to 40% of the duration to catch a readable
  in-between frame, or pose the in-between state by hand.

## 7. Reduced motion

`@Environment(\.accessibilityReduceMotion)`. Replace movement with
cross-fades, keep feedback. Never lose information when motion is off.

## 8. Living screens and the reel

Stills win the click on a store page. A screen that moves wins the scroll:
a muted, looping clip of the app doing its job is what people stop for on
a feed, and what they share. Pro designs the motion **across the design**,
not only one interaction: content arrives, numbers roll, a route draws, an
object travels the screen. Then `reel.mjs` records it to video.

### What a living screen is

A real screen of the app (`data-motion="8000"`: an 8-second loop) where the
app is shown working, in a few beats. It is the core screen, with motion
born from the concept:

| Pattern | What moves | Example |
|---|---|---|
| **Arrival** | A new item slides in from an edge and settles with the platform spring; the list makes room | A train's delay drops into the departure list |
| **Count** | The hero number rolls to its new value | The pace ticks from 5:48 to 5:42 a km |
| **Draw** | A line, a route, a ring fills | Today's walk draws itself on the map |
| **Travel** | The concept's object crosses the screen | A paper plane crosses the itinerary as the flight boards |
| **Transform** | A card grows into its detail and back (zoom / container transform) | A recipe card opens into its first step |
| **Material** | The ground itself breathes, slowly | The light of a sky that follows the time of day |
| **Exploded** | On a stage: components lift out of the phone, glide across the frame, and dock back | The plan card floats beside the phone, then returns |

### The rules

1. **One protagonist per beat.** At any moment, one thing moves and the
   rest is still or nearly still. Two things fighting for the eye is noise.
2. **Motion carries content, never decoration.** No floating blobs, no
   drifting particles, no shimmer. If you cannot say what the motion tells
   the viewer, cut it.
3. **The first beat lands by 0.8 seconds.** Feeds autoplay muted and people
   decide in a second.
4. **Platform physics.** iOS springs on the iPhone, Material springs on the
   Android (§2). Same story, each in its own feel.
5. **The loop is seamless.** The last frame flows into the first: every
   animation's duration divides the loop, and every element ends where it
   began. reel.mjs fails a loop that jumps.
6. **No dead air.** Nothing still for more than 2.5 seconds (reel.mjs
   warns), and no frantic motion either: leave a held beat after each
   change so it reads.
7. **The still is chosen.** `data-freeze="3200"` sets the frame shoot.mjs
   uses for the PNG and the scan: the moment that sells the screen.
8. **No flashing** more than three times a second, ever.

### Choreograph on one timeline

Write every beat as keyframes on the loop length, so the whole screen is
one score:

```css
.screen[data-name="today-live"] { --loop: 8000ms; }
/* Beat 1 (0.6s to 1.4s): the delay notice arrives from the right and settles. */
.notice { animation: notice var(--loop) var(--spring-smooth) infinite; }
@keyframes notice {
  0%, 7%    { transform: translateX(110%); }
  17.5%     { transform: translateX(0); }   /* 1.4s: settled */
  88%       { transform: translateX(0); opacity: 1; }
  96%, 100% { transform: translateX(0); opacity: 0; } /* fades out to reset */
}
/* Beat 2 (2.0s to 2.6s): the platform number rolls. */
.platform-new { animation: roll var(--loop) var(--spring-bouncy) infinite; }
@keyframes roll { 0%, 25% { transform: translateY(100%); } 32.5%, 92% { transform: translateY(0); } 100% { transform: translateY(100%); } }
```

- Percentages are beats: `time / loop`. Keep a list of beats with their
  times in DIRECTION.md under `## Motion`.
- The `animation-timing-function` applies between each pair of keyframes,
  so a spring easing works per beat.
- Reset quietly: the last 5 to 10% of the loop returns everything to its
  first frame, ideally under a fade or off-screen.
- A number that rolls sits in a window with `overflow: hidden` marked
  `data-roll`, so a digit caught mid-roll at the freeze frame is not
  reported as clipped text.
- Alternate states that wait their turn (a "paused" label, the next
  card) stay in the DOM: hide them with `opacity: 0` **and** `visibility:
  hidden` in the keyframes, so they never cover what is showing.
- JavaScript timers and `requestAnimationFrame` work too (reel.mjs steps
  the page clock with the frames), but CSS keyframes are exact and
  preferred.

### Walkthroughs

To show a tap, add a finger: `<div class="touch"></div>` (device.css),
positioned on the target. It fades in 150ms before the change, scales to
0.9 on the press, and leaves as the screen responds. One tap per beat, and
never a cursor arrow: phones have fingers.

### The reel set

When the brief includes motion or launch assets:

1. **A living version of the core screen**, on each platform in scope.
2. **A hero stage** (`.stage`, 4:5 for feeds, 9:16 for stories and
   short-form, 16:9 for a site header): the phones in their hardware
   (`.device`), the app's ground, one line of type of at most ten words,
   and the living screens inside. When both platforms ship, the iPhone and
   the Pixel side by side running the same moment, each with its own
   physics. That is the shot people repost.
3. Record: `node <skill>/scripts/reel.mjs mockup.html` (all moving things)
   or `--only <name>`; `--fps 60` for the hero; `--gif` for a light
   preview. MP4s land in `reels/`, with a six-frame `-strip.png` each.

### Reviewing motion

Nobody (and no critic) can judge motion from one still. Review the strip:
six moments across the loop. Each frame should have one clear protagonist,
the beats should read in order, and no frame should look broken (half-way
text, an element clipped mid-flight in an ugly place). Then watch the MP4
on a phone-sized window, twice: once for the story, once for the timing.

App Store preview videos must be captured from the real app, so a reel made
from mockups is for social, the website, the launch post and the Play
Store's promo video, not for App Store previews.

