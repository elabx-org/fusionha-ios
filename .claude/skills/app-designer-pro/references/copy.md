# Copy

> Every example in this file comes from a different imaginary app, on
> purpose. They show a shape, never words to reuse: if your app is in one
> of these domains, write your own lines from your own voice rules.

Half of what reads as "AI design" is AI writing. A beautiful screen that
says "Unlock your potential" looks generated, and people now spot machine
copy faster than machine layouts. The words have to sound like a person who
knows the app's world, and they have to sit on the screen in proportion:
few, big where they matter, small where they don't.

## 1. Content before layout

Before drawing a screen, write exactly what is on it: every label, row,
number, name and button, in a `## Content` section of DIRECTION.md. Real
content decides the layout: how long the titles are, how many items there
are, what the biggest number is. Layout first means the words get bent to
fit placeholder shapes, and the result reads like a template.

## 2. Find the voice, don't invent it

A voice is not "friendly but professional". That describes every app. A
voice is a specific person.

1. **Start from the person.** Step 0 asks for something they wrote: a post,
   a message to a customer, a product description. Read it for habits: how
   long their sentences are, whether they joke, whether they say "you" or
   "we", what they never say.
2. **No sample?** Pick a person from the app's world and write as them: the
   climbing coach who checks the weather every morning, the baker who has
   been up since four, the coach who has heard every excuse.
3. **Write three voice rules** in `## Voice` in DIRECTION.md. Rules you can
   check, not adjectives:
   - "Numbers instead of adjectives. '14 km at 5:42 a km', never 'a great run'."
   - "Says 'you', never 'users' or 'we'."
   - "One dry joke, in the empty state only."
4. **Platform words** follow the platform (platforms.md §4). Everything else
   is identical on iOS and Android.

## 3. Three tests for every sentence

- **The friend test.** Read it out loud as if you were telling a friend
  across a table. If you would feel silly saying it, rewrite it.
- **The swap test.** Replace the app's name with a competitor's. If the
  sentence still works, it says nothing about this app.
- **The proof test.** Can you point at the thing in the app that makes the
  sentence true? "Plan the week in one swipe" needs a screen where one swipe
  plans the week.

## 4. How AI copy sounds, and the fix

| What it sounds like | Why people spot it | What a person writes |
|---|---|---|
| "Unlock your potential", "Elevate your workflow", "Seamless", "Effortless" | Verbs and adjectives with nothing in them | The concrete result: "Your Tuesday, planned by 8am" |
| "Plan. Track. Grow." / "Simple, fast, and secure." | The three-beat list is the rhythm of generated text | One claim, with its proof |
| "Not just a budget app. It's a money coach." / "More than a journal" | The most recognisable AI sentence shape | Say what it is |
| "Your money, finally organised" with an em dash | The em dash is the punctuation people now read as AI | A full stop or a colon |
| "Ready to take control?" | Rhetorical questions stall | The answer: "See where Tuesday went" |
| "You've got this!", "Great job!", "Oops!" | Cheerleading and cutesy errors | The state of the thing: "5 of 7 this week" |
| "Welcome to Ledger", "Let's get started" | Spends the best line on nothing | The first action: "Add the first account" |
| "Insights", "wellness", "productivity", "experience" | Category nouns, not things | The thing: "You spend most on Fridays" |
| "Designed to help you...", "Whether you're a beginner or a pro..." | Brochure syntax | Talk to one person about one thing |
| "Transform your sleep" | A promise nobody can check | A promise you can keep: "A 6-minute wind-down, every night at 22:30" |
| Title Case On Every Heading | Slide-deck habit | Sentence case everywhere |

The scan fails the hard cases (shoot.mjs lists the words) and warns on the
soft ones. Passing the scan is the floor: a sentence can avoid every banned
word and still be empty.

## 5. Proportion: the words on the screen

Copy is part of the layout. A screen converts when it says one thing, big,
and gets out of the way. Every screen has a **word budget set by its job**
(legal small print marked `data-legal` is counted apart):

| Screen | What it holds | Budget |
|---|---|---|
| Core, detail, list | Labels and content. No explanatory sentences: if the UI needs one, the UI is unclear | no budget, but no paragraph over 5 lines |
| Onboarding step (`data-kind="onboarding"`) | Headline 3 to 7 words, one support line up to 15, a button of 2 to 4 | about 30 (the scan warns over 45, fails over 70) |
| Paywall (`data-kind="paywall"`) | Headline up to 8 words, up to 3 benefit lines of up to 6 words, the plans, the button, the price line | 60 to 90 (warns over 90, fails over 130) |
| Empty state | One sentence, one action | 15 |
| Store panel caption | 5 to 8 words on two balanced lines | 9 |
| Stage (social, launch) | One line, and the name | 10 |

**Size follows importance:**

- The headline is the hero: at least twice the body size, 28 to 40pt on an
  onboarding screen or paywall, two or three lines at most. When it runs
  long, cut words. Never shrink the type to fit.
