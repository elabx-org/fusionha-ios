# Directions

A direction is the set of decisions that makes every screen of an app feel
like the same object. Without one, each screen is designed from defaults and
the app averages out into slop.

**An anti-slop skill has its own slop.** Its first version turned a habit
tracker, a finance app and a recipe app into the same grey paper form with
mono numbers and one red (slop.md §7). Warm cream with a serif and one italic
word is the other rut. Either one, repeated, is as recognisable as the indigo
gradient. The directions below are a range, not a menu of safe picks. Choose
from the concept, and if the concept wants something none of them describe,
invent it.

**The hex values below are illustrations of a register, never a palette to
copy.** Two apps that both lift `#1F4FE0` from this file are the same app.
Derive every value from your own concept.

## How to choose

1. **Write three concept sentences.** "Ritual is a ___." Fill each with
   something from the real world, never an adjective, and take each from a
   **different source family**:

   | Family | Examples |
   |---|---|
   | Printed matter | a timetable, a boarding pass, a seed packet, a field guide, a zine, a cookbook margin |
   | Objects and materials | a ceramic glaze, a Polaroid, a deck of cards, a terrazzo floor, a sticker sheet, a wristwatch |
   | Places | a public pool, a night market, a planetarium, a corner bakery at 6am, a ski lift, a greenhouse |
   | Media | a vinyl sleeve, a Saturday cartoon, a weather broadcast, a museum audio guide, a film title card |
   | Nature | a tide chart, moss, a sunrise over water, a beehive, a herbarium, a coral reef |
   | Play | a board game, a pinball table, a toy kitchen, a puzzle box, a gachapon machine |

   At most **one** of the three may be a printed form (ticket, ledger,
   receipt, label, timetable). Printed forms are this skill's known rut:
   grey, black, one ink, mono.
2. **Map each concept to a direction below**, or invent one with the same
   fields. The three must land on different grounds (light, dark, colour or
   image), different type, and different richness sources.
3. **Render all three** on the real core screen (SKILL.md Step 2), then pick.
4. **Write the tokens** for the winner into DIRECTION.md. Every screen reads
   from them.

The category never picks the direction. A finance app can be Soft tactile, a
meditation app can be Instrument, a habit app can be Colour field. Fighting
the category's default look is often where the award is.

---

## A. Native, sharpened

*Apple News, Apple Sports, Weather, Journal.* The system design language
executed with more conviction than most third parties manage: large titles,
Liquid Glass chrome, content edge to edge, one brand accent.

- **Type:** SF Pro throughout. Character comes from scale and width:
  Expanded or Compressed for the display moments, Heavy/Black weights at 34+,
  default Dynamic Type styles for everything else.
- **Colour:** system backgrounds (`#FFFFFF` / `#F2F2F7` grouped; `#000000` /
  `#1C1C1E` dark), labels from the system ramp, **one** saturated brand accent
  (Apple News red `#FA2D48`-like, but yours).
- **Layout:** large title, edge-to-edge imagery, inset grouped lists where
  data is list-shaped, floating glass tab bar with a separate search button.
- **Motion:** system springs, zoom navigation transitions, glass morphing.
- **Its own slop:** looks like a template from the SwiftUI sample code. The
  fix is content quality and one moment of scale (a 64pt number, a
  full-bleed photo) per screen.

## B. Editorial

*Five Minute Journal, Apple News+ features, Artifact, Day One at its best.*
The app as a printed publication: a typeface with a voice, a page ground, and
the confidence of white space.

- **Type:** a serif display (New York at 600 to 800 weight, or a licensed
  face) with italic used for one meaning-carrying word; SF Pro for UI
  controls. Big headlines: 32 to 44pt, leading 1.05 to 1.15.
- **Colour:** a paper ground that is *not* cream by default. Try newsprint
  grey `#E9E7E1`, cool bone `#EEF0EC`, pale ink-blue `#E8EDF2`, or pure white
  with black ink and one spot colour. Ink near-black. One spot colour, used
  like a printer would: sparingly, flat.
