# PressBench iPhone

Production iPhone release repository for PressBench.

The release target is locked to:

- Bundle ID: `com.goodusestudios.pressbench`
- Apple Team: `49SQ3XQ68Q`
- Version: `0.21.4`
- Scheme: `PressBench`

## Source contract

Both GitHub Actions workflows accept either:

1. the unpacked production source tree at repository root (`project.yml`, `PressBench/`, `PressBenchTests/`, `scripts/`), or
2. the canonical production package at repository root named exactly:

   `PressBench-TestFlight-Source-v0.21.4.zip`

The packaged-source path exists specifically so the binary ZIP can be uploaded once without manually unpacking dozens of files. The workflow extracts it into an isolated runner directory and then requires the full deterministic engine and release gates before compiling.

## CI

- **Validate PressBench iOS** runs on pushes/PRs and can also be run manually. It checks release integrity, the 31-language localization layer, deterministic engine smoke tests, Xcode project generation, a Release simulator build, and unit tests.
- **Run TestFlight Build** is manual. It repeats all validation, verifies the Apple credentials and App Store Connect identity, archives/signs the production app, verifies bundle/version/build/privacy-manifest identity, exports and validates the IPA, then uploads it to TestFlight.

The TestFlight workflow requires the literal confirmation `UPLOAD TESTFLIGHT` and fails closed before upload on any error.

See `TESTFLIGHT_SETUP.md` for the one-time Apple secret setup.
