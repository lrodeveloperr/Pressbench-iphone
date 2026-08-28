import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: PressBenchStore
    @EnvironmentObject private var appleBackup: AppleBackupManager
    @AppStorage("pressbench.onboarding.completed") private var onboardingCompleted = true
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue
    @AppStorage("pressbench.temperature.unit") private var temperatureUnitRaw = Locale.current.measurementSystem == .us ? "F" : "C"
    @AppStorage(PBAppearancePreference.storageKey) private var appearanceRaw = PBAppearancePreference.system.rawValue
    @AppStorage("pressbench.notifications.enabled") private var notificationsEnabled = true
    @AppStorage("pressbench.haptics.enabled") private var hapticsEnabled = true
    @AppStorage("pressbench.sound.enabled") private var soundEnabled = false
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var showingDeleteConfirmation = false
    @State private var backupURL: URL?
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @State private var showingCloudRestoreConfirmation = false
    @State private var showingTurnOffConfirmation = false
    @State private var showingDeleteCloudBackupConfirmation = false

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
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(PBTheme.secondary)
                        .textSelection(.enabled)
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
                if appleBackup.isCheckingCredential {
                    HStack {
                        ProgressView()
                        Text(t("backup.checking"))
                            .foregroundStyle(PBTheme.secondary)
                    }
                } else if appleBackup.isEnabled {
                    Label(t("backup.enabled"), systemImage: "checkmark.icloud.fill")
                        .foregroundStyle(PBTheme.successInk)

                    if let date = appleBackup.lastBackupDate {
                        LabeledContent(t("backup.lastBackup")) {
                            Text(PBFormat.date(date, locale: locale, time: true))
                                .foregroundStyle(PBTheme.secondary)
                        }
                    } else {
                        Label(t("backup.never"), systemImage: "clock")
                            .foregroundStyle(PBTheme.secondary)
                    }

                    Button { Task { await backUpNow() } } label: {
                        Label { Text(t("backup.backUpNow")) } icon: { Image(systemName: "icloud.and.arrow.up") }
                    }
                    .disabled(appleBackup.isWorking)

                    Button { showingCloudRestoreConfirmation = true } label: {
                        Label { Text(t("backup.restore")) } icon: { Image(systemName: "arrow.clockwise.icloud") }
                    }
                    .disabled(appleBackup.isWorking)

                    Button(role: .destructive) { showingTurnOffConfirmation = true } label: {
                        Label { Text(t("backup.turnOff")) } icon: { Image(systemName: "icloud.slash") }
                    }
                    .disabled(appleBackup.isWorking)

                    Button(role: .destructive) { showingDeleteCloudBackupConfirmation = true } label: {
                        Label { Text(t("backup.delete")) } icon: { Image(systemName: "trash") }
                    }
                    .disabled(appleBackup.isWorking || appleBackup.lastBackupDate == nil)
                } else {
                    Text(t("backup.settingsBody"))
                        .font(.subheadline)
                        .foregroundStyle(PBTheme.secondary)
                    PBSignInWithAppleButton()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            } header: {
                Text(t("backup.title"))
            }

            Section {
                NavigationLink { ReportsView() } label: {
                    Label { Text(t("common.exports")) } icon: { Image(systemName: "square.and.arrow.up") }
                }
                Button { createBackup() } label: {
                    Label { Text(t("settings.createBackup")) } icon: { Image(systemName: "arrow.down.doc") }
                }
                if let backupURL {
                    ShareLink(item: backupURL) {
                        Label { Text(t("settings.shareBackup")) } icon: { Image(systemName: "square.and.arrow.up") }
                    }
                }
                if store.hasRestoreRecovery {
                    Button { rollbackRestore() } label: {
                        Label { Text(t("settings.rollbackRestore")) } icon: { Image(systemName: "arrow.uturn.backward.circle") }
                    }
                }
                Button { onboardingCompleted = false } label: {
                    Label { Text(t("more.viewOnboarding")) } icon: { Image(systemName: "arrow.counterclockwise") }
                }
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
        .confirmationDialog(t("backup.restore"), isPresented: $showingCloudRestoreConfirmation, titleVisibility: .visible) {
            Button(t("backup.restore"), role: .destructive) { Task { await restoreFromICloud() } }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t("backup.restoreWarning"))
        }
        .confirmationDialog(t("backup.turnOff"), isPresented: $showingTurnOffConfirmation, titleVisibility: .visible) {
            Button(t("backup.turnOff"), role: .destructive) { appleBackup.turnOff() }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t("backup.turnOffWarning"))
        }
        .confirmationDialog(t("backup.delete"), isPresented: $showingDeleteCloudBackupConfirmation, titleVisibility: .visible) {
            Button(t("backup.delete"), role: .destructive) { Task { await deleteCloudBackup() } }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t("backup.deleteWarning"))
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
            appleBackup.turnOff()
            store.selectedTab = 0
            languageRaw = AppLanguage.detected().rawValue
            temperatureUnitRaw = Locale.current.measurementSystem == .us ? "F" : "C"
            appearanceRaw = PBAppearancePreference.system.rawValue
            notificationsEnabled = true
            hapticsEnabled = true
            soundEnabled = false
            onboardingCompleted = false
            PBTimerNotification.cancel()
        } catch {
            present(error)
        }
    }

    private func createBackup() {
        do {
            let data = try JSONSerialization.data(withJSONObject: store.backupPayload(), options: [.prettyPrinted, .sortedKeys])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("PressBench-Backup.json")
            try data.write(to: url, options: .atomic)
            backupURL = url
            PBFeedback.success()
        } catch { present(error) }
    }

    private func backUpNow() async {
        do {
            try await appleBackup.backUpNow()
            PBFeedback.success()
        } catch { presentBackup(error) }
    }

    private func restoreFromICloud() async {
        do {
            try await appleBackup.restoreFromICloud()
            PBFeedback.success()
        } catch { presentBackup(error) }
    }

    private func deleteCloudBackup() async {
        do {
            try await appleBackup.deleteFromICloud()
            PBFeedback.success()
        } catch { presentBackup(error) }
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

    private func presentBackup(_ error: Error) {
        if let backupError = error as? AppleBackupError {
            failureMessageKey = backupError.localizationKey
        } else {
            failureMessageKey = store.errorLocalizationKey(error)
        }
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
