#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, re, shutil, subprocess, sys, tempfile

root = Path(__file__).resolve().parents[1]
failures=[]

def require(condition, message):
    if not condition: failures.append(message)

logic = root/'PressBench/Resources/PressBenchLogic.js'
logic_hash = hashlib.sha256(logic.read_bytes()).hexdigest()
require(logic_hash == '3e2cef1d33b0d10986f838dad29ed71ddeedd064cd4a1c0b40fb8793c157c22c', f'logic hash changed: {logic_hash}')
text = logic.read_text(encoding='utf-8')
require(all(marker in text for marker in ['pressbench_unlimited_monthly_ios', 'pressbench_unlimited_lifetime_ios',
        'productType: "auto_renewable_subscription"', 'recurring: true', 'baseAmountMinor: 999']),
        'monthly iOS subscription or grandfathered lifetime entitlement is missing')
require('FREE_RECIPE_LIMIT = D.MAX_RECORDS' in text and 'FREE_BATCH_LIMIT = 5' in text and
        'setup_capacity_required' not in text,
        'five-press free allowance or unrestricted setup library changed')
require('function completedTimerPlan' in text and text.count('if (!completedTimerPlan(run.timer))') >= 2 and
        'TIMER_RESTART_PLAN' in text,
        'first-piece or production counting can bypass the complete timer plan')

project=(root/'project.yml').read_text(encoding='utf-8')
info_plist=(root/'PressBench/Info.plist').read_text(encoding='utf-8')
require('com.goodusestudios.pressbench' in project, 'production bundle id mismatch')
require('49SQ3XQ68Q' in project, 'Apple team id mismatch')
require('path: PressBench/Resources\n        buildPhase: resources' in project,
        'production resources are not explicitly assigned to the Xcode resources build phase')
require('PressBenchUITests:' in project and 'type: bundle.ui-testing' in project,
        'first-use UI regression target is missing')
require('CODE_SIGN_ENTITLEMENTS: PressBench/PressBench.entitlements' in project,
        'production entitlements are not assigned to the app target')
require(all(marker in project for marker in ['GoogleMobileAds:', 'exactVersion: 13.9.0',
        'GoogleUserMessagingPlatform:', 'exactVersion: 3.1.0',
        'INFOPLIST_FILE: PressBench/Info.plist']) and
        'ca-app-pub-3940256099942544~1458002511' in info_plist and
        '<key>GADApplicationIdentifier</key>' in info_plist,
        'pinned Google ad/consent SDK or explicit official demo application id is missing')

approved_logo_hash = '03ee625d3c2c6a1efb8e49b4cc060c5b0c61e6397fc0b39633f66151ac2a6a8b'
brand_logo = root/'PressBench/Assets.xcassets/BrandLogo.imageset/BrandLogo.png'
app_icon = root/'PressBench/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
require(hashlib.sha256(brand_logo.read_bytes()).hexdigest() == approved_logo_hash,
        'approved BrandLogo asset changed')
require(hashlib.sha256(app_icon.read_bytes()).hexdigest() == approved_logo_hash,
        'AppIcon is no longer the approved logo/thumbnail')

theme=(root/'PressBench/DesignSystem/PBTheme.swift').read_text(encoding='utf-8')
for token in [
    '#EEF6FF', '#FFFFFF', '#F7FBFF', '#163451', '#698098', '#D7E6F3',
    '#247BD1', '#E7F3FF', '#278E67', '#E7F6EF', '#AA7114', '#FFF5DD',
    '#BF414A', '#FFF0F1',
    '#526D89', '#1769BA', '#1D7556', '#8A570C', '#A82F39',
    'static let cardRadius: CGFloat = 24',
    'static let primaryHeight: CGFloat = 62',
    'static let primaryGradient = LinearGradient',
    '@Environment(\\.accessibilityReduceMotion)',
    '@ScaledMetric(relativeTo: .headline)',
    'struct PBTactileButtonStyle: ButtonStyle',
    'static let primaryActionFill = Color(uiColor: oceanPrimaryStrongLight)',
    'static let successActionFill = Color(uiColor: oceanSuccessInkLight)',
    'static let warningActionFill = Color(uiColor: oceanWarningInkLight)',
    'static let errorActionFill = Color(uiColor: oceanErrorInkLight)',
]:
    require(token in theme, f'GoodUse Ocean Pearl token missing: {token}')