- One support line under it at 15 to 17pt. Not a paragraph.
- The button label at the body size, semibold, in a 50 to 56pt button in
  the bottom third, where the thumb is.
- Small print at 11 to 13pt, but readable: 4.5:1 contrast. Terms hidden in
  pale grey is a dark pattern, and the scan fails the contrast.

**Breaks are part of the writing.** A headline breaks where a person would
pause saying it ("Know the water / before you leave"). Use `text-wrap:
balance`, or a `<br>` where the meaning splits. Never one word alone on a
headline's last line.

**Air sells.** Seven words with 64pt of space around them say more than
twenty that fill the screen. If the copy needs the whole screen, the screen
has more than one job.

## 6. Copy that converts and stays honest

On onboarding, paywalls, store panels and stages, the words are selling.
They still sound like a person.

- **The headline is the outcome, in the user's words.** Not the feature.
  Where to find the words: the brief ("what do they open it for?"), how
  people describe the problem in reviews of competing apps, how the person
  in §2 would say it. Three shapes that work without being templates:
  - the result: "Dinner decided before you leave the office"
  - the moment: "The 7:42 to Leeds, already on your lock screen"
  - the relief: "Stop doing the maths in your head"
- **The support line answers "how?"** in one concrete sentence: "Three
  recipes a night from what's already in your fridge."
- **The button says what happens next:** "Start my 7 free days", "Show me
  tonight's dinner", "Build my plan". "Continue" is fine between onboarding
  steps; it is wrong on a button that costs money.
- **Proof is real or absent.** A rating only if the app has it, a review
  quote only with the reviewer's real name and permission, press logos
  only if the press happened, user counts only if counted. In a mockup of
  an unlaunched app: no proof on the screen. Never invent it, not even as
  a placeholder that looks real.
- **Prices are plain** (paywall.md has the full rules): the billed amount
  and its period first ("€39.99 a year"), the monthly equivalent smaller
  ("€3.33 a month"), the saving computed and true, and what happens after
  a trial in the same sentence as the trial: "Free for 7 days, then €39.99
  a year. Cancel anytime in Settings."
- **Risk reversal only if it is true:** "We'll remind you 2 days before the
  trial ends" only if the app sends that reminder.
- **No dark patterns:** no fake countdowns, no "Only 3 spots left" that
  isn't, no hidden close button, no confirmshaming on the way out ("No
  thanks, I like being tired"). "Not now" is the decent exit.

## 7. Microcopy

- **Labels say what things are.** Verbs on buttons ("Add habit",
  "Transfer"), nouns on screens ("Today", "Library").
- **Sentence case.** Everywhere except proper nouns, on both platforms.
  Android buttons are no longer ALL CAPS.
- **Short.** A button is one to four words.
- **Specific over clever.** "No spending since Tuesday" beats "You're
  crushing it!".
- **Calm.** No exclamation marks in system copy. No emoji. No "Oops".
- **One personality, if any,** in a few chosen places (an empty state, a
  milestone), not on every label.
- **Empty:** what will be here and the one action that fills it. "Your
  first climb goes here. Log a route."
- **Error:** what happened, in plain words, and what to do. "The timetable
  didn't load. Check your connection and pull to refresh." Never "Something
  went wrong".
- **Permissions:** ask at the moment the feature needs it, with one
  sentence of why: "Location finds the crag you're at. It never leaves
  your phone."
- **Loading:** skeletons that match the real layout, or nothing for
  anything under 300ms.

## 8. Believable data

Specific data is the cheapest premium signal there is.

| Slop | Believable |
|---|---|
| $1,000.00 | $1,284.37 |
| 1,234 steps | 8,612 steps |
| 12-day streak | 23 days, best was 41 |
| 75% complete | 5 of 7 |
| John Doe | Mara Okafor |
| Coffee Shop, $4.50 | Bluestone Lane, $6.25 |
| Lorem ipsum | the real sentence |

- Uneven numbers, names from the user's region, real places, invented but
  brand-shaped merchants (never real trademarks).
- A realistic state: some done, one overdue, one new.
- Relative dates where people think relatively ("Yesterday", "In 2 hours"),
  absolute where they plan.
- Content a person typed is user content: mark it `data-ugc` so the copy
  scan leaves it alone (a recipe titled "Nonna's ragù — the real one" can
  keep its dash).

## 9. The read-aloud pass

After every shoot, before the critic:

1. Open the screens in order and read every string out loud, labels
   included.
2. Mark every line a person would not say. Rewrite it.
3. Check each screen's word count against §5 (the scan prints `words` and
   the headline for each surface).
4. Read the headline of each onboarding screen, paywall and store panel on
   its own. Does it make someone want the next screen?
5. Log what you changed in CRITIQUE.md under "Copy".

## 10. Writing for other languages

Leave room for 30% more length (German, Finnish), never bake words into
images, and write captions that translate as sentences rather than puns.
