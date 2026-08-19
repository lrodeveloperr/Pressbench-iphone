# PressBench TestFlight — one-time setup

The repository is wired so normal TestFlight operation is a manual GitHub Actions button. Apple private credentials are never committed to source.

## 1. App Store Connect

Create the PressBench iOS app record with bundle ID:

`com.goodusestudios.pressbench`

The Apple Developer team configured in the project is:

`49SQ3XQ68Q`

## 2. App Store Connect API key

Create a **Team API key** with sufficient App Manager / Developer access for build upload and automatic signing. Download its `.p8` file once.

In this repository open **Settings → Secrets and variables → Actions** and add:

- `ASC_KEY_ID` — the 10-character key ID.
- `ASC_ISSUER_ID` — the issuer UUID.
- `ASC_PRIVATE_KEY` — the complete text of `AuthKey_<KEY_ID>.p8`, including the BEGIN/END lines.

Do not commit the `.p8` file and do not paste it into issues, pull requests, logs, or chat.

## 3. Upload a build

Open **Actions → Run TestFlight Build → Run workflow**.

Enter exactly:

`UPLOAD TESTFLIGHT`

Leave build number blank to use the GitHub run number, or supply a higher unused positive integer.

The workflow will:

1. verify release integrity, localization and deterministic engine smoke tests;
2. verify the App Store Connect app record for the production bundle ID;
3. generate the Xcode project;
4. compile a Release simulator build and run unit tests;
5. create a signed App Store archive using automatic signing and the API key;
6. verify bundle/version/build/privacy-manifest identity;
7. export and validate the IPA;
8. upload the IPA to App Store Connect/TestFlight;
9. retain the exact IPA as a short-lived GitHub Actions artifact.

Any failure stops before the upload step.