root_tabs=(root/'PressBench/Views/RootTabView.swift').read_text(encoding='utf-8')
require(root_tabs.count('.tabItem') == 4, 'GoodUse navigation must expose four stable thumb destinations')
require('.tag(0)' in root_tabs and '.tag(1)' in root_tabs and '.tag(2)' in root_tabs and '.tag(3)' in root_tabs,
        'root tab identifiers are not the reviewed 0...3 sequence')
require('store.persistenceWarning != nil' in root_tabs and 'NavigationStack { SettingsView() }' in root_tabs,
        'persistence recovery no longer gates the operational tab surface')

app=(root/'PressBench/App/PressBenchApp.swift').read_text(encoding='utf-8')
settings_view=(root/'PressBench/Views/SettingsView.swift').read_text(encoding='utf-8')
store_source=(root/'PressBench/Models/PressBenchStore.swift').read_text(encoding='utf-8')
editors=(root/'PressBench/Views/ProductionEditors.swift').read_text(encoding='utf-8')
models_source=(root/'PressBench/Models/Models.swift').read_text(encoding='utf-8')
prefill_source=(root/'PressBench/Models/PBPrefillCatalog.swift').read_text(encoding='utf-8')
choice_field_source=(root/'PressBench/Views/PBChoiceField.swift').read_text(encoding='utf-8')
require('preferredColorScheme' in app and 'PBAppearancePreference.storageKey' in app,
        'system/light/dark appearance preference is not applied at the app root')
require('settings.appearance' in settings_view and 'AccessibilitySettingsView' in settings_view,
        'GoodUse appearance or in-app accessibility settings are missing')
for marker in ['backup.backupNow', 'backup.restore', 'backup.signOut', 'settings.rollbackRestore',
               'pressbench.notifications.enabled', 'pressbench.haptics.enabled', 'pressbench.sound.enabled',
               'syncPresentationPreferences', 'settings.storageRecoveryRequired']:
    require(marker in settings_view, f'restored Settings production control missing: {marker}')
require('confirmationDialog' in settings_view and 'settings.deleteLocalDataMessage' in settings_view,
        'destructive local-data reset confirmation is missing')
require(all(marker in settings_view for marker in [
            'notificationsEnabled = false', 'hapticsEnabled = true', 'soundEnabled = true',
            'PBTimerNotification.cancel()']),
        'local-data reset no longer resets presentation preferences and pending timer notifications')
require('fileImporter' not in settings_view and 'AppleBackupService.backup' in settings_view and
        'AppleBackupService.restoredPayload' in settings_view,
        'Apple private-backup flow regressed to a manual file workflow')
backup_service=(root/'PressBench/Services/AppleBackupService.swift').read_text(encoding='utf-8')
entitlements=(root/'PressBench/PressBench.entitlements').read_text(encoding='utf-8')
require('NSUbiquitousKeyValueStore.default' in backup_service and 'owner' in backup_service and
        'com.apple.developer.applesignin' in entitlements and 'com.apple.developer.ubiquity-kvstore-identifier' in entitlements,
        'Sign in with Apple private-backup implementation or entitlements are missing')
require('planDeleteAll' in store_source and '"entitlement": entitlement' in store_source,
        'local-data reset does not use the deterministic planner while preserving purchase entitlement')
require('.presentationDetents([.fraction(0.88), .large])' in theme and editors.count('.pbEditorSheetStyle()') >= 4,
        'all editor/reuse sheets must use 28-point, <=88-percent GoodUse presentation styling')
for marker in ['run.jobDifference', 'run.exactRepeat', 'run.sameProductVariant', 'run.materiallyDifferent',
               'bridge.domain("reuseSetup"', 'saveSameProductVariant', 'mode == .sameProductVariant']:
    require(marker in (editors + store_source + models_source), f'pre-run reuse selector/safe variant path missing: {marker}')
for marker in ['struct RunConfigurationView', 'confirmUnprovenProduction', 'progressMode', 'jobReference',
               'stage.repeatCount', 'stage.add', 'stage.moveUp', 'stage.moveDown', 'stage.remove']:
    require(marker in editors, f'run configuration or multi-stage setup editor control missing: {marker}')
require('childRoute = .configuration(setup)' in editors and 'try store.startRun(draft)' in editors,
        'reuse selector bypasses the reviewed run-configuration authorization surface')
