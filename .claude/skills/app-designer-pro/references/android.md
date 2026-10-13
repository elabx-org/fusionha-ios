# Android

Android is not "iOS with a back button". It has its own navigation layer,
its own type, its own icons, its own way of using colour and shape, and its
own physics. An app that is copied from the iPhone feels foreign on a Pixel
in the first second, the same way a Material app feels foreign on an iPhone.
And an app that only follows Material's defaults looks like every unthemed
app on the Play Store.

The target is the same as on iOS: **the app's own direction, spoken in the
platform's grammar.** This file is the grammar. Facts here are current as of
October 2026; Material 3 Expressive is still moving in code (§9), so check
the version you build against.

## 1. The canvas

| Device | dp | Status bar | Gesture area | Margin |
|---|---|---|---|---|
| Pixel-class phone (design target) | 412 x 915 | 48 (around the camera hole) | 24 | 16, or 20 to 24 for editorial |
| Compact Android (check it fits) | 360 x 760 to 800 | 24 to 40 | 24 (48 with 3-button nav) | 16 |
| Large phone | 448 x 998 | 48 | 24 | 20 to 24 |

- Mockup pixels are dp, and text sizes are sp (they scale with the user's
  font size, up to 200% on Android 14 and later). Design at 412 x 915 with
  `data-os="android"`; shoot.mjs `--small` renders 360 x 760.
- **Edge to edge is the law.** From Android 15 (targetSdk 35) apps draw
  behind the status bar and the navigation area, and Android 16 removed the
  opt-out for apps that target it. So there is no coloured status bar strip
  and no black bar at the bottom: your ground runs under both, and content
  keeps clear of them with insets. The gesture handle sits on your ground,
  like the home indicator on iOS. On 3-button navigation the system adds a
  translucent scrim; design so it would not cut anything important.
- Display corners are about 44dp on a Pixel. Content near a corner is
  concentric with it.

## 2. Material 3 Expressive in one page

Material 3 Expressive (announced May 2025, shipping on Pixels with Android
16) is the current Material. What it changed, and what it means for a design:

- **Shape is a voice.** A larger corner scale, a library of 35 expressive
  shapes (cookie, clover, sunny, burst, pill, gem...) and **shape morphing**:
  a button squares off when pressed, a selected icon's container changes
  shape, a loading indicator morphs between shapes.
- **Motion is springs**, in two kinds: spatial springs for position, size
  and shape (they may overshoot) and effects springs for colour and opacity
  (they never do). See §7.
- **Bolder type and colour:** emphasized type styles (heavier versions of
  the scale), larger display moments, colour used in bigger fields with more
  contrast between containers.
- **New components:** button groups (connected buttons that squeeze when one
  is pressed), split buttons, the FAB menu, floating and docked toolbars
  (replacing the bottom app bar), a shorter flexible navigation bar, the
  morphing loading indicator, wavy progress indicators.

Use this vocabulary the way the iOS side uses Liquid Glass: as the native
default **behaviour**, with the **look** following your direction. Material's
own baseline look (its purple, its tonal pastel containers, plain Roboto) is
Android's version of the indigo gradient. Never ship it unthemed.

## 3. The navigation layer

Android depth is **tonal**: surfaces get lighter or more tinted as they rise
(surface container levels), and shadows are kept for things that float (a
FAB, a menu). There is no glass navigation layer: a frosted tab bar on
Android is an iPhone costume (the scan warns).

### Top

- **Top app bar:** 64dp tall, leading icon (back arrow `arrow_back`, or
  `menu` at the root), the title in Title Large (22sp) or your display face,
  up to 3 trailing icon buttons (48dp targets). It sits on the ground and
  takes a tonal container colour when content scrolls under it.
- **Medium and large flexible top app bars** start with a big headline and
  collapse into the 64dp bar on scroll. This is Android's large title: use it
  where iOS would use a large title.
- **Search** is often a full-radius search bar at the top (56dp) that
  expands into a full search view. A search tab in the bottom bar is an iOS
  habit.

