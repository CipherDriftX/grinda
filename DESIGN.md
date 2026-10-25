# Steppie design system

The world: **a stadium track seen from above**, with a cast of characters running it. A walking day is a race against yourself. Every race is a numbered bib printed on Tyvek and pinned at four corners. Money gets banknote-grade line work. The source of truth for values is `ios/Steppie/DesignSystem/`.

## Colour

Strategy: **Committed.** Lane Cobalt owns the top of Today, the Welcome screen, the featured race, and the finish, which is 30–60% of the key surfaces. Everything else is paper on ground.

| Token | Light | Dark | Role |
|---|---|---|---|
| `Palette.cobalt` | `#1F4FD8` | `#3D6BFF` | Tint, interactive, brand |
| `Palette.field` | `#1F4FD8` | `#16307F` | The track field (full-bleed regions) |
| `Palette.lane` | `#1942B8` | `#0F2463` | Lane band drawn on the field |
| `Palette.tyvek` | `#F4F6F8` | `#1A1E26` | Bibs, cards, rows |
| `Palette.ground` | `#E9ECF1` | `#0E1116` | Screen ground |
| `Palette.ink` | `#0E1116` | `#F1F3F6` | Primary text |
| `Palette.inkSecondary` | `#4A5261` | `#A3AAB8` | Secondary text |
| `Palette.hairline` | `#CDD2DB` | `#2C323D` | Rules, empty punches |
| `Palette.volt` | `#C8F03C` | same | **Only** completion and money returned |
| `Palette.risk` | `#D92D20` | `#FF5A4E` | **Only** stake at risk / missed |
| `Palette.onFieldSecondary` | `#C9D6FF` | same | Secondary text on cobalt (tinted, never gray) |

Rules: volt never decorates. Red never decorates. On cobalt, secondary text is `onFieldSecondary`.

## Type

- **UI:** SF Pro text styles (Dynamic Type). Headings are bold/heavy and sized as `.title3`–`.largeTitle`.
- **Numerals:** `BrandFont.numerals(size, relativeTo:)` uses Steppie Bib Black (Archivo, width 62, weight 900), like race-bib numbers. It's used for step counts, goals, money amounts, and day counts.
- **Labels:** `BrandFont.label(size)` uses Steppie Bib Bold (width 75, weight 750), uppercase, for bib headers, grid labels, and money bands.
- **Display:** Steppie Wide Black is for the wordmark only.
- No eyebrow or kicker labels above headings.

## Components

| Component | File | Notes |
|---|---|---|
| `TrackView` | `Track.swift` | Stadium lane, lane lines, finish line at t=0, progress stroke, runner with `figure.walk`, dashed ghost pacer. Arc-length geometry shared by stroke and runner. |
| `BibCard` | `Bib.swift` | Header (race, Nº), numeral row, 3-cell label grid (Race / Stake / Settles), punch row, guilloche money band, 4 pins. |
| `PunchRow` | `Bib.swift` | Hit = hole showing the field colour. Missed = red ×. Grace = dashed. Today = progress ring. |
| `Guilloche` | `Bib.swift` | Fine sine-wave line work behind money. |
| `HoldToPinButton` | `HoldToPin.swift` | Signature interaction: 1.6 s hold, a pin every 25% with a rigid haptic, success haptic at the end; release springs back in 0.25 s. |
| `StrideMark` | `StrideMark.swift` | Live logo. Draws itself on Welcome. |
| Leader lines | `WalletView.swift` | Passbook "label …… value" rows. |
| Buttons | `Motion.swift` | `.primary` (cobalt slab, 56 pt), `.onField` (white on cobalt), `.volt` (finish only), `.pressable` (scale 0.97). |

Radii: 14 for bibs and cards, 16 for primary buttons and feature panels, 12 for chips.
Depth: paper on ground, `shadow(black 14%, radius 18, y 10)`. No zero-offset glows.

## Motion

- Default spring: response 0.38, damping 1.0 (`Motion.standard`). Press: 0.22 / 0.9.
- Bounce only where a physical thing snaps: pins and the finish tape (`Motion.snap`, damping 0.62).
- The track draws in once on appear (`Motion.draw`). Numbers roll with `.numericText`.
- Arrival stagger 50 ms per element, only on first appearance.
- Reduce Motion replaces movement with short fades. The track shows its final state immediately.
- Haptics fire on the same frame as the visual they belong to (pins, ticks, success).

## Voice

A coach on your side. Specific numbers ("4,120 to go · about 38 min"), plain money language ("held · never charged if you finish"), and never shaming. Money copy appears only where money moves.

## Cast and motion

