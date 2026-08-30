import AuthenticationServices
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
    @AppStorage("pressbench.apple.user.id") private var appleUserID = ""
    @AppStorage("pressbench.backup.lastSuccessAt") private var backupLastSuccessAt = 0.0
    @AppStorage("pressbench.backup.lastSuccessOwner") private var backupLastSuccessOwner = ""
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var showingDeleteConfirmation = false
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @State private var showingRestoreConfirmation = false
    @State private var showingRollbackConfirmation = false
    @State private var showingRejectedRunDiscardConfirmation = false
    @State private var showingUpgrade = false
    @State private var privacyOptionsAvailable = false
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
                }
            }

            Section {
                DisclosureGroup {
                    Button { onboardingCompleted = false } label: {
                        Label(t("more.viewOnboarding"), systemImage: "arrow.counterclockwise")
                    }
                    .disabled(store.activeRun != nil)
                    Link(destination: PressBenchPolicyLinks.support) {
                        Label(t("common.support"), systemImage: "questionmark.circle")
                    }
                    Link(destination: PressBenchPolicyLinks.safety) {
                        Label(t("common.safetyNotice"), systemImage: "exclamationmark.triangle")
                    }
                    Link(destination: PressBenchPolicyLinks.privacy) {
                        Label(t("common.privacyPolicy"), systemImage: "hand.raised")
                    }
                    Link(destination: PressBenchPolicyLinks.terms) {
                        Label(t("common.termsOfUse"), systemImage: "doc.text")
                    }
                    if !store.isPro {
                        Link(destination: PressBenchPolicyLinks.reportAd) {
                            Label(t("ads.report"), systemImage: "exclamationmark.bubble")
                        }
                        if privacyOptionsAvailable {
                            Button { presentPrivacyOptions() } label: {
                                Label(t("ads.privacyChoices"), systemImage: "checkmark.shield")
                            }
                        }
                    }
                    if language != .en {
                        Text(t("onboarding.legal.policyLanguageNotice"))
                            .font(.caption)
                            .foregroundStyle(PBTheme.secondary)
                    }
                } label: {
                    Label(t("settings.legalSupport"), systemImage: "questionmark.circle")
                }
            }

            Section {
                DisclosureGroup {
                    if store.hasRestoreRecovery {
                        Button { showingRollbackConfirmation = true } label: {
                            Label(t("settings.rollbackRestore"), systemImage: "arrow.uturn.backward.circle")
                        }
                        .disabled(store.activeRun != nil || store.hasRejectedRun)
                    }
                    Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                        Label(t("settings.deleteLocalData"), systemImage: "trash")
                    }
                    .disabled(store.activeRun != nil)
                } label: {
                    Label(t("common.maintenance"), systemImage: "wrench.and.screwdriver")
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
        .confirmationDialog(t("settings.rollbackRestore"), isPresented: $showingRollbackConfirmation, titleVisibility: .visible) {
            Button(t("settings.rollbackRestore"), role: .destructive) { rollbackRestore() }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t("backup.rollbackWarning"))
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
        .task(id: store.adEligibilityResolved) {
            guard store.adEligibilityResolved, !store.isPro else { return }
            _ = await PBAdvertising.prepareForAds()
            privacyOptionsAvailable = PBAdvertising.privacyOptionsRequired
        }
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
                            .frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget, alignment: .leading)
                    }
                } else {
                    Text(PBL10n.format(
                        "usage.freeRunsRemaining", language: language, locale: locale,
                        PBFormat.integer(store.freePressesRemaining, locale: locale) as NSString,
                        PBFormat.integer(PBUsageMeter.freePressLimit, locale: locale) as NSString
                    ))
                    .font(.subheadline.weight(.bold))
                    Button { showingUpgrade = true } label: {
                        Label(t("common.unlockPro"), systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pb.settings.plan")
                    Button(t("upgrade.restore")) { showingUpgrade = true }
                        .frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var backupSection: some View {
        Section {
            if appleUserID.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(t("backup.optionalTitle"), systemImage: "icloud")
                        .font(.headline)
                        .foregroundStyle(PBTheme.navy)
                    Text(t("backup.optionalBody"))
                        .font(.caption)
                        .foregroundStyle(PBTheme.secondary)
                    SignInWithAppleButton(.continue, onRequest: { $0.requestedScopes = [] }, onCompletion: handleAppleSignIn)
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .accessibilityIdentifier("pb.settings.backup")
                }
                .padding(.vertical, 4)
            } else {
                if backupLastSuccessAt > 0 && backupLastSuccessOwner == appleUserID {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t("backup.lastSuccessful")).font(.subheadline.weight(.semibold))
                            Text(PBFormat.date(Date(timeIntervalSince1970: backupLastSuccessAt), locale: locale, time: true))
                                .font(.caption).foregroundStyle(PBTheme.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.icloud.fill").foregroundStyle(PBTheme.successInk)
                    }
                    .accessibilityElement(children: .combine)
                }
                Button { createBackup() } label: {
                    Label(t("backup.backupNow"), systemImage: "icloud.and.arrow.up")
                }
                DisclosureGroup {
                    Button { prepareAppleRestore() } label: {
                        Label(t("backup.restore"), systemImage: "icloud.and.arrow.down")
                    }
                    .disabled(store.activeRun != nil || store.hasRejectedRun)
                    Button(role: .destructive) { signOutOfBackup() } label: {
                        Label(t("backup.signOut"), systemImage: "person.crop.circle.badge.xmark")
                    }
                } label: {
                    Label(t("common.localDataBackups"), systemImage: "ellipsis.circle")
                }
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
            AppleBackupService.signOut()
            appleUserID = ""
            backupLastSuccessAt = 0
            backupLastSuccessOwner = ""
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

    private func createBackup() {
        do {
            try AppleBackupService.backup(payload: store.backupPayload())
            PBFeedback.success()
        } catch { present(error) }
    }

    private func prepareAppleRestore() {
        guard store.activeRun == nil else { present(PressBenchStore.StoreError.activeRunConflict); return }
        guard !store.hasRejectedRun else { present(PressBenchStore.StoreError.persistenceBlocked); return }
        do {
            pendingRestoreRaw = try AppleBackupService.restoredPayload()
            if let data = pendingRestoreRaw.data(using: .utf8),
               let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let machines = (object["machines"] as? [Any])?.count ?? 0
                let setups = (object["setups"] as? [Any])?.count ?? (object["recipes"] as? [Any])?.count ?? 0
                let batches = (object["batches"] as? [Any])?.count ?? 0
                restoreSummary = "\(machines) · \(t("machines.title"))   \(setups) · \(t("home.metric.setups"))   \(batches) · \(t("home.metric.batches"))"
            }
            showingRestoreConfirmation = true
        } catch { present(error) }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                failureMessageKey = "backup.signInFailed"; failed = true; return
            }
            if appleUserID != credential.user {
                backupLastSuccessAt = 0
                backupLastSuccessOwner = ""
            }
            AppleBackupService.saveSignedInUser(credential.user)
            appleUserID = credential.user
            createBackup()
        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            break
        case .failure:
            failureMessageKey = "backup.signInFailed"; failed = true
        }
    }

    private func restorePendingBackup() {
        do {
            try store.restoreBackup(raw: pendingRestoreRaw)
            pendingRestoreRaw = ""
            PBFeedback.success()
        } catch { present(error) }
    }

    private func rollbackRestore() {
        do {
            try store.rollbackRestore()
            PBFeedback.success()
        } catch { present(error) }
    }

    private func signOutOfBackup() {
        AppleBackupService.signOut()
        appleUserID = ""
        backupLastSuccessAt = 0
        backupLastSuccessOwner = ""
    }

    private func presentPrivacyOptions() {
        Task {
            let shown = await PBAdvertising.presentPrivacyOptions()
            privacyOptionsAvailable = PBAdvertising.privacyOptionsRequired
            if !shown {
                failureMessageKey = "common.actionFailed"
                failed = true
            }
        }
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