reuse_test=(root/'PressBenchTests/SetupReuseSafetyTests.swift').read_text(encoding='utf-8')
require('testSameProductVariantSavePreservesMultiStageDefinition' in reuse_test and 'stepsWithoutIDs' in reuse_test,
        'multi-stage same-product variant regression test is missing')
require('if mode == .sameProductVariant' in editors and 'Int(draft.defaultQuantity).map { $0 > 0 } == true' in editors,
        'same-product variant readiness must depend only on a title and positive quantity')
require('!draft.sourceReference.trimmingCharacters' in editors and 'throw StoreError.invalidSetup' in store_source,
        'setup editor/store can persist a visibly complete but non-runnable setup')
require(all(marker in prefill_source for marker in [
            'static let platenSizes', 'static let materials', 'static let transferMedia',
            'static let pressureDescriptions', 'static let instructionSources',
            'static let placementActions', 'static let finishActions',
            'static var choiceCount']) and
        all(marker in editors for marker in [
            'PBPrefillCatalog.platenSizes', 'PBPrefillCatalog.materials', 'PBPrefillCatalog.transferMedia',
            'PBPrefillCatalog.pressureDescriptions', 'PBPrefillCatalog.instructionSources',
            'PBPrefillCatalog.placementActions', 'PBPrefillCatalog.finishActions']) and
        'struct PBChoiceField' in choice_field_source and 'chooseOther' in choice_field_source,
        'offline prefilled choices or the Other/custom escape path are missing')
prefill_test=(root/'PressBenchTests/PrefillCatalogTests.swift').read_text(encoding='utf-8')
require('XCTAssertEqual(PBPrefillCatalog.choiceCount, 98)' in prefill_test and
        'testCatalogContainsNoOperatingRecipeValuesOrCopiedBrandMarkers' in prefill_test,
        'prefill breadth, uniqueness, or no-operating-values regression coverage is missing')
require('locale: Locale = .current' in store_source and 'decimal(primaryPressStage.temperature, locale: locale)' in store_source and
        'primaryTemperatureUnit' in store_source and 'primaryPressStage.pressure' in store_source and
        'locale: locale, reuseClass:' in editors,
        'localized setup numbers or the primary stage temperature unit can diverge during save')
setups_view=(root/'PressBench/Views/SetupsView.swift').read_text(encoding='utf-8')
runs_view=(root/'PressBench/Views/RunsView.swift').read_text(encoding='utf-8')
setup_detail=(root/'PressBench/Views/SetupDetailView.swift').read_text(encoding='utf-8')
require(setups_view.count('dynamicTypeSize.isAccessibilitySize') >= 5 and setup_detail.count('dynamicTypeSize.isAccessibilitySize') >= 5,
        'saved setup metrics do not reflow and wrap at Accessibility Dynamic Type sizes')
require('frame(minHeight: PBTheme.minimumTarget)' in setups_view and 'frame(minHeight: PBTheme.minimumTarget)' in runs_view,
        'filter pills do not meet the 48-point GoodUse touch target')
require('accessibilityAddTraits(selected ? .isSelected : [])' in setups_view and
        'accessibilityAddTraits(selected ? .isSelected : [])' in runs_view,
        'filter pill selection state is not exposed to assistive technology')
home_view=(root/'PressBench/Views/HomeView.swift').read_text(encoding='utf-8')
active_run_view=(root/'PressBench/Views/ActiveRunView.swift').read_text(encoding='utf-8')
require('dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())]' in home_view and
        'dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())]' in active_run_view,
        'dashboard or active-run facts do not collapse to one column at Accessibility text sizes')
language_dropdown=(root/'PressBench/Views/LanguageDropdown.swift').read_text(encoding='utf-8')
onboarding_view=(root/'PressBench/Views/OnboardingView.swift').read_text(encoding='utf-8')
require('.frame(minHeight: PBTheme.minimumTarget)' in language_dropdown,
        'shared language dropdown no longer exposes a 48-point touch target')
require(home_view.count('.frame(minHeight: PBTheme.minimumTarget)') >= 2 and
        onboarding_view.count('.frame(minHeight: PBTheme.minimumTarget)') >= 3,
        'Home or onboarding text-link/first-use controls dropped below the 48-point target')
require(setup_detail.count('.frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)') >= 1 and 'Menu {' in setup_detail,
        'Setup detail toolbar controls dropped below the 48-point target')
