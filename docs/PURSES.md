# Purses: Steppa's game, Steppie's world

Source: the Steppa teardown (owner's Desktop, 2026-10-25). Steppa grew to 205k players in five months on one loop: put money in, hit a daily step goal every day, and the finishers split the pot. This file maps every Steppa mechanic to its Steppie version, and lists the places we beat it, which are the things its one-star reviews complain about.

The name Steppie is a working name and may change before launch.

Mechanics, rules and game structures are not protected by copyright. Names, art, copy and UI are. Everything here uses our own names, our own cast and our own track-and-bib look. Nothing is copied from Steppa's screens, text or brand.

## Two ways to play

| | Purse races (new, the main product) | Solo races (what Steppie had) |
|---|---|---|
| Steppa name | Challenges | Me vs Me |
| You put in | An entry, $5 to $250, plus a small fee | A stake, $5 to $500 |
| Finish | Your entry back plus your share of the missed entries | Every cent back |
| Miss | Your entry stays in the purse for the finishers | Steppie keeps the stake |
| Steppie earns | Fee on every entry, win or lose | Missed stakes |
| The hook | "Get paid to walk" | "Back yourself, keep your money" |

The purse is the hook, and solo races are for people who want discipline without a prize. Both use the same bib, track, Shields and settlement rules.

## Purse races

- **Split:** 100% of the purse goes to finishers, split evenly. Leftover cents go to the finisher with the most steps, never to us. We earn from the fee alone.
- **Fee:** $0.50 + 4% of the entry, shown on top of the entry before you pin. Pro members pay no fee. Host purses add 5% for the host.
- **Payout math before you join:** the join screen shows your payout if 93%, 85% or 75% of the field finishes. Those are the finish rates real step purses see. The projection never changes after you join; only the real result does.
- **Live count:** every purse shows how many are still in, on pace and behind, and the purse total, updated live. When late syncs move someone back in, the purse page says so in a line, so a final winner count never looks invented.
- **Kinds:**
  - House purses, run by Steppie with our own names (Lion's Share, Dawn Patrol, Night Shift, One and Done, The Gauntlet, Golden Mane, Fresh Paws, Winter Mane, Walktober Finale).
  - Window purses: steps only count inside a time window, like 3,000 steps between 6 and 9 am.
  - Host purses: any member can host a public purse with a code and earns 5% of each entry, paid on top. Creating one costs $25, or is free once a month with Pro.
  - Crew purses: private, invite code only, for friends.
- **Rules in one line**, on the bib: "10,000 steps every day for 7 days. Miss a day and you're out." No "5 of 7" tricks.

## Where we beat Steppa

Each point is a top complaint in Steppa's App Store reviews or on Reddit.

1. **Sync.** A day closes at midnight in your time zone, but nobody is marked out until 24 hours later. Late watch syncs still count, and the screen says so.
2. **Sync disputes.** If a day is marked missed, a button lets you send a Health screenshot. A person reviews it before the purse settles.
3. **Deadline clock.** Today shows the exact time your day closes, in your time zone. Pip sends one push at 10 pm if you're short: "You need 1,240 more steps."
4. **Honest numbers.** Payout math up front, live still-in counts, and a line explaining any late change.
5. **Sick days.** Shields cover a missed day in purse races too. Every account starts with one, and you can equip up to two per race.
6. **Pro trial.** We send a reminder two days before a free trial turns into a paid plan.
7. **Human support** for anything about money. In-app contact goes to a person.
8. **Respect.** We never mock users in public, cheaters included. The bench count in Crew shows how many accounts were removed for fake steps, with no names.

## Growth, copied from what worked

- **$5 + $5 referral:** the new member gets $5 of entry credit, and the inviter gets $5 cash after the new member's first paid entry. Codes are short and easy to post.
- **Paid to Post:** members earn $1 per 1,000 views on TikTok, Instagram or YouTube posts about Steppie, up to $600 a video. They submit a link in the app.
- **Big visible purses:** the purse total is the biggest number on every purse card.
- **Rating prompt** right after a win, never after a miss.

## How it's built

**App (SwiftUI).** Races has two boards, Purses and Solo. A purse opens to its banknote, payout math, live board and rules; joining goes through `JoinPurseView`. Today shows the live strip under your bib. The Crew tab holds the league, invites, Paid to Post, payouts and the bench. Wallet shows the Vault (ready to cash out) and entry credit.

**Database (`supabase/migrations/20261025000100_purses.sql`).**
- `purses`: kind (house, host, crew), entry, goal, days, start date, optional step window, code, cap, `listed`, `settled_at`.
- `races` gains `purse_id`, fee, host fee, amount paid from balance, payout, finishers. One entry per member per purse.
- `profiles` gains `vault_cents`, `credit_cents`, invite code, invited by, `is_pro`, free host purse month. Every balance change goes through `adjust_balance()`.
- Views: `purse_board` (cards and live counts), `purse_runners()` (the live board), `payout_feed` and `bench_total` (public), `purse_by_code()` (crew codes).
- `split_purse()` pays 100% of the purse to finishers, cent for cent, into their Vaults, and pays the host cut. If nobody finishes, every entry goes back to its owner's Vault.
- `open_house_purses()` runs every Sunday from pg_cron and opens the week's 7 house purses in USD and EUR.
- Tables for cash-outs, disputes (with a private storage bucket for screenshots), Paid to Post submissions and referrals.

**Edge functions.** `join-purse` (entry credit first, then the Vault, then the card), `host-purse` (crew purses are free; public ones cost $25 unless it's a Pro member's free one this month), `cash-out`, `redeem-invite`, `submit-dispute`, `submit-post`. `stripe-webhook` records entry and fee lines and pays referrals; `settle` marks disputed days under review and calls `split_purse` when a purse is due. Shared fee maths and tests live in `_shared/common.ts`.

## Still to do before money moves

- **Server-side Pro.** The server reads `is_pro` from the database and never trusts the app, but nothing sets that flag yet. It needs App Store Server Notifications. Until then, Pro members are charged the fee on real entries.
- **Cash-out payouts.** A cash-out is recorded as "requested". A payouts run (Stripe Connect or PayPal Payouts) or a person still has to send the money.
- **Host fee payment.** The host fee reuses the stake payment reply shape with a placeholder race id. It works, but deserves its own type.
- **Legal.** 18+ checks and location blocks are in the plan, not yet in the code.

## Money in and out

- Entries are paid by card through Stripe, from your Vault balance first. Apple in-app purchase is only used for Pro and Shields.
- Winnings land in the Vault. Cash out from $25, up to $500 a day, to a bank account or PayPal. US first, then UK, EU and Canada.
- 18+ only for paid play. Location checks block paid purses where the law requires it.

## Pro

Steppie Pro gives you 5 races at once (free accounts get 1), no service fee, $10 of entry credit every month, one free host purse a month, the gold mane badge and the Stride S icon.

## Open questions

- Which US states and EU countries block paid step contests? Ask a lawyer before money moves.
- Stripe's terms for skill contests: confirm the merchant category with Stripe before launch.
