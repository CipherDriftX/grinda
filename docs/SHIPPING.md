# Shipping Steppie to the App Store

Everything in the repo is ready to build, sign, and upload from GitHub Actions. What's left needs your accounts: Apple, Whop, and Supabase. Budget about 2 hours the first time, plus Whop's review of the business.

## 1. Apple Developer portal (developer.apple.com)

1. **Identifiers › App IDs › +**, bundle ID `com.cipherdriftx.steppie`. Enable **HealthKit** (with background delivery), **Sign in with Apple** and **App Groups**. No Apple Pay merchant and no App Attest: card payments run on Whop's hosted checkout.
2. Second App ID for the widget: `com.cipherdriftx.steppie.widget` with **App Groups**.
3. **App Groups › +** `group.com.cipherdriftx.steppie`. Assign it to both App IDs.
4. Note your **Team ID** (Membership page).

To use a different bundle ID, change `bundleIdPrefix`, the `PRODUCT_BUNDLE_IDENTIFIER`s and the app group in `ios/project.yml` and `ios/fastlane/Appfile`, and `APPSTORE_BUNDLE_ID` in `supabase/.env`.

## 2. App Store Connect (appstoreconnect.apple.com)

1. **Apps › +**: iOS, name "Steppie: Step Challenges", primary language English (U.S.), bundle ID from above, SKU `steppie-ios`.
2. **Subscriptions**: create group `steppie.pro` (copy the **group ID** Apple generates into `StoreService.groupID`). Add:
   - `steppie.pro.monthly`: 1 month, suggested €7.99 / $7.99
   - `steppie.pro.yearly`: 1 year, suggested €49.99 / $49.99, 1-week free trial
3. **In-App Purchases › Consumable**: `steppie.shield.1` (1 Shield, €1.99 / $1.99) and `steppie.shield.3` (3 Shields, €4.99 / $4.99). Display names "1 Shield" and "3 Shields". Review note: a Shield is a digital item that covers one missed day in a race; it doesn't change the entry or the payout rules.
4. **Users and Access › Integrations › In-App Purchase › +**: generate a key for the App Store Server API. Put the Key ID, Issuer ID and the `.p8` contents into `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_PRIVATE_KEY` in `supabase/.env`. `verify-pro`, `grant-shields` and `app-store-notifications` use it to ask Apple; the app's word is never enough.
5. **App Information › App Store Server Notifications**: Version 2, production and sandbox URL `https://<ref>.supabase.co/functions/v1/app-store-notifications`. Renewals, refunds and expiries then reach the server even when the app is closed.
6. **App Privacy**: Health & Fitness (steps, weight), Purchases, Name (Sign in with Apple), User ID, and Other Data (date of birth and country or state, used to check who may join paid races). All App Functionality, linked to the user, **no tracking**. Payments are taken by Whop, so card numbers never reach Steppie.
7. **Users and Access › Integrations › App Store Connect API › +**: role **App Manager**. Download the `.p8` once, and note the Key ID and Issuer ID.
8. **Age rating**: answer truthfully. Purses are skill contests with real-money prizes (finishers split the entries), so "Contests" is not "None". Paid races are 18+ (higher where `AGE_RULES` says) and blocked in `BLOCKED_REGIONS`; say so in the review notes. Shoe Boxes are cosmetic, earned by finishing and never sold, so they aren't paid random items.

## 3. Supabase (supabase.com)

```bash
brew install supabase/tap/supabase         # or npm i -g supabase
supabase login
supabase link --project-ref <your-ref>
supabase db push                            # runs supabase/migrations
cp supabase/.env.example supabase/.env      # fill in values (section 4 for Whop)
supabase secrets set --env-file supabase/.env

# Called by the app with the user's login:
supabase functions deploy create-stake join-purse host-purse cancel-checkout cash-out \
  submit-steps submit-dispute submit-post redeem-invite save-profile verify-pro grant-shields delete-account
# Called by Whop, Apple, pg_cron, the website or the review desk (they check their own secret):
supabase functions deploy whop-webhook app-store-notifications settle public-stats admin-review --no-verify-jwt
```

Then in the SQL editor, store the two values the settle cron job needs (it runs every 15 minutes):

```sql
select vault.create_secret('https://<ref>.supabase.co', 'project_url');
select vault.create_secret('<same CRON_SECRET as in .env>', 'cron_secret');
```

**Auth › Providers › Apple**: enable it, and add `com.cipherdriftx.steppie` to the authorized client IDs (native sign-in only needs the bundle ID). A profile row is made for every new login by a database trigger.

Run the tests before every deploy:

```bash
cd supabase && deno test -A tests/                                   # money SQL on an in-memory Postgres
cd functions && deno test --allow-env --allow-read _shared/          # Whop, App Store and eligibility helpers
```

## 4. Whop (whop.com)

