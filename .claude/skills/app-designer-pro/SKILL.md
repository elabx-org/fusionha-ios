---
name: app-designer-pro
description: >
  Design iPhone and Android apps that look like Apple Design Award and
  Google Play editors' choice work instead of AI slop, and the screens
  that sell them. Interviews for the concept, explores three genuinely
  different directions on the real core screen, writes the copy in a human
  voice with word budgets per screen, then designs every screen on iOS 26
  (Liquid Glass) and Android 16 (Material 3 Expressive) as one app in two
  native grammars. Designs onboarding and paywalls that convert honestly
  under App Store and Play rules, living screens where the app moves, and
  records them to MP4 reels. Renders at 3x with real status bars, scans the
  rendered design and copy for slop (purple gradients, Material's baseline
  purple, emoji icons, AI sentences, em dashes, word budgets, fake urgency,
  missing prices, clipped text, contrast), has one fresh critic score every
  round, and exports App Store and Google Play screenshots, the feature
  graphic, both app icons (iOS modes, Android adaptive and themed) and
  launch visuals. Can carry the design into SwiftUI, Jetpack Compose, Expo /
  React Native or Flutter. Use for "design my app", "iOS app design",
  "Android app design", "Material 3 / Material You design", "make my app
  look premium", "this looks like AI made it", "redesign this screen",
  "paywall", "onboarding", "app promo video", "App Store screenshots",
  "Play Store screenshots", "SwiftUI / Compose / React Native / Flutter
  design", or any app that should look crafted by a top studio.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, Agent
---

# App Designer Pro

AI slop is not ugly. It is **average**: every decision left at the most likely
value. Cream and terracotta because the app is calm. Lime on black because it
is money. Material's lavender because nobody themed it. "Unlock your
potential" because it is a paywall. Each choice is defensible, and together
they make an app nobody can tell apart from the last hundred.

Award-winning apps are the opposite: a few **specific, defended decisions**,
executed with craft at every pixel, colour that is bold and owned, words a
real person would say, and one moment people remember. This skill is a
process for making those decisions on purpose, on both platforms, and
proving on the rendered screen, in the words and in the motion that you
made them.

**What you produce:** `DIRECTION.md` (brief, concept, voice, tokens, content,
motion beats, signature), a three-direction exploration, every screen at 3x
on iPhone and/or Android, both app icons, living screens and reels (MP4),
onboarding and a paywall when the app charges, store screenshots and
launch visuals when asked, a clean scan, a scored critique per round, and
code when asked.

`<skill>` below means this skill's folder, normally
`~/.claude/skills/app-designer-pro`. First run on a machine:
`(cd <skill> && npm install)` (playwright-core, to drive the installed
Chrome). Reels need ffmpeg (`brew install ffmpeg`).

## The references

Read each one when its step needs it, not all up front:

| File | Read before |
|---|---|
| [slop.md](references/slop.md) | Step 1. What not to do, with what to do instead, on both platforms |
| [directions.md](references/directions.md) | Step 2. Twelve directions, the bar, each direction on Android |
| [type.md](references/type.md), [color.md](references/color.md), [layout.md](references/layout.md) | Step 2 tokens, and Step 4 |
| [finish.md](references/finish.md) | Step 4, and before every critique round: colour, gradients, cards and depth at the level of the best apps; the stranger test |
| [android.md](references/android.md) | any Android screen: canvas, Material 3 Expressive, navigation, colour, type, motion, icons |
| [platforms.md](references/platforms.md) | when both platforms ship: what carries over, what changes, the pair tests |
| [copy.md](references/copy.md) | Step 3, and every round: voice, AI tells, word budgets, honest conversion |
| [imagery.md](references/imagery.md) | Step 2 (what imagery you can get) and Step 4: icons for both, characters, stickers |
| [motion.md](references/motion.md) | the signature (Step 2), living screens and reels (Step 7) |
| [paywall.md](references/paywall.md) | onboarding and paywalls (Step 7) |
| [stores.md](references/stores.md) | store screenshots, the feature graphic, stages (Step 7) |
| [critique.md](references/critique.md) | Step 5 |
| [swiftui.md](references/swiftui.md), [compose.md](references/compose.md), [expo.md](references/expo.md) | Step 8, writing code |

## Step 0: The brief

Ask before designing. One message, short, numbered so they can answer
quickly:

