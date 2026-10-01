# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

Delegated. Native Swift 6 + SwiftUI (iOS 17+), HealthKit, Swift Charts, WidgetKit, StoreKit 2, Stripe iOS SDK (PaymentSheet). Project generated with XcodeGen from `ios/project.yml`. Backend: Supabase (Postgres, Row Level Security, Sign in with Apple, Edge Functions in TypeScript/Deno, pg_cron). CI and App Store delivery: GitHub Actions macOS runners + fastlane. Chosen because native SwiftUI gives the best animation fidelity, HealthKit access, and App Store review path for an iPhone-first product.

## Users

Adults (18+) who want to lose weight and have tried and quit before. They know walking works; what they lack is follow-through. They open the app several times a day for a few seconds (glance at progress), once in the evening (am I going to make it?), and occasionally for longer (start a challenge, review progress). Primary markets: EU (EUR, DACH first) and US (USD).

## Product Purpose

Steppie turns a daily walking goal into a commitment backed by the user's own money. The user stakes an amount on a challenge (e.g. 10,000 steps a day for 7 days). If they finish, they get every cent back. If they miss, Steppie keeps the stake. The purpose is weight loss through walking; the stake is the mechanism that makes people actually do it.

The business: revenue = stakers × stakes each × average stake × miss rate, plus Shields and Pro. Steppie grows by moving the first three (more people backing themselves, more often, with bigger stakes), never by engineering misses. The full playbook is `docs/STRATEGY.md`.

## Positioning

- **Your money never leaves if you walk.** For challenges up to 6 days the card is only authorized (a hold), never charged; the hold is released the moment the challenge settles. Longer challenges are charged and refunded in full, automatically, within minutes of settlement.
- **Commitment contract, not a lottery.** No prize pool, no chance element. You compete only against your past self.
- **Honest about how it makes money.** Steppie earns from missed stakes and an optional Pro subscription, and shows this plainly, including a public, live "refunded vs. kept" ledger.
- **Built around the body, not the bet.** Goals are set from the user's weight goal and current baseline, not from what maximises revenue.

## Operating Context

- Steps come from Apple Health (HealthKit). Any tracker that writes to Apple Health works: Apple Watch, iPhone motion, Garmin Connect, Fitbit (via sync apps), Oura, Withings, Samsung Health bridges, Google Fit bridges.
- Stakes are paid with Stripe (Apple Pay, cards, SEPA where available) via PaymentSheet. Payouts are refunds or released holds, back to the original payment method.
- Days are counted in the user's time zone at challenge start; settlement runs after the day closes plus a sync grace window.
- Marketing runs through X (Twitter) and Discord: shareable progress cards and real, aggregate public statistics.

## Capabilities and Constraints

- Free forever: step tracking, daily goal ring, streaks, weight log, practice challenges (no money), weekly recap, share cards.
- Staked challenges: the core paid mechanic. Stakes from 5 to 500 in the local currency, on tables (Rookie, Pacer, Racer, Champion, Legend). Champion opens after 1 finish, Legend after 3. One free grace day per challenge of 7+ days.
- Steppie Shields (StoreKit consumable): cover one missed day each, up to 2 per race, unused ones return. One free with every account.
- Comeback: one 5-day race within 72 h of a miss; finishing refunds 50% of the missed stake.
- Game layer (no cash value): Grit and weekly leagues, the stake ladder, Shoe Boxes with cosmetic trainers for Steppie.
- Steppie Pro (StoreKit subscription): custom challenge builder, advanced insights, multiple concurrent challenges, friend challenges, the Stride S icon.
- Anti-cheat: ignore manually entered HealthKit samples (`HKMetadataKeyWasUserEntered`), prefer watch/phone motion sources, flag physiologically implausible cadence (> 250 steps/min sustained), device attestation (App Attest) on step submissions.
- App Store: account deletion in-app, Sign in with Apple, HealthKit purpose strings, no HealthKit data used for advertising, 18+ age gate for staking.
- Undecided: legal review per country for commitment contracts (consumer-law "penalty clause" rules in DE), charity option for forfeits, friend/team pools.

## Brand Commitments

- Name: **Steppie**, for the app and for its lion (renamed from Grinda on 2026-10-01 by the owner).
- Cast: Steppie (lead), Dash (pacer, leagues), Shelly (Shields), Pip (notifications), Bo (the Vault). See `brand/mascot/MASCOT.md`.
- Voice: warm, direct, and on your side, like a coach who believes in you, not a casino host. Never "bet", "wager" or "odds". Never shames. Celebrates effort.

## Evidence on Hand

- Research: StepBet peer-reviewed study (72,974 participants): +31.2% daily steps (7,774 to 10,197), 73% success rate, larger deposits increase completion odds. Source: PMC9982638.
- No users, testimonials, or outcome data exist yet. Public statistics must come from the real `public_stats` view. Never fabricate numbers, testimonials, or weight-loss claims.

## Product Principles

1. **Grow the stakes, not the misses.** Optimise for first-stake uptake, stakes per person and stake size. Never optimise for the miss rate: no silence after a deposit, no hidden terms, no chance element near money.
2. **Trust is the product.** Show exactly where every cent is, at every moment. No surprises, no fine print, instant release.
3. **Free is genuinely useful.** The free tier must help people walk more on its own; stakes are the upgrade for people who want to be held to it.
4. **Honest hooks, loud before the deposit.** Before a stake, persuade hard with true reasons (loss framing, endowed progress, fresh starts, the user's own shadow week, real deadlines), in opt-in notifications. After a stake, go quiet except one pace nudge. Variable rewards are cosmetic only. No fake urgency, no fake scarcity, no fake numbers.
5. **Body first.** Goals, copy and nudges start from the user's health goal and real baseline.

## Accessibility & Inclusion

Dynamic Type across all text, VoiceOver labels on rings and charts, Reduce Motion alternatives for every animation, color never the only signal (progress also stated in numbers). Walking goals must allow lower targets (from 3,000 steps) for people starting from low baselines.
