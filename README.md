# PressBench iOS

Production iPhone release repository for PressBench.

The release target is locked to:

- Bundle ID: `com.goodusestudios.pressbench`
- Apple Team: `49SQ3XQ68Q`
- Version: `1.0`
- Scheme: `PressBench`

## Source contract

The canonical release source is the unpacked production tree at repository root (`project.yml`, `PressBench/`, `PressBenchTests/`, `scripts/`). For recovery, both GitHub Actions workflows can also accept either of the legacy reviewed v0.21.4 package forms:

1. the split Base64 package at `.source/PressBench-iOS-Approved-UI-v0.21.4.zip.b64.part-*`, or
2. the package at repository root named exactly:

   `PressBench-TestFlight-Source-v0.21.4.zip`

The workflows always prefer the current unpacked source. Package fallbacks are used only when that source is absent.

## Approved interface

The reviewed production source uses the Operator Focus SwiftUI interface on the GoodUse Studios Ocean Pearl base: a fixed light presentation, three stable destinations (Today, Run, Library), native iPad split navigation, RTL/Dynamic Type reflow, and Reduce Motion-aware interaction. Today exposes the next action, Run guides first-piece, timer, counting, and QC gates, and Library holds setups, history, machines, and one-tap PDF/XLSX reports. Settings remains available from the gear on every destination and preserves subscription, backup/recovery, accessibility, legal, and data-safety controls. The deterministic engine enforces timer, QC, capacity, recovery, and commit integrity. The durable catalog contains 368 keys across 32 runtime locale codes with 31 selectable languages plus Traditional Chinese locale support.

## CI

- **Validate PressBench iOS** runs on pushes/PRs and can also be run manually. It checks release integrity, the 31-language UI layer, all 98 localized operator presets, deterministic engine smoke tests, Xcode project generation, a Release simulator build, unit/UI tests, and captures first-use UI audit screenshots.
- **Run TestFlight Build** builds, validates, signs, and uploads the production app when explicitly authorized by the release workflow.

The iOS app contains no advertising or tracking SDK. Free users may complete ten successfully saved press runs, with the remaining-run counter kept visible. PressBench Pro is offered as the auto-renewable `pressbench_unlimited_monthly_ios` subscription at US$9.99/month. App Store Connect supplies the approved geopriced schedule in other storefronts, and customer-facing currency always comes from StoreKit. See `MONETIZATION.md` for product setup, App Review wording, and release controls.

See `TESTFLIGHT_SETUP.md` for the Apple credential and release setup.