require(re.search(r'plus\.circle\.fill[\s\S]{0,260}frame\(width: PBTheme\.minimumTarget, height: PBTheme\.minimumTarget\)', active_run_view) and
        re.search(r'Image\(systemName: "trash"\)[\s\S]{0,220}frame\(width: PBTheme\.minimumTarget, height: PBTheme\.minimumTarget\)', active_run_view),
        'active-run inline issue controls dropped below the 48-point target')
for marker in ['recordFirstPieceAdjustment', 'stopAfterFirstPiece', 'completeCycle', 'undoCycle',
               'recordQC', 'showingIssue', 'discardUnstartedRun', 'nextStageTimer', 'previousStageTimer',
               'UIApplication.shared.isIdleTimerDisabled', 'PBTimerNotification', 'PBTimerSound']:
    require(marker in (active_run_view + store_source), f'active-run production control missing: {marker}')
require('@ScaledMetric(relativeTo: .largeTitle)' in active_run_view and
        active_run_view.count('.pbEditorSheetStyle()') >= 3,
        'active-run timer scaling or editor sheet styling regressed')
for marker in ['timerPlanReady(run)', 'run.finishRun', 'run.nextItem', 'qcDue(run)',
               'scheduleIfAuthorized', 'syncIssueTotals()', 'resultReady(run)']:
    require(marker in active_run_view, f'impatient-operator run guard missing: {marker}')
require('requestPermissionIfNeeded' not in active_run_view,
        'notification authorization can interrupt a timed production action')
error_event_test=(root/'PressBenchTests/ErrorEventTests.swift').read_text(encoding='utf-8')
require('@Published private(set) var errorEventID' in store_source and 'errorEventID &+= 1' in store_source and
        '.onChange(of: store.errorEventID)' in active_run_view and
        'testIdenticalConsecutiveFailuresPublishDistinctEvents' in error_event_test,
        'repeated active-run failures no longer produce distinct immediate error events')
require(all(marker in store_source for marker in ['"rejectedSession"', 'hasRejectedRun', 'quarantineActiveRun',
                                                   'func discardRejectedRun', 'loadedActiveRun', 'migratedActiveRun',
                                                   'safeSession["activeRun"] = NSNull()', 'hasSetupDraft']) and
        store_source.count('quarantineIfPermitInvalid(error)') >= 3 and
        store_source.count('guard !hasRejectedRun else { throw StoreError.persistenceBlocked }') >= 2 and
        all(marker in settings_view for marker in ['showingRejectedRunDiscardConfirmation',
                                                    'store.hasRejectedRun', 'discardRejectedRun()',
                                                    'run.discardRejectedConfirm']) and
        all(marker in error_event_test for marker in ['testRejectedSessionIsQuarantinedUntilOperatorDiscardsIt',
                                                       'reopenedBeforeDiscard', 'XCTAssertTrue(store.hasSetupDraft)',
                                                       'XCTAssertNil(reopenedBeforeDiscard.activeRunRouteID)']),
        'an unverifiable active run can disappear without a visible, operator-controlled recovery path')
for unsafe_fill in ['background(PBTheme.primaryStrong', 'background(PBTheme.successInk',
                    'background(PBTheme.warningInk', 'background(PBTheme.errorInk']:
    require(unsafe_fill not in active_run_view, f'adaptive semantic ink reused as white-label action fill: {unsafe_fill}')
require('CompletedRunDetailView(run: run)' in runs_view and 'struct CompletedRunDetailView' in runs_view,
        'completed-run navigation/detail surface is missing')
for marker in ['activeRunRouteID', 'lastCompletedBatchID', 'func correctBatch', 'func deleteBatch',
               'guard activeRun == nil else { throw StoreError.activeRunConflict }']:
    require(marker in store_source, f'run routing, correction, or recovery integrity guard missing: {marker}')
require('run.correctRecord' in runs_view and 'run.deleteRecord' in runs_view and 'run.correctionReason' in runs_view,
        'auditable completed-run correction/removal UI is missing')
require(all(marker in runs_view for marker in ['jobReference, planned, processed, notes, issues, reason',
        'issueTotal("discarded")', 'issueTotal("reworked")']) and
        all(marker in store_source for marker in ['"jobReference": jobReference', '"quantityPlanned": planned',
        '"quantityProcessed": processed', '"issues": rawIssues']),
        'completed-run correction does not cover identity, quantities, issue evidence, and notes')
require('.interactiveDismissDisabled(hasChanges)' in runs_view and 'editor.discardChanges' in runs_view,
        'completed-run corrections can still be lost through accidental dismissal')