- **Layout:** asymmetric, left-aligned, hairline rules (0.5pt), generous
  margins (20 to 24pt), images with captions, numbered or dated entries.
- **Motion:** page-like. Cross-fades, gentle zooms into images, nothing bouncy.
- **Its own slop:** the cream-and-terracotta-and-serif wellness look. Rotate
  the ground, and earn the serif.

## C. Instrument

*Flighty, Halide, Sky Guide, Carrot Weather's data views.* The app as a
precision tool: dense, legible, exact, usually dark.

- **Type:** SF Pro Compressed or SF Mono for numerals and codes, tabular
  figures everywhere numbers change, SF Pro Text for labels at 13 to 15pt.
  One giant numeral per screen.
- **Colour:** near-black ground (`#0B0C0E`, or true `#000` on OLED-first apps),
  greys stepped in 3 to 4 levels of the same hue, **one signal colour** that
  means "live" or "attention" (amber, signal green, sodium orange). Red only
  for a real problem.
- **Layout:** tight grid, aligned columns, labels small and above values,
  dividers instead of cards, information density with strict hierarchy.
- **Motion:** precise. Numbers roll (`contentTransition(.numericText())`),
  progress lines draw, maps track. Haptics on state changes.
- **Its own slop:** sci-fi HUD cosplay: glows, scan lines, cyan. Real
  instruments are calm.

## D. Swiss timetable

*Railway signage, Massimo Vignelli, Things 3's restraint, Apple Clock.*
Grid, type, and one colour, nothing else.

- **Type:** SF Pro, often Expanded for headings or Compressed for big
  numbers. Two weights only (Regular and Bold). Flush left, ragged right.
- **Colour:** white or off-white, black, one primary (signal red `#E5322D`,
  cobalt `#1F4FE0`, or yellow `#FFD400` with black). No tints.
- **Layout:** a strict 4 or 6 column grid, large numerals, rules,
  extreme scale contrast, no rounded cards, no shadows.
- **Motion:** snaps and slides along the grid axes. No fades.
- **Its own slop:** sterile. Give it one moment of play or warmth in
  content.

## E. Soft tactile

*Bears Gratitude, (Not Boring) apps, Duolingo at its most restrained,
Partiful.* Chunky, physical, joyful, toy-like, made by one hand.

- **Type:** SF Rounded Heavy or a characterful rounded/grotesque display
  face; big, tightly tracked.
- **Colour:** two or three saturated flats from one family (not a rainbow),
  on a light tinted ground. Shapes with real depth: a hard offset shadow, an
  inner bevel, a pressed state.
- **Layout:** big touch targets, generous radius (concentric), stickers,
  objects you poke.
- **Motion:** bouncy springs, squash on press, confetti only at a real
  milestone, rich haptics.
- **Its own slop:** Memphis-pattern kindergarten. Restraint in the number of
  colours is what makes it feel crafted.

## F. Colour field

*Apple News+ App Store panels, Arc Search, Spotify Wrapped, Teenage
Engineering.* One saturated ground fills the whole screen and the type sits
on it like a poster.

- **Type:** big. 48 to 96pt display moments, tight tracking, black or white
  ink only.
- **Colour:** one bold ground per screen or per mode (tomato, cobalt,
  chartreuse, signal orange). Ink is black or white, picked by contrast.
  Swap the ground to mark sections or states.
- **Layout:** poster composition, type as the image, very few elements.
- **Motion:** colour transitions between states, big type moving as a block.
- **Its own slop:** the ground changes for no reason. It must mean something
  (time, mood, category, step).

## G. Gallery

*Museum apps, VSCO, Glass, Leica.* Images do all the talking; UI nearly
disappears.

- **Type:** small and quiet. 13 to 15pt, regular weights, generous tracking
  on small caps labels. One display size used rarely.
- **Colour:** black or bone ground, ink in two levels. No accent, or a single
  tiny one for selection.
