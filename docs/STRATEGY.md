# Steppie: growth and money playbook

> Back yourself. Keep your money.

Steppie makes money when people back themselves: more people staking, bigger stakes, more often. Some of them miss, and the stake is kept. That is the whole business, and the app is built to maximise the first three numbers, not the miss rate.

## 1. The money equation

```
revenue / month =  active stakers × stakes per staker × average stake × miss rate
                 + Shields + Steppie Pro
                 − Stripe fees − refunds of Comebacks
```

Every lever below moves one of these terms. None of them works by making people fail more often. That lever exists ("go quiet after the deposit so they forget"), and we deliberately don't pull it:

- **It's the most expensive money in the business.** People who forget are the people who file chargebacks ("I didn't know I'd be charged"). Stripe reviews accounts above roughly 0.75% disputes and can close payments for good. One closed Stripe account ends Steppie.
- **It breaks the legal case.** A commitment contract stays outside gambling law (GlüStV in Germany, state gambling law in the US) because the outcome is in the user's control. An app engineered so users fail undermines exactly that. EU dark-pattern rules (DSA Art. 25, UWG §§ 4a, 5a) and Apple's review guidelines (4.5.4 for push, 5.3 for real-money mechanics) add risk on top.
- **It kills the funnel.** The second stake is where the lifetime value is. People who lost money because the app went silent don't come back, and they tell people.

The real misses are enough: about one in four staked challenges is missed even with good support (StepBet, 73% completion, n = 72,974, PMC9982638).

## 2. The bottleneck is the first stake

Deposit contracts work for the people who sign them, but few people sign. In Halpern et al. (NEJM 2015), 90% accepted a reward programme and only **13.7%** accepted a deposit programme, yet among the people who would accept either, deposits worked better. **Uptake is the whole game.** Everything before the first stake is designed to move that 13.7% up.

| Lever | Research | Where it lives in Steppie |
|---|---|---|
| **Loss framing** | Patel et al. (Ann Intern Med 2016): a "lose $1.40 a day" incentive got 45% of days to goal vs 30% control; the same money as a gain or lottery didn't beat control. | Copy is always "keep your €20", never "win". The stake is yours to keep, not a prize. |
| **Endowed progress** | Nunes & Drèze (2006): a 10-stamp card with 2 stamps already in was finished 34% of the time, vs 19% for an empty 8-stamp card. | Onboarding ends with the **Starter Kit**: a bib with the first pin already in ("goal set, Health connected") and **1 free Shield**. |
| **Hold, not charge** | Removes the perceived cost of saying yes: nothing leaves the account if you finish. | The 5-Day Sprint is the front door. Every pre-stake CTA says "hold". |
| **Shadow week** | The person's own data is the most credible evidence. | Today shows their last 7 days as if money had been on them: "5 of 7. With €10 on it, you'd have kept every cent." Real numbers only. |
| **Fresh start effect** | Dai, Milkman & Riis (2014): gym visits jump 33% at the start of a week, 47% at a new semester. | Pip's invites lead with Mondays and the 1st of the month. |
| **Social proof** | Only real numbers. | Public books in the Vault and on the site, from `public_stats`. |
| **Small first stake, default chosen** | Defaults decide; first stakes should be easy. | First race defaults to the second-smallest chip (€10 on the Sprint). |

### Notifications: loud before the deposit, quiet after

- **Before a stake (opt-in "race invites"):** Pip brings at most one message a day on a decaying schedule (days 0, 1, 2, 4, 7, 10, 14, 21, 28 after onboarding or the last finish, max 4 queued). Each uses a different true reason: fresh start, shadow week, Shield waiting, endowed bib, a real Comeback deadline. Apple requires explicit opt-in for promotional pushes (guideline 4.5.4), so onboarding asks with two clear choices: "pace nudges and race invites" or "only pace nudges".
- **While a stake is live:** one evening pace check, only if behind, cancelled the moment the goal is hit. Everything else is silent. People don't want noise once they've committed, and the one nudge protects us from "I forgot" chargebacks.

Source: `ios/Steppie/Services/NotificationService.swift`.

## 3. More stakes, bigger stakes: the game layer

Gamified like a card table, but the money side is pure skill: whether money comes back depends only on steps. All random rewards are cosmetic and never sold.

