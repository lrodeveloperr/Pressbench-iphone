# PressBench iOS monetization

## Customer model

- Free: a fixed 320 × 50 Google banner and five successfully completed press runs.
- PressBench Pro: US$9.99 per month in the US storefront, with unlimited presses, no ads, and PDF/XLSX reports while subscribed.
- Setups, machines, search, existing records, corrections, and deletion are not artificially capped.
- A failed, canceled, or unsaved run does not consume a free press. Deleting data does not restore free presses.
- The former `pressbench_unlimited_lifetime_ios` entitlement remains recognized for any existing buyer.

## App Store Connect product

Create this in a `PressBench Pro` subscription group before testing purchases:

- Product ID: `pressbench_unlimited_monthly_ios`
- Type: auto-renewable subscription
- Duration: one month
- US price: US$9.99
- Suggested display name: `PressBench Pro Monthly`
- Suggested description: `Unlimited press-run logging, an ad-free workspace, and PDF/XLSX production reports while subscribed.`

Add localized product metadata, a subscription review screenshot, the privacy-policy URL, and the terms-of-use URL. The code rejects a StoreKit product that is not an auto-renewable one-month subscription.

## Review explanation

Use this accurate wording in App Review Notes:

> PressBench Pro provides continuing access to a recurring production workflow: unlimited press-run logging, an ad-free workspace, and ongoing PDF/XLSX production reporting on the customer’s Apple devices while subscribed. Free users may complete five press runs. Existing records remain readable after the subscription ends. The app does not claim cloud storage or new content as subscription value.

This follows [App Review Guideline 3.1.2](https://developer.apple.com/app-store/review/guidelines/#subscriptions): the subscription lasts at least seven days, supplies ongoing value, uses in-app purchase for digital access, clearly explains the benefits and renewal, works across the user’s devices through StoreKit entitlement, and preserves any former lifetime purchase.

## Ad configuration

The release uses the PressBench production AdMob app and banner IDs, disables ad personalization, and requests General-rated creative. Google UMP 3.1.0 is pinned with Google Mobile Ads 13.9.0. At launch, the app requests current consent information, presents any required form, and checks `canRequestAds` before starting Mobile Ads or sending an ad request. More includes privacy choices and a direct Report an ad action.

Google Privacy & messaging for the final application ID, Google’s current SKAdNetwork guidance, the public privacy policy, and App Store privacy answers must remain consistent with the SDK’s actual data use. The release-integrity gate rejects Google demo IDs so a mixed test/production configuration cannot ship.

References: [Google iOS quick start](https://developers.google.com/admob/ios/quick-start), [banner guide](https://developers.google.com/admob/ios/banner), [privacy/UMP](https://developers.google.com/admob/ios/privacy), and [ad targeting/content rating](https://developers.google.com/admob/ios/targeting).
