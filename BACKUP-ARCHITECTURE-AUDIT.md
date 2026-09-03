# PressBench iOS backup architecture audit

Reviewed: 3 September 2026  
Surface: Settings → Local Data & Backups and the five-free-run boundary

## Decision

PressBench uses a user-owned backup file through Apple’s native Files interface. It does not require an account, use Sign in with Apple, or synchronize the production log through iCloud key-value storage.

This follows Apple’s intended platform boundaries:

- [`fileExporter`](https://developer.apple.com/documentation/swiftui/view/fileexporter%28ispresented%3Adocument%3Acontenttype%3Adefaultfilename%3Aoncompletion%3A%29-32vwk) and [`fileImporter`](https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aallowsmultipleselection%3Aoncompletion%3Aoncancellation%3A%29) provide native save/open flows; imported URLs require security-scoped access.
- [`NSUbiquitousKeyValueStore`](https://developer.apple.com/documentation/foundation/synchronizing-app-preferences-with-icloud) is a 1 MB preference/state mechanism, not a production-log backup store.
- A [`ThisDeviceOnly` Keychain item](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility) is appropriate for the local usage high-water mark because it does not migrate to another device.
- Pro remains a separate, verified [StoreKit entitlement](https://developer.apple.com/documentation/storekit/transaction/currententitlements); backup restore cannot grant or revoke it.

## Release invariants

| Path | Required behavior |
| --- | --- |
| Create backup | Opens Files, exports a validated PressBench document, and records success only after export completes. |
| Import backup | Bounds the file before loading, uses security-scoped access, validates schema and references, then shows date, record counts, and post-restore free allowance. |
| Confirm restore | Clearly states that local data will be replaced; the destructive action is explicit and cancel is safe. |
| Restore commit | Atomically replaces machines, setups, runs, and settings; clears active-session state; preserves StoreKit entitlement. |
| Delete local data | Deletes operational data but does not reset the five-run usage ledger or delete previously exported files. |
| Five free runs | Counts unique successfully committed run IDs only; failed, canceled, unsaved, duplicated, deleted, or older restored runs cannot replenish allowance. |
| Cross-device restore | Uses the maximum of current secure usage, the backup’s monotonic count, and restored completed runs; never decrements usage. |
| Persistence failure | Fails closed for free-run authorization and retries a transient Keychain failure without resetting the counter. |

## Removed failure surfaces

- Sign in with Apple onboarding and Settings controls
- Private iCloud KVS backup dependency and entitlements
- Sign out and Delete iCloud Backup
- Roll Back Last Restore
- Authentication-related alerts and reviewer credentials

## Validation matrix

- Valid, empty, malformed, foreign, oversized, legacy, and unexpected-field backup files
- Export/import document round trip
- Restore to a new ledger and restore over a higher current count
- Repeated completion ID, non-adjacent duplicate ID, deletion, preference reset, limit cap, durable-write failure, and transient recovery
- Release UI checks for both backup controls and absence of removed controls
- Signed IPA must have Apple Distribution identity and must not contain Sign in with Apple or iCloud KVS entitlements

## Security boundary

Backup files are not encrypted by PressBench and are controlled by the destination the user selects. With no developer account or server, a user-editable file cannot be a cryptographically authoritative cross-device licensing record against deliberate tampering. The implemented design is monotonic and fail-closed for normal operation, deletion, restore, reinstall-style preference loss, and corrupt files. Server-authoritative quota enforcement would require a service/account boundary and is intentionally out of scope.

The release remains blocked until the same commit passes Release compilation, unit/UI tests, signed-IPA checks, App Store validation, and TestFlight upload.
