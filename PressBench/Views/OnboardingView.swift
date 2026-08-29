import AuthenticationServices
import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    private enum Step {
        case preferences
        case legal
        case backup
    }

    @Binding var completed: Bool
    @EnvironmentObject private var store: PressBenchStore
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue
    @AppStorage("pressbench.temperature.unit") private var temperatureUnitRaw = Locale.current.measurementSystem == .us ? "F" : "C"
    @State private var step: Step = .preferences
    @State private var acceptedPolicies = false
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Spacer(minLength: 8)
                    BrandLogo(size: 76)

                    Group {
                        switch step {
                        case .preferences:
                            preferencesStep
                        case .legal:
                            legalStep
                        case .backup:
                            backupStep
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, PBTheme.pagePadding)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .background(PBTheme.canvasGradient.ignoresSafeArea()).tint(PBTheme.primary)
        .alert("PressBench", isPresented: $failed) {
            Button(t("accessibility.openSettings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button(t("common.ok"), role: .cancel) {}
        } message: { Text(t(failureMessageKey)) }
    }

    private var preferencesStep: some View {
        VStack(spacing: 16) {
            Text(t("onboarding.welcome.title"))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(PBTheme.navy)

            PBCard {
                VStack(spacing: 10) {
                    LanguageDropdown(selection: selectedLanguage, titleKey: "common.language", systemImage: "globe")
                    Divider().opacity(0.35)
                    VStack(alignment: .leading, spacing: 8) {
                        Label(t("settings.temperatureUnit"), systemImage: "thermometer.medium")
                            .font(.headline)
                        Picker(t("settings.temperatureUnit"), selection: $temperatureUnitRaw) {
                            Text("°F").tag("F")
                            Text("°C").tag("C")
                        }
                        .pickerStyle(.segmented)
                        .frame(minHeight: PBTheme.minimumTarget)
                        .accessibilityIdentifier("pb.onboarding.temperatureUnit")
                    }
                }
            }

            PBPrimaryButton(title: t("common.continue")) {
                withAnimation(.easeInOut) { step = .legal }
            }
            .accessibilityIdentifier("pb.onboarding.continue")
        }
    }

    private var legalStep: some View {
        VStack(spacing: 16) {
            Text(t("onboarding.legal.title"))
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(PBTheme.navy)

            PBCard {
                VStack(spacing: 0) {
                    PolicyLinkRow(titleKey: "common.termsOfUse", icon: "doc.text", url: PressBenchPolicyLinks.terms)
                    Divider().opacity(0.35)
                    PolicyLinkRow(titleKey: "common.privacyPolicy", icon: "hand.raised", url: PressBenchPolicyLinks.privacy)
                    Divider().opacity(0.35)
                    PolicyLinkRow(titleKey: "common.heatPressSafetyNotice", icon: "exclamationmark.triangle", url: PressBenchPolicyLinks.safety)
                }
            }

            CombinedPolicyAcknowledgement(isOn: $acceptedPolicies)

            PBPrimaryButton(title: t("common.continue")) {
                withAnimation(.easeInOut) { step = .backup }
            }
            .disabled(!acceptedPolicies)
            .accessibilityIdentifier("pb.onboarding.continue")
        }
    }

    private var backupStep: some View {
        VStack(spacing: 14) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(PBTheme.primary)
            Text(t("backup.optionalTitle"))
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(PBTheme.navy)
            Text(t("backup.optionalBody"))
                .font(.subheadline)
                .foregroundStyle(PBTheme.secondary)
                .multilineTextAlignment(.center)
            SignInWithAppleButton(.continue, onRequest: { $0.requestedScopes = [] }, onCompletion: handleAppleSignIn)
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .accessibilityIdentifier("pb.onboarding.appleBackup")
            Button(t("backup.continueWithout")) { finishOnboarding() }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget)
                .accessibilityIdentifier("pb.onboarding.skipBackup")
        }
    }

    private var selectedLanguage: Binding<AppLanguage> {
        Binding(get: { AppLanguageStorage.resolved(rawValue: languageRaw) }, set: { languageRaw = $0.rawValue })
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                failureMessageKey = "backup.signInFailed"; failed = true; return
            }
            AppleBackupService.saveSignedInUser(credential.user)
            finishOnboarding(backUpAfterward: true)
        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            break
        case .failure:
            failureMessageKey = "backup.signInFailed"; failed = true
        }
    }

    private func finishOnboarding(backUpAfterward: Bool = false) {
        do {
            let chosen = AppLanguageStorage.resolved(rawValue: languageRaw)
            try store.completeOnboarding(language: chosen, locale: .current, temperatureUnit: temperatureUnitRaw)
            if backUpAfterward { try AppleBackupService.backup(payload: store.backupPayload()) }
            completed = true
        } catch {
            failureMessageKey = store.errorLocalizationKey(error); failed = true
        }
    }
}

struct BrandLogo: View {
    var size: CGFloat
    var body: some View {
        Image("BrandLogo").resizable().scaledToFit().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: PBTheme.cardShadow, radius: 11, y: 5).accessibilityLabel("PressBench")
    }
}

private struct PolicyLinkRow: View {
    let titleKey: String; let icon: String; let url: URL
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    var body: some View {
        Link(destination: url) {
            HStack(spacing: 13) {
                Image(systemName: icon).frame(width: 25).foregroundStyle(PBTheme.primary)
                Text(PBL10n.text(titleKey, language: language, locale: locale)).font(.headline).foregroundStyle(.primary)
                Spacer(); Image(systemName: "arrow.up.forward").foregroundStyle(PBTheme.secondary)
            }.frame(minHeight: PBTheme.minimumTarget).padding(.vertical, 8)
        }
    }
}

private struct CombinedPolicyAcknowledgement: View {
    @Binding var isOn: Bool
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square").font(.title3)
                    .foregroundStyle(isOn ? PBTheme.primary : PBTheme.secondary)
                Text([
                    PBL10n.text("onboarding.legal.acceptTerms", language: language, locale: locale),
                    PBL10n.text("common.privacyPolicy", language: language, locale: locale),
                    PBL10n.text("common.safetyNotice", language: language, locale: locale)
                ].joined(separator: " · "))
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                Spacer()
            }.frame(minHeight: PBTheme.minimumTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pb.onboarding.accept")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityValue(PBL10n.text(
            isOn ? "accessibility.enabled" : "accessibility.disabled",
            language: language,
            locale: locale
        ))
    }
}