require('run.processStages.enumerated()' in runs_view and 'completedStageDetail' in runs_view and
        'stage.canonicalLocalizationKey.map(t) ?? stage.name' in runs_view and
        'instruction: string(stage["instruction"])' in store_source,
        'completed history no longer exposes the stored multi-stage process definition')
require('run.deleteRecordConfirm' in runs_view,
        'completed-record deletion lacks an identified irreversible warning')
require('missingRequiredFields' in editors and 'ForEach(missingRequiredFields' in editors,
        'setup validation no longer identifies the required fields that are incomplete')
require('showingStarter = true' in home_view and 'StartRunSheet().environmentObject(store)' in home_view,
        'Home start-run affordance no longer launches the run workflow directly')
machines_view=(root/'PressBench/Views/MachinesView.swift').read_text(encoding='utf-8')
require('machineIcon(machine)' in machines_view and 'facts.contains("mug")' in machines_view and
        'facts.contains("hat")' in machines_view and 'facts.contains("auto")' in machines_view,
        'machine icons are no longer derived from stable machine semantics')

privacy=(root/'PressBench/Resources/PrivacyInfo.xcprivacy').read_text(encoding='utf-8')
require('NSPrivacyAccessedAPICategoryUserDefaults' in privacy and 'CA92.1' in privacy, 'UserDefaults required-reason declaration missing')
require('<key>NSPrivacyTracking</key>\n    <false/>' in privacy, 'privacy manifest tracking flag changed')

policy=(root/'PressBench/App/PolicyLinks.swift').read_text(encoding='utf-8')
require('https://lrodeveloperr.github.io/pressbench-legal/' in policy, 'policy base URL changed')

swift_files=list((root/'PressBench').rglob('*.swift'))
joined='\n'.join(p.read_text(encoding='utf-8') for p in swift_files)
shadow_colors=re.findall(r'\.shadow\(color:\s*([^,\n\)]+)', joined)
require(all(color.strip().startswith('PBTheme.') for color in shadow_colors),
        'ad-hoc shadow detected; GoodUse depth must use a named PBTheme token')
segmented_controls=joined.count('.pickerStyle(.segmented)')
segmented_min_targets=len(re.findall(
    r'\.pickerStyle\(\.segmented\)\s*\.frame\(minHeight:\s*PBTheme\.minimumTarget\)',
    joined
))
require(segmented_controls >= 4 and segmented_min_targets == segmented_controls,
        'segmented controls dropped below the 48-point GoodUse target')
require('PressBenchStore.preview' not in joined, 'preview store reachable in production source')
require('Button(action: {})' not in joined and 'action: {}' not in joined, 'dead empty UI action found')
require('max(186' not in joined and '0.968' not in joined and '0.017' not in joined, 'known preview metric fallback found')
require('PressBenchStore.production()' in (root/'PressBench/App/PressBenchApp.swift').read_text(), 'app is not using production store')
require('StoreKit' in (root/'PressBench/Services/PurchaseManager.swift').read_text(), 'StoreKit2 adapter missing')
purchase_source=(root/'PressBench/Services/PurchaseManager.swift').read_text()
ad_source=(root/'PressBench/Services/PBAdvertising.swift').read_text()
usage_source=(root/'PressBench/Services/PBUsageMeter.swift').read_text()
require(all(marker in purchase_source for marker in ['pressbench_unlimited_monthly_ios',
        'pressbench_unlimited_lifetime_ios', '.autoRenewable', 'subscriptionPeriod.unit == .month',
        'transaction.expirationDate']), 'native subscription verification or lifetime grandfathering is incomplete')
require(all(marker in ad_source for marker in ['ca-app-pub-3940256099942544/2435281174',
        'BannerView(adSize: AdSizeBanner)', 'frame(width: 320', 'slotHeight: CGFloat = 50',
        'maxAdContentRating = GADMaxAdContentRating.general',
        'publisherPrivacyPersonalizationState = .disabled',
        'requestConsentInfoUpdate', 'loadAndPresentIfRequired', 'ConsentInformation.shared.canRequestAds']),
        'fixed official Google demo banner or required UMP consent gate is missing')
require('pbTestBanner(visible: store.adEligibilityResolved && !store.isPro && store.activeRun == nil)' in root_tabs and root_tabs.count('.pbTestBanner') == 1,
        'one persistent free-user test banner is not fixed outside the active press flow or does not disappear for Pro')
