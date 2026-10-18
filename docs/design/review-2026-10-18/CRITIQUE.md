# Design review, 2026-10-18

Today's shipped UI run through the `app-designer-pro` skill: rendered at 3x on
four palettes (Eclipse, Aurora, Daylight, Monochrome), scanned with
`shoot.mjs`, and scored by one fresh critic over three rounds (rubric lines
1 to 12 plus Fidelity). Screens: Settings › Access › Users (the source chips
and Show filter), Requests › Rules › Recently auto-approved, the Inbox deck.

## Scores (Users)

| # | Line | R1 | R2 | R3 |
|---|---|---|---|---|
| 1 | Concept | 3 | 3 | 3 |
| 2 | Category | 3 | 3 | 3 |
| 3 | Skill average | 3 | 3 | 3 |
| 4 | Hierarchy | 3 | 4 | 4 |
| 5 | Typography | 3 | 3 | 3 |
| 6 | Colour | 3 | 3 | 4 |
| 7 | Richness | 2 | 3 | 3 |
| 8 | Rhythm | 3 | 3 | 3 |
| 9 | Finish | 3 | 3 | 4 |
| 10 | Native | 4 | 4 | 4 |
| 11 | Signature | 2 | 3 | 3 |
| 12 | Copy | 3 | 3 | 3 |
| F | Fidelity | 4 | 5 | 5 |

## What changed

- **Scan (r0, as shipped):**
  - 9pt glyphs in the chips, and 9.5pt tile labels on the deck.
  - The `dim` token failed WCAG for small text on every palette but Noir (2.7 to 4.1:1). Every palette's `dim` now passes 4.6:1.
  - Hints were clipped.
- **R1 → R2:**
  - One pill per source the person has, each with a state glyph.
  - Add user is a toolbar ＋.
  - Person avatars with the web's `hueForId` tint.
  - The disabled name dims.
  - "N session(s)".
  - Neutral source glyphs (amber and green belong to wanted and done).
  - The auto-approved card names the source in words.
- **R2 → R3:**
  - Avatars muted off the status hues, with a ground-colour ring.
  - The auto-approved meta reads who · from where · why on one line.
  - Pill glyph at 12 semibold.
  - The selected lane scrolls into view.

**Stopped at R3 by the plateau rule** (critique.md): Concept, Category and
Skill average held at 3 for three rounds, and lifting them would need a
structural change that a settings list inside the established redesign
shouldn't get. Colour and Finish reached 4; Fidelity 5. The critic's last
defect (the auto-approved reason truncated) is fixed after R3 and unscored:
two lines, middle truncation, stacked tier chips.

## Declined, with reasons

- **Pill copy** ("Allowed · off", "Healthy · 3 sources", "Healthy · diary", "Needs attention · 1 blocked"): the web's own chip labels; voice rule 3. Worth raising with the web.
- **Orange for problems:** the web's `--stuck`, one owner on every screen.
- **Problems-first sort and a red summary line:** not on the web.
- **One-letter initials:** the web uses two.
- **Avatar hues skipping ±15° of every status hue:** too little of the wheel would be left. Low saturation separates people from states.
- **Deck layout:** the approved 0.4.214 mock.
