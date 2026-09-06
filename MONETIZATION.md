# PressBench iOS monetization

## Customer model

- Free: three successfully completed and saved press runs.
- PressBench Unlimited: one non-consumable purchase permanently unlocks unlimited press runs and locally generated PDF/XLSX reports.
- United States reference price: US$39.99 one time. App Store Connect supplies the storefront-localized geopriced amount; the app never hard-codes customer-facing currency or converts prices itself.
- Setups, machines, search, existing records, corrections, deletion, backup/restore, and reading existing data are never artificially locked.
- A failed, canceled, or unsaved run does not consume a free press. Deleting data or restoring an older backup does not restore free presses.
- No account, advertising, analytics, tracking, recurring charge, renewal, billing-retry lockout, or subscription-management requirement.

## App Store Connect product

Create or retain this In-App Purchase before testing purchases:

- Product ID: `pressbench_unlimited_lifetime_ios`
- Type: non-consumable
- Reference name: `PressBench Unlimited Lifetime`
- Suggested display name: `Unlock PressBench Forever`
- Suggested description: `Unlimited press runs and PDF/XLSX reports. One-time purchase.`
- United States reference price: US$39.99
- Other storefronts: use the approved geopriced schedule in App Store Connect and always show StoreKit's localized `displayPrice` in the app.

The legacy product `pressbench_unlimited_monthly_ios` remains recognized only so an already-entitled historical subscriber is not abruptly denied access during migration. It is not offered to new customers. The production purchase sheet loads only `pressbench_unlimited_lifetime_ios` and requires it to be a StoreKit non-consumable.

## App Review access path

There is no reviewer password, hidden unlock, or production entitlement bypass. App Review reaches the real StoreKit purchase sheet through either supported route:

1. Open **More → Settings → Unlock PressBench**.
2. Or open **More → Production Report**, choose **PDF** or **XLSX**, and continue from the unlock screen.
3. Use **Restore Purchase** on the same screen to verify an existing non-consumable entitlement.

The unlock screen must display StoreKit's localized price for the current storefront, keep purchase unavailable until the exact lifetime product loads, provide a visible retry state when loading fails, and serialize purchase, restore, and retry so only one StoreKit operation can run at a time.

## Review explanation

Use this wording in App Review Notes:

> No login or demo account is required. PressBench includes three successfully saved press runs so App Review can exercise the complete production workflow. To review the permanent unlock, open More → Settings → Unlock PressBench, or open More → Production Report and choose PDF/XLSX. The app presents Apple's StoreKit purchase sheet for the non-consumable `pressbench_unlimited_lifetime_ios`; Restore Purchase is on the same screen. The one-time purchase permanently unlocks unlimited runs and locally generated PDF/XLSX reports. Existing local records remain readable regardless of purchase status. Backups are optional user-initiated exports and imports through Apple's Files picker; PressBench has no cloud-backup account, advertising, analytics, or tracking.

## Advertising and reports

The iOS release contains no advertising, attribution, consent-management, analytics, or tracking SDK. It displays no ads and does not request App Tracking Transparency permission. Free users can complete three successfully saved runs; the one-time unlock removes the run limit and enables PDF/XLSX production reports permanently for the purchaser's App Store account, subject only to normal App Store revocation/refund rules.
