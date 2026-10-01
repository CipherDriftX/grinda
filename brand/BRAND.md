# Steppie brand

![Steppie lockup](logo/lockup-on-cobalt.png)

## Name

**Steppie.** Two syllables, stress on the first (STEP-ee). A step is the unit of the whole product, and the "-ie" ending makes it a character's name: friendly, a little cheeky, easy to say in English and German. The app and the lion share the name, the way Duolingo and Duo share one, so every mention of the mascot is a mention of the brand.

## The mark: Stride S

An **S cut in two by a forward stride**. Two bowls, one stroke weight, and every cut (the stride gap in the middle and both terminals) on the same **58°** angle, leaning forward.

- **One idea, two reads.** It's an S, and it's two steps: the top half lands, the bottom half pushes off. The gap is the stride between them, the same trick as the FedEx arrow (meaning in negative space).
- **A system, not a drawing.** The 58° cut repeats everywhere: the two slashes on Steppie's trainers, the dot on the wordmark's *i*, the slash on the app icon, the stripes on Shoe Boxes, the league crest.
- **Reducible.** One flat colour, reversed or positive, legible at 16 px (tested at 16, 24, 32, 48 px). No gradients or effects in the master.
- **Built from geometry.** Two circles of radius 100 on a vertical axis, stroke 84, stride gap 22, terminal cuts 40° from the end of each bowl. Generator: `tools/stride.py` (writes `logo/stride-s.json`, used by every other tool and by the app's `StrideShape`).

### What we learned from the Fortune 500 marks

| Principle | Where it comes from | How Stride S applies it |
|---|---|---|
| One shape, one colour | Nike swoosh, Apple, Target | A single filled shape; works in cobalt, ink or white. |
| Meaning in negative space | FedEx arrow, NBC peacock | The stride gap carries the idea of a step. |
| A distinctive detail | The bite in Apple, the smile in Amazon | The forward cut, repeated as a brand signature. |
| Geometric construction | Target, Mastercard, Chase | Two circles, one stroke, one angle. |
| Scales to the smallest use | Every mark that survives app icons and favicons | Clear at 16 px; counters stay open. |
| Mascot separate from mark | Duolingo (Duo + wordmark), Michelin | Steppie the lion is the app icon and the voice; the Stride S is the signature. |

### Rand/Haviv test

| Test | Answer |
|---|---|
| Appropriate | A step, an S, forward motion. |
| Distinctive | No fitness or fintech brand owns a split S with angled cuts. |
| Simple | Drawable from memory: an S with a slash. |
| Memorable | "The S that's taking a step." |
| Timeless | Pure geometry, no trend effects. |
| Scalable | 16 px to a billboard. |

## Wordmark

`steppie` in lowercase **Steppie Wide Black** (Archivo, width 112, weight 900, SIL OFL 1.1), tracked −1%, converted to outlines. The dot of the *i* is the stride cut: a parallelogram on the 58° angle, in **cobalt** on light grounds and **volt** on cobalt. Lowercase reads as a friend, the heavy wide cut as a serious money brand.

Lockup: symbol height = 1; wordmark x-height = 0.5; gap = 0.3. Clear space on every side = the width of one bowl's stroke.

## Colour

| Role | Name | Hex | Use |
|---|---|---|---|
| Brand field | **Lane Cobalt** | `#1F4FD8` | The track, app icon field, primary actions. White text reaches 6.6:1. |
| Signal | **Finish Volt** | `#C8F03C` | Completion, money returned, the i-dot on cobalt, Steppie's midsoles. |
| Paper | **Tyvek** | `#F4F6F8` | Bibs and cards. |
| Ink | **Ink** | `#0E1116` | Text, dark mode ground. |
| Mascot | Fur `#FFBE3D`, mane `#F0781E` | | Steppie only. |
| Cast accents | Dash `#7C5CFF`, Shelly `#2E9E6B`, Pip `#5B8CFF`, Bo `#A87452` | | Each character and the mechanic it owns. |
| Tables | Rookie `#9AA3B2`, Pacer `#22B37A`, Racer `#1F4FD8`, Champion `#7C5CFF`, Legend `#FFB020` | | Stake chips and table badges. |
| Alert | Risk red `#D92D20` | | Only for a stake at risk. |

## Type

- **UI:** SF Pro (system), Dynamic Type everywhere.
- **Numerals and labels:** Steppie Bib Black (Archivo width 62, weight 900) and Steppie Bib Bold (width 75, weight 750).
- **Wordmark and headlines in marketing:** Steppie Wide Black.

## Voice

A coach who's on your side, with a crew that's fun to be around. Short, warm, specific. Money is stated plainly, only where money moves.

- Yes: "Dash is 1,200 ahead. A 12-minute walk and we pass him."
- Yes: "€20 back on your card. You earned that."
- Yes: "Back yourself with €10."
- Never: "bet", "wager", "odds", "jackpot", or anything that sounds like a casino. Never shaming.

## App icon

- `icon/appicon.png`: Steppie's face on a floodlit cobalt field with the volt stride slash. Mascot faces win the home screen (Duolingo's owl is the precedent).
- `icon/appicon-dark.png`: the same on ink.
- `icon/appicon-tinted.png`: the Stride S, for iOS tinted mode.
- `icon/appicon-stride.png`: the Stride S on cobalt, the Pro alternate icon.

Generator: `tools/brand.py` (fonts, wordmark, lockups, icons).
