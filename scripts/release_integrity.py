#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, re, sys

root = Path(__file__).resolve().parents[1]
failures=[]

def require(condition, message):
    if not condition: failures.append(message)

logic = root/'PressBench/Resources/PressBenchLogic.js'
logic_hash = hashlib.sha256(logic.read_bytes()).hexdigest()
require(logic_hash == '5bd9bbef6af2bd104fa93bc6a7a302a7445943814c64666b09ee8a7e56170eec', f'logic hash changed: {logic_hash}')
text = logic.read_text(encoding='utf-8')
require('pressbench_unlimited_lifetime_ios' in text, 'iOS product id missing from deterministic engine')
require('FREE_RECIPE_LIMIT = 3' in text and 'FREE_BATCH_LIMIT = 10' in text, 'free capacity constants changed')

project=(root/'project.yml').read_text(encoding='utf-8')
require('com.goodusestudios.pressbench' in project, 'production bundle id mismatch')
require('49SQ3XQ68Q' in project, 'Apple team id mismatch')
require('path: PressBench/Resources\n        buildPhase: resources' in project,
        'production resources are not explicitly assigned to the Xcode resources build phase')
require('CODE_SIGN_ENTITLEMENTS: PressBench/PressBench.entitlements' in project,
        'production target is not signed with the PressBench capabilities')
entitlements=(root/'PressBench/PressBench.entitlements').read_text(encoding='utf-8')
for marker in ['com.apple.developer.applesignin', 'iCloud.com.goodusestudios.pressbench',
               'com.apple.developer.icloud-services', 'CloudDocuments']:
    require(marker in entitlements, f'optional Apple/iCloud backup entitlement missing: {marker}')

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
onboarding_view=(root/'PressBench/Views/OnboardingView.swift').read_text(encoding='utf-8')
store_source=(root/'PressBench/Models/PressBenchStore.swift').read_text(encoding='utf-8')
editors=(root/'PressBench/Views/ProductionEditors.swift').read_text(encoding='utf-8')
models_source=(root/'PressBench/Models/Models.swift').read_text(encoding='utf-8')
require('preferredColorScheme' in app and 'PBAppearancePreference.storageKey' in app,
        'system/light/dark appearance preference is not applied at the app root')
require('settings.appearance' in settings_view and 'AccessibilitySettingsView' in settings_view,
        'GoodUse appearance or in-app accessibility settings are missing')
for marker in ['settings.createBackup', 'settings.rollbackRestore', 'backup.title',
               'PBSignInWithAppleButton', 'restoreFromICloud',
               'pressbench.notifications.enabled', 'pressbench.haptics.enabled', 'pressbench.sound.enabled',
               'syncPresentationPreferences', 'settings.storageRecoveryRequired']:
    require(marker in settings_view, f'restored Settings production control missing: {marker}')
require('fileImporter' not in settings_view and 'settings.importBackup' not in settings_view,
        'manual backup-file import must remain removed from Settings')
require('common.continueWithoutSigningIn' in onboarding_view and 'PBSignInWithAppleButton' in onboarding_view,
        'optional Apple sign-in route or explicit continue-without-signing-in action is missing')
backup_manager=(root/'PressBench/Services/AppleBackupManager.swift').read_text(encoding='utf-8')
for marker in ['ASAuthorizationAppleIDProvider', 'AppleBackupCredentialStore',
               'url(forUbiquityContainerIdentifier:', 'scheduleAutomaticBackup',
               'request.requestedScopes = []']:
    require(marker in backup_manager, f'Apple/iCloud backup contract missing: {marker}')
require('confirmationDialog' in settings_view and 'settings.deleteLocalDataMessage' in settings_view,
        'destructive local-data reset confirmation is missing')
require(all(marker in settings_view for marker in [
            'notificationsEnabled = true', 'hapticsEnabled = true', 'soundEnabled = false',
            'PBTimerNotification.cancel()']),
        'local-data reset no longer resets presentation preferences and pending timer notifications')
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
require('.frame(minHeight: PBTheme.minimumTarget)' in language_dropdown,
        'shared language dropdown no longer exposes a 48-point touch target')
require(home_view.count('.frame(minHeight: PBTheme.minimumTarget)') >= 5 and
        onboarding_view.count('.frame(minHeight: PBTheme.minimumTarget)') >= 6,
        'Home or onboarding text-link/first-use controls dropped below the 48-point target')