1. **What is the app, and who is it for?** In their words.
2. **The core action:** what someone does in the first ten seconds of
   opening it, every day.
3. **Platforms:** iPhone, Android, or both? Which ships first? Built with
   what (SwiftUI, Compose, Expo / React Native, Flutter, not yet)? If both
   ship at once, explore on the platform with more of their users; if
   nobody knows, the iPhone.
4. **Three words for how it should feel**, and up to three references
   *from outside apps* (a magazine, a shop, an object, a film, a place).
   **Apps whose look they love, as screenshots:** these set the bar for the
   finish (colour, cards, depth). Study them with finish.md §1 and write
   what they do in DIRECTION.md under `## The bar`. Never copy their
   layout or their palette; match their level.
5. **Money:** free, subscription or one-time? A price in mind?
6. **Voice:** something they wrote (a post, a message to a customer), or
   who would talk to their users if the app were a person.
7. **What exists already:** name, logo, colours, fonts, photos, a codebase,
   screenshots of the current app.
8. **What they need:** the app's screens; onboarding and a paywall; living
   screens and a launch reel; App Store / Play screenshots; code. And how
   far to take it: done at the critic's bar, or the portfolio version that
   goes for 5 on every line (more rounds, more time).
9. **Image generation:** if an image-generation tool is connected and it
   costs them credits, may you use it?

Do not re-ask what the user already said. If they are unreachable or said
"just do it", answer the questions yourself, mark the brief
**self-authored**, and do not spend paid credits.

**Default scope** when the brief does not say: the app set (Step 4) on the
platforms named (both if unsure), the living core screen and one hero
stage reel (Step 7), and onboarding plus a paywall if the app charges.
Store assets and code only when asked; offer them in the report.

Create the working folder and `DIRECTION.md`, and put the brief at its top.

### If this is a redesign

An existing app changes the job: you are replacing a look, not inventing a
product. Before Step 1, add a `## Current app` section to DIRECTION.md:

1. **Audit it.** Screenshot or rebuild its key screens into `before.html` and
   run `shoot.mjs` on them. Name which slop faces it hits (slop.md, and
   android.md §11 for Android) and paste the scan's FAILs.
2. **Inventory: keep / lose / unknown.** Every feature, data point and
   screen, and every good idea worth carrying over (a clever line of copy, a
   useful number). This list is a contract: the redesign must keep every
   "keep".
3. **Harvest assets** from the codebase or the user: logo, photos, icons,
   brand colours, real data. Use them before drawing anything.
4. **Decisions for the user.** Any change to the name, the tab structure, the
   hero metric or a removed feature is a decision you list explicitly, not one
   you make silently.
5. The current look counts as a **history row** for this app: the new
   direction must differ from it on at least 3 of 5 columns.
6. The deliverable gains a **before/after**: `before-after.html` with the old
   core screen beside the new one, shot like everything else.

## Step 1: Know the traps

Read [slop.md](references/slop.md) in full, including **"The overcorrection"**
(the austere grey-paper look an anti-slop process falls into) and the
Android faces. Then read the history file:

```bash
mkdir -p ~/.app-designer
[ -f ~/.app-designer/history.md ] || printf '| date | app | source family | ground | type | accent hue | richness source |\n|---|---|---|---|---|---|---|\n' > ~/.app-designer/history.md
cat ~/.app-designer/history.md
```

Every row there is a look you may not repeat (Step 2 explains the rule). On a
fresh machine it is empty and the rule starts with your first app.

## Step 2: Direction, by exploration

Read [directions.md](references/directions.md) (including **The bar**) and
[imagery.md](references/imagery.md).

1. **Find out what imagery you can really get** (the user's assets, generation
   if allowed, verified photo URLs, or none). This decides what directions are
   honest. Do not promise photography you cannot deliver; drawn shapes, a
   character, stickers and colour objects are always available.
2. **Write three concept sentences**: "<App> is a <thing>." Each from a
   **different source family** (directions.md: printed matter, objects and
   materials, places, media, nature, play). At most one may be a printed
   form (ticket, ledger, receipt, label, timetable).
