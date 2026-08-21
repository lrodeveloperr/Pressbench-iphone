# Approved GoodUse Ocean Pearl native iOS source

The files `PressBench-iOS-Approved-UI-v0.21.4.zip.b64.part-*` are the approved native SwiftUI source archive, skinned with the GoodUse Studios Ocean Pearl system and split as Base64 text for GitHub's file API.

- Archive SHA-256: `9923c610a3f68c33eeb44b0b605718bebe49413e8ac3513a21a1e5fcd315381d`
- Archive size / source parts: `726172` bytes / `21`
- Bundle ID: `com.goodusestudios.pressbench`
- Marketing version: `0.21.4`
- Production logic SHA-256: `5bd9bbef6af2bd104fa93bc6a7a302a7445943814c64666b09ee8a7e56170eec`
- Navigation: four stable destinations (Home, Setups, Runs, More)
- Appearance: adaptive light/dark Ocean Pearl tokens, contrast-safe semantic inks, named depth, Dynamic Type reflow, and Reduce Motion support
- Production workflow: complete preflight, first-piece evidence, multi-stage timers, quantity/QC/issues, result recording, backup/recovery, and completed-run detail surfaces retained
- Reuse workflow: Exact repeat / Same product variant / Materially different selector with full run configuration and evidence-safe variant persistence
- Localization: 311 keys × 32 runtime locale codes from a durable 286-phrase canonical source; 960 compact-layout checks pass

The validation and TestFlight workflows concatenate the parts, decode the ZIP, verify its exact SHA-256, then run release integrity, localization, engine, Xcode build, and XCTest gates.

Local reconstruction:

```bash
cat .source/PressBench-iOS-Approved-UI-v0.21.4.zip.b64.part-* | base64 --decode > PressBench-iOS-Approved-UI-v0.21.4.zip
shasum -a 256 PressBench-iOS-Approved-UI-v0.21.4.zip
```

Never commit App Store Connect private keys.
