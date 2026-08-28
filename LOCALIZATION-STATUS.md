# PressBench Localization Status — v0.22.0 native wrapper

## Current status

**31-language UI localization catalog and language switching: implemented and audited in the current source package.**

- 31 canonical language choices are exposed in onboarding and Settings.
- The iPhone language is detected and preselected on first launch.
- User choice persists under `pressbench.language`.
- The selected locale is injected into SwiftUI at the app root.
- Arabic, Hebrew and Urdu use right-to-left layout direction.
- Chinese remains one language choice while Simplified/Traditional script follows the device locale/region (`zh-Hans` / `zh-Hant`).
- 329 customer-facing localization keys cover the complete production UI plus the optional Apple/iCloud backup and human-facing report copy contracts.
- Every key has complete copy for all 31 language choices; Traditional Chinese has a complete script override.
- Runtime placeholder parity, report worksheet-name safety and localization-key references are checked by `scripts/verify_localization.py` and CI.
- Compact tabs/status surfaces have context-specific translations where a full literal translation would truncate.
- Dates, numbers, percentages and timer digits use the selected locale.
- User-entered production content is never silently translated.

## Report localization

Human-facing PDF/XLSX headings, worksheet names, table labels, notes and metrics now have 31-language copy in `Localizations.json` and a native access contract in `ReportLocalization.swift`.

The native PDF/XLSX presentation renderer is wired. The localized copy and renderer contract are complete, while final generated-file visual QA remains required on Apple infrastructure.

CSV/JSON schema/header keys remain canonical and untranslated by design so imports, backups and downstream processing do not change when the user changes language.

## External legal pages

The live Privacy, Terms, Safety and related GitHub Pages documents currently remain English. Non-English app UI explicitly says that policy pages are currently available in English. Do not describe the legal documents themselves as localized until separately reviewed translations are published.

## QA completed in this package

1. 329 keys × 31 language choices + Traditional Chinese script override: complete (10,528 key/locale rows).
2. Placeholder parity: pass.
3. Swift structural/release-integrity audit: pass; Xcode parsing/build remains a macOS CI gate.
4. Semantic forward/back icons for RTL: pass.
5. Compact iPhone text-slot width audit (960 tab, badge, primary-action, reuse-selector, Settings and legal-link checks): pass after context-specific shortening.
6. XLSX worksheet-name constraints (unique, ≤31 characters, no forbidden characters): pass in every locale.
7. Cultural terminology review for manufacturing terms and certification-sensitive wording: completed; see `LOCALIZATION-CULTURAL-REVIEW.md`.
8. Full key-by-key audit matrix: `LOCALIZATION-AUDIT-31-LANGUAGES.csv`.
9. Customer-facing source inventory: `UI-TEXT-INVENTORY.md`.

## Remaining release QA

- Run the complete SwiftUI app on physical/simulator iPhones in all languages at standard and large Dynamic Type sizes once the native adapters are fully wired.
- Generate native PDF/XLSX files in each locale once that renderer exists and check pagination, fonts, RTL tables, print layout and Excel interoperability.
- Obtain independent native-speaker sign-off for priority commercial markets, especially before translating or publishing legal documents.

## Supported language identifiers

`en es pt fr de it nl pl tr ro cs uk ru ar zh ja ko hi ur bn vi id th fil ms fi sv da nb el he`
