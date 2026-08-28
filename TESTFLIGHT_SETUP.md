# PressBench TestFlight — one-time setup

The repository is wired so normal TestFlight operation is a manual GitHub Actions button. Apple private credentials are never committed to source.

## 1. Canonical production source

The workflows accept either the unpacked source tree at repository root or one ZIP at repository root named exactly:

`PressBench-TestFlight-Source-v0.21.4.zip`

The ZIP path is the simplest handoff. GitHub Actions extracts it into an isolated runner directory and refuses to continue unless it contains `project.yml`, the deterministic `PressBenchLogic.js` engine, and the release/localization/engine test scripts.

## 2. App Store Connect

The PressBench iOS app record must use bundle ID:

`com.goodusestudios.pressbench`

The Apple Developer team configured in the workflow is:

`49SQ3XQ68Q`

## 3. App Store Connect API key

Use a **Team API key** with sufficient App Manager / Developer access for build upload and automatic signing. The `.p8` key itself must remain private.

In this repository open **Settings → Secrets and variables → Actions** and ensure these repository secrets exist:

- `ASC_KEY_ID` — the 10-character key ID.
- `ASC_ISSUER_ID` — the issuer UUID.
- `ASC_PRIVATE_KEY` — the complete text of `AuthKey_<KEY_ID>.p8`, including the BEGIN/END lines.

Do not commit the `.p8` file and do not paste it into issues, pull requests, logs, or chat.

## 4. Validate

Open **Actions → Validate PressBench iOS → Run workflow**.

The validation job must pass before the TestFlight build is treated as a release candidate. It checks:

1. release integrity;
2. all 31 language choices / locale resources;
3. deterministic engine smoke tests;
4. Xcode project generation;
5. Release simulator compilation;
6. unit tests.

## 5. Upload a build

Open **Actions → Run TestFlight Build → Run workflow**.

Enter exactly:

`UPLOAD TESTFLIGHT`

Leave build number blank to use the GitHub run number, or supply a higher unused positive integer.

The workflow then:

1. repeats the release/localization/engine gates;
2. verifies the registered Apple bundle ID and PressBench App Store Connect app record;
3. generates the Xcode project;
4. compiles and tests the app;
5. creates a signed App Store archive using automatic signing and the API key;
6. verifies bundle/version/build/privacy-manifest identity and code signing;
7. exports and validates the IPA;
8. uploads the IPA to App Store Connect/TestFlight;
9. retains the exact IPA as a seven-day GitHub Actions artifact.

Any failure stops before the upload step.