- **Layout:** full-bleed images, wide margins on text, lots of nothing.
- **Motion:** slow, cinematic zooms and cross-fades.
- **Its own slop:** empty and cold. The imagery must be extraordinary or this
  fails.

## H. Field notebook

*Paper notebooks, Field Notes, park maps, seed catalogues, technical
manuals.* Utility printed on a material, with a hand-made trace.

- **Type:** a grotesque or typewriter-ish mono for data, a condensed sans
  for headings, handwriting only as user content.
- **Colour:** a material ground (kraft `#C9B48F`, blueprint `#21447A`, graph
  green `#DDE7DA`, slate) with one stamp colour.
- **Layout:** ruled lines, grids, stamps, labels, coordinates, things filled
  in.
- **Motion:** stamping, ticking, pages turning over.
- **Its own slop:** skeuomorphic costume (stitched leather, torn paper).
  Suggest the material through colour and rule, never texture images.

---

## I. Object world

*(Not Boring) Weather and Habits, Apple's Memoji and Invites stickers, a
toy shelf.* The UI is a small physical world: one hero object, rendered in
3D or as a lit illustration, that reacts to the data and to touch.

- **Type:** a heavy, characterful face (SF Pro Expanded Black, SF Rounded
  Heavy, or a display grotesque) set big against the object.
- **Colour:** the object's materials decide it (glossy enamel, frosted
  glass, chrome, felt). One ground colour that flatters the object, often
  saturated or deep.
- **Layout:** the object owns the top half of the core screen; data sits
  beside or beneath it in few, large figures.
- **Motion:** the object tilts with the gyroscope, squashes on touch,
  changes state with a spring. Rich haptics.
- **Its own slop:** generic glossy 3D blobs. The object must be *specific*
  (this plant, this jar, this instrument) and made in one consistent render
  style. Needs generated or commissioned assets; in a mockup, a carefully
  drawn SVG or CSS object with real lighting is the honest substitute.

## J. Cinematic

*Apple Invites, Apple TV, Airbnb's experiences, Criterion.* Full-bleed
imagery is the ground and type sits on it like a film title.

- **Type:** a display face with presence (New York heavy, SF Pro Expanded,
  a licensed serif or condensed sans), white or near-white on image, large.
- **Colour:** taken from the images; a dominant hue sampled from each
  image tints its screen's chrome and scrims.
- **Layout:** the image fills the screen behind the content; content rises
  on a sheet or a scrim-backed zone at the bottom; glass controls float.
- **Motion:** slow parallax, zoom transitions from thumbnails, image-derived
  colour cross-fading between items.
- **Its own slop:** stock photography with type on top. The images must be
  the user's content or art-directed as one shoot.

## K. Colour objects