3. **Render the core screen three ways**, one per concept, in one file
   (`explore.html`), on the platform that ships first, with real content and
   full craft. Not wireframes. The three must differ on every axis:
   - **Ground:** one light, one dark, one saturated colour field or
     full-bleed image.
   - **Type:** three different families or designs (serif / grotesque or
     expanded / rounded or mono or custom).
   - **Richness source:** photography, illustration or a character, shape
     language or colour objects, colour and material. Different in each.
   - **Accent hue:** three different hue families, so the brief's mood
     does not quietly pick the palette for all three.
   At least one of the three should be the boldest, most colourful or most
   playful version you can defend: the bar is Atoms and the best sticker
   apps, not a tidy form.
4. Shoot it (`shoot.mjs explore.html --out shots/explore`), look at each, and
   **choose**. Write in DIRECTION.md which one won, and one line each on why
   the other two lost. Picking the safest of the three is usually wrong:
   pick the one that is most *this app* and that an editor would remember.
   You may merge, but say what came from where.
5. **Check it against the history.** It must differ from every row in
   `~/.app-designer/history.md` on at least 3 of the 5 columns. Use only these
   words in the columns, so the comparison is mechanical:
   - source family: `printed` `object` `place` `media` `nature` `play`
     (for a compound concept, the family of the thing people would name:
     "the note on the fridge" is `printed`, "the fridge door" is `object`)
   - ground: `light` `dark` `colour-field` `image`
   - type: `serif` `grotesque` `expanded` `condensed` `rounded` `mono` `custom-display`,
     plus the display face in brackets: `rounded (Google Sans Flex)`. Never
     the same display face as any of the last three rows.
   - accent hue: `red` `orange` `yellow` `green` `teal` `blue` `violet` `pink` `neutral` `multi`
   - richness: `photo` `illustration` `shape` `colour-material` `3d-object`

   **Claim it now:** append a provisional row as soon as the direction is
   chosen (app column `<app> (exploring)`), so another session working at
   the same time cannot pick the same look. In Step 6, re-read the file and
   replace your provisional row with the final one.
6. Then write the rest of DIRECTION.md:
   - **The category default you are refusing**: what the top three apps in
     the category share, and which of those you are not doing. Include the
     category's colour cliché (a flag's colours for a language app, green for
     money, sage for plants, navy and violet for sleep), which the history
     columns cannot catch.
   - **Tokens:** the colour roles for light and dark (hex), and the owner of
     every hue if it is an identity palette (color.md §9); type families
     for each platform, 5 to 7 size steps with weights and tracking; side
     margin, radius family, spacing scale (type.md, color.md, layout.md,
     android.md §4 and §5).
   - **The richness source**, written as an art direction: photography
     (light, distance, grade), an illustration, character or shape language
     (one hand), or a colour and material system. Every app has at least
     one. Pure greyscale typography on paper is not one.
   - **The signature interaction** as a storyboard: trigger, frames, timing,
     haptic on each platform, reduced-motion fallback (motion.md §6).

If the user is reachable, show them the exploration sheet and your pick
before Step 3.

## Step 3: Voice and content

Read [copy.md](references/copy.md).

1. Write `## Voice` in DIRECTION.md: who is speaking, and three rules you
   can check (copy.md §2), drawn from what the user wrote if they gave you
   something.
2. Write `## Content`: the exact content of every screen before any layout,
   every label, value, name, date, image subject and button. Specific,
   uneven, believable data, in a realistic state (some done, one overdue,
   one new). Content decides the layout, never the reverse.
3. Run the three tests on every sentence (friend, swap, proof) and keep
   each screen inside its word budget (copy.md §5).

## Step 4: Design the app

**The set** (in `mockup.html`). If the brief names more screens than fit,
pick the ones that carry the core loop and list the rest as not designed:

1. The core screen, in a realistic mid-use state.
2. A detail screen (one level deeper).
3. A second core-loop screen: creation, a list, or a different tab.
4. The signature as **2 or 3 full frames** of the moment, each a real
   screen frozen at its beat (`data-freeze`), named `signature-1`,
   `signature-2`... Full frames read; scaled-down storyboards don't. Use a
   `.mini` storyboard panel only for a moment that is purely about shape
   and position, three frames in one row at a scale of 0.3 or more. See
   motion.md §6.
5. The core screen in dark mode (`data-theme="dark"`). If the core is a
   scene that does not change with the theme, the most list-like screen in
   dark mode instead.
