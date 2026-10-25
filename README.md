<p align="center"><img src="brand/mascot/renders/x-header.png" alt="Steppie: Back yourself. Keep your money."></p>

<h3 align="center">Get paid to walk.</h3>

Steppie is an iPhone app that pays you to walk. Join a purse, hit your step goal every day, and everyone who finishes splits the whole purse. Miss a day and your entry stays in for the finishers. Prefer to race yourself? Solo races still work the old way: put down a stake, finish, and every cent comes back.

The name Steppie is a working name. How purses work, and how they map to Steppa's game, is in [`docs/PURSES.md`](docs/PURSES.md).

**Steppie** is a lion in running shoes who runs your laps with you. The crew around him each own one part of the game.

<p align="center"><img src="brand/mascot/renders/cast-character-sheet.png" alt="Steppie and the crew"></p>

| | Who | Job in the app |
|---|---|---|
| 🦁 | **Steppie** | Runs your laps on the Today track, coaches you, grows his mane with your goal days, wears the trainers you earn. |
| 🐆 | **Dash** | The pacer: a ghost on your track showing where a steady walker would be by now. Hosts the weekly league in Crew. |
| 🐢 | **Shelly** | Keeper of Shields. Each Shield covers one missed day; unused ones come back. |
| 🐦 | **Pip** | Brings the news: purse invites, the 10 pm last call, your shadow week, and Paid to Post. |
| 🐻 | **Bo** | Guards the Vault: winnings, entry credit, cash-outs, holds and refunds. |

## The app

<p align="center">
  <img src="screenshots/light/onboarding-welcome.png" width="200">
  <img src="screenshots/light/today.png" width="200">
  <img src="screenshots/light/purses.png" width="200">
  <img src="screenshots/light/purse.png" width="200">
</p>
<p align="center">
  <img src="screenshots/light/purse-live.png" width="200">
  <img src="screenshots/light/purse-join.png" width="200">
  <img src="screenshots/light/purse-entered.png" width="200">
  <img src="screenshots/light/finish-purse.png" width="200">
</p>
<p align="center">
  <img src="screenshots/light/crew.png" width="200">
  <img src="screenshots/light/invite.png" width="200">
  <img src="screenshots/light/paid-to-post.png" width="200">
  <img src="screenshots/light/wallet.png" width="200">
</p>
<p align="center">
  <img src="screenshots/light/cash-out.png" width="200">
  <img src="screenshots/light/host-purse.png" width="200">
  <img src="screenshots/light/dispute.png" width="200">
  <img src="screenshots/light/shoebox-open.png" width="200">
</p>

<p align="center"><img src="screenshots/pinning.gif" width="260" alt="Hold to pin your bib"><br><em>The signature interaction: hold to pin your bib.</em></p>

These are real iOS Simulator captures (iPhone 6.9") taken by CI in demo mode. The data is synthetic. Dark mode versions are in [`screenshots/dark`](screenshots/dark).

### App Store screenshots

<p align="center">
  <img src="ios/fastlane/screenshots/en-US/01_today.png" width="130">
  <img src="ios/fastlane/screenshots/en-US/02_contract.png" width="130">
  <img src="ios/fastlane/screenshots/en-US/03_entered.png" width="130">
  <img src="ios/fastlane/screenshots/en-US/04_finish.png" width="130">
  <img src="ios/fastlane/screenshots/en-US/05_comeback.png" width="130">
  <img src="ios/fastlane/screenshots/en-US/06_league.png" width="130">
</p>

## How it makes money

Steppie earns a small fee on every purse entry, win or lose, plus Pro, hosting and Shields. 100% of every purse goes to the people who finish, so Steppie never earns more when people miss. Solo stakes that are missed still go to Steppie. The playbook is in [`docs/STRATEGY.md`](docs/STRATEGY.md) and the purse rules in [`docs/PURSES.md`](docs/PURSES.md).

| Lever | What it is |
|---|---|
| **Purse fee** | $0.50 + 4% of the entry, shown on top before you pin. Pro pays none. |
| **Steppie Pro** | No fee, $10 of entry credit a month, 5 races at once, a free host purse each month, the gold mane badge and the Stride S icon. Trial reminder 2 days before it renews. |
| **Hosting** | A public purse costs $25 to host (free once a month with Pro). The host earns 5% on top of each entry. Crew purses are free. |
| **$5 + $5 invites** | The friend gets $5 of entry credit; you get $5 cash after their first paid entry. |
| **Paid to Post** | $1 per 1,000 views on posts about Steppie, up to $600 a post. Cheaper than ads. |
| **Shields** | Each covers one missed day, in purses too. Up to 2 per race; unused ones come back. |
| **Starter Kit** | Onboarding ends with the first pin already in your bib and a free Shield. |
| **Weekly leagues** | Grit from race days. Top 7 move up every Sunday. |
| **Shoe Boxes** | Every finish: a random pair of trainers for Steppie. Cosmetic only, never sold. |
| **Solo stakes** | Rookie €5 to Legend €100. Finish and every cent comes back. Miss and the stake is kept. |

Whether you finish depends only on your steps, and the split is plain maths: the purse divided by the finishers. Winnings go to the Vault; cash out from $25, up to $500 a day. Paid play is 18+ and blocked where local law requires it.

## Brand

<p align="center"><img src="brand/logo/lockup-on-cobalt.png" width="520" alt="Steppie lockup"></p>

The **Stride S**: an S cut in two by a forward stride, every cut on the same 58° angle. One colour, works at 16 px, generated from geometry (`brand/tools/stride.py`). Full guide: [`brand/BRAND.md`](brand/BRAND.md).

## Repo map

- `ios/`: SwiftUI app (iOS 17+), widget, and fastlane. The project is generated by XcodeGen (`cd ios && xcodegen generate`).
- `supabase/`: Postgres schema with RLS, plus Edge Functions: `create-stake`, `join-purse`, `host-purse`, `cash-out`, `redeem-invite`, `submit-dispute`, `submit-post`, `stripe-webhook`, `submit-steps`, `settle` (cron), `grant-shields`, `public-stats`, `delete-account`. Leagues and purse splits are SQL (`league_board()`, `roll_leagues()`, `split_purse()`, `open_house_purses()`).
- `brand/`: the Stride S, wordmark, icons, Steppie fonts, and the cast (`brand/mascot/`: geometry source, renders, bible).
- `marketing/`: weekly stats post for X and Discord (live numbers only) and the App Store frame generator.
- `site/`: landing page, privacy, support and race rules.
- `docs/`: strategy and money playbook, research, the prompt audit, and the shipping guide.

## Run it

- **On a Mac:** `brew install xcodegen && cd ios && xcodegen generate && open Steppie.xcodeproj`. Add the launch arguments `-demo YES` to see it with sample data, and `-screen <name>` to jump to a scene (see `DemoRouter` in `SteppieApp.swift`).
- **CI:** every push to `ios/` builds on a macOS runner and captures screenshots.
- **Ship:** follow [`docs/SHIPPING.md`](docs/SHIPPING.md) (Apple, Stripe, Supabase, App Store Server API and GitHub secrets), then run the **Release** workflow.
