# PressBench iOS monetization

## Customer model

- Free: five successfully completed and saved press runs; PDF/XLSX reports require Pro.
- PressBench Pro: US$6.99 per month in the US storefront, with Apple-managed equivalent pricing in other storefronts and unlimited press runs and PDF/XLSX reports while subscribed.
- Setups, machines, search, existing records, corrections, and deletion are not artificially capped.
- A failed, canceled, or unsaved run does not consume a free press. Deleting data does not restore free presses.
- The former `pressbench_unlimited_lifetime_ios` entitlement remains recognized for any existing buyer.

## App Store Connect product

Create this in a `PressBench Pro` subscription group before testing purchases:

- Product ID: `pressbench_unlimited_monthly_ios`
- Type: auto-renewable subscription
- Duration: one month
- US base price: US$6.99
- Other storefronts: use App Store Connect's Apple-managed equivalent prices; do not hard-code or manually convert currencies in the app.
- Suggested display name: `PressBench Pro Monthly`
- Suggested description: `Unlimited runs and PDF/XLSX reports.`

Add localized product metadata, a subscription review screenshot, the privacy-policy URL, and the terms-of-use URL. The code rejects a StoreKit product that is not an auto-renewable one-month subscription.

For the first subscription review, add all three items to the same App Store Connect draft submission before submitting it: the iOS app version, the `PressBench Pro` subscription group, and `pressbench_unlimited_monthly_ios`. A product that only says `Ready for Review` but is not in that draft is not review-accessible.

## App Review access path

There is no reviewer password, hidden unlock, or production entitlement bypass. App Review reaches the real StoreKit purchase sheet through either supported route:

1. Open **More → Settings → Unlock PressBench Pro**.
2. Or open **More → Production Report**, choose **PDF** or **XLSX**, and continue from the Pro paywall.
3. Use **Restore Purchase** on the paywall to verify an existing App Store entitlement.

The paywall must display StoreKit's localized `displayPrice` for the customer's current storefront, keep purchase unavailable until the exact monthly product loads, provide a visible retry state when loading fails, and serialize purchase, restore, and retry so only one StoreKit operation can run at a time. The US$6.99 amount is configuration metadata and must never be used as customer-facing fallback copy.

## Review explanation

Use this accurate wording in App Review Notes:

> No login or demo account is required. To review PressBench Pro, open More → Settings → Unlock PressBench Pro, or open More → Production Report and choose PDF/XLSX. The app then presents Apple’s StoreKit purchase sheet for `pressbench_unlimited_monthly_ios`; Restore Purchase is on the same screen. PressBench Pro provides continuing access to unlimited press-run logging and PDF/XLSX production reporting while subscribed. Free users may complete five press runs, and existing records remain readable after the subscription ends. Backups are optional user-initiated exports and imports through Apple’s Files picker; PressBench has no cloud-backup account.

This follows [App Review Guideline 3.1.2](https://developer.apple.com/app-store/review/guidelines/#subscriptions): the subscription lasts at least seven days, supplies ongoing value, uses in-app purchase for digital access, clearly explains the benefits and renewal, works across the user’s devices through StoreKit entitlement, and preserves any former lifetime purchase.

## Advertising and reports

The iOS release contains no advertising, attribution, consent-management, analytics, or tracking SDK. It displays no ads in either tier and does not request App Tracking Transparency permission. Free users cannot generate PDF or XLSX reports; both report formats require a verified PressBench Pro entitlement. The release-integrity gate rejects Google ad packages, advertising identifiers, SKAdNetwork entries, banner code, and ad-only localization.
