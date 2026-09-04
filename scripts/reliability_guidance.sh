#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

show_guidance() {
  cat <<'GUIDANCE'
PressBench iOS reliability guidance
===================================

PB-01  Persistence recovery could route back into onboarding and hide recovery.
       Fix: recovery state now routes directly to Settings; destructive recovery has a tested path.
PB-02  A run completion could overwrite a setup edited or archived while the run was active.
       Fix: active-run machine/setup mutation locks plus snapshot conflict preservation in the engine.
PB-03  Timer ticks and issue typing caused excessive full-state writes on the main actor.
       Fix: ticks derive from endAt in memory; writes occur at durable boundaries; issue writes debounce and flush.
PB-04  iCloud KVS could reject otherwise-supported backup payloads near its quota.
       Fix: versioned zlib transport, strict post-compression quota check, and large-payload regression coverage.
PB-05  Restore could read before iCloud KVS completed its initial synchronization.
       Fix: launch synchronization, external-change observation, and bounded asynchronous restore polling.
PB-06  A stale device could overwrite a newer cloud backup or report a local write as cloud success.
       Fix: optimistic backup ID/revision checks; cloud confirmation is separated from the local cache write.
PB-07  StoreKit entitlement enumeration could let a weaker later result replace valid lifetime access.
       Fix: collect all recognized entitlements and deterministically prefer active lifetime, then active monthly.
PB-08  Purchase UI could report success before entitlement persistence succeeded.
       Fix: the StoreKit transaction is finished and the UI unlocks only after the durable store callback succeeds.
PB-09  First-backup failure during onboarding was swallowed.
       Fix: failure is shown and acknowledged before onboarding completes.
PB-10  Start Run could open an empty picker when only draft setups existed.
       Fix: runnable setup readiness controls Start Run; the empty state links directly to setup creation.
PB-11  Restore/rollback did not synchronize AppStorage presentation preferences.
       Fix: language, units, haptics, sound, and fixed light appearance are reapplied after restore or rollback.
PB-12  Machine nickname changes left stale names inside setup and stage snapshots.
       Fix: nickname propagation updates every dependent snapshot and resets fingerprint-bound proof.
PB-13  Archived machines/setups were invisible and permanently consumed capacity.
       Fix: archived sections now provide explicit Restore and confirmed Delete actions.
PB-14  Timer notification scheduling could race with cancellation and recreate a cancelled notification.
       Fix: main-actor generation tokens invalidate stale asynchronous schedules.
PB-15  A machine used only by a setup stage produced a late generic archive failure.
       Fix: top-level and nested stage references are checked before archive.
PB-16  The first timer sound could default off while Settings displayed on.
       Fix: service and UI now share the same true default.
PB-17  Search clear exposed a misleading VoiceOver label.
       Fix: localized Clear search semantics and a full 48-point target.
PB-18  Cancelled PDF/XLSX export continued expensive rendering and writing.
       Fix: cancellation checks cover rendering loops, archive creation, and writes.
PB-19  CI exercised only a small subset of touch interactions and masked multi-tap failures with retries.
       Fix: full UI suite runs on iPhone SE and Face ID; one-tap helpers, edge taps, destructive reset, and visible-button geometry are asserted.

Delete Local Data is intentionally available even when a run is active: its explicit destructive confirmation covers and removes that run with all other local records.

Touchscreen checklist
---------------------
1. Custom buttons use a minimum 48-point target and Rectangle content shape.
2. Full-width rows make transparent Spacer/padding regions tappable.
3. Icon-only actions expose a 48-by-48-point frame and accessibility label.
4. Destructive actions respond on the first tap and require one explicit confirmation.
5. Disabled state reflects real prerequisites; an action never opens an empty dead end.
6. Async actions expose in-progress state and cannot be double-submitted.
7. UI tests never retry a tap to conceal a missed first interaction.
8. Both compact Touch ID and modern Face ID simulator layouts run the complete UI suite.
9. UIKit segmented controls are verified by first-tap state changes; their visual segment frame is not misreported as the parent control's hit region.

Authoritative implementation references
---------------------------------------
- Apple UI Design Dos and Don'ts (44-point controls): https://developer.apple.com/design/tips/
- Apple accessibility guidance: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple iCloud key-value storage synchronization: https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForKey-ValueDataIniCloud.html
- Apple StoreKit entitlement guidance: https://developer.apple.com/videos/play/wwdc2022/110404/
- Apple main-thread responsiveness guidance: https://developer.apple.com/documentation/xcode/diagnosing-performance-issues-early
- Apple XCUIElement interaction API: https://developer.apple.com/documentation/xcuiautomation/xcuielement

Run `scripts/reliability_guidance.sh check` before committing.
GUIDANCE
}

run_checks() {
  cd "$repo_root"
  git diff --check
  node --check PressBench/Resources/PressBenchLogic.js
  node scripts/engine_smoke.js
  python3 scripts/verify_localization.py
  python3 scripts/release_integrity.py

  if command -v xcodebuild >/dev/null 2>&1 && command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
    xcodebuild -project PressBench.xcodeproj -scheme PressBench \
      -configuration Debug -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
  else
    printf '%s\n' 'Native build/UI tests require macOS and run in GitHub Actions on iPhone SE and Face ID simulators.'
  fi
}

case "${1:-guide}" in
  guide) show_guidance ;;
  check) run_checks ;;
  *) printf 'Usage: %s [guide|check]\n' "$0" >&2; exit 64 ;;
esac
