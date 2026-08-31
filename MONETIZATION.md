# PressBench iOS monetization

## Customer model

- Free: five successfully completed and saved press runs; PDF/XLSX reports require Pro.
- PressBench Pro: US$9.99 per month in the US storefront, with unlimited press runs and PDF/XLSX reports while subscribed.
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
- Suggested description: `Unlimited runs and PDF/XLSX reports.`

Add localized product metadata, a subscription review screenshot, the privacy-policy URL, and the terms-of-use URL. The code rejects a StoreKit product that is not an auto-renewable one-month subscription.

## Review explanation

Use this accurate wording in App Review Notes:

> PressBench Pro provides continuing access to a recurring production workflow: unlimited press-run logging and ongoing PDF/XLSX production reporting on the customer’s Apple devices while subscribed. Free users may complete five press runs. Existing records remain readable after the subscription ends. The app does not claim cloud storage or new content as subscription value.

This follows [App Review Guideline 3.1.2](https://developer.apple.com/app-store/review/guidelines/#subscriptions): the subscription lasts at least seven days, supplies ongoing value, uses in-app purchase for digital access, clearly explains the benefits and renewal, works across the user’s devices through StoreKit entitlement, and preserves any former lifetime purchase.

## Advertising and reports

The iOS release contains no advertising, attribution, consent-management, analytics, or tracking SDK. It displays no ads in either tier and does not request App Tracking Transparency permission. Free users cannot generate PDF or XLSX reports; both report formats require a verified PressBench Pro entitlement. The release-integrity gate rejects Google ad packages, advertising identifiers, SKAdNetwork entries, banner code, and ad-only localization.
