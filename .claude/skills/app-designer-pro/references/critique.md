# Critique

The designer always grades too kindly. They know what they meant, so they
see it on the screen even where it is not. Whenever possible the critique is
done by **fresh eyes**: a separate agent that sees the rendered PNGs, not the
designer's reasoning.

## One critic, for the whole job

Spawn the critic **once** and keep talking to the same agent every round
(continue it with SendMessage, or the equivalent in your harness). A new
critic each round brings new taste, reverses the last one's asks, and the
scores never converge. The same critic remembers what it asked for, so it
can judge whether it landed.

**Wait for the critique before editing.** Work done while the critic is
reading gets judged on the wrong render.

## First message to the critic

> You are a design director at a studio that has won Apple Design Awards
> and shipped Material 3 apps for Google. You will critique one app over
> several rounds. The bar is Atoms, Flighty, Apple News+ and the best
> sticker-and-mascot apps: colour that is bold and owned, type with a
> voice, one idea per screen, a moment of joy, and a finish (cards with
> depth, lit gradients, crafted badges and avatars) that looks expensive.
> Clean and correct is a 3.
> Bar references from the user, if any: <screenshot paths>.
> First, look at every screen as a stranger: name anything whose purpose
> you cannot tell without the concept explained (a stray letter, a
> symbol). Each one is a defect.
>
> Concept: "<concept sentence>"
> Platforms: <iPhone / Android / both>
> Colour system (what each colour means, and who owns each hue if it is an
> identity palette): <from DIRECTION.md>
> Voice rules: <the three rules from DIRECTION.md>
> Refused defaults (deliberate, do not ask for them back): <the category
> default paragraph from DIRECTION.md>
> Rubric: <path>/references/critique.md (read it). Platform grammar:
> <path>/references/android.md and platforms.md, if Android is in scope.
> Copy rules: <path>/references/copy.md §4 and §5.
> Round 1 (open every image at full size):
> - screens: <absolute PNG paths>
> - pairs: <pairs/*.png> (same screen on both platforms)
> - motion: <reels/*-strip.png> and the stills of the living screens
> - store and stage: <panels.png, stages/*.png>
> - icons: <icon PNG, icon-ios-modes.png, icons/*-masks.png>
> - the scan's facts per screen (words, headline, CTA): <scan.json>
>
> Score each rubric line 1 to 5 with one sentence of evidence that points
> at something visible. For every line below 5, name the single change
> that would make it a 5. Then list the five changes that would raise the
> lowest scores most, each specific enough to execute (which screen, which
> element, what value or what words). A 4 means you would ship it at a top
> studio; a 5 means it goes in your portfolio. Judge pixels and words, not
> intentions. Read every string on every screen as if out loud and quote
> any that a person would not say. Richness and native fluency are judged
> on what a static mockup can show: drawn illustration, shape and colour
> count fully, and gestures a mockup cannot show are not penalised. Motion
> is judged on the strips. Dark mode is judged on the dark frames shown.

For a **redesign**, add: "Before (the current app): <PNG paths>. Must keep:
<the keep list>." and score the extra **Fidelity** line.

Ask the critic to end every round with one line: "Done / not done by the
stop rule in critique.md". It reports to you only; nobody else is listening.

Each later round: "Round N. Here is what changed and which of your asks I
declined, with reasons: <list>. New images: <paths>. Rescore, say which of
your asks landed, and give the next five."

## Declining an ask

The designer may decline a critic's ask with a one-line reason in
CRITIQUE.md. Always decline asks that bring back a refused default, that
undo a change the same critic asked for earlier, or that break a hard rule.
Tell the critic, so it stops asking.

## The rubric

Score 1 to 5. Lines 13 to 15 apply only when that work is in scope.

| # | Line | 5 looks like | 2 looks like |
|---|---|---|---|
| 1 | **Concept on the pixel** | Cover the name and you could still guess the concept from any screen | A competent app of the category; the concept only lives in the doc |
| 2 | **Not the category average** | Nothing like the top three apps in the category, and better for it | Shares the category's skeleton, palette or type |
| 3 | **Not this skill's average** | Clearly not grey paper + mono + one red + ruled rows, not cream + serif + terracotta. Lists and controls speak the direction's voice | Austere and tabular; or a rich hero bolted onto a generic settings list |
| 4 | **Hierarchy** | Squint: one thing lands first on every screen, and it is the right thing | Two or more things compete, or nothing leads |
| 5 | **Typography** | The faces have a voice, the scale has real contrast, tracking is tuned, numbers are tabular, headlines break where a person pauses | Default faces, sizes a step apart, loose display type |
| 6 | **Colour** | A palette you could name and remember, bold where it lives and quiet elsewhere; every hue has a job or an owner; dark mode designed | Timid, arbitrary or confetti; dark mode an inversion |
| 7 | **Richness and joy** | Something to *look at* and one thing that makes you smile: image, colour objects, a character, a material, one art direction | All text and rules; a wireframe with good fonts |
| 8 | **Rhythm and space** | Tight groups, generous breaks, aligned to few verticals, nothing cramped or stranded | Even spacing everywhere, or dead gaps and crowding |
| 9 | **Finish and craft** | Looks expensive next to Atoms: owned colour in polished objects, cards with real depth, lit gradients, crafted badges and avatars, concentric corners, consistent icons, nothing a stranger can't read | Flat, unconsidered surfaces; or decoration with no owner; misalignments, placeholder smell, gimmick props |
| 10 | **Native fluency** | iPhone: feels like iOS 26 (glass navigation, system patterns used with confidence). Android: feels like Material 3 Expressive in the app's own colours (tonal navigation, FAB and back done right, Material Symbols). Score each platform in scope; the lower one counts | A web page in a phone frame, a SwiftUI or Compose sample, or one platform's design pasted onto the other |
| 11 | **Signature** | One interaction you would describe to a friend, born from the concept, shown clearly | None, or a generic animation |
| 12 | **Copy** | Every string sounds like the person in the voice rules; no line you could paste into a competitor; each screen within its word budget; headlines are the hero, buttons say what happens | Brochure words, three-beat lists, explanatory paragraphs, Title Case, "Continue" on a purchase |
| 13 | **Motion** (reels) | Each beat has one protagonist, the story reads from the strip in order, platform physics, the loop is seamless, nothing moves for decoration | Everything moves at once, or nothing does; a jump at the loop; floating decoration |
| 14 | **Conversion** (onboarding, paywall) | Value before price, one promise, the result they would lose on screen, the billed price clearest, trial terms in one sentence, one big button, a decent exit, no dark pattern | A feature list behind a crown, a hidden price or exit, invented proof, fake urgency |
| 15 | **The feature test** | An App Store or Play editor would feature it for its design | Nobody would screenshot it |

## When to stop

- **Done:** no line below 3; at least 80% of the scored lines at 4 or
  above; and lines 1 (Concept), 9 (Finish), 10 (Native fluency) and 12
  (Copy) at 4 or above. If line 14 is in scope, it is at 4 or above too: a paywall that is
  merely fine costs real money.
- **Plateau:** if two consecutive rounds change no score, stop iterating on
  polish. Either make one structural change (a different hero, a different
  richness source, a layout rethought) and run one more round, or stop.
- **After done:** fix any concrete defect the critic still named (a data
  mismatch, a collision, a sentence it quoted). A change made after the
  last critique is either re-scored or listed as unscored in the report.
- **No way to continue the critic** (the harness cannot resume a finished
  agent): start a new one, give it the previous CRITIQUE.md, and tell it its
  job is to judge whether those asks landed, not to start over.
- **Going for 5:** once done, if the person wants the portfolio version and
  there is time, run up to two more rounds on the critic's "change that
  would make it a 5" list, highest-scoring lines last (they are the
  closest). Never call a line a 5 that the critic did not score 5.
- **Budget:** at least two rounds, at most five (seven when going for 5).
  Then stop and report the honest scores. A truthful 3 is worth more than
  an inflated 4.

## The six quick tests (run them before scoring)

1. **Logo test.** Cover the name. Could this be any app in the category?
2. **Squint test.** Blur your eyes. One landing point per screen?
3. **Category test.** Picture the top three apps in the category. Is yours
   their average?
4. **Specificity test.** Point at any colour, size, gap or word. Can you say
   why it is that and not the default?
5. **Feature test.** What would the Today-tab headline say about the design?
6. **Subtraction test.** Remove one element. Did the screen get worse?
7. **Stranger test.** Could someone who never read DIRECTION.md say what
   every element is for? (finish.md §7)

When both platforms are in scope, add the **swap test** and the **family
test** from platforms.md §5 on every pair.

## Writing CRITIQUE.md

Per round: the scores table, the five changes, the strings the critic
quoted and what they became, and after the next round, whether each change
landed. Keep the history; the trend is the evidence.
