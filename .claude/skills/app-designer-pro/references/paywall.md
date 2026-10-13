# Onboarding and paywalls

These are the screens that decide whether the app makes money, and the ones
where generated design is at its worst: feature carousels, a crown icon on
a gold gradient, ten green ticks, "Unlock Premium", a grey X that appears
after three seconds. A crafted paywall is a screen of the app, in its
direction, that tells the truth plainly and makes the yes easy.

Design them when the brief says the app charges (a subscription or a
one-time unlock), or when the user asks. Mark the screens
`data-kind="onboarding"` and `data-kind="paywall"`: the scan then holds
them to the word budgets in copy.md §5 and checks prices, trials, Restore
and fake urgency.

## 1. Onboarding: get them to the first result

Onboarding has one job: bring the person to the moment the app is
obviously worth it (the first real result), as fast as possible, and earn
the paywall on the way.

**The shape** (skip any step the app does not need):

1. **A first screen that is the product,** or one promise screen at most.
   The promise is the outcome in the user's words (copy.md §6) over the
   app's richness: its photo, its object, its colour field. No carousel of
   three feature slides with dots.
2. **One to three questions whose answers visibly change the app.** One
   question per screen, big tappable answers, the effect shown ("Mornings:
   your plan starts at 7:00"). A question that changes nothing is a form.
3. **The first result:** their plan, their first entry, tonight's dinner
   from their fridge. Show it built from their answers. This is the screen that
   sells.
4. **Permissions in context,** each with one sentence of why, at the moment
   the feature needs it (copy.md §7). Never three system prompts in a row.
5. **The paywall,** after the result (§2), with a decent way out unless the
   app is deliberately hard-paywalled.

**Rules:**

- Progress shown when there are more than three steps (a thin bar or
  "2 of 4"), and Back always works.
- No account wall before value unless the app cannot work without one; then
  Sign in with Apple / Sign in with Google as the first choice.
- Each step meets the onboarding budget: a headline of 3 to 7 words, one
  support line, one button.
- Same tokens, type and richness as the rest of the app. Onboarding is not
  a different, brighter brand.

## 2. The paywall, top to bottom

1. **A way out:** a close button (44pt / 48dp target, visible from the
   first frame, marked `data-close`) or "Not now" under the button. A hard
   paywall (no way into the app without paying) is a business decision:
   write it in DIRECTION.md, and know that both stores scrutinise them.
2. **The hero is what they get,** shown, not listed: their plan built from
   onboarding, the library they are about to open, the object of the
   concept. The app's richness source belongs here.
3. **A headline of up to 8 words:** the outcome, not "Go Premium".
4. **Up to three benefit lines,** each a short, concrete outcome ("Every
   route in the guidebook, offline"). Not a ten-row checklist of features. A two-column
   free-vs-paid comparison only when there is a real free tier, five rows
   at most.
5. **The plans:** two is the norm (yearly and monthly), three at most.
   - The yearly plan selected by default is fine; say what it costs per
     year first and per month second.
   - **The billed amount is the clearest price on the screen.** App Review
     rejects paywalls where a per-month equivalent or "Free" is bigger or
     bolder than the amount actually charged ("€39.99 a year"). Set the
     billed amount at the body size or larger, the equivalent smaller.
   - The saving is computed and true: €4.99 a month is €59.88 a year, so
     €39.99 a year saves 33%. Show the arithmetic in DIRECTION.md.
   - The selected plan is obvious at a glance (fill, border or check in the
     accent), the other plainly tappable.
6. **The trial, if any, in one sentence with what happens after:** "Free
   for 7 days, then €39.99 a year." A timeline (Today: full access; Day 5:
   we remind you; Day 7: €39.99) is clear and honest, but only if the app
   really sends the reminder.
7. **One button:** filled, full width inside the margins, 50 to 56pt tall,
   in the bottom third. The label says what happens: "Start my 7 free
   days", "Subscribe for €39.99 a year".
8. **The small print** (`data-legal`): "Cancel anytime in Settings" (iOS)
   or "in Google Play" (Android), Restore Purchases (iOS: required), Terms,
   Privacy. 11 to 13pt, readable contrast, never hidden.
9. **Proof, only if real** (copy.md §6): an actual rating with its count, a
   quote with a real name. On an unlaunched app, none.

## 2b. One-time purchases and unlocks

A one-time unlock (a "Pro" for €4.99, a lifetime licence, a pack) is
simpler and should look it:

- **The price once, with what makes it different from a subscription:**
  "€4.99 once" or "€4.99, yours to keep". "No subscription" is a real
  benefit; say it if it's true.
- **"Unlock Pro" is an honest label** for a non-consumable. "Unlock your
  potential" and "Unlock Premium" with a crown are not (the scan fails the
  phrases, not the word).