*Atoms (the Atomic Habits app, an Editors' Choice), Apple's Invites, a
pebble beach.* A calm, near-white app where colour lives in a few bold,
flat **objects**: a pebble, a badge, one warm card, a habit's own token.
The UI stays quiet and neutral, so every colour lands.

- **Type:** a text serif with a real italic for content and headlines (New
  York, Newsreader, a licensed serif), one italic word carrying the meaning
  ("Small steps, *big momentum*"); SF Pro or Google Sans Flex for controls.
- **Colour:** white or barely-warm white ground, ink near-black, greys
  tinted. Then a **family of 4 to 6 saturated hues** tuned together (same
  energy, different hue: sage, marigold, tangerine, magenta, navy), each
  owned by one thing (a habit, a category, a person) and used on that thing
  everywhere. At most one warm gradient, on one hero object (a "hall of
  fame" card), never on chrome. This is an identity palette, not confetti:
  mark such screens `data-palette="identity"` and list who owns each hue in
  DIRECTION.md.
- **Richness:** the objects themselves, finished (finish.md §1): big soft
  squircle cards with a pillow of light, glossy gradient badges in each
  owner's hues, one aura card for the celebration, a warm dark card for
  advice, illustrated avatars, and crisp organic shapes (pebbles, blobs
  with hard edges, never blurred) on the marketing surfaces. On store panels and
  stages the shapes bleed off the edges and UI components lift out of the
  phone.
- **Layout:** generous white space, one object per moment, content cards
  that are objects you tap (a habit, a lesson), never sections in boxes.
- **Motion:** objects settle with a soft spring, a completed habit's token
  pops and its count rolls; shapes drift into place on the stage.
- **Its own slop:** pastel everything (the hues go timid), shapes as
  wallpaper with no owner, or a purple-to-pink gradient on every card.

## L. Sticker book

*An Apple Design Award finalist translation app with a hand-drawn
capybara, Bears Gratitude, Duolingo's early restraint, Finch.* Fun first:
one character drawn by one hand, and icons like stickers.

- **Type:** a bold, warm grotesque or a rounded sans for headlines (SF Pro
  Rounded Heavy, Google Sans Flex with ROND, Bricolage Grotesque, Familjen
  Grotesk), set short and confident; plain SF or Roboto Flex in the UI.
- **Colour:** white or a light ground, black ink, and a sticker palette of
  4 or 5 flat, saturated colours, each tied to one feature or mode (purple
  for transcribe, red for translate, orange for summaries, green for
  search). Same identity-palette rule as K.
- **Richness:** **a mascot** with a personality and a pose for each key
  moment (onboarding, the empty state, the paywall, a milestone, the icon),
  drawn in one line weight; **sticker icons**: chunky shapes with a thick
  ink outline, a slight tilt, a flat fill. The everyday UI itself stays
  clean and native: the mascot visits, it does not live on every screen.
- **Layout:** native lists and controls, with the stickers and the
  character at the edges of moments: peeking over a sheet, sitting on the
  empty state, holding the paywall's offer.
- **Motion:** the character reacts (a hop, a blink, a head tilt), stickers
  pop in with a bouncy spring, never everything at once.
- **Its own slop:** a generic mascot (any cute animal could swap in),
  stickers in five different drawing styles, the character on every
  screen, or 3D clay renders standing in for illustration.

## The bar

Directions K and L, Apple News+, Flighty and Five Minute Journal are the
level to beat: colour that is bold and owned, type with a voice, one idea
per screen, and a moment of joy. A design that is merely clean and
correct has not started yet.

## Each direction on Android

The direction stays; its grammar changes (platforms.md). Starting points:

| Direction | On Android |
|---|---|
| A. Native, sharpened | Material 3 Expressive with conviction: Google Sans Flex, tonal surfaces from your own scheme, shape morphing on state, the flexible navigation bar, one bold display moment per screen |
| B. Editorial | The bundled serif (Android has no system one), a transparent top app bar over the page ground, Material Symbols Outlined at a light weight |
| C. Instrument | Roboto Flex condensed (`wdth` 75) with tabular figures, Material Symbols Sharp, true black, dividers instead of containers |
| D. Swiss timetable | Google Sans Flex at `wdth` 100 in two weights, square corners (shape none), Sharp symbols, a strict grid |
| E. Soft tactile | Native ground on M3 Expressive: Google Sans Flex with `ROND` 100 Heavy, expressive shapes and bouncy spatial springs |
| F. Colour field | The ground as the scheme's `surface` per mode, the navigation bar tinted from the field, ink black or white |
| G. Gallery | Edge-to-edge images under the status bar, an almost invisible top app bar, Outlined symbols at weight 300 |
| H. Field notebook | The material ground, a condensed Roboto Flex for headings, Sharp symbols, stamps |
| I. Object world | The object drawn the same, the navigation bar as a tonal shelf under it |
| J. Cinematic | Full-bleed image grounds with the status bar on the image (light chrome), content rising on a bottom sheet |
| K. Colour objects | The same objects and identity palette; Google Sans Flex for UI, the serif bundled; FAB in the palette's hue for the current item |
| L. Sticker book | The same character and stickers; Material Symbols only where the stickers do not go; bouncy expressive springs |

## Inventing a direction

Fill the same fields: **source (and its family), type, colour (with hex),
richness source, layout, motion, its own slop.** Then check it is not just one of the above
with a new name.