### Bottom

- **Navigation bar** (the flexible, short one): 64dp, 3 to 5 destinations,
  each a 24dp icon over a label (Label Medium, 12sp). The selected
  destination gets an **active indicator**: a full-radius pill behind the
  icon (about 56 x 32dp) in a container colour, and a filled icon. Below it,
  the 24dp gesture area on the same ground. Mark a drawn bar `data-system`.
- **FAB (floating action button):** the screen's one primary action, bottom
  right, 16dp from the edge, above the navigation bar. 56dp (corner 16),
  80dp medium (corner 20) or 96dp large (corner 28); the extended FAB carries
  a label ("New entry"). A FAB menu opens up to six related actions. A FAB
  is native Android, not a slop tell; the centred "+" docked into the bottom
  bar is the old pattern, and it fails the scan on both platforms.
- **Floating toolbar:** a pill of actions floating above content (an editor's
  tools, a player's controls). It replaces the bottom app bar.
- Not every screen needs a FAB. A screen whose primary action is reading
  has none.

### Going back

- **The system back gesture** (a swipe from either edge) and the top app
  bar's back arrow. Never a "‹ Back" text button.
- **Predictive back:** as the swipe starts, the current screen shrinks and
  the destination peeks behind it; letting go commits. Apps that target
  Android 16 get the system animations by default. It is a real piece of
  motion: if the signature lives on a detail screen, design how it leaves.

### Surfaces

- **Bottom sheets:** drag handle (32 x 4dp), top corners 28dp, a scrim over
  the content; modal for a task, standard (non-modal) for a persistent panel.
- **Dialogs:** corner 28dp, a headline in Headline Small, body text, actions
  as text buttons aligned right ("Cancel", "Delete"). Used rarely.
- **Snackbars** at the bottom, above the FAB and the navigation bar, with one
  text action ("Undo").
- **Menus:** dropdown menus anchored to their button, not action sheets.

### Lists and controls

- **List items:** 56dp one line, 72dp two lines, 88dp three lines; a leading
  24dp icon or a 40dp avatar; supporting text in Body Medium. **No trailing
  chevrons**: that is iOS. Android 16's settings group rows into rounded,
  segmented containers; use that for settings-like lists only.
- **Buttons:** full-radius by default (they square off when pressed in
  Expressive). Filled for the primary, tonal for secondary, outlined and
  text for the rest. Heights 40dp by default, 56dp (medium) for a hero
  action, larger sizes exist for single actions on a screen. Labels in
  sentence case, never ALL CAPS (that was 2018).
- **Switch** 52 x 32dp with a thumb that grows when on; **segmented buttons**
  or a connected button group instead of the iOS segmented control; **chips**
  (32dp, corner 8) for filters and suggestions; sliders with a tall handle.
- **Touch targets: 48dp.** A 24dp icon gets a 48dp button around it.

## 4. Colour

The skill's nine roles (color.md) map onto Material's scheme:

| Skill role | Material role |
|---|---|
| ground | `surface` (and `background`) |
| raised | `surfaceContainer` (`Low` / `High` / `Highest` for levels) |
| ink | `onSurface` |
| ink-2 | `onSurfaceVariant` |
| ink-3 | `outline` (and disabled states) |
| rule | `outlineVariant` |
| accent | `primary` (its one role) |
| on-accent | `onPrimary` |
| accent as a soft fill | `primaryContainer` / `onPrimaryContainer` |

- **Write the scheme from your own values**, light and dark. Material's
  generator (and `dynamicColorScheme`) builds tonal palettes from a seed:
  useful to fill the roles you did not decide, never the source of the
  direction.
- **Dynamic colour (Material You)** recolours the app from the wallpaper.
  It suits utilities that should feel like part of the system. It erases a
  brand: most directed apps keep their own scheme and may offer dynamic
  colour as a setting. Decide, and write it in DIRECTION.md.
- **The tonal soup.** Material's default look tints everything a little:
  every card `primaryContainer`, every chip `secondaryContainer`, the
  ground lavender-grey. The result is soft and indistinct. Keep most of the
  screen on `surface` roles and spend the accent on its one job.
- **The baseline purple** (`#6750A4`, `#EADDFF`, `#E8DEF8`, `#FEF7FF`...) is
  what an app ships when nobody designed its colour. The scan fails it.
- **Dark theme:** Material's dark surface is a dark grey with a hint of the
  primary hue (around `#141218` in the baseline). Tint it from your own hue;
  true black is a choice for OLED-first, media or instrument directions.

## 5. Type

| Face | What it is | When |
|---|---|---|
| **Roboto** | the system face | Plain Roboto at default settings is Android's Inter: the face nobody chose (scan warns) |
| **Roboto Flex** | variable Roboto: wdth 25 to 151, wght 100 to 1000, GRAD, opsz 8 to 144 | Native and sharpened: wide or condensed display, graded weights |
| **Google Sans Flex** | Google's own UI face, open source (OFL) since November 2025: wdth 25 to 151, wght 1 to 1000, **ROND 0 to 100**, GRAD, slnt, opsz 6 to 144 | The Pixel voice. ROND makes it soft (the SF Rounded of Android) |
| A bundled face | any licensed font in `res/font` | Whenever the concept has a voice the system faces cannot make |

**Mapping an iOS direction to Android** (for UI text, and for a "Native,
sharpened" direction that uses each platform's own face on purpose; any
other direction keeps one display face on both platforms, bundled):

| iOS | Android |
|---|---|
| SF Pro | Roboto Flex, or Google Sans Flex |
| SF Pro Expanded | `wdth` 125 to 151 |
| SF Pro Condensed / Compressed | `wdth` 75 / 50 to 62 |
| SF Pro Rounded | Google Sans Flex, `ROND` 100 |
| New York | no system serif: bundle the serif (Newsreader, Literata, Source Serif 4, Instrument Serif...) |
| SF Mono | Roboto Mono, Google Sans Code, JetBrains Mono |

In mockups: `font-family: var(--roboto)` or `var(--gsf)`, and the axes with
`font-stretch` (width) and `font-variation-settings: "ROND" 100, "GRAD" 50`.
device.js loads both from Google Fonts on any page with an Android screen.

**The Material type scale** (sp): Display 57 / 45 / 36, Headline 32 / 28 /
24, Title 22 / 16 / 14, Body 16 / 14 / 12, Label 14 / 12 / 11. They are in
device.css as `.m-display-l` ... `.m-label-s`. As on iOS, the scale is the
floor for text; the design lives in the display moments above it. The same
rules hold: one hero per screen, weights two steps apart, negative tracking
on display, tabular figures for numbers that change, 11sp is the floor.
Material sets body text with slight positive tracking for Roboto; with
Google Sans Flex or a custom face, bring it to about 0.

Big text on Android grows to 200%: layouts reflow (columns stack, rows wrap)
instead of truncating.

## 6. Shape

- **The corner scale** (dp): none 0, extra small 4, small 8, medium 12,
  large 16, large increased 20, extra large 28, extra large increased 32,
  extra extra large 48, full. Pick a family as on iOS: small for chips and
  fields, large or extra large for containers, full for buttons and the
  navigation pill.
- **Expressive shapes** are for avatars, image crops, a loading indicator,
  a selected state, a celebration. In Compose they are `MaterialShapes`. One
  shape with a meaning beats five shapes as decoration: cookie-shaped
  avatars on every row are the new Android slop.
- **Morph with state:** pressed buttons square off, a selected item's
  container changes shape, a toggle grows. Shape change is how Expressive
  says "this changed".
- **Square corners** are a valid direction choice here too (Swiss,
  editorial). Commit.

## 7. Motion and haptics

Material's motion schemes are springs. Values as published in the Material
motion tokens (check `MotionScheme` in the version you pin):

| Spring | Use | Damping | Stiffness |
|---|---|---|---|
| Expressive spatial, fast | small things: a switch, a chip, a button | 0.6 | 800 |
| Expressive spatial, default | most moves: a card, a sheet, a nav change | 0.8 | 380 |
| Expressive spatial, slow | full-screen moves | 0.8 | 200 |
| Standard spatial | the calmer scheme: fast / default / slow | 0.9 | 1400 / 700 / 300 |
| Effects (colour, opacity) | never overshoot: fast / default / slow | 1.0 | 3800 / 1600 / 800 |

- Spatial springs move things and may bounce; effects springs fade and
  recolour and never do. Speed follows size: small elements fast, full
  screen slow.
- **Container transform:** a card grows into its detail screen (Compose
  `SharedTransitionLayout`). It is Android's zoom transition.
- **Predictive back** (§3) is part of every screen's exit.
- **Haptics** have their own vocabulary: `CONFIRM` and `REJECT` for results,
  `SEGMENT_TICK` and `CLOCK_TICK` for scrubbing and snapping,
  `GESTURE_START` / `GESTURE_END` around a drag, `TOGGLE_ON` / `TOGGLE_OFF`,
  `LONG_PRESS`. Same discipline as iOS: on state changes, never on every
  tap. In Compose, `LocalHapticFeedback` with `HapticFeedbackType.Confirm`
  and the rest.
- In mockups, use the `--spring-m3-*` easings in device.css (motion.md §2).
  The expressive fast spring is the bounciest on either platform (for small
  things); the default spring is calmer than iOS `.bouncy`.

## 8. Icons

- **Material Symbols**, one style per app: Rounded (soft), Outlined
  (neutral) or Sharp (precise). A variable font with `FILL`, `wght`, `GRAD`
  and `opsz` axes: match `wght` to the text beside it, `FILL 1` only for the
  selected destination, 24dp by default.
- In mockups: `<span class="ms">search</span>` (Rounded), `.ms.ms-outlined`,
  `.ms.ms-sharp`, `.ms.filled`. The names are the ligatures listed on
  fonts.google.com/icons. device.js loads the font.
- Never SF-style glyphs on Android, never Material Symbols on iOS (the scan
  warns both ways). Custom icons drawn for the direction are fine on both,
  as long as they are one hand and one weight.

## 9. In code (October 2026)

- Compose Material 3 **1.4.0** is the stable line; **1.5.0** is in beta and
  carries the Expressive components (several, like the floating toolbar,
  flexible bottom app bar and button groups, have graduated from
  experimental; `MaterialShapes` and the loading indicator were still
  experimental). Google says 1.5.0 goes stable later in 2026. Pin a version
  and read its release notes before writing code. compose.md has the build.
- Flutter's Material library trails Material 3 Expressive; for Flutter,
  design to this file and build the expressive parts by hand.

## 10. Android-only moments worth designing

- **Home screen widgets** (Jetpack Glance): resizable, often the most-seen
  surface of a utility. A strong candidate for the signature on Android.
- **Live Updates** (Android 16): progress-centric notifications for an
  ongoing thing (a delivery, a ride, a timer). The Android answer to Live
  Activities. Design the notification's progress and its compact chip.
- **Quick Settings tiles** for a one-tap action.
- **Themed icon:** the monochrome layer of the adaptive icon (imagery.md §5).

## 11. Android slop, by name

- **"Material Default."** Lavender ground, baseline purple, Roboto 400 and
  500 everywhere, a top app bar that says "Home", a `LazyColumn` of elevated
  cards each with a tonal icon chip, filter chips in `secondaryContainer`, a
  purple FAB with a "+". It is the Compose sample code.
- **"iPhone in a Pixel."** A frosted tab bar, a "‹ Back" button, SF-style
  glyphs, iOS switches, a centred large title on every screen, no FAB where
  the primary action needs one, no thought for the back gesture.
- **Cookie everything:** expressive shapes as decoration on every avatar,
  card and button, and bouncy springs on every element.
- **The fake status bar strip:** a solid colour band under the status bar,
  or content ending at a black bar above the gesture handle. Edge to edge.

Each fails the logo test (slop.md §11) as surely as the iOS faces.