require(all(marker in usage_source for marker in ['freePressLimit = 5', 'completedPresses',
        'lastCreditedBatchID', 'creditedBatchIDs', 'canStartFreePress']) and
        all(marker in store_source for marker in ['usageMeter.canStartFreePress', 'recordCompletedPress',
                                                   'case .pressLimitReached', 'alreadyCommitted']),
        'monotonic five-completed-press limit is missing or deletion can recreate free usage')
require('PressBenchReportExporter.pdf' in (root/'PressBench/Views/ReportsView.swift').read_text(), 'native PDF report not wired')
require('PressBenchReportExporter.xlsx' in (root/'PressBench/Views/ReportsView.swift').read_text(), 'native XLSX report not wired')
reports_view=(root/'PressBench/Views/ReportsView.swift').read_text(encoding='utf-8')
report_exporter=(root/'PressBench/Reports/PressBenchReportExporter.swift').read_text(encoding='utf-8')
require('Task.detached(priority: .userInitiated)' in reports_view and '@MainActor\nenum PressBenchReportExporter' not in report_exporter,
        'PDF/XLSX generation can still block the main actor')
require('format: "CSV"' not in reports_view and 'format: "JSON"' not in reports_view and
        'func csvExport' not in store_source and 'static func json(' not in report_exporter and
        'CSV_SCHEMA_VERSION' not in text and 'function toCsv' not in text,
        'raw CSV or JSON export remains reachable')
require('pressbench.backup.lastSuccessAt' in settings_view and 'pressbench.backup.lastSuccessOwner' in settings_view and
        'backupLastSuccessOwner == appleUserID' in settings_view and 'backup.lastSuccessful' in settings_view,
        'successful Apple backup has no persistent visible confirmation')
require('object["setups"]' in settings_view,
        'Apple restore preview does not count setups from the backup schema')
ui_test=(root/'PressBenchUITests/FirstUseFlowUITests.swift').read_text(encoding='utf-8')
app_source=(root/'PressBench/App/PressBenchApp.swift').read_text(encoding='utf-8')
workflow=(root/'.github/workflows/validate-ios.yml').read_text(encoding='utf-8')
require('testZeroPatienceFirstUseShowsOnlyNextActionAndChainsMachineToSetup' in ui_test and
        'Continue without signing in' in ui_test and 'XCTAssertFalse' in ui_test and
        '10-identified-delete-warning' in ui_test and 'First piece passed' in ui_test and
        all(marker in ui_test for marker in ['choose("pb.choice.platen"', 'choose("pb.choice.material"',
                                              'choose("pb.choice.transfer"', 'choose("pb.choice.pressure"',
                                              'choose("pb.choice.source"']) and
        'matching(identifier: "pb.correction.reason")' in ui_test and
        re.search(r'matching\(identifier: "pb\.correction\.discard"\)[\s\S]{0,350}'
                  r'app\.keyboards\.firstMatch\.waitForNonExistence\(timeout: 2\)', ui_test) and
        'accessibilityIdentifier("pb.correction.reason")' in runs_view and
        'accessibilityIdentifier("pb.correction.discard")' in runs_view and
        '#selector(UIResponder.resignFirstResponder)' in runs_view,
        'zero-patience end-to-end UI regression test is missing or too shallow')
require('-resultBundlePath' in workflow and 'xcresulttool export attachments' in workflow and
        'attachment.lifetime = .keepAlways' in ui_test,
        'UI audit screenshots are not exported from the Xcode result bundle')
require('simctl bootstatus' in workflow,
        'UI test runner does not pre-boot the selected simulator')
require('requestPermissionIfNeeded' not in onboarding_view and
        'private var notificationsEnabled = false' in settings_view and
        'private var notificationsEnabled = false' in active_run_view,
        'notification permission interrupts onboarding or is not explicit opt-in')
require(theme.count('object(forKey: "pressbench.notifications.enabled") as? Bool ?? false') == 2 and
        'notificationsEnabled = false' in settings_view and
        'showingNotificationSettings = true' in settings_view and
        'UIApplication.openSettingsURLString' in settings_view,
        'notification service or denied-permission UI contradicts explicit opt-in')
