import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: PressBenchStore
    @AppStorage("pressbench.onboarding.completed") private var onboardingCompleted = true
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue
    @AppStorage("pressbench.temperature.unit") private var temperatureUnitRaw = Locale.current.measurementSystem == .us ? "F" : "C"
    @AppStorage(PBAppearancePreference.storageKey) private var appearanceRaw = PBAppearancePreference.light.rawValue
    @AppStorage("pressbench.notifications.enabled") private var notificationsEnabled = false
    @AppStorage("pressbench.haptics.enabled") private var hapticsEnabled = true
    @AppStorage("pressbench.sound.enabled") private var soundEnabled = true
    @AppStorage("pressbench.backup.lastSuccessAt") private var backupLastSuccessAt = 0.0
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var showingDeleteConfirmation = false
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @State private var showingRestoreConfirmation = false
    @State private var showingRejectedRunDiscardConfirmation = false
    @State private var showingUpgrade = false
    @State private var backupDocument: PressBenchBackupDocument?
    @State private var backupFilename = PressBenchBackupDocument.defaultFilename()
    @State private var showingBackupExporter = false
    @State private var showingBackupImporter = false
    @State private var showingRestoreSuccess = false
    @State private var backupOperationInProgress = false
    @State private var pendingRestoreRaw = ""
    @State private var restoreSummary = ""

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        List {
            if let warning = store.persistenceWarning {
                Section {
                    Label(t("settings.storageRecoveryRequired"), systemImage: "externaldrive.badge.exclamationmark")
                        .font(.headline)
                        .foregroundStyle(PBTheme.warningInk)
                    Text(store.hasRejectedRun ? t("error.storageRecovery") : warning)
                        .font(.caption)
                        .foregroundStyle(PBTheme.secondary)
                        .textSelection(.enabled)
                    if store.hasRejectedRun {
                        Button(role: .destructive) { showingRejectedRunDiscardConfirmation = true } label: {
                            Label(t("run.discardRejected"), systemImage: "trash")
                                .pbFullSurfaceTarget()
                        }
                    }
                }
            }

            planSection
            backupSection

            Section {
                NavigationLink {
                    PreferencesSettingsView()
                        .environmentObject(store)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t("settings.general"))
                            Text("\(AppLanguageStorage.resolved(rawValue: languageRaw).nativeName) · °\(temperatureUnitRaw)")
                                .font(.caption)
                                .foregroundStyle(PBTheme.secondary)
                        }
                    } icon: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .pbFullSurfaceTarget()
                }
                .accessibilityIdentifier("pb.settings.general")
            }

            Section {
                DisclosureGroup {
                    Button { onboardingCompleted = false } label: {
                        Label(t("more.viewOnboarding"), systemImage: "arrow.counterclockwise")
                            .pbFullSurfaceTarget()
                    }
                    .disabled(store.activeRun != nil)
                    Link(destination: PressBenchPolicyLinks.support) {
                        Label(t("common.support"), systemImage: "questionmark.circle")
                            .pbFullSurfaceTarget()
                    }
                    Link(destination: PressBenchPolicyLinks.safety) {
                        Label(t("common.safetyNotice"), systemImage: "exclamationmark.triangle")
                            .pbFullSurfaceTarget()
                    }
                    Link(destination: PressBenchPolicyLinks.privacy) {
                        Label(t("common.privacyPolicy"), systemImage: "hand.raised")
                            .pbFullSurfaceTarget()
                    }
                    Link(destination: PressBenchPolicyLinks.terms) {
                        Label(t("common.termsOfUse"), systemImage: "doc.text")
                            .pbFullSurfaceTarget()
                    }
                    if language != .en {
                        Text(t("onboarding.legal.policyLanguageNotice"))
                            .font(.caption)
                            .foregroundStyle(PBTheme.secondary)
                    }
                } label: {
                    Label(t("settings.legalSupport"), systemImage: "questionmark.circle")
                        .pbFullSurfaceTarget()
                }
            }

            Section {
                DisclosureGroup {
                    Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                        Label(t("settings.deleteLocalData"), systemImage: "trash")
                            .pbFullSurfaceTarget()
                    }
                    .disabled(store.activeRun != nil)
                } label: {
                    Label(t("common.maintenance"), systemImage: "wrench.and.screwdriver")
                        .pbFullSurfaceTarget()
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 64)
        .scrollContentBackground(.hidden)
        .background(PBTheme.canvasGradient)
        .listRowSpacing(4)
        .tint(PBTheme.primary)
        .navigationTitle(t("settings.title"))
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showingUpgrade) {
            ProUpgradeView().environmentObject(store).pbEditorSheetStyle()
        }
        .confirmationDialog(t("common.localDataBackups"), isPresented: $showingRestoreConfirmation, titleVisibility: .visible) {
            Button(t("settings.restoreBackup"), role: .destructive) { restorePendingBackup() }
            Button(t("common.cancel"), role: .cancel) { pendingRestoreRaw = "" }
        } message: {
            Text(t("backup.restoreReplaces") + "\n" + restoreSummary)
        }
        .confirmationDialog(
            t("run.discardRejected"),
            isPresented: $showingRejectedRunDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(t("run.discardRejected"), role: .destructive) { discardRejectedRun() }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(PBL10n.format("run.discardRejectedConfirm", language: language, locale: locale,
                              store.rejectedRunLabel as NSString))
        }
        .confirmationDialog(t("settings.deleteLocalData"), isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button(t("settings.deleteLocalData"), role: .destructive) { deleteLocalData() }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t("settings.deleteLocalDataMessage"))
        }
        .alert("PressBench", isPresented: $failed) {
            Button(t("common.ok"), role: .cancel) {}
        } message: {
            Text(t(failureMessageKey))
        }
        .alert(t("settings.restoreBackup"), isPresented: $showingRestoreSuccess) {
            Button(t("common.ok"), role: .cancel) {}
        } message: {
            Text(t("runState.completed") + "\n" + restoreSummary)
        }
        .fileExporter(
            isPresented: $showingBackupExporter,
            document: backupDocument,
            contentType: .pressBenchBackup,
            defaultFilename: backupFilename,
            onCompletion: handleBackupExport
        )
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [.pressBenchBackup, .json],
            allowsMultipleSelection: false,
            onCompletion: handleBackupImport
        )
    }

    @ViewBuilder
    private var planSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label(t(store.isPro ? "common.purchasesPro" : "upgrade.title"),
                      systemImage: store.isPro ? "checkmark.seal.fill" : "infinity.circle.fill")
                    .font(.headline)
                    .foregroundStyle(store.isPro ? PBTheme.successInk : PBTheme.navy)
                if store.isPro {
                    Link(destination: store.canManageMonthlySubscription ?
                         PressBenchPolicyLinks.manageSubscription : PressBenchPolicyLinks.purchases) {
                        Label(t("upgrade.manage"), systemImage: "creditcard")
                            .pbFullSurfaceTarget()
                    }
                } else {
                    Text(PBL10n.format(
                        "usage.freeRunsRemaining", language: language, locale: locale,
                        PBFormat.integer(store.freePressesRemaining, locale: locale) as NSString,
                        PBFormat.integer(PBUsageMeter.freePressLimit, locale: locale) as NSString
                    ))
                    .font(.subheadline.weight(.bold))
                    Button { showingUpgrade = true } label: {
                        Text(t("common.unlockPro"))
                            .font(.headline)
                            .pbFullSurfaceTarget(alignment: .center)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pb.settings.plan")
                    Button { showingUpgrade = true } label: {
                        Text(t("upgrade.restore"))
                            .pbFullSurfaceTarget(alignment: .center)
                    }
                    .accessibilityIdentifier("pb.settings.restorePurchase")
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var backupSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label(t("backup.optionalTitle"), systemImage: "externaldrive.fill")
                    .font(.headline)
                    .foregroundStyle(PBTheme.navy)
                Text(t("backup.optionalBody"))
                    .font(.caption)
                    .foregroundStyle(PBTheme.secondary)
            }
            .padding(.vertical, 4)

            if backupLastSuccessAt > 0 {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("backup.lastSuccessful")).font(.subheadline.weight(.semibold))
                        Text(PBFormat.date(Date(timeIntervalSince1970: backupLastSuccessAt), locale: locale, time: true))
                            .font(.caption).foregroundStyle(PBTheme.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(PBTheme.successInk)
                }
                .accessibilityElement(children: .combine)
            }

            Button { prepareBackupExport() } label: {
                Label(t("settings.createBackup"), systemImage: "square.and.arrow.up")
                    .pbFullSurfaceTarget()
            }
            .disabled(backupOperationInProgress)
            .accessibilityIdentifier("pb.settings.backup")

            Button { showingBackupImporter = true } label: {
                Label(t("settings.importBackup"), systemImage: "square.and.arrow.down")
                    .pbFullSurfaceTarget()
            }
            .disabled(backupOperationInProgress || store.activeRun != nil || store.hasRejectedRun)
            .accessibilityIdentifier("pb.settings.restoreBackup")

            if backupOperationInProgress {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(t("common.localDataBackups"))
            }
        } header: {
            Text(t("common.localDataBackups"))
        }
    }

    private func deleteLocalData() {
        do {
            let resetTemperatureUnit = Locale.current.measurementSystem == .us ? "F" : "C"
            try store.deleteAllLocalData()
            store.updateTemperatureUnit(resetTemperatureUnit)
            store.selectedTab = 0
            languageRaw = AppLanguage.detected().rawValue
            temperatureUnitRaw = resetTemperatureUnit
            appearanceRaw = PBAppearancePreference.light.rawValue
            notificationsEnabled = false
            hapticsEnabled = true
            soundEnabled = true
            backupLastSuccessAt = 0
            onboardingCompleted = false
            PBTimerNotification.cancel()
        } catch {
            present(error)
        }
    }

    private func discardRejectedRun() {
        do {
            try store.discardRejectedRun()
            PBFeedback.warning()
        } catch { present(error) }
    }

    private func prepareBackupExport() {
        do {
            backupDocument = try PressBenchBackupDocument(payload: store.backupPayload())
            backupFilename = PressBenchBackupDocument.defaultFilename()
            showingBackupExporter = true
        } catch { present(error) }
    }

    private func handleBackupExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            backupLastSuccessAt = Date().timeIntervalSince1970
            backupDocument = nil
            PBFeedback.success()
        case .failure(let error as CocoaError) where error.code == .userCancelled:
            backupDocument = nil
        case .failure(let error):
            backupDocument = nil
            present(error)
        }
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            prepareRestore(from: url)
        case .failure(let error as CocoaError) where error.code == .userCancelled:
            break
        case .failure(let error):
            present(error)
        }
    }

    private func prepareRestore(from url: URL) {
        guard store.activeRun == nil else { present(PressBenchStore.StoreError.activeRunConflict); return }
        guard !store.hasRejectedRun else { present(PressBenchStore.StoreError.persistenceBlocked); return }
        backupOperationInProgress = true
        Task {
            do {
                let raw = try await Task.detached(priority: .userInitiated) {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                    guard values.isRegularFile == true,
                          (values.fileSize ?? 0) <= PressBenchBackupDocument.maximumBytes else {
                        throw PressBenchBackupDocument.BackupDocumentError.invalid
                    }
                    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                    return try PressBenchBackupDocument(data: data).rawPayload()
                }.value
                pendingRestoreRaw = raw
                let preview = try store.previewBackup(raw: raw)
                let dateLine = preview.exportedAt.map {
                    "\(t("backup.lastSuccessful")): \(PBFormat.date($0, locale: locale, time: true))\n"
                } ?? ""
                let contentLine = "\(preview.machines) · \(t("machines.title"))   \(preview.setups) · \(t("home.metric.setups"))   \(preview.batches) · \(t("home.metric.batches"))"
                let currentUsed = PBUsageMeter.freePressLimit - store.freePressesRemaining
                let restoredRemaining = max(0, PBUsageMeter.freePressLimit - max(currentUsed, preview.freeRunsUsed))
                let allowanceLine = PBL10n.format(
                    "usage.freeRunsRemaining", language: language, locale: locale,
                    PBFormat.integer(restoredRemaining, locale: locale) as NSString,
                    PBFormat.integer(PBUsageMeter.freePressLimit, locale: locale) as NSString
                )
                restoreSummary = dateLine + contentLine + "\n" + allowanceLine
                backupOperationInProgress = false
                showingRestoreConfirmation = true
            } catch {
                backupOperationInProgress = false
                pendingRestoreRaw = ""
                failureMessageKey = "error.backupRestore"
                failed = true
                PBFeedback.error()
            }
        }
    }

    private func restorePendingBackup() {
        do {
            try store.restoreBackup(raw: pendingRestoreRaw)
            pendingRestoreRaw = ""
            showingRestoreSuccess = true
            PBFeedback.success()
        } catch { present(error) }
    }

    private func present(_ error: Error) {
        failureMessageKey = store.errorLocalizationKey(error)
        failed = true
        PBFeedback.error()
    }
}