| Mechanic | What it does to revenue | Why it doesn't repel people |
|---|---|---|
| **Stake tables** (Rookie €5, Pacer €10, Racer €20, Champion €50, Legend €100) | Raises the average stake: bigger tables earn more Grit (1.5× to 4×). | Status, not pressure. Champion opens after 1 finish, Legend after 3, so nobody starts at the deep end. |
| **Stake ladder** | After a win, the next race suggests one rung up (5, 10, 20, 35, 50 …), marked "LEVEL UP", and the finish screen says "Level up: race for €20". After a miss it suggests the same rung, never more. | Beeminder's pledge schedule, but it only climbs after success, so nobody is chasing losses. |
| **Weekly Grit leagues** (Bronze to Diamond, top 7 move up) | More stakes per month: Grit only comes from race days. | Duolingo's leagues are its strongest engagement loop; Grit is effort, not money. |
| **Steppie Shields** (€1.99, 3 for €4.99, StoreKit consumable) | A second revenue line at the moment of highest intent ("you're behind, Shelly can cover today"). Keeps people in races, which keeps them staking. | Max 2 per race (Duolingo: two streak freezes beat one, three beat two by nothing). Unused Shields come back. First one is free. |
| **Comeback** (72 h, once per miss, stake ≥ the missed one) | Turns a churn moment into another stake. We refund 50% of the missed stake if they finish; we keep the rest plus any new misses. | One second chance, never a chain: a Comeback can't have a Comeback. |
| **Shoe Boxes** | Retention: a variable reward after every finish, and a reason to finish longer races (better odds). | Cosmetic, odds tied to race length (effort), never to stake size, never purchasable. This keeps it out of loot-box territory. |
| **Dash, the pacer** | More finishes earlier in the day, which means more confident second stakes. | A rival with a wink, never a shamer. |

## 4. Illustrative unit economics (assumptions, not a forecast)

Per 1,000 installs, first 90 days:

| Assumption | Value |
|---|---|
| Finish onboarding | 60% → 600 |
| First stake (base 14%, target with the levers above) | 25% → 150 stakers |
| Stakes per staker in 90 days (ladder + leagues + Comeback) | 4 |
| Average stake (ladder from €10) | €22 |
| Miss rate (73% completion, Shields lift it a little) | 24% |
| Shield attach (purchases per stake) | 0.15 at €1.99, 30% App Store cut |
| Pro conversion of stakers | 5% at €7.99/month |

- Stakes: 150 × 4 = 600 stakes, €13,200 staked.
- Kept: 24% × €13,200 = **€3,168**, minus Comeback refunds (say 20% of misses take one, 75% finish, 50% back: about €238) and Stripe fees (about €0.55 per captured or refunded stake, about €330). Net about **€2,600**.
- Shields: 600 × 0.15 × €1.99 × 0.7 ≈ **€125**.
- Pro: 150 × 5% × €7.99 × 3 × 0.7 ≈ **€125**.
- **≈ €2,850 per 1,000 installs in 90 days**, about €2.85 per install. Moving first-stake uptake from 14% to 25% is worth more than every other lever combined. That's why the pre-stake experience gets the most design.

## 5. Guardrails (they protect the revenue)

1. Money outcome = steps only. No chance element touches money; random rewards are cosmetic and never sold.
2. Never "bet", "wager", "odds", "jackpot" or casino language. Stakes, tables, backing yourself.
3. Never a charge the user didn't see coming: holds for short races, the whole deal on one screen, hold-to-pin.
4. One pace nudge while a stake is live, so "I forgot" never happens because of us.
5. Opt-in for race invites, opt-out any time in Settings.
6. 18+ for money. The Champion and Legend tables open only after finished races.
7. Public books: returned vs kept, live.

## 6. Money flow (Stripe)

- `create-stake` validates the template (or the Comeback rules), the table gates and the Shields in the locker, moves equipped Shields onto the race, and creates a PaymentIntent: `capture_method=manual` (a hold) for races that settle within 6 days, `automatic` otherwise.
- `stripe-webhook` marks the stake `held` or `charged` and activates the race.
- `settle` (pg_cron, every 15 min): a race is won if missed days ≤ grace days + equipped Shields. Unused Shields go back to the locker. Won: release the hold or refund in full, and for a Comeback also refund 50% of the missed race's stake. Lost: capture the hold or keep the charge.
- `grant-shields` checks a StoreKit transaction with the App Store Server API (bundle, product, not revoked, `appAccountToken` = the account) and credits the locker once per transaction.
- `league_board()` (SQL, RLS-safe) returns the caller's league table; `roll_leagues()` moves the top 7 up and the bottom 5 down every Sunday night.

## 7. Growth engine: X and Discord

- Share cards with Steppie and #BackYourself; weekly public-stats posts (real numbers only); the cast as a Discord emoji pack.
- Seasonal campaigns (Walktober) with cosmetic medals.
- Referral: when a friend finishes their first staked race, both get a Shield.

## 8. Roadmap

1. v1 (this branch): Steppie and the cast, stakes, Shields, Comebacks, tables, leagues, Shoe Boxes, Vault, widgets, Pro.
2. v1.1: friend races ("prides"), Live Activities for the last hour, Pro monthly Shields (needs App Store Server Notifications on the backend).
3. v2: new race types (distance, active minutes), charity forfeit option, Android.
