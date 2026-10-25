# Research

## 1. Steppa: Schritte-Challenges (the reference app)

- Listing: "Steppa – Step Challenges", subtitle "Fitness Goals, Walk, Win Money", 4.6★ from ~1.4–1.7K ratings (App Store id6755126064).
- **Mechanic: pool model.** You pay an entry fee, hit a daily step goal via Apple Health, and finishers split the pool. "No penalties or charges for missing goals": you just don't qualify for a payout. The fee is now 0% (all entry fees go back to finishers). Monetisation: Steppa Pro subscription ($4.99–$119.99 IAP).
- **Formats:** daily, weekly, multi-day challenges; leaderboards; friends; wallet with PayPal payouts.
- **What reviewers praise:** a clean UI, a small team shipping constantly, motivation that actually changes behaviour, responsive support.
- **What reviewers complain about (our openings):**
  1. **Settlement delay**: challenges take 1–2 days to settle before you can rejoin.
  2. **Cheating**: "users that have registered 20k plus steps within hours" on leaderboards.
  3. Payout friction (wallet, withdrawal thresholds).

## 2. The category

| App | Model | Revenue | Notes |
|---|---|---|---|
| StepBet / DietBet (WayBetter) | Pool, winners split | 15% rake (10–25% DietBet) + $59.99/yr membership | "No-lose guarantee" when many win |
| Steppa | Pool | 0% rake, Pro subscription | Fastest-growing, DACH |
| Beeminder | Commitment contract, pledge escalates | Keeps forfeits, open about it | Nerd-loved, dated UI |
| stickK | Commitment contract | Forfeits to charity/anti-charity/friend | Yale economists (Karlan, Ayres) |
| Forfeit | Commitment contract | **Stripe pre-authorises the stake; captured only on failure** | Proves the pre-auth pattern passes App Review |
| HealthyWage | Weight-loss bets | Insurance-style, sponsor-funded prizes | Long bets, high stakes |

**Where Steppie sits:** commitment contract (the owner's choice: forfeits are kept) with a Forfeit-style hold, Steppa-level design, and faster settlement and stronger anti-cheat than both.

## 3. Evidence that money on the line works

- **StepBet field study** (n = 72,974, 2015–2020, 6-week games): daily steps rose **31.2%** (7,774 to 10,197). Winners rose 44%. **73%** of participants succeeded. **Larger deposits predicted higher odds of success.** Source: "Put your money where your feet are", PMC9982638.
- **Loss aversion** (Kahneman & Tversky, 1979): losses weigh about 2x equivalent gains. Staking your own money beats winning someone else's.
- **Commitment devices** (Giné, Karlan, Zinman, 2010, "Put Your Money Where Your Butt Is"): offering smokers a deposit account they forfeit on failure raised verified quit rates at 6 and 12 months by roughly 3–6 percentage points, a large relative effect for a voluntary, self-funded device.
- **Walking and weight:** at roughly 0.04–0.05 kcal per step (body-weight dependent), 10k steps is about 300–500 kcal per day. A sustained deficit of about 7,700 kcal is about 1 kg of fat. Steppie shows this estimate transparently and never promises outcomes.
- **Step targets and health:** mortality benefits plateau around 7,000–10,000 steps per day for adults (Paluch et al., Lancet Public Health 2022). Steppie recommends goals from the user's baseline (+20–30%, capped), not a blanket 10k.

## 4. Hooked model (Nir Eyal), mapped honestly

| Phase | Steppie implementation |
|---|---|
| **External trigger** | One smart evening nudge, only when you're behind pace ("1,840 steps to keep your €20: a 17-minute walk"). Morning "your day starts at 0" nudge. Streak-at-risk nudge. Max 2 per day, user-tunable. |
| **Internal trigger** | "I want to feel in control of my weight." Guilt after a sedentary day turns into "open Steppie." Built by the onboarding "why" question, shown back to the user on hard days. |
| **Action** | Opening the app takes one glance: ring, steps to go, minutes-of-walking equivalent. Widget and Lock Screen widget remove even the open. |
| **Variable reward: self** | Ring closes with a haptic and particle burst; streak flame grows; weight-trend line bends; milestone badges at unpredictable-but-earned moments ("You just walked the length of Manhattan"). |
| **Variable reward: hunt** | Stake released back. The moment money returns is the biggest designed moment in the app. |
| **Variable reward: tribe** | Live community pulse (real counts); share cards; friend challenges (Pro). |
| **Investment** | Stake (money), streak, weight log, "why" statement, friends. Each makes the next loop more likely and the app more personal. |

Manipulation Matrix check: the maker would use it (yes), and it materially improves the user's life (yes, more walking). That puts Steppie in the "facilitator" quadrant.

## 5. What makes a logo "Fortune 500" (see brand/BRAND.md)

Paul Rand ("a logo derives its meaning from the quality of the thing it symbolizes"), Chermayeff & Geismar & Haviv's test (**appropriate, distinctive, simple**), and the pattern in marks that last (Nike, Apple, Target, Mastercard, FedEx, Chase, Shell):
1. Reducible to one colour and a single silhouette; recognisable at 16 px (favicon) and at billboard size.
2. Built on a geometric grid (circles, consistent stroke), so it feels engineered rather than drawn.
3. One idea, not three. The strongest marks carry a hidden second read (FedEx arrow, Amazon smile).
4. Timeless: no gradients or effects in the master; trends go in the campaign, not the mark.
5. The wordmark is custom-tuned (tracking, weight) and pairs with the symbol at a fixed ratio.

## Sources

- https://apps.apple.com/us/app/steppa-step-challenges/id6755126064
- https://www.playsteppa.com/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC9982638/
- https://fourweekmba.com/how-does-dietbet-make-money/
- https://www.forfeit.app/
- https://www.accountablo.com/blog/apps-that-charge-you-money
- https://en.wikipedia.org/wiki/StickK
