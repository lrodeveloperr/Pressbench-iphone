# PressBench iPhone

Production iPhone release repository for PressBench.

The release target is locked to:

- Bundle ID: `com.goodusestudios.pressbench`
- Apple Team: `49SQ3XQ68Q`
- Version: `0.21.4`
- Scheme: `PressBench`

## Source contract

Both GitHub Actions workflows accept any of:

1. the unpacked production source tree at repository root (`project.yml`, `PressBench/`, `PressBenchTests/`, `scripts/`), or
2. the reviewed split Base64 package at `.source/PressBench-iOS-Approved-UI-v0.21.4.zip.b64.part-*`, or
3. the canonical production package at repository root named exactly:

   `PressBench-TestFlight-Source-v0.21.4.zip`

The packaged-source path exists specifically so the binary ZIP can be uploaded once without manually unpacking dozens of files. The workflow extracts it into an isolated runner directory and then requires the full deterministic engine and release gates before compiling.

## Approved interface

The reviewed production source uses the GoodUse Studios Ocean Pearl system: adaptive light/dark tokens, 28-point page headers, 24-point cards, 62-point primary controls, four stable thumb destinations, RTL/Dynamic Type reflow, and Reduce Motion-aware interaction. The operator workflow includes one-screen onboarding, chained first-use setup, strict runnable-setup validation, guided first-piece/timer/QC gates, quantity and issue capture, Apple private backup/recovery, auditable completed-run correction, and the three-way reuse selector. The deterministic engine enforces timer, QC, capacity, recovery, and commit integrity. The durable catalog contains 366 keys across 32 runtime locale codes, generated from 327 canonical phrases; the compact-layout audit covers 960 text slots with zero failures.

## CI

- **Validate PressBench iOS** runs on pushes/PRs and can also be run manually. It checks release integrity, the 31-language localization layer, deterministic engine smoke tests, Xcode project generation, a Release simulator build, unit/UI tests, and captures first-use UI audit screenshots.
- **Run TestFlight Build** is manual. It repeats all validation, verifies the Apple credentials and App Store Connect identity, archives/signs the production app, verifies bundle/version/build/privacy-manifest identity, exports and validates the IPA, then uploads it to TestFlight.

The TestFlight workflow requires the literal confirmation `UPLOAD TESTFLIGHT` and fails closed before upload on any error.

The current iOS monetization test profile is a fixed Google demo banner plus five completed free press runs. The US subscription target is $9.99/month for unlimited presses, no ads, and PDF/XLSX reports. See `MONETIZATION.md` for the StoreKit product, App Review wording, lifetime-purchase migration, and the production-ad privacy gate.

See `TESTFLIGHT_SETUP.md` for the one-time Apple secret setup.