Source of truth: `brand/mascot/tools/steppie.py` and `cast.py` (400 × 460 canvas), exported to `ios/Steppie/DesignSystem/MascotArt.swift` as rigs. `CharacterView(who:mood:pose:mane:shoes:hop:running:animated:)` renders and animates any of the five: Steppie (lead), Dash (pacer), Shelly (Shields), Pip (messages), Bo (Vault). Steppie's shoe colourways come from `ShoeStyle` and recolour his trainer parts by id.

Effects live in `Effects.swift`: `ConfettiBurst` (fluttering paper), `CoinRain` (money coming home), `SparkleField`, `RaysBackground`, `DustPuffs`, and the modifiers `.shimmer()`, `.pulseHalo()`, `.shake(_)`. Loud effects are rationed to rare moments (pinning, goal, finish, Shoe Box); everyday screens get sparkles and shimmer. Every effect is skipped under Reduce Motion.

## Game components

| Component | File | Notes |
|---|---|---|
| `StakeChip` | `ContractView.swift` | Poker chip per stake, coloured by table. Selected chip sits on a stack with a volt glow; locked tables show a padlock; the ladder's next rung wears "LEVEL UP". |
| `TierBadge` | `ContractView.swift` | The table you're sitting at. |
| `StatChip` | `TodayView.swift` | Streak, Shields and Grit on the field. |
| `ShadowRaceCard` | `TodayView.swift` | Pip shows your last 7 days as if staked. Only when nothing is staked. |
| `ComebackCard` | `TodayView.swift` | Real 72 h deadline, live countdown. |
| `ShoeBoxSheet` | `Rewards/ShoeBoxView.swift` | Anticipation shakes, burst, reveal with rarity colour. |
| `LeagueBadge` | `League/LeagueView.swift` | Crest in the league colour with the Stride S. |
| `StrideMark` | `StrideMark.swift` | The live logo: the two halves stride in and snap together on the cut. |

## Purse components

Purse races borrow banknote language: rosettes, guilloche, serial-style codes and a big money figure. The purse total is always the biggest number on a purse surface. Green money (`#1F7A52`) is for a split you could win; volt stays for money that came back.

| Component | File | Notes |
|---|---|---|
| `PurseNote` | `PurseKit.swift` | A purse as a banknote: art colour, rosette, guilloche band, purse total, entry, days, goal, still-in. `compact:` for rows and teasers. |
| `CountingMoney` / `CountUpMoney` | `PurseKit.swift` | Money that rolls up digit by digit. Used when an entry lands in a purse and when a split is paid. |
| `LiveTag` | `PurseKit.swift` | Pulsing dot + label. Red only while a purse is live and someone can still drop out. |
| `Countdown` | `PurseKit.swift` | Ticks once a second to the day close in your time zone. Turns red under 4 hours if steps are left. |
| `StillInBar` | `PurseKit.swift` | One bar, three parts: on pace, behind, out. The live count in one glance. |
| `PayoutTicker` | `PurseKit.swift` | Recent payouts from `payout_feed` sliding past on the Purses board. Hidden when the feed is empty, so a new app never shows invented wins. |
| `EntrantsStack` | `PurseKit.swift` | Overlapping cast faces plus "N in". |
| `CoinDrop` | `PurseKit.swift` | A coin falls into the purse when you join. |
| `PayoutMath` | `PurseDetailView.swift` | Your split if 93%, 85% or 75% finish, shown before you join. |
| `LiveBoard` | `PurseDetailView.swift` | Ranked runners with today's steps, you pinned and highlighted. |
| `JoinPurseView` + `PurseEnteredOverlay` | `JoinPurseView.swift` | Bib preview, money leader lines (entry, fee, host 5%, total, from Vault, on card), Shields stepper, hold to pin. Then the purse total counts up with your entry, coin drop, confetti and the cast. |
| `PurseLiveStrip` | `TodayPurse.swift` | Under your bib on Today: LIVE, day N, the clock, purse total, your split now, still-in bar, your rank, steps left. |
| `AlsoRunning` | `TodayPurse.swift` | Other races (Pro runs 5 at once) as slim rows with a ring. |
| `PurseTeaser` | `TodayPurse.swift` | No purse yet: the biggest open purse as a banknote. |
| `InviteCard`, `PaidToPostCard`, `PayoutsList`, `BenchNote` | `Crew/CrewView.swift` | The Crew tab: league, $5 + $5 invites, Paid to Post, recent payouts, accounts removed for fake steps (never names). |
| Sheets | `CrewSheets.swift`, `CashOutSheet.swift`, `HostPurseSheet.swift`, `DisputeSheet.swift` | Invite code, Paid to Post calculator, cash out from the Vault, host a purse with a live banknote preview, send proof for a day that didn't sync. |

## App icon

Steppie's lion on a purse seal: a cobalt field with soft rays, a scalloped volt seal ring with fine green guilloche, and an inner cobalt disc behind the lion. Dark uses an ink field; tinted is a grayscale version for iOS tinted mode. Files live in `brand/icon/` and `AppIcon.appiconset`.
