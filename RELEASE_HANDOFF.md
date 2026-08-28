# PressBench iOS release handoff

## Prepared source

- Native SwiftUI production source; no WebView substitution.
- Production logic hash remains `5bd9bbef6af2bd104fa93bc6a7a302a7445943814c64666b09ee8a7e56170eec`.
- Bundle ID: `com.goodusestudios.pressbench`.
- Apple team: `49SQ3XQ68Q`.
- Marketing version: `0.22.0`.
- Approved GoodUse Studios Ocean Pearl tokens, 24-point cards, named adaptive depth, 28-point page headers and 62-point primary actions are presentation-only changes.
- The Proven evidence surface carries a visible, 32-locale boundary explaining that the status is based on qualifying operator-entered runs and is not manufacturer validation, certification or a safety determination.
- The pre-run GoodUse selector routes Exact repeat to preflight, Same product variant through the engine’s restricted clone path, and Materially different through a proof/operating-value-reset Draft. A multi-stage regression test protects the safe variant path.
- The root navigation has four stable destinations: Home, Setups, Runs and More. Machines is reachable through More and machine creation remains direct from first-use and Setups.
- System/Light/Dark appearance, Dynamic Type, contrast-safe copy inks, RTL, VoiceOver semantics and Reduce Motion are wired through the native presentation layer.
- Onboarding and Settings expose optional Sign in with Apple for automatic private iCloud backup, while the app remains fully usable through the explicit continue-without-signing-in route. Manual backup-file import has been removed.
- Settings exposes language, temperature, exports, local backup creation/sharing, iCloud restore, a useful accessibility status screen, confirmed entitlement-preserving local-data deletion, reset/onboarding, privacy, terms, safety and support.
- Canonical localization regeneration is live at 329 keys across 32 runtime locale codes, backed by 304 source phrases and per-locale translation files.
- Compact layout QA covers 960 localized text slots (including the reuse selector and Settings) with zero failures; saved setup metrics reflow vertically at Accessibility Dynamic Type sizes.
- The approved logo bytes are used by both `BrandLogo` and `AppIcon`.

## GitHub source wiring

Commit the unpacked contents of this directory at the repository root. This is
the supported source path and repairs the current repository's incomplete
`.source` Base64 chunk set. The workflows may retain their ZIP fallback, but the
root tree is canonical and reviewable.

Use a pull request into `main`. Let `Validate PressBench iOS` pass before merge.
After merge, a repository administrator can manually run `Run TestFlight Build`
from `main` with the confirmation text `UPLOAD TESTFLIGHT`.

## External requirements

The repository needs Actions secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, and
`ASC_PRIVATE_KEY`. App Store Connect must contain exactly one app record and
registered bundle identifier for `com.goodusestudios.pressbench`, accessible to
that API key. Automatic signing must be permitted for team `49SQ3XQ68Q`.

Never commit the `.p8` private key.

## QA still requiring Apple infrastructure

- Xcode Release simulator compile and XCTest suite.
- Archive/export signing and IPA validation.
- Physical-device checks for Dynamic Type, VoiceOver, RTL, haptics, timers,
  purchase/restore, persistence, and PDF/XLSX export.
- Native-speaker review of high-risk safety and purchase strings.
