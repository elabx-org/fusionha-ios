# The finish

A design can make every right decision and still look like a wireframe
with good fonts. What separates it from the apps people screenshot is the
**finish**: how colour sits on surfaces, how cards have weight, how a
gradient catches the light, how a badge or an avatar is made. This is
where the last point on every rubric line is won, and where AI design is
weakest: it either paints everything (purple gradients, glows) or, told not
to, paints nothing.

Read this before Step 4, and again before every critique round.

## 1. The bar, taken apart

Atoms (the Atomic Habits app, an Editors' Choice) is the reference for a
calm app that still looks expensive. What it actually does:

- **A warm white ground** (around `#FAF8F5`), not grey, not cream.
- **Big, soft cards as objects.** A habit is a large squircle card
  (corner 28 to 36) with a gentle pillow of light: the top a hair lighter
  than the bottom, a soft two-layer shadow, sometimes an inner hairline.
  You want to press it.
- **Colour concentrated in small, saturated objects:** a streak badge in
  a tangerine-to-amber gradient, another in magenta-to-violet, an avatar,
  a progress block. Each is small, glossy and owned by one habit.
- **One aura per screen at most:** a "Hall of Fame" card in a soft
  peach-to-pink-to-lilac gradient, ink text on it. It is the one moment of
  celebration, so it can be the richest surface on the screen.
- **A dark card as a counterpoint:** a near-black, warm suggestion card
  with white text and one colour accent, floating over the light UI. It
  reads as "this is different: advice, not data".
- **Crisp organic shapes** (pebbles, blobs with hard edges) in flat
  colour on the store panels and onboarding, bleeding off the edge,
  never behind body text.
- **Type with an editorial voice:** a serif with one italic word in the
  headlines, a clean sans for the UI, big tabular numbers.
- **People, drawn:** avatars as illustrated faces, not grey circles.

None of that is decoration for its own sake. Every colour belongs to a
habit, the aura belongs to an achievement, the dark card to advice. That
is why it looks professional instead of busy.

## 2. Gradients: crafted, not generated

| The AI gradient | The crafted gradient |
|---|---|
| Indigo to violet, on the hero, the button, the background | Two neighbouring hues (amber to tangerine, magenta to violet, sky to cobalt), or one deliberate aura |
| Saturated end to end, high contrast within itself | Gentle: the stops close in lightness, light at the top or top-left |
| On everything, so it means nothing | On an object that owns it (a badge, a habit, an achievement), one kind per role |
| Text set on a loud gradient, white, low contrast | Ink on a light aura, or white on a deep one, measured |
| A blurred colour blob floating behind the UI | A crisp shape, or light inside an object |

Recipes for mockups (change the hues to your palette; never paste these
hexes):

```css
/* A badge or token that looks lit: neighbouring hues, a top highlight, a
   shadow in its own colour that falls downward (never a zero-offset glow). */
.badge {
  background: linear-gradient(150deg, #FFC04D, #FF7A1A);
  box-shadow: inset 0 1px 0 rgba(255,255,255,.5), 0 8px 16px -8px rgba(255,122,26,.6);
  border-radius: 14px;
}

/* An aura card: the one celebration on the screen. Soft, light, ink text. */
.aura {
  background:
    radial-gradient(120% 120% at 0% 0%, #FFD8BA 0%, transparent 55%),
    radial-gradient(120% 120% at 100% 100%, #D9B8F5 0%, transparent 60%),
    linear-gradient(135deg, #FFC7A6, #F6A9CC 55%, #CDAAF2);
  color: #2A1A24;
  border-radius: 28px;
}

/* A surface with a pillow of light: barely visible, felt more than seen. */
.card {
  background: linear-gradient(180deg, #FFFFFF, #FBFAF7);
  border-radius: 28px;
  box-shadow:
    0 1px 1px rgba(40,28,10,.04),
    0 10px 28px -10px rgba(40,28,10,.12),
    inset 0 0 0 1px rgba(40,28,10,.04);
}

/* The dark counterpoint card, over a light screen. */
.insight {
  background: linear-gradient(180deg, #2B2724, #1C1A17);
  color: #F6F1EA;
  border-radius: 24px;
  box-shadow: 0 24px 48px -20px rgba(0,0,0,.4);
}
```

- A gradient on a button is allowed when it is the same hue, light to a
  little darker, so the button looks pressable. Not two hues, never violet
  by default.
- Never gradient text.
- The scan fails blue-indigo-violet gradients on large surfaces and more
  than one warm-to-violet aura per screen; small badges are judged by eye.

## 3. Cards: objects, not boxes

"Everything is a card" (slop.md) is about sections boxed for no reason. A
card is right, and should get the full finish, when **it is an object
people act on**: a habit, a lesson, a route, a bill, a person.

- **One card style per object type,** used everywhere that object
  appears: same radius, same depth, the same place for its colour token
  and its one action.
- **A collection of objects may fill a screen** (a list of habit cards).
  Give it rhythm: 12 to 16 between cards, 20 to 24 inside them.
- **Sections are not cards.** Headers, settings, metadata: space and
  hairlines.
- **Never cards in cards.** Inside a card, group with space.
- **Concentric corners:** inner radius = outer radius minus the padding.
- **One card per screen may break the system** (the aura, the dark
  insight): that is the moment.

## 4. Depth, in three levels

1. **The ground:** flat, warm or cool to match the direction.
2. **Objects on it:** the pillow card. Two shadows, both soft and faint:
   one tight contact shadow (1 to 2px, 4 to 6% opacity), one wide ambient
   one (24 to 40px blur, 8 to 12%, pulled in with negative spread). Tint
   the shadow with the ground's hue: warm shadows on a warm ground.
3. **What floats:** the tab bar or navigation bar, a sheet, the dark
   insight card, a FAB. A stronger, larger shadow, or Liquid Glass on iOS.

One shadow style per level, the same on every screen. The scan warns when
a screen uses more distinct shadow styles than that.

On Android the same three levels exist as tonal surfaces (android.md §3):
objects can carry the soft shadow too, but the navigation layer is tonal.

## 5. Colour in proportion

For a colour-led direction (directions.md K, L, F):

- About **70%** of the screen is calm ground and surfaces, **20%** ink and
  neutral detail, **10%** saturated colour, concentrated in objects. The
  10% is what people remember; spread over everything, it becomes noise.
- Colour sits **on objects that own it** (an identity palette, color.md
  §9), at full strength, small and glossy, rather than tinting every
  surface a little.
- **Light text on colour only when the colour is deep;** otherwise ink.
  Measure it.
- **A dark mode keeps the colour objects at full strength** and lowers
  the surfaces, so the colour glows in the dark.

## 6. The small things that make it look expensive

- Badges and tokens with a white glyph or number on a lit gradient.
- Avatars as illustrated faces, or initials on a gradient disc in the
  person's colour, with a 2px ring in the ground colour where they overlap.
- Numbers big and tabular, units smaller and lighter, cents raised.
- Action pills with an icon and a label, 36 to 44pt tall, on a soft fill.
- Progress shown as filled shapes or a block of colour, not a 4pt grey bar.
- Hairlines at 6 to 8% ink, never 1px of mid-grey.
- Text 20 to 24 from a card's edge; nothing cramped against a corner.
- Charts with rounded bars in the owner's colour, one highlighted.

## 7. The stranger test

Every element on the screen must make sense to someone who never read
DIRECTION.md. The concept should be **felt** (in the material, the
colour, the type, the voice, the motion), not **illustrated** with props
that need explaining.

- A letter on a card, a symbol in a corner, an object that only means
  something once you know the concept: it reads as a mistake. Cut it, or
  make it carry real information (a person's initial is fine as their
  avatar, next to their name; a giant letter pinned on the balance is not).
- The app's name and any character belong where people expect a name or
  a character: the top bar, the icon, an empty state. Not as a running
  joke on every screen.
- Ask the critic to look at each screen as a stranger first: "What is
  this, and what is that element for?" Anything it cannot answer fails.

## 8. The polish pass: what turned 4s into 5s in testing

Five test apps, five critics, and the same asks came back again and again.
Do these before the critic asks:

1. **Give every decoration a job.** The soil shows the minutes done, the
   ticket's stub carries the next departure, the poster prints as the pot
   fills, the postmark says the day and time. A drawing that only decorates
   scores 4; a drawing that also informs scores 5.
2. **Real objects instead of generic glyphs.** A tiny poster of the goal,
   the person's avatar, the plant's sticker, never a coloured disc with an
   arrow in it. If a row has an icon, it is a thumbnail of its own object.
3. **Real platform chrome.** On iOS, the tab bar and toolbar buttons are
   Liquid Glass with content visibly scrolling under them (`.glass`), not a
   flat white bar. On Android, the FAB exists only where adding is the
   screen's primary action; elsewhere "add" lives in the top app bar.
   System controls (Stop, toggles, segmented choices) look like the
   platform's own, styled by the tokens.
4. **Craft the drawing like a product, not a sketch.** One light source and
   one shadow style (paper-cut or soft, never both), details at the scale
   people look at (doors and windows on houses, a wake behind a boat),
   silhouettes that still read at 40pt.
5. **The display face for display only.** UI text, rows and labels in the
   platform face; the brand face for the hero, the headline and the number.
   Tune tracking on every display size, and check that punctuation clears
   the glyph next to it ("10.20." at 64pt).
6. **Spacing that groups.** Tight inside a group, a visible break between
   groups (people who are in, then people who might be), scroll padding so
   the last row clears the tab bar or FAB, 96dp on Android with a FAB.
7. **Copy that is specific everywhere,** not only in the hero: "3 of 6
   have said what they're bringing", "Marco hasn't booked it", "Stop and
   keep a bud". Every generic label is a lost point.
8. **Icons that survive small.** At 40pt the mark is still the mark; the
   Android mono layer and the iOS tinted icon read as the same object, not
   a capsule or a mouse.
9. **Small phones keep what matters.** On 375 x 667 drop the least
   important block, never the core object or the primary action.

## 9. Before every critique round

- Is the 10% of colour concentrated in objects that own it?
- Does every card that is an object have the finish, and every section
  that is not a card have none?
- Do the gradients use neighbouring hues, light from the top, and an
  owner?
- Three levels of depth, one shadow style each?
- Would a stranger understand every element?
- Put the strongest screen next to the Atoms panels in your head. If it
  looks flatter, cheaper or emptier, it is not done.