1. Make a company and finish the business verification. Tell Whop plainly what Steppie is: adults pay an entry into a walking contest, finishers split the entries, Steppie keeps a stated fee. Whop decides whether it accepts paid contests; nothing here works until it says yes. **Unknown until asked**: whether Whop accepts this model in each country you launch in.
2. Start in the **sandbox** (`WHOP_ENVIRONMENT=sandbox`, sandbox API key and company). Switch every Whop value together when you go live.
3. **Developer › API keys**: a company key with payments, refunds, transfers and webhooks. `WHOP_API_KEY=apik_…`, `WHOP_ACCOUNT_ID=biz_…`.
4. **Developer › Webhooks › +**: URL `https://<ref>.supabase.co/functions/v1/whop-webhook`, events `payment.succeeded`, `dispute.created`, `transfer.completed`, `transfer.failed`. Copy the secret into `WHOP_WEBHOOK_SECRET=ws_…`. Entries go live only when this webhook arrives.
5. `WHOP_REDIRECT_URL=https://steppie.app/paid.html`. That page (`site/paid.html`) hands the buyer back to the app. The site must be live at that address (section 7).
6. Balance: cash-outs are Whop transfers from your company balance, or claim links. Keep enough balance in each currency you pay out in. **Verify in the sandbox before launch**: transfer and refund fees, a EUR transfer from a USD balance, and what a claim link pays in EUR.

## 5. Who may pay

`BLOCKED_REGIONS` and `AGE_RULES` in `supabase/.env` decide where paid races are open and from what age. A lawyer fills them. In production an unset `BLOCKED_REGIONS` stops every paid race with "Paid races are paused", so a missing setting can never open everything. The app asks for date of birth and country (and state in the US, Canada and Australia) before the first money move; both are kept once saved. Cash-outs are never blocked.

## 6. The review desk

Flagged days, Health screenshots, frozen payouts and failed cash-outs wait for a person. There's no admin app yet; use `admin-review` with `ADMIN_SECRET` (24+ characters, never in the app):

```bash
curl -X POST "https://<ref>.supabase.co/functions/v1/admin-review" -H "x-admin-secret: $ADMIN_SECRET" \
  -d '{"action":"queue"}'
curl -X POST "https://<ref>.supabase.co/functions/v1/admin-review" -H "x-admin-secret: $ADMIN_SECRET" \
  -d '{"action":"resolve_day","race_id":"<uuid>","day":"2026-11-12","verdict":"accept","note":"Health screenshot matches"}'
curl -X POST "https://<ref>.supabase.co/functions/v1/admin-review" -H "x-admin-secret: $ADMIN_SECRET" \
  -d '{"action":"unfreeze","user_id":"<uuid>","note":"dispute answered"}'
```

The app tells people a screenshot is usually checked within a few hours, so check the queue every few hours during the day.

## 7. GitHub secrets (repo › Settings › Secrets and variables › Actions)

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | Team ID |
| `ASC_KEY_ID` | API Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8` |
| `STEPPIE_SUPABASE_URL` | `https://<ref>.supabase.co` |
| `STEPPIE_SUPABASE_ANON_KEY` | Supabase anon key |

The app holds no payment keys. The website (`site/`) deploys to GitHub Pages on every push that touches it; point `steppie.app` at it.

## 8. Ship it

In **Actions › Release to TestFlight / App Store › Run workflow**, run these lanes in order:

1. `beta`: builds, signs automatically through the API key, and uploads to TestFlight. Test on your phone against the Whop **sandbox** first: a solo race, a purse paid partly from the Vault, closing the checkout without paying, a cash-out, Pro bought with a sandbox Apple account. Then switch Whop to production.
2. `metadata`: uploads the listing text (EN + DE) and the screenshots in `screenshots/light/`.
3. `release`: submits the latest build for review.

### App Review notes (paste into "Notes" in App Store Connect)

> Steppie is a walking app. Adults (18+, higher where local law requires) can put money on their own walking goal (a solo race: the money comes back when they finish) or join a purse: everyone pays the same entry, and the people who walk the daily goal every day split all the entries. There is no element of chance; the result depends only on each person's own steps from HealthKit (manually entered samples are excluded). Paid races are geo-restricted: the app asks for country and state before any payment, and the server refuses regions where they aren't allowed. Entries are real-money payments processed by Whop on its hosted checkout, not digital content, so they don't use In-App Purchase. Pro and Shields are digital and use StoreKit. Demo: install, finish onboarding, and open Races › Practice Lap to try the flow without money.

## 9. Legal checklist before going live

- [ ] A lawyer has checked purses (paid skill contests) in every country and US state you open, and filled `BLOCKED_REGIONS` and `AGE_RULES`.
- [ ] Whop has approved the business model in writing.
- [ ] Terms of service and Race Rules reviewed by a lawyer in DE (BGB §305 ff. on standard terms) and in the US states you launch in.
- [ ] Privacy policy published at the URL in the store listing (GDPR Art. 9: health data needs explicit consent, which the HealthKit prompt plus onboarding copy provide; document it).
- [ ] Imprint (Impressum) for Germany.
- [ ] VAT/sales tax on fees and kept stakes: ask your accountant.
- [ ] steppie.app live with the support, privacy, rules, `paid.html` and `p.html` pages.
