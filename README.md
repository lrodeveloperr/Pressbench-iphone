# PressBench iPhone

Production iPhone release repository for PressBench.

The release target is locked to:

- Bundle ID: `com.goodusestudios.pressbench`
- Apple Team: `49SQ3XQ68Q`
- Version: `1.0`
- Scheme: `PressBench`

## Source contract

Both GitHub Actions workflows accept any of:

1. the unpacked production source tree at repository root (`project.yml`, `PressBench/`, `PressBenchTests/`, `scripts/`), or
2. the reviewed split Base64 package at `.source/PressBench-iOS-Approved-UI-v0.21.4.zip.b64.part-*`, or
3. the canonical production package at repository root named exactly:

   `PressBench-TestFlight-Source-v0.21.4.zip`

The packaged-source path exists specifically so the binary ZIP can be uploaded once without manually unpacking dozens of files. The workflow extracts it into an isolated runner directory and then requires the full deterministic engine and release gates before compiling.

## Approved interface

The reviewed production source uses the GoodUse Studios Ocean Pearl system: a fixed light presentation, 28-point page headers, 24-point cards, 62-point primary controls, four stable thumb destinations, RTL/Dynamic Type reflow, and Reduce Motion-aware interaction. First launch opens Home and shows only the next required action. Adding a machine first offers catalog or manual entry; catalog entry asks only for brand and model, derives the remaining profile, and returns Home after save. Setup creation then begins with preset-base, saved-base, or manual entry. The workflow includes strict runnable-setup validation, direct run configuration, guided first-piece/timer/QC gates, quantity and issue capture, Apple Files backup/recovery, and auditable completed-run correction. The deterministic engine enforces timer, QC, capacity, recovery, and commit integrity. The durable catalog contains 366 keys across 32 runtime locale codes; the compact-layout audit covers all supported text slots with zero failures.

## CI

- **Validate PressBench iOS** runs on pushes/PRs and can also be run manually. It checks release integrity, the 31-language UI layer, all 98 localized operator presets, deterministic engine smoke tests, Xcode project generation, a Release simulator build, unit/UI tests, and captures first-use UI audit screenshots.
- **Run TestFlight Build** builds, validates, signs, and uploads the production app when explicitly authorized by the release workflow.

The iOS app contains no advertising or tracking SDK. Free users may complete two successfully saved press runs. PressBench Pro is offered as the auto-renewable `pressbench_unlimited_monthly_ios` subscription at US$12.99/month or `pressbench_unlimited_annual_ios` at US$119.99/year. App Store Connect supplies the approved geopriced schedule in other storefronts, and customer-facing currency always comes from StoreKit. See `MONETIZATION.md` for product setup, App Review wording, and release controls.

See `TESTFLIGHT_SETUP.md` for the Apple credential and release setup.