- **What the free app keeps,** in one line, so the unlock does not read as
  a threat.
- **Restore Purchases still applies on iOS** (it restores a non-consumable
  too); on Android, purchases come back with the Google account.
- No trial, no plans picker, no timeline: one price, one button, a way out.

## 3. Three honest layouts

Not templates: three starting points, each drawn in the app's direction.

- **The result paywall.** Their own result fills the top (the plan, the
  first chapter, this week's dinners), slightly dimmed or cropped by the
  sheet that holds the offer. Converts best after a personalised
  onboarding, because the thing they would lose is on screen.
- **The poster paywall.** One big promise on the direction's richest
  ground (a colour field, a photograph, the hero object), three short
  lines, the plans and the button. Best for apps whose value is a feeling
  or a library.
- **The object paywall.** The offer as an object from the concept: a
  membership card, a season ticket, a key, a seed packet. The plans are
  its options. Best for directions with a strong object (directions.md I).

## 4. Store rules (check the current text before shipping)

**Apple** (App Review Guidelines 3.1.1 and 3.1.2, and Schedule 2 of the
developer agreement):

- Describe clearly what the subscription gives for the price before asking
  for it.
- The full price and the billing period, and for a trial, its length and
  the price after it.
- The amount billed must be the most clear and conspicuous price.
- A way to restore purchases (a Restore button on the paywall or in
  Settings; put it on the paywall).
- Links to the Terms of Use (EULA) and the Privacy Policy.
- No bait and switch, no tricks. Apps that trick people into subscribing
  are removed.
- Native option: StoreKit's `SubscriptionStoreView` in SwiftUI gives a
  compliant, system-styled paywall you can dress in the direction
  (swiftui.md).

**Google Play** (Payments and Subscriptions policies):

- State the trial length, the price after it and when it converts, in the
  local currency and language.
- Make clear what is free and what is paid.
- Tell people how to cancel, and give them an easy way to do it (Google
  Play's subscription center).
- Google sends its own reminders before trials end; don't promise a
  reminder of your own unless the app sends one.

Both: no fake countdowns, no false scarcity, no confirmshaming, no price
shown smaller than its decoration.

## 5. Paywall slop, by name

- **"Unlock Premium":** a crown or a diamond icon, a gold or purple
  gradient, the word Premium three times.
- **The tick wall:** eight to twelve features with green checkmarks, half
  of them things the free app already does.
- **The ambush:** "70% off, today only", a countdown, "Only 12 spots left".
- **The tiny exit:** a 14pt grey X that fades in after a delay, or a "Skip"
  hidden behind the home indicator.
- **The giant FREE:** "Free" at 48pt and "€59.99/year" at 11pt.
- **Confirmshaming:** "No thanks, I don't care about my health."
- **The brand break:** a paywall in a brighter, different style from the
  app, as if bought from a template.
- **The stranger:** a paywall that appears before the person has seen
  anything the app does.

## 6. In the mockup

- Onboarding: 2 to 4 screens (the promise if any, one question, the first
  result), plus the paywall. On both platforms when both are in scope: the
  paywall always pairs (the Android one says "in Google Play", has no
  Restore requirement, uses the platform's controls).
- Realistic local prices from the store's price points (€4.99, €9.99,
  €39.99, €59.99; $4.99, $49.99), the saving computed.
- The scan checks: word budget, headline length and size, the button's
  size and place, price and period present, trial with its after-price,
  Restore on iOS, Terms and Privacy, a way out, fake urgency, proof claims.
  The critic scores the rest with the Conversion line (critique.md).