require('ToolbarItemGroup(placement: .keyboard)' in theme and
        'accessibilityIdentifier("pb.keyboard.dismiss")' in theme and
        editors.count('.pbKeyboardDismissToolbar(t("common.ok"))') >= 3 and
        active_run_view.count('.pbKeyboardDismissToolbar(t("common.ok"))') >= 4 and
        active_run_view.count('.scrollDismissesKeyboard(.interactively)') >= 3 and
        'matching(identifier: "pb.keyboard.dismiss")' in ui_test and
        'waitForNonExistence(timeout: 2)' in ui_test,
        'editor keyboards can trap an impatient operator or the end-to-end test')
require('--pressbench-ui-test-reset' in ui_test and '--pressbench-ui-test-reset' in app_source and
        'removePersistentDomain' in app_source and 'state-v5' not in app_source and
        '-pressbench.onboarding.completed' not in ui_test,
        'UI test does not request a deterministic pre-store persistence reset')
require(all(marker in ui_test for marker in ['--pressbench-ui-test-limit-reached',
        '--pressbench-ui-test-product-unavailable', '--pressbench-ui-test-pro',
        'Free runs left: 0 of 5', 'pb.ad.banner', 'Unlock PressBench Pro',
        'Repeat this setup', 'capped-repeat-upgrade', 'app.tabBars.buttons["Runs"]',
        'pb.runs.screen']),
        'UI test does not cover the sixth-run paywall, capped Repeat, active-run ad removal, or Pro ad removal')
require(ui_test.count('XCTAssertFalse(app.otherElements["pb.ad.banner"].exists)') >= 2,
        'UI test does not verify both active-run and Pro banner removal')

advertising=(root/'PressBench/Services/PBAdvertising.swift').read_text(encoding='utf-8')
more_view=(root/'PressBench/Views/MoreView.swift').read_text(encoding='utf-8')
require('privacyOptionsRequirementStatus == .required' in advertising and
        'privacyOptionsAvailable = PBAdvertising.privacyOptionsRequired' in more_view and
        'let shown = await PBAdvertising.presentPrivacyOptions()' in more_view and
        'guard store.adEligibilityResolved, !store.isPro else { return }' in more_view and
        'if !store.isPro {' in more_view,
        'ad privacy choices must only be offered when required and must report presentation failure')
require('BannerViewDelegate' in advertising and 'didFailToReceiveAdWithError' in advertising and
        'bannerLoadResolved && !bannerLoaded ? 0' in advertising,
        'failed banner loads must collapse instead of leaving a blank fixed strip')

catalog=json.loads((root/'PressBench/Resources/Localizations.json').read_text(encoding='utf-8'))
require(len(catalog.get('languages',[])) == 31, 'language choice count is not 31')
require(len(catalog.get('strings',{})) == 366, 'reviewed localization catalog must contain 366 keys')
language_tests=(root/'PressBenchTests/LanguageSupportTests.swift').read_text(encoding='utf-8')
require('XCTAssertEqual(PBL10n.catalog.strings.count, 366)' in language_tests,
        'unit-test localization count is stale')
boundary = catalog.get('strings',{}).get('setup.provenBoundary',{})
require(bool(boundary), 'localized Proven evidence boundary is missing')
boundary_source = boundary.get('source','').lower()
require(all(term in boundary_source for term in ['operator-entered', 'manufacturer validation', 'certification', 'safety determination']),
        'Proven evidence boundary no longer states its operator-entered and non-certification limits')
detail_view=(root/'PressBench/Views/SetupDetailView.swift').read_text(encoding='utf-8')
require('t("setup.provenBoundary")' in detail_view and 'setup.status == .proven' in detail_view,
        'Proven evidence boundary is not visibly gated in SetupDetailView')

metadata=json.loads((root/'localization_keys.json').read_text(encoding='utf-8'))
require(set(metadata) == set(catalog.get('strings',{})), 'canonical localization_keys.json does not match runtime catalog')
for key, item in metadata.items():
    canonical_source=item.get('source','').replace('%1$d','%1$@').replace('%2$d','%2$@').replace('%d','%@')
    require(canonical_source == catalog.get('strings',{}).get(key,{}).get('source'), f'canonical source mismatch: {key}')
build_l10n=(root/'build_l10n.py').read_text(encoding='utf-8')
assemble=(root/'assemble_catalog.py').read_text(encoding='utf-8')
require('setup.provenBoundary' in build_l10n and 'raise SystemExit(\'Legacy' not in build_l10n,
        'build_l10n.py is not the live 366-key canonical generator')
