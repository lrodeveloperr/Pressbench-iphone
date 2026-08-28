# PressBench for iPhone

Production SwiftUI source for PressBench `0.22.0`.

This repository is intentionally root-ready: `project.yml`, `PressBench/`,
`PressBenchTests/`, and `scripts/` are committed as normal files. Do not replace
them with partial Base64 source chunks. Both GitHub Actions workflows fail closed
if the deterministic engine or release gates are missing.

## Local integrity gates

```bash
python3 scripts/release_integrity.py
python3 scripts/verify_localization.py
node scripts/engine_smoke.js
python3 run_static_layout_audit.py
```

On macOS with Xcode and XcodeGen installed:

```bash
xcodegen generate
xcodebuild -project PressBench.xcodeproj -scheme PressBench \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The production bundle identifier is `com.goodusestudios.pressbench`; the Apple
Developer team is `49SQ3XQ68Q`. See `TESTFLIGHT_SETUP.md` before running the
manual TestFlight workflow.

## Release source policy

- `PressBench/Resources/PressBenchLogic.js` is the reviewed deterministic engine.
- The approved logo remains both the brand image and app icon.
- The GoodUse Studios Ocean Pearl visual system is locked by `scripts/release_integrity.py`.
- Every Proven setup shows a localized boundary directly below its run evidence: the status comes from qualifying operator-entered runs, not manufacturer validation, certification or a safety determination.
- Before a run, the localized GoodUse selector classifies the job as an Exact repeat, Same product variant or Materially different. Same-variant editing is limited to title, quantity and notes; materially different setups use the engine’s proof and operating-value reset.
- Four stable thumb destinations keep Machines under More while machine creation remains directly reachable from first-use and Setups flows.
- Appearance can follow the iPhone or be set to Light/Dark. Dynamic Type, RTL layout, VoiceOver semantics, high-contrast semantic inks and Reduce Motion are honored natively; the in-app accessibility screen reports relevant system states and opens iOS app settings.
- Settings also exposes language, temperature units, optional Sign in with Apple and private iCloud backup, exports, local backup creation/sharing, confirmed local-data deletion that preserves App Store entitlement, onboarding reset, privacy, terms, safety and support. Manual backup-file import is intentionally unavailable.
- `build_l10n.py` and `assemble_catalog.py` are the live 329-key/304-phrase source-of-truth pipeline; every runtime locale is reproducible from the canonical metadata and translation files.
- Generated `PressBench.xcodeproj` and signed artifacts are build outputs, not source.
