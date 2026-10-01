# Grinda: product and business strategy

> Walk it off. Keep your money.

## 1. First principles

1. People who want to lose weight already know walking works. **The problem is follow-through, not information.**
2. Loss aversion is the strongest cheap motivator we have. A stake of your own money roughly doubles the felt cost of skipping.
3. A money app lives or dies on trust. **One surprise charge ends the relationship.**
4. Revenue from misses creates a perverse incentive (the company profits when users fail). Grinda neutralises it by designing every surface to increase completion, publishing the refunded-vs-kept ratio, and building a second revenue line (Pro) that grows when users succeed.

## 2. The core loop

```
Set goal from your body  →  Stake (hold, not charge)  →  Walk (ring, nudges, widget)
        ↑                                                         ↓
   Re-stake bigger  ←  Money back + badge + share card  ←  Day closes, auto-settle
```

## 3. Free vs. paid

| Free forever (the bait that genuinely helps) | Staked challenges (the core) | Grinda Pro (subscription, StoreKit) |
|---|---|---|
| Step ring, daily goal from baseline | Stake 5–500 EUR/USD | 3 grace tokens / month |
| Streaks + streak calendar | Hold for ≤5-day challenges, charge + instant refund for longer | Custom challenge builder (any days, any goal) |
| Weight log + trend (Health sync) | 1 grace day on 7+ day challenges | Up to 3 concurrent challenges |
| Practice challenges (no money, no rewards beyond badges) | Auto-settlement 3 h after day close | Friend challenges (each stakes their own money) |
| Weekly recap, share cards | Money-back ledger | Advanced insights (pace, best hours, kcal/weight projection) |
| Home and Lock Screen widgets | | |

**Why free isn't "enough":** practice challenges show your progress but carry no consequence. The app shows data from the StepBet study (73% completion with money on the line) next to your own practice completion rate. The pitch writes itself, and it's honest.

## 4. Trust system (the moat)

1. **Hold, don't charge.** Challenges of 5 days or fewer place a card authorization only. Win and it's released, and no money ever moves.
2. **Instant refunds.** Longer challenges are refunded by webhook the minute they settle. The target is under 5 minutes, against Steppa's 1–2 days.
3. **Contract screen.** Before paying, one screen states the whole deal in plain words: goal, days, stake, when settlement happens, grace day, what counts as steps. It ends with hold-to-commit.
4. **Live ledger.** The Wallet shows every cent: held, released, refunded, kept, with timestamps and Stripe references.
5. **Public stats.** A public page and in-app card show totals refunded, total kept, completion rate, and steps walked, straight from the database.
6. **Sync-failure guarantee.** If Health data arrives late due to a verified sync issue, support can mark the day complete. No questions within 48 h.
7. **Start small.** The suggested first stake is €5/$5, and the app says so: "Start with an amount you'd hate to lose but won't miss."
8. **No auto-renewing stakes.** Every stake is an explicit act.

## 5. Money flow (Stripe)

- `create-stake` Edge Function creates a Stripe Customer and a PaymentIntent. For challenges settling within 6 days (≤5 days) it uses `capture_method=manual`; otherwise `automatic`. Returns client secret + ephemeral key for PaymentSheet (Apple Pay first).
- `stripe-webhook` marks the stake `held` (authorized) or `charged` (succeeded). Only then does the challenge become `active`.
- `settle` (pg_cron, every 15 min) closes days whose local end + 3 h grace has passed:
  - **won:** manual capture intents are cancelled (`hold released`); charged intents get a full refund.
  - **lost:** manual capture intents are captured; charged intents stay.
- Idempotency keys on every Stripe call; all transitions recorded in `ledger_entries`.

## 6. Anti-cheat

- Steps are read with `HKStatisticsCollectionQuery` and **exclude** samples with `HKMetadataKeyWasUserEntered = true`.
- Per-hour buckets are uploaded, not just a daily total. The server flags any hour > 15,000 steps (about 250/min sustained) and days with > 60,000.
- App Attest assertion on submissions (server verifies). Flagged days go to review and are never auto-lost; the user sees "under review".
- Rate limit: 1 submission per 5 min per challenge.

## 7. Economics (illustrative, not a forecast)

Assume average stake €20 and 73% completion (StepBet benchmark):
- Expected kept per stake: 27% × €20 = **€5.40**.
- Stripe cost: holds released are free, refunds lose the fee (about €0.55 on 7-day stakes), and captures cost about €0.55. Net about €4.70 per stake.
- A user doing 3 stakes/month is worth about €14/month from stakes, plus Pro (€7.99/month, €49.99/year).
- **If completion rises, stake revenue falls but retention and stake size rise.** That's the intended trade.

## 8. Growth engine: X and Discord

- **Share cards** (1080×1350, generated in-app): "Day 7/7 ✓ · 74,210 steps · €20 back", in the brand style. The share sheet posts to X with #WalkItOff.
- **Public stats, weekly**: an X thread template built from the `public_stats` view: "This week Grinda users walked 1.2M km, completed 8,410 challenges, got €71,304 back." **Only real numbers.** An Edge Function `public-stats` exposes JSON for a bot/website.
- **Discord**: a community server with a #proof channel (share cards), weekly community challenges, and a bot that posts the public stats.
- **Referral**: invite a friend, and when they finish their first staked challenge you both get a free grace token (no money, so no regulatory issue).

## 9. Roadmap

1. v1 (this repo): steps challenges, stakes, Health, wallet, widgets, Pro, share cards.
2. v1.1: friend challenges, Live Activities for the final hour, Garmin/Fitbit direct.
3. v2: new challenge types (distance, active minutes, workouts, weight milestones), charity forfeit option, Android.

## 10. Grin and the engagement layer (added 2026-10-01)

Grin, the Grinda lion, carries the habit loop without changing the product:
- **Trigger:** Grin-voiced evening nudge, at most one, only when behind.
- **Action:** Today opens to Grin saying something specific about your day.
- **Variable reward:** rotating coach lines, tap reactions, medal moments, confetti.
- **Investment:** a mane that grows with goal days in the last 14, Finch-style.

Plus the **trophy case** (13 medals), the **Walktober 2026** launch campaign (a cosmetic medal, no money involved), a **Grin app icon** for Pro, and a Discord emoji pack. Full rationale and research: [`brand/mascot/MASCOT.md`](../brand/mascot/MASCOT.md).
