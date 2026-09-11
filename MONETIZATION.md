# PressBench iOS monetization

## Customer model

- Free: two successfully completed and saved press runs.
- PressBench Pro: unlimited press runs and locally generated PDF/XLSX reports.
- Monthly plan: US$12.99/month.
- Annual plan: US$119.99/year.
- App Store Connect supplies the storefront-localized geopriced amount. The app displays StoreKit's `displayPrice`; it does not hard-code customer-facing currency or perform exchange-rate conversion.
- Setups, machines, search, existing records, corrections, deletion, backup/restore, and reading existing data remain available without Pro.
- A failed, cancelled, or unsaved run does not consume a free run. Deleting data or restoring an older backup does not restore free runs.
- There is no PressBench account, advertising, analytics, or tracking.

Both plans auto-renew until cancelled. Apple handles billing, cancellation, refunds, grace periods, and subscription management.

## App Store Connect products

Create one auto-renewable subscription group containing both products:

| Product ID | Duration | US base price | Suggested display name |
|---|---:|---:|---|
| `pressbench_unlimited_monthly_ios` | 1 month | US$12.99 | PressBench Pro Monthly |
| `pressbench_unlimited_annual_ios` | 1 year | US$119.99 | PressBench Pro Annual |

Suggested description: `Unlimited press runs and PDF/XLSX production reports.`

For each product, configure the approved geopriced storefront schedule, localized metadata, review screenshot, privacy policy, and terms. The production purchase sheet loads both exact product IDs, requires StoreKit's auto-renewable product type, and shows the price returned by StoreKit.

## App Review access path

There is no reviewer password, hidden unlock, or production entitlement bypass. App Review can reach the real StoreKit purchase sheet through either route:

1. Open **More → Settings → Unlock PressBench Pro**.
2. Or open **More → Production Report**, choose **PDF** or **XLSX**, and continue from the subscription screen.
3. Use **Restore purchase** on the same screen to verify an existing subscription.

The subscription screen displays StoreKit's localized price for each available plan, keeps unavailable products disabled, provides a visible retry state if no plan loads, and serializes purchase, restore, and retry operations.

## Review explanation

Use this wording in App Review Notes:

> No login or demo account is required. PressBench allows two successfully saved runs at no charge so App Review can exercise the complete production workflow. To review PressBench Pro, open More → Settings → Unlock PressBench Pro, or open More → Production Report and choose PDF/XLSX. Pro provides ongoing access to unlimited production runs and PDF/XLSX report generation during the subscription period. The app offers the auto-renewable `pressbench_unlimited_monthly_ios` and `pressbench_unlimited_annual_ios` subscriptions; Restore purchase, Terms of Use, and Privacy Policy are on the same purchase screen. Existing local records remain readable regardless of subscription status. Backups are optional, user-initiated exports and imports through Apple's Files picker. PressBench has no account, cloud service, advertising, analytics, or tracking.

## Renewal and entitlement behavior

Verified active monthly and annual transactions grant Pro until their StoreKit expiration date. Revoked, refunded, upgraded, or expired transactions do not grant access. Transaction updates are observed continuously, and entitlement refresh still runs if product metadata cannot be loaded.