private struct PreferencesSettingsView: View {
    @EnvironmentObject private var store: PressBenchStore
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue
    @AppStorage("pressbench.temperature.unit") private var temperatureUnitRaw = Locale.current.measurementSystem == .us ? "F" : "C"
    @AppStorage("pressbench.notifications.enabled") private var notificationsEnabled = false
    @AppStorage("pressbench.haptics.enabled") private var hapticsEnabled = true
    @AppStorage("pressbench.sound.enabled") private var soundEnabled = true
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var showingNotificationSettings = false

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { AppLanguageStorage.resolved(rawValue: languageRaw) },
            set: { newValue in
                languageRaw = newValue.rawValue
                store.updateLanguage(newValue, locale: Locale.current)
            }
        )
    }

    private var temperatureBinding: Binding<String> {
        Binding(
            get: { temperatureUnitRaw },
            set: { newValue in
                temperatureUnitRaw = newValue
                store.updateTemperatureUnit(newValue)
            }
        )
    }

    var body: some View {
        List {
            Section {
                LanguageDropdown(selection: languageBinding, titleKey: "common.language", systemImage: "globe")
                Picker(selection: temperatureBinding) {
                    Text("°F").tag("F")
                    Text("°C").tag("C")
                } label: {
                    Label(t("settings.temperatureUnit"), systemImage: "thermometer.medium")
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Label(t("common.notifications"), systemImage: "bell.badge")
                }
                Toggle(isOn: $hapticsEnabled) {
                    Label(t("settings.hapticFeedback"), systemImage: "hand.tap")
                }
                Toggle(isOn: $soundEnabled) {
                    Label(t("settings.timerSound"), systemImage: "speaker.wave.2")
                }
                NavigationLink { AccessibilitySettingsView() } label: {
                    Label(t("common.accessibility"), systemImage: "accessibility")
                        .pbFullSurfaceTarget()
                }
            }
            .tint(PBTheme.primary)
        }
        .environment(\.defaultMinListRowHeight, 64)
        .scrollContentBackground(.hidden)
        .background(PBTheme.canvasGradient)
        .tint(PBTheme.primary)
        .navigationTitle(t("settings.general"))
        .onChange(of: hapticsEnabled) { _, _ in syncPresentationPreferences() }
        .onChange(of: soundEnabled) { _, _ in syncPresentationPreferences() }
        .onChange(of: notificationsEnabled) { _, enabled in
            if enabled {
                Task {
                    let allowed = await PBTimerNotification.requestPermissionIfNeeded()
                    guard !allowed else { return }
                    await MainActor.run {
                        notificationsEnabled = false
                        showingNotificationSettings = true
                    }
                }
            } else {
                PBTimerNotification.cancel()
            }
        }
        .alert(t("common.notifications"), isPresented: $showingNotificationSettings) {
            Button(t("accessibility.openSettings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t("common.notifications") + ". " + t("accessibility.openSettings") + ".")
        }
    }

    private func syncPresentationPreferences() {
        store.updatePresentationPreferences(haptics: hapticsEnabled, sound: soundEnabled,
                                            theme: PBAppearancePreference.light.rawValue)
    }
}

private struct AccessibilitySettingsView: View {
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        List {
            Section {
                LabeledContent {
                    Text(t("accessibility.systemManaged")).foregroundStyle(PBTheme.secondary)
                } label: {
                    Label(t("accessibility.textSize"), systemImage: "textformat.size")
                }
                accessibilityStateRow("accessibility.reduceMotion", enabled: reduceMotion, icon: "figure.walk.motion")
                accessibilityStateRow("accessibility.differentiateWithoutColor", enabled: differentiateWithoutColor, icon: "circle.lefthalf.striped.horizontal")
            }

            Section {
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label(t("accessibility.openSettings"), systemImage: "gearshape")
                        .pbFullSurfaceTarget()
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 64)
        .scrollContentBackground(.hidden)
        .background(PBTheme.canvasGradient)
        .tint(PBTheme.primary)
        .navigationTitle(t("common.accessibility"))
    }

    private func accessibilityStateRow(_ key: String, enabled: Bool, icon: String) -> some View {
        LabeledContent {
            Text(t(enabled ? "accessibility.enabled" : "accessibility.disabled"))
                .foregroundStyle(PBTheme.secondary)
        } label: {
            Label(t(key), systemImage: icon)
        }
        .accessibilityValue(t(enabled ? "accessibility.enabled" : "accessibility.disabled"))
    }
}
