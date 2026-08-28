# PressBench 31-Language Localization QA Report

## Bottom line

The current SwiftUI presentation layer now has complete system-copy coverage for all 31 PressBench language choices, plus a complete Traditional Chinese script override. The audit covers the current native-wrapper UI inventory and the human-facing PDF/XLSX report copy contract.

This is **not** a claim that the final signed iOS binary has been visually certified in all languages: the native app still needs final simulator/device QA after the remaining production adapters and native report renderer are wired.

## Scope exercised

- Three-page onboarding: Welcome + shared language dropdown, legal acknowledgements, and explicit temperature-unit confirmation.
- Home (including the conditional first-use machine/setup/run guide), Setups, setup detail, Runs, active run, Machines, More and Settings.
- Status badges and canonical process-stage labels.
- Human-facing report headings, metrics, table headers, worksheet names and notices.
- Locale-aware dates, numbers, percentages and timer digits.
- RTL direction for Arabic, Hebrew and Urdu.
- Simplified/Traditional Chinese script selection.

## Inventory and completeness

- 31 user-selectable languages.
- 1 additional locale/script override: `zh-Hant`.
- 329 reviewed localization catalog keys, including the complete production/QC/Apple backup surface plus appearance/accessibility settings, destructive-reset copy, the Proven evidence boundary and pre-run reuse choices.
- 10,528 key/locale audit rows (329 × 32).
- Missing strings: 0.
- Placeholder mismatches: 0.
- Empty translations: 0.

## Cultural/localization changes made during review

1. Replaced time-of-day greeting with a neutral localized “Welcome back” concept.
2. Shortened bottom-tab labels in languages where literal translations would truncate, while retaining fuller wording elsewhere.
3. Changed evidence-backed “Proven” wording in several languages to culturally natural “tried/tested / successful track record” concepts so it does not read like manufacturer or regulatory certification.
4. Used manufacturing vocabulary for first piece, first-pass yield, rework and scrap/waste rather than consumer-style literal translations.
5. Preserved technical English/Taglish where that is the natural professional register (notably Filipino) instead of forcing unusual purist terms.
6. Preserved operator-entered production data exactly as recorded and never auto-translated it.
7. Kept CSV/JSON schema keys canonical; human-facing PDF/XLSX copy is localized separately.
8. Replaced physical left/right UI icons with semantic forward/back icons for RTL.
9. Added an explicit localized disclosure that the live external policy pages are currently English-only.

## Automated/code QA

- `scripts/verify_localization.py`: PASS.
  - exact 31-language list;
  - complete locale matrix;
  - placeholder parity;
  - safe Excel worksheet names;
  - Swift localization-key references;
  - no physical left/right navigation icons.
- Swift structural/release-integrity audit: PASS; full Xcode parsing/build remains a macOS CI gate.
- Compact iPhone-width static layout tests: 960 tests, 0 failures after context-specific label fixes.
  - bottom tabs;
  - status badges;
  - primary actions;
  - pre-run reuse choices and heading;
  - appearance, accessibility and destructive-reset settings rows;
  - combined Home legal links.
- Excel worksheet names: unique, ≤31 characters, and free of Excel-forbidden characters in every locale.

## Important content boundary

The following are **not translated automatically** because they are operator/customer data, not interface copy:

- setup titles;
- job/customer references;
- machine nicknames/model names;
- supplier/source names;
- free-text notes;
- free-text pressure descriptions and other operator-entered values;
- imported historical record content.

This prevents PressBench from altering the meaning of production records when the UI language changes.

## Remaining release gates

1. Build and run the complete SwiftUI app on actual iPhone/simulator targets for every language after the production adapters are finished.
2. Repeat at large Dynamic Type sizes and compact-screen widths.
3. Generate PDF/XLSX reports with the native renderer in every locale and inspect page breaks, font fallback, RTL tables, print output and Excel opening behavior.
4. Obtain independent native-speaker review in priority commercial markets.
5. Do not publish translated legal policies until those legal translations have been independently reviewed and approved.
