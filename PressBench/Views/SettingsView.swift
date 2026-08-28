import AuthenticationServices
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: PressBenchStore
    @AppStorage("pressbench.onboarding.completed") private var onboardingCompleted = true
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue
    @AppStorage("pressbench.temperature.unit") private var temperatureUnitRaw = Locale.current.measurementSystem == .us ? "F" : "C"
    @AppStorage(PBAppearancePreference.storageKey) private var appearanceRaw = PBAppearancePreference.system.rawValue
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
    @State private var showingNotificationSettings = false
    @State private var showingRestoreConfirmation = false
    @State private var showingRollbackConfirmation = false
    @State private var showingRejectedRunDiscardConfirmation = false
    @State private var pendingRestoreRaw = ""
    @State private var restoreSummary = ""

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

            Section {
                LanguageDropdown(selection: languageBinding, titleKey: "common.language", systemImage: "globe")

                Picker(selection: temperatureBinding) {
                    Text("°F").tag("F")
                    Text("°C").tag("C")
                } label: {
                    Label { Text(t("settings.temperatureUnit")) } icon: { Image(systemName: "thermometer.medium") }
                }
                .pickerStyle(.menu)

                Picker(selection: $appearanceRaw) {
                    ForEach(PBAppearancePreference.allCases) { option in
                        Text(t(option.localizationKey)).tag(option.rawValue)
                    }
                } label: {
                    Label { Text(t("settings.appearance")) } icon: { Image(systemName: "circle.lefthalf.filled") }
                }
                .pickerStyle(.menu)

                Toggle(isOn: $notificationsEnabled) {
                    Label { Text(t("common.notifications")) } icon: { Image(systemName: "bell.badge") }
                }
                .tint(PBTheme.primary)

                Toggle(isOn: $hapticsEnabled) {
                    Label { Text(t("settings.hapticFeedback")) } icon: { Image(systemName: "hand.tap") }
                }
                .tint(PBTheme.primary)

                Toggle(isOn: $soundEnabled) {
                    Label { Text(t("settings.timerSound")) } icon: { Image(systemName: "speaker.wave.2") }
                }
                .tint(PBTheme.primary)
            } header: {
                Text(t("settings.general"))
            }

            Section {
                NavigationLink { ReportsView() } label: {
                    Label { Text(t("common.exports")) } icon: { Image(systemName: "square.and.arrow.up") }
                }
                if !appleUserID.isEmpty {
                    Button { createBackup() } label: {
                        Label { Text(t("backup.backupNow")) } icon: { Image(systemName: "icloud.and.arrow.up") }
                    }
                    Button { prepareAppleRestore() } label: {
                        Label { Text(t("backup.restore")) } icon: { Image(systemName: "icloud.and.arrow.down") }
                    }
                    .disabled(store.activeRun != nil || store.hasRejectedRun)
                    Button(role: .destructive) {
                        AppleBackupService.signOut()
                        appleUserID = ""
                        backupLastSuccessAt = 0
                        backupLastSuccessOwner = ""
                    } label: {
                        Label { Text(t("backup.signOut")) } icon: { Image(systemName: "person.crop.circle.badge.xmark") }
                    }
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
                } else {
                    SignInWithAppleButton(.continue, onRequest: { $0.requestedScopes = [] }, onCompletion: handleAppleSignIn)
                        .signInWithAppleButtonStyle(.black).frame(height: 52).listRowInsets(EdgeInsets())
                }
                if store.hasRestoreRecovery {
                    Button { showingRollbackConfirmation = true } label: {
                        Label { Text(t("settings.rollbackRestore")) } icon: { Image(systemName: "arrow.uturn.backward.circle") }
                    }
                    .disabled(store.activeRun != nil || store.hasRejectedRun)
                }
                Button { onboardingCompleted = false } label: {
                    Label { Text(t("more.viewOnboarding")) } icon: { Image(systemName: "arrow.counterclockwise") }
                }
                .disabled(store.activeRun != nil)
                Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                    Label { Text(t("settings.deleteLocalData")) } icon: { Image(systemName: "trash") }
                }
                .disabled(store.activeRun != nil)
            } header: {
                Text(t("common.localDataBackups"))
            }

            Section {
                NavigationLink { AccessibilitySettingsView() } label: {
                    Label { Text(t("common.accessibility")) } icon: { Image(systemName: "accessibility") }
                }
            } header: {
                Text(t("common.accessibility"))
            }

            Section {
                Link(destination: PressBenchPolicyLinks.privacy) { Label { Text(t("common.privacyPolicy")) } icon: { Image(systemName: "hand.raised") } }
                Link(destination: PressBenchPolicyLinks.terms) { Label { Text(t("common.termsOfUse")) } icon: { Image(systemName: "doc.text") } }
                Link(destination: PressBenchPolicyLinks.safety) { Label { Text(t("common.safetyNotice")) } icon: { Image(systemName: "exclamationmark.triangle") } }
                Link(destination: PressBenchPolicyLinks.support) { Label { Text(t("common.support")) } icon: { Image(systemName: "questionmark.circle") } }
                if language != .en {
                    Text(t("onboarding.legal.policyLanguageNotice"))
                        .font(.caption)
                        .foregroundStyle(PBTheme.secondary)
                }
            } header: {
                Text(t("settings.legalSupport"))
            }
        }
        .environment(\.defaultMinListRowHeight, 64)
        .scrollContentBackground(.hidden)
        .background(PBTheme.canvasGradient)
        .listRowSpacing(4)
        .tint(PBTheme.primary)
        .navigationTitle(t("settings.title"))
        .onChange(of: hapticsEnabled) { _, _ in syncPresentationPreferences() }
        .onChange(of: soundEnabled) { _, _ in syncPresentationPreferences() }
        .onChange(of: appearanceRaw) { _, _ in syncPresentationPreferences() }
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

    private func deleteLocalData() {
        do {
            try store.deleteAllLocalData()
            store.selectedTab = 0
            languageRaw = AppLanguage.detected().rawValue
            temperatureUnitRaw = Locale.current.measurementSystem == .us ? "F" : "C"
            appearanceRaw = PBAppearancePreference.system.rawValue
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

    private func syncPresentationPreferences() {
        store.updatePresentationPreferences(haptics: hapticsEnabled, sound: soundEnabled, theme: appearanceRaw)
    }

    private func present(_ error: Error) {
        failureMessageKey = store.errorLocalizationKey(error)
        failed = true
        PBFeedback.error()
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