6. An empty or first-run state, if the app has one worth designing.
7. The app icon: `<section class="app-icon">` for iOS with its dark and
   tinted modes, and `<section class="adaptive-icon">` for Android when it
   ships there (imagery.md §4 and §5).

**When both platforms ship,** screens 1, 2, 3 and 5 are pairs: the same
screen with `data-os="android"` and a shared `data-pair`. Do the core pair
first and run the swap and family tests on `pairs/core.png`
(platforms.md §5) before designing the rest.

**The device kit.** Link `<skill>/assets/device.css` in the head and
`<skill>/assets/device.js` at the end of the body (as `file://` URLs). Each
`<section class="screen" data-name="slug">` is a 402 x 874 iPhone 17 Pro
screen with status bar, Dynamic Island and home indicator injected; add
`data-os="android"` for a 412 x 915 Pixel-class screen with its status bar,
camera hole and gesture handle (device.js then loads Google Sans Flex,
Roboto Flex and Material Symbols). The header comment of device.css lists
every attribute; the ones you will use most:

- On a screen: `data-time="18:52"`, `data-chrome="light"` (white chrome) or
  `"none"`, `data-home`, `data-theme="dark"`, `data-kind` (core, state, detail,
  onboarding, paywall...: the copy scan budgets by it), `data-pair`,
  `data-palette="identity"`, `data-freeze="ms"`, `data-motion="ms"`,
  `data-dense`.
- Inside a screen: `data-system` (system component replicas), `data-scrolls`,
  `data-float`, `data-behind`, `data-bleed`, `data-legal` (small print),
  `data-ugc` (content shown as content: a name someone typed, a quoted
  message), `data-art` (letters drawn as art), `data-cta` (the primary
  button), `data-close`, `data-hit-expanded`, `.mini` for storyboard frames.
- In a store panel or a stage: `<div class="device"><section class="screen"
  data-clone="today"></section></div>` shows the current "today" screen
  in hardware; never paste a copy of its markup, it goes stale.
- Every surface gets its own `data-name`: it is the PNG's filename, and it
  stays the same when you add screens, so paths in CRITIQUE.md hold.
- Faces: `var(--sf)`, `var(--ny)`, `var(--sf-rounded)`, `var(--sf-mono)`,
  `var(--roboto)`, `var(--gsf)`, plus any web font you load. Type classes
  `.t-large-title` ... `.t-caption2` (iOS) and `.m-display-l` ...
  `.m-label-s` (Material). Glass as `.glass` (iOS only). Material Symbols as
  `<span class="ms">search</span>`.

Put tokens on `:root` named after the DIRECTION.md roles, and their dark
values on `.screen[data-theme="dark"]` (restate `color` there).

**One display face on both platforms.** The face that carries the
direction (headlines, the hero number) is identical on iPhone and Android:
bundle it in both apps (a licensed face, or an open one such as Google Sans
Flex, Roboto Flex or a Google Fonts serif, which ship on iOS too). The
platform's system face (SF Pro, Roboto Flex or Google Sans Flex) is for UI
text: labels, lists, controls. Only a "Native, sharpened" direction uses
each platform's own face for display, on purpose.

**Build layouts that flex**, not absolute coordinates: flex or grid columns,
heights in `%` or `flex: 1`, so the same markup survives the small-phone
render. Absolute positioning is for overlays and illustration only. **Every
list or page that scrolls in the real app gets `data-scrolls` on its scroll
view** (overflow hidden): on a small phone it simply shows less. To show a
whole scrolling page at once, make the screen `data-tall`.

**Design rules, in the order they usually go wrong:**

1. **One hero per screen**, at least twice the size of anything else.
2. **Richness on the core screen**: the image, the colour objects, the
   character, the shape language or the material is *on* the first screen,
   not saved for later.
3. **Real type contrast:** a display moment (34 to 96pt) against 13 to 15pt
   metadata, weights two steps apart, negative tracking on display.
4. **Rhythm:** tight inside groups, loose between, a rest where the screen
   decides (dense screens are exempt). More space above a heading than
   below.
5. **Colour with a job:** one accent with one role, or an identity palette
   where every hue has an owner. Neutrals tinted. Contrast measured.
6. **Native structure:** iOS 26 on the iPhone (layout.md §5: content edge
   to edge, Liquid Glass only on the floating navigation layer, primary
   action in the thumb zone); Material 3 Expressive on Android (android.md
   §3: tonal navigation bar, top app bar, FAB where there is one primary
   action, back arrow, 48dp targets, edge to edge). Keep native
   *behaviour*; the *look* of the navigation layer may follow the concept.