purchase_manager=(root/'PressBench/Services/PurchaseManager.swift').read_text(encoding='utf-8')
require(purchase_manager.count('let productLoaded = await loadProduct()') == 2 and
        purchase_manager.count('if !productLoaded, state == .free { state = productLoadState }') == 2 and
        'guard await loadProduct() else { return }' not in purchase_manager,
        'entitlement refresh must continue when StoreKit product metadata is unavailable')
root_tabs=(root/'PressBench/Views/RootTabView.swift').read_text(encoding='utf-8')
require('@Published private(set) var entitlementsResolved = false' in purchase_manager and
        'entitlementsResolved = true' in purchase_manager and
        'store.adEligibilityResolved && !store.isPro' in root_tabs and
        'guard store.adEligibilityResolved, !store.isPro else { return }' in more_view,
        'ads must stay disabled until the current StoreKit entitlement scan resolves')
require("assert len(phrases)==286" in assemble and 'DIRECT_NEW_KEYS' in assemble and
        'OPERATOR_TRANSLATIONS' in assemble and 'ADDITIONAL_TRANSLATIONS' in assemble and
        'RESIDUAL_TRANSLATIONS' in assemble and
        "raise SystemExit('Legacy" not in assemble,
        'assemble_catalog.py is not the live base-plus-operator canonical generator')
phrase_rows=[line.split('\t') for line in (root/'phrases.tsv').read_text(encoding='utf-8').splitlines()]
require(len(phrase_rows) == 327, 'canonical phrase table must contain 327 rows')
source_to_index={row[1]: index for index,row in enumerate(phrase_rows) if len(row) >= 3}
durable_keys=['setup.provenBoundary','settings.appearance','appearance.system','appearance.light','appearance.dark',
              'accessibility.textSize','accessibility.systemManaged','accessibility.reduceMotion',
              'accessibility.differentiateWithoutColor','accessibility.enabled','accessibility.disabled',
              'accessibility.openSettings','settings.deleteLocalData','settings.deleteLocalDataMessage',
              'run.jobDifference','run.exactRepeat','run.sameProductVariant','run.materiallyDifferent']
for code in [item for item in catalog['languages'] if item != 'en'] + ['zh-Hant']:
    lines=(root/f'translations/{code}.txt').read_text(encoding='utf-8').splitlines()
    require(len(lines) == 286, f'canonical translation line count is not 286: {code}')
    for key in durable_keys:
        source=metadata.get(key,{}).get('source','')
        index=source_to_index.get(source)
        require(index is not None and lines[index] == catalog['strings'][key]['translations'][code],
                f'canonical translation does not regenerate {key}:{code}')
for key, entry in catalog.get('strings',{}).items():
    for code in catalog['languages'] + ['zh-Hant']:
        require(bool(entry.get('translations',{}).get(code,'').strip()), f'missing localization {key}:{code}')

# Rebuild localization artifacts in isolation so checked-in subscription copy
# cannot silently drift back to an earlier one-time-purchase model.
with tempfile.TemporaryDirectory(prefix='pressbench-l10n-') as temp_name:
    temp = Path(temp_name)
    for filename in ['build_l10n.py', 'assemble_catalog.py', 'phrases.tsv', 'monetization_translations.json']:
        shutil.copy2(root/filename, temp/filename)
    shutil.copytree(root/'translations', temp/'translations')
    (temp/'PressBench/Resources').mkdir(parents=True)
    generated = subprocess.run([sys.executable, 'build_l10n.py'], cwd=temp, capture_output=True, text=True)
    require(generated.returncode == 0, f'isolated build_l10n.py failed: {generated.stderr.strip()}')
    if generated.returncode == 0:
        generated = subprocess.run([sys.executable, 'assemble_catalog.py'], cwd=temp, capture_output=True, text=True)
        require(generated.returncode == 0, f'isolated assemble_catalog.py failed: {generated.stderr.strip()}')
    generated_catalog = temp/'PressBench/Resources/Localizations.json'
    require(generated_catalog.exists() and generated_catalog.read_bytes() == (root/'PressBench/Resources/Localizations.json').read_bytes(),
            'checked-in localization catalog differs from a clean canonical rebuild')

if failures:
    print('RELEASE INTEGRITY: FAIL')
    for item in failures: print(' -', item)
    sys.exit(1)
print(f'RELEASE INTEGRITY: PASS — {len(swift_files)} Swift files; {len(catalog["strings"])} localization keys; logic {logic_hash[:12]}…')
