# Shipping Steppie to the App Store

Everything in the repo is ready to build, sign, and upload from GitHub Actions. What's left needs your accounts: Apple, Stripe, and Supabase. Budget about 2 hours the first time.

## 1. Apple Developer portal (developer.apple.com)

1. **Identifiers › App IDs › +**, bundle ID `com.cipherdriftx.steppie`. Enable **HealthKit** (with background delivery), **Sign in with Apple**, **App Groups**, **Apple Pay Payment Processing**, and **App Attest**.
2. Second App ID for the widget: `com.cipherdriftx.steppie.widget` with **App Groups**.
3. **App Groups › +** `group.com.cipherdriftx.steppie`. Assign it to both App IDs.
4. **Merchant IDs › +** `merchant.com.cipherdriftx.steppie`. Then in Stripe Dashboard › Settings › Payment methods › Apple Pay, add an iOS certificate. Stripe gives you a CSR; upload it to the merchant ID and give the resulting certificate back to Stripe.
5. Note your **Team ID** (Membership page).

To use a different bundle ID, change `bundleIdPrefix`, the `PRODUCT_BUNDLE_IDENTIFIER`s, the app group, and the merchant ID in `ios/project.yml`, `ios/fastlane/Appfile`, and `PaymentService.merchantID`.

## 2. App Store Connect (appstoreconnect.apple.com)

1. **Apps › +**: iOS, name "Steppie: Step Challenges", primary language English (U.S.), bundle ID from above, SKU `steppie-ios`.
2. **Subscriptions**: create group `steppie.pro` (the reference name must be "steppie.pro"; the app looks it up by group ID, so copy the **group ID** Apple generates into `StoreService.groupID`). Add:
   - `steppie.pro.monthly`: 1 month, suggested €7.99 / $7.99
   - `steppie.pro.yearly`: 1 year, suggested €49.99 / $49.99, 1-week free trial
3. **In-App Purchases › Consumable**: `steppie.shield.1` (1 Shield, €1.99 / $1.99) and `steppie.shield.3` (3 Shields, €4.99 / $4.99). Display names "1 Shield" and "3 Shields". Review note: a Shield is a digital item that covers one missed day in a race; it doesn't change the stake.
4. **Users and Access › Integrations › In-App Purchase › +**: generate a key for the App Store Server API. Put the Key ID, Issuer ID and the `.p8` contents into the Supabase secrets `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_PRIVATE_KEY` (used by `grant-shields`).
5. **App Privacy**: Health & Fitness (steps, weight): App Functionality, linked to the user, not used for tracking. Purchases: App Functionality. Contact info (name via Sign in with Apple): App Functionality. **No tracking.**
6. **Users and Access › Integrations › App Store Connect API › +**: role **App Manager**. Download the `.p8` once, and note the Key ID and Issuer ID.
7. Age rating: 17+ is not required (no gambling: there's no prize and no chance element). Answer "Contests: None" and "Simulated gambling: None". Shoe Boxes are cosmetic, earned by finishing and never sold, so they aren't paid random items. Staking is limited to 18+ inside the app.

## 3. Supabase (supabase.com)

```bash
brew install supabase/tap/supabase         # or npm i -g supabase
supabase login
supabase link --project-ref <your-ref>
supabase db push                            # runs supabase/migrations
cp supabase/.env.example supabase/.env      # fill in values
supabase secrets set --env-file supabase/.env
supabase functions deploy create-stake submit-steps delete-account
supabase functions deploy stripe-webhook settle public-stats --no-verify-jwt
```

Then in the SQL editor, store the two values the settlement cron job needs:

```sql
select vault.create_secret('https://<ref>.supabase.co', 'project_url');
select vault.create_secret('<same CRON_SECRET as in .env>', 'cron_secret');
```

**Auth › Providers › Apple**: enable it, and add `com.cipherdriftx.steppie` to the authorized client IDs (native sign-in only needs the bundle ID).

## 4. Stripe (dashboard.stripe.com)

1. Activate the account, with business type and payouts.
2. **Developers › Webhooks › +**: endpoint `https://<ref>.supabase.co/functions/v1/stripe-webhook`. Events: `payment_intent.amount_capturable_updated`, `payment_intent.succeeded`, `payment_intent.payment_failed`, `payment_intent.canceled`, `charge.refunded`. Copy the signing secret into `STRIPE_WEBHOOK_SECRET`.
3. Statement descriptor: "STEPPIE". Customers see "STEPPIE STAKE" on holds and charges.
4. Radar: keep the defaults on.
5. Tell Stripe support what the business model is: a user-funded commitment contract with no prize pool. Stripe restricts gambling, and this is not gambling, but it's worth stating up front.

## 5. GitHub secrets (repo › Settings › Secrets and variables › Actions)

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | Team ID |
| `ASC_KEY_ID` | API Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8` |
| `STEPPIE_SUPABASE_URL` | `https://<ref>.supabase.co` |
| `STEPPIE_SUPABASE_ANON_KEY` | Supabase anon key |
| `STEPPIE_STRIPE_PUBLISHABLE_KEY` | `pk_live_…` (use `pk_test_…` for TestFlight testing) |

## 6. Ship it

In **Actions › Release to TestFlight / App Store › Run workflow**, run these lanes in order:

1. `beta`: builds, signs automatically through the API key, and uploads to TestFlight. Test on your phone with a real card in Stripe **test mode** first (`pk_test`/`sk_test`), then switch to live keys.
2. `metadata`: uploads the listing text (EN + DE) and the screenshots in `screenshots/light/`.
3. `release`: submits the latest build for review.

### App Review notes (paste into "Notes" in App Store Connect)

> Steppie lets adults stake their own money on a walking goal (a commitment contract, like stickK or Beeminder). There is no prize, no pool, and no element of chance: users only compete against their own goal, and the stake is returned in full when they finish. Stakes are real-money commitments processed by Stripe, not digital content, so they are not sold through In-App Purchase (guideline 3.1.1 applies to the Pro subscription, which uses StoreKit). Short races are authorisations (holds) that are released on success. Steps come from HealthKit; manually entered samples are excluded. Demo: install, complete onboarding, and open Races › Practice Lap to try the flow without money. Test card for staking in the review build: 4242 4242 4242 4242, any future date and CVC.

## 7. Legal checklist before going live

- [ ] Terms of service and Race Rules reviewed by a lawyer in DE (BGB §305 ff. on standard terms, and §309 Nr. 6 on contractual penalties) and in the US states you launch in.
- [ ] Privacy policy published at the URL in the store listing (GDPR Art. 9: health data needs explicit consent, which the HealthKit prompt plus onboarding copy provide; document it).
- [ ] Imprint (Impressum) for Germany.
- [ ] VAT/sales tax on kept stakes: ask your accountant whether forfeits are taxable revenue in your structure.
- [ ] steppie.app (or your domain) live with the support, privacy, and marketing pages.
