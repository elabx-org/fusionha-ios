# One design, two natives

When the app ships on iPhone and Android, there is one app and two
grammars. Someone who switches phones should recognise the app in a second
and never feel it is a port. Two failures sit on either side:

- **The port:** the iPhone design pasted onto a Pixel (glass tab bar, back
  chevrons, SF glyphs) or the reverse. It looks cheap to the people on the
  other platform, which is half the audience.
- **The split:** two designs that share nothing, because each platform's
  defaults were followed separately. Now there is no brand, and twice the
  slop.

The rule: **the app's identity carries over; the platform's grammar does
not.**

## 1. What carries over

- The concept, the direction and the richness source.
- **The tokens:** colour values for every role, light and dark; **the
  display face, identical on both** (bundled in each app); the spacing
  scale; the radius family (adjusted to each platform's scale only if it
  fights it). Only UI text (labels, lists, controls) follows each
  platform's system face.
- **The content and the copy**, word for word, except where a platform
  names a thing differently (§4).
- **The hero of every screen**, its size and its position. The squint test
  should land on the same thing on both.
- **The signature**, as a moment (trigger, story, haptic) even when its
  native implementation differs.
- Illustration, imagery, the icon's mark.

## 2. What changes

| Thing | iPhone (iOS 26) | Android (Material 3 Expressive) |
|---|---|---|
| Navigation layer | Liquid Glass, floating over content | Tonal surfaces; shadow only on what floats |
| Tabs | Floating glass capsule tab bar, search as its own circle | Navigation bar, 64dp, active pill behind the selected icon |
| Big title | Large title, collapses to an inline title | Medium/large flexible top app bar, collapses to 64dp |
| Top buttons | 44pt glass circles, grouped in capsules | 48dp icon buttons in the top app bar |
| Back | Chevron, edge swipe | Arrow icon, system back gesture with predictive back |
| Primary action | Capsule button in the thumb zone, or a toolbar button | FAB bottom right (extended with a label), or a filled button in the thumb zone |
| Search | Search tab or a pull-down field | Search bar at the top that expands to a search view |
| Sheet | Detents, grabber, floating at partial height | Bottom sheet, drag handle, 28dp top corners, scrim |
| Alert | Centred alert, stacked or side-by-side buttons | Dialog, 28dp corners, text buttons aligned right |
| Choice of 2 to 4 | Segmented control | Segmented buttons / connected button group |
| Toggle | iOS switch | Material switch (52 x 32) |
| Context actions | Context menu (long press), swipe actions | Dropdown menu, long press; swipe for dismiss |
| List rows | Inset grouped, trailing chevron for navigation | List items 56/72/88dp, no chevrons |
| Icons | SF Symbols (SF-style SVG in mockups) | Material Symbols, one style |
| UI face (if not custom) | SF Pro family | Roboto Flex or Google Sans Flex |
| Touch target | 44pt | 48dp |
| Corners of the display | ~55pt | ~44dp |
| Ongoing activity | Live Activity, Dynamic Island | Live Update notification, status chip |
| Haptic: done | `.success` | `CONFIRM` |
| Haptic: snapping | `.selection` | `SEGMENT_TICK` / `CLOCK_TICK` |
| Springs | `.smooth`, `.snappy`, `.bouncy` | Expressive spatial fast / default / slow, effects springs |
| Zoom into detail | `.navigationTransition(.zoom)` | Container transform (shared element) |

## 3. Where the design may ignore the grammar

A concept may replace the navigation layer with its own object (a dial, a
deck of cards, a single screen with no tabs). Then it replaces it on both
platforms with the same object. What stays native even then: the back
behaviour, the touch target size, the status bar and the gesture area,
system dialogs and permission prompts, the keyboard, text selection.

Custom controls inside the content (a tide dial, a recipe timer) are the
app's own and may be identical on both.

## 4. Words that differ

Most copy is identical. Platform words are not: "Settings" on both, but
"Share" opens a share sheet on iOS and the Sharesheet on Android (same
word, fine); "Swipe" gestures differ; "Tap" on both. App Store vs Google
Play, Apple Pay vs Google Pay, Sign in with Apple vs Sign in with Google:
show each platform its own. Notifications, widgets and permissions are
described in each platform's terms.

## 5. The process

1. Ask which platform ships first (SKILL.md Step 0). Design the
   exploration and the direction on that platform.
2. **Before the rest of the set, translate the core screen** to the other
   platform and shoot both as a pair (`data-pair="core"` on both). Look at
   `pairs/core.png`:
   - **The swap test:** cover the status bars. Can you tell which is which
     from the navigation layer alone? You should.
   - **The family test:** cover the navigation layers. Could they be two
     different apps? They should not be.
3. Then the set: every core-loop screen as a pair when both platforms are in
   scope (core, detail, second core-loop screen, dark core). Onboarding,
   paywall and empty states can be designed on the first platform and
   paired only where the platform changes them (the paywall always pairs:
   the stores' rules differ, paywall.md §4).
4. Icons for both: the iOS icon and the Android adaptive icon from the same
   mark (imagery.md §4 and §5).
5. Store assets for both (stores.md), and a stage that shows the two phones
   together (motion.md §8).

## 6. Cross-platform code

Expo, React Native and Flutter share the logic and most of the views; they
do not share the grammar automatically. Keep the tokens in one theme, and
branch the navigation layer, the system controls, the icon set and the
haptics per platform. expo.md has the patterns.