7. **Words in proportion:** few, big where they matter, every string in the
   voice (copy.md §5).
8. **The finish** (finish.md): colour concentrated in objects that own it,
   cards that are objects get depth and polish, gradients that are lit and
   owned, three levels of depth, and every element understandable by a
   stranger. Flat and correct is not finished.
9. **Never** grey placeholder boxes, emoji icons, stock illustration, the
   other platform's icons, or Material's baseline purple.

## Step 5: Shoot, scan, read, critique

```bash
node <skill>/scripts/shoot.mjs mockup.html --out shots/r1
node <skill>/scripts/shoot.mjs mockup.html --out shots/r1-small --small   # 375x667 iPhone, 360x760 Android, scanned too
node <skill>/scripts/shoot.mjs mockup.html --out shots/wip --only today,paywall   # just these, while you iterate
```

Shoot the whole file into a new round folder for every critique round
(and `--small` whenever a layout changed). Between rounds, `--only` keeps
iteration fast.

It renders every screen and icon at 3x, tiles `sheet.png`, puts pairs side
by side in `pairs/`, renders the icon modes and the Android masks, and scans
the rendered DOM for design tells (clipping, collisions, contrast, emoji,
purple gradients, Material baseline colours, confetti, glows, greetings,
centred FABs, nested cards, default fonts, flat type scales, small targets,
the wrong platform's icons) and copy tells (slop words, AI sentence shapes,
em dashes, exclamation marks, Title Case, long sentences, word budgets,
headline size and length, the primary button's size and place, and on
paywalls the price, the period, the trial terms, Restore, Terms, a way out
and fake urgency). Exit code 1 on any FAIL.

1. **Fix every FAIL. Answer every warn** (fix it, or one line on why it is
   deliberate).
2. **Read every screen in `review/`** (two per image at 1.5x), not only
   the sheet, and every pair. Open a 3x PNG when a detail needs checking.
3. **The read-aloud pass** (copy.md §9): every string, in order, out loud.
4. **Score it** with [critique.md](references/critique.md). If you can spawn
   an agent, spawn **one** critic for the whole job and brief it as
   critique.md says; don't edit what it is judging until its scores come
   back (preparing the next phase in a separate file meanwhile is fine). Otherwise score it
   yourself, harder than feels fair. Write scores, findings, the strings it
   quoted and any declined asks to `CRITIQUE.md`.

## Step 6: Iterate

Before round 1 and between rounds, run the polish pass (finish.md §8): it
holds the asks critics made on every test app, so doing them first saves a
round. Then fix what the critique found, shoot into a new folder (`r2`,
`r3`), compare. **At least two rounds, at most five**, and up to two more
when the person wants every line at 5 (critique.md, "Going for 5"). Done, plateau and budget are defined
in critique.md "When to stop". Always: no FAILs, every warn answered.

When the app set is done, append one row to the history so the next app
cannot repeat this one:

```bash
echo "| <date> | <app> | <source family> | <ground> | <type> | <accent hue> | <richness source> |" >> ~/.app-designer/history.md
```

## Step 7: The selling set

Same file, same tokens, same critic. Then shoot, scan and critique again
(one round at least, up to three), with the rubric's lines 12 to 15.