require(setup_detail.count('.frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)') >= 2,
        'Setup detail toolbar controls dropped below the 48-point target')
require(re.search(r'plus\.circle\.fill[\s\S]{0,260}frame\(width: PBTheme\.minimumTarget, height: PBTheme\.minimumTarget\)', active_run_view) and
        re.search(r'Image\(systemName: "trash"\)[\s\S]{0,220}frame\(width: PBTheme\.minimumTarget, height: PBTheme\.minimumTarget\)', active_run_view),
        'active-run inline issue controls dropped below the 48-point target')
for marker in ['recordFirstPieceAdjustment', 'stopAfterFirstPiece', 'completeCycle', 'undoCycle',
               'recordQC', 'showingIssue', 'discardUnstartedRun', 'nextStageTimer', 'previousStageTimer',
               'UIApplication.shared.isIdleTimerDisabled', 'PBTimerNotification', 'PBTimerSound']:
    require(marker in (active_run_view + store_source), f'active-run production control missing: {marker}')
require('@ScaledMetric(relativeTo: .largeTitle)' in active_run_view and
        active_run_view.count('.pbEditorSheetStyle()') >= 4,
        'active-run timer scaling or editor sheet styling regressed')
for unsafe_fill in ['background(PBTheme.primaryStrong', 'background(PBTheme.successInk',
                    'background(PBTheme.warningInk', 'background(PBTheme.errorInk']:
    require(unsafe_fill not in active_run_view, f'adaptive semantic ink reused as white-label action fill: {unsafe_fill}')
require('CompletedRunDetailView(run: run)' in runs_view and 'private struct CompletedRunDetailView' in runs_view,
        'completed-run navigation/detail surface is missing')
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
require('pressbench_unlimited_lifetime_ios' in (root/'PressBench/Services/PurchaseManager.swift').read_text(), 'native purchase id mismatch')
require('PressBenchReportExporter.pdf' in (root/'PressBench/Views/ReportsView.swift').read_text(), 'native PDF report not wired')
require('PressBenchReportExporter.xlsx' in (root/'PressBench/Views/ReportsView.swift').read_text(), 'native XLSX report not wired')

catalog=json.loads((root/'PressBench/Resources/Localizations.json').read_text(encoding='utf-8'))
require(len(catalog.get('languages',[])) == 31, 'language choice count is not 31')
require(len(catalog.get('strings',{})) == 329, 'reviewed localization catalog must contain 329 keys')
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
        'build_l10n.py is not the live 329-key canonical generator')
require("assert len(phrases)==304" in assemble and "raise SystemExit('Legacy" not in assemble,
        'assemble_catalog.py is not the live 304-phrase generator')
phrase_rows=[line.split('\t') for line in (root/'phrases.tsv').read_text(encoding='utf-8').splitlines()]
require(len(phrase_rows) == 304, 'canonical phrase table must contain 304 rows')
source_to_index={row[1]: index for index,row in enumerate(phrase_rows) if len(row) >= 3}
durable_keys=['setup.provenBoundary','settings.appearance','appearance.system','appearance.light','appearance.dark',
              'accessibility.textSize','accessibility.systemManaged','accessibility.reduceMotion',
              'accessibility.differentiateWithoutColor','accessibility.enabled','accessibility.disabled',
              'accessibility.openSettings','settings.deleteLocalData','settings.deleteLocalDataMessage',
              'run.jobDifference','run.exactRepeat','run.sameProductVariant','run.materiallyDifferent']
for code in [item for item in catalog['languages'] if item != 'en'] + ['zh-Hant']:
    lines=(root/f'translations/{code}.txt').read_text(encoding='utf-8').splitlines()
    require(len(lines) == 304, f'canonical translation line count is not 304: {code}')
    for key in durable_keys:
        source=metadata.get(key,{}).get('source','')
        index=source_to_index.get(source)
        require(index is not None and lines[index] == catalog['strings'][key]['translations'][code],
                f'canonical translation does not regenerate {key}:{code}')
for key, entry in catalog.get('strings',{}).items():
    for code in catalog['languages'] + ['zh-Hant']:
        require(bool(entry.get('translations',{}).get(code,'').strip()), f'missing localization {key}:{code}')

if failures:
    print('RELEASE INTEGRITY: FAIL')
    for item in failures: print(' -', item)
    sys.exit(1)
print(f'RELEASE INTEGRITY: PASS — {len(swift_files)} Swift files; {len(catalog["strings"])} localization keys; logic {logic_hash[:12]}…')
