# Approved native iOS source

The files `PressBench-iOS-Approved-UI-v0.21.4.zip.b64.part-*` are the approved native SwiftUI source archive split as Base64 text for GitHub's file API.

- Archive SHA-256: `b93c69ddd469b31271b768807e1a78e3c9fd966393ea875efac07e024e360691`
- Bundle ID: `com.goodusestudios.pressbench`
- Marketing version: `0.21.4`
- Production logic SHA-256: `5bd9bbef6af2bd104fa93bc6a7a302a7445943814c64666b09ee8a7e56170eec`

The validation and TestFlight workflows concatenate the parts, decode the ZIP, verify its exact SHA-256, then run release integrity, localization, engine, Xcode build, and XCTest gates.

Local reconstruction:

```bash
cat .source/PressBench-iOS-Approved-UI-v0.21.4.zip.b64.part-* | base64 --decode > PressBench-iOS-Approved-UI-v0.21.4.zip
shasum -a 256 PressBench-iOS-Approved-UI-v0.21.4.zip
```

Never commit App Store Connect private keys.