- **Onboarding and the paywall** ([paywall.md](references/paywall.md)):
  2 to 4 onboarding screens and the paywall, `data-kind` set, the paywall
  paired when both platforms ship. Prices from real store price points,
  the saving computed in DIRECTION.md. Any promise the paywall makes ("we
  remind you the day before") goes in `## Promises the app must keep` in
  DIRECTION.md: it is a build requirement.
- **Living screens** ([motion.md](references/motion.md) §8): the core
  screen with `data-motion` (a 6 to 10 second loop) on each platform, its
  beats written in `## Motion` in DIRECTION.md, `data-freeze` on the frame
  that sells it.
- **The hero stage:** a `.stage` (4:5 by default) with the phones in
  `.device` frames, the app's ground, one line of type, the living screens
  inside. Both phones side by side when both platforms ship.
- **Store assets** when asked ([stores.md](references/stores.md)): `.panel`
  elements for the App Store and Google Play, the feature graphic.

Record and review the motion:

```bash
node <skill>/scripts/reel.mjs mockup.html            # every data-motion element -> reels/*.mp4
node <skill>/scripts/reel.mjs mockup.html --only hero --fps 60 --gif
```

Each MP4 comes with a six-frame `-strip.png`: review the beats there, then
watch the video. Fix every FAIL (a loop that jumps) and answer every warn
(dead air, nothing moving). Give the critic the strips.

## Step 8: Build (when asked)

- **SwiftUI:** [swiftui.md](references/swiftui.md).
- **Jetpack Compose:** [compose.md](references/compose.md).
- **Expo / React Native / Flutter:** [expo.md](references/expo.md).

Tokens first, then screens with native components styled by the tokens.
Run it in the simulator or emulator and compare screenshots with the
mockups, pair by pair.

## Hard rules

| Never | Instead |
|---|---|
| Committing to a direction without rendering three | Step 2: three concepts, three grounds, three type families |
| The category's default look (cream wellness, dark-lime fintech, purple AI) | Name the default in DIRECTION.md and refuse it |
| This skill's own default: grey paper, black ink, one red, mono, ruled rows | slop.md, "The overcorrection". Colour, character and joy are allowed and expected |
| A core screen with no richness (all type, all grey) | Image, colour objects, character, shape language or material, on screen one |
| Flat, unconsidered surfaces that look like a wireframe | finish.md: owned colour, polished object cards, lit gradients, three levels of depth |
| A concept illustrated with props a stranger can't read (a random letter, a symbol) | The concept felt in material, colour, type and voice; every element passes the stranger test |
| Repeating a row of `~/.app-designer/history.md` | Differ on 3 of 5 columns |
| "Good morning, Name" or any greeting header | The date, the place, or the thing itself |
| The dashboard skeleton (hero stat card, 2x2 tiles, "Recent") by default | The core action owns the first screen |
| Emoji as icons or in UI copy | SF Symbols on iOS, Material Symbols on Android, one weight |
| Indigo/violet gradients, glows, blurred colour blobs | A colour from the concept, flat; crisp shapes, never blurred |
| Material's baseline purple or tonal soup on Android | Your own scheme, accent spent on one role |
| The iPhone design pasted onto Android, or the reverse | One app, two grammars (platforms.md); pairs pass the swap and family tests |
| Confetti: hues with no owner | One accent, or an identity palette where every hue has an owner |
| Cards inside cards, a screen that is a stack of boxes | Space and alignment, hairlines, then containers |
| Inter / Poppins / Manrope / plain Roboto as an unexamined default | A face with a stated reason |
| A centred floating "+" over the tab bar | iOS: the action in context or a toolbar button. Android: a FAB bottom right |
| AI copy: slop words, "not just X", three-beat lists, em dashes, Title Case, exclamation marks | copy.md §4: the specific thing, said by a person |
| Paragraphs on onboarding screens and paywalls | The word budgets in copy.md §5 |
| Fake data, invented proof, fake urgency | Believable data; real proof or none; real deadlines only |
| A paywall that hides the price, the exit or the trial terms | paywall.md: billed price clearest, trial in one sentence, Restore, a decent exit |
| Grey placeholder boxes or broken image URLs | Real images, verified, or a designed colour or shape field |
| Liquid Glass on content cards, or anywhere on Android | Glass for the iOS navigation layer only |
| Staggered fade-up on every element; decoration that moves | Motion where state changes; in reels one protagonist per beat |
| A reel loop that jumps, or phones spinning in 3D | reel.mjs passes the seam; the app doing its job on a still phone |
| No signature interaction | One storyboarded, haptic, concept-born moment |
| Grading your own work and calling it done | One fresh critic, briefed on the refused defaults, critique.md's stop rule |

## Report

Short: the three concepts and why two lost, the category default refused,
the voice rules, the signature, the paths to the latest `sheet.png`, the
pairs, `panels.png` and the reels, the scan result, the rubric scores per
round, what changed between rounds, and what you could not verify
(real-device feel, motion on a real phone, fonts on a non-Mac machine,
store rules that may have changed). Say if the brief was self-authored. For
a redesign, add the before/after, the keep list with each item checked off,
and the decisions the user needs to make. Offer what was out of scope
(store assets, code, the other platform).
