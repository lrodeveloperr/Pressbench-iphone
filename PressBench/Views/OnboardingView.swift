import AuthenticationServices
import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    @Binding var completed: Bool
    @EnvironmentObject private var store: PressBenchStore
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue
    @AppStorage("pressbench.temperature.unit") private var temperatureUnitRaw = Locale.current.measurementSystem == .us ? "F" : "C"
    @State private var acceptedTerms = false
    @State private var acknowledgedSafety = false
    @State private var viewedPrivacy = false
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var ready: Bool { acceptedTerms && acknowledgedSafety && viewedPrivacy }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                BrandLogo(size: 92)
                Text(t("onboarding.welcome.title"))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center).foregroundStyle(PBTheme.navy)
                Text(t("onboarding.welcome.subtitle"))
                    .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(PBTheme.secondary)

                PBCard {
                    VStack(spacing: 12) {
                        LanguageDropdown(selection: selectedLanguage, titleKey: "common.language", systemImage: "globe")
                        Divider()
                        Picker(t("settings.temperatureUnit"), selection: $temperatureUnitRaw) {
                            Text("°F").tag("F"); Text("°C").tag("C")
                        }
                        .pickerStyle(.segmented).frame(minHeight: PBTheme.minimumTarget)
                    }
                }

                PBCard {
                    VStack(spacing: 0) {
                        PolicyLinkRow(titleKey: "common.termsOfUse", icon: "doc.text", url: PressBenchPolicyLinks.terms)
                        Divider().opacity(0.35)
                        PolicyLinkRow(titleKey: "common.heatPressSafetyNotice", icon: "exclamationmark.triangle", url: PressBenchPolicyLinks.safety)
                        Divider().opacity(0.35)
                        PolicyLinkRow(titleKey: "common.privacyPolicy", icon: "hand.raised", url: PressBenchPolicyLinks.privacy)
                    }
                }

                VStack(spacing: 8) {
                    AcknowledgementRow(isOn: $acceptedTerms, titleKey: "onboarding.legal.acceptTerms")
                    AcknowledgementRow(isOn: $acknowledgedSafety, titleKey: "onboarding.legal.ackSafety")
                    AcknowledgementRow(isOn: $viewedPrivacy, titleKey: "onboarding.legal.reviewPrivacy")
                }.padding(.horizontal, 4)

                if ready {
                    VStack(spacing: 10) {
                        Text(t("backup.optionalTitle")).font(.headline).foregroundStyle(PBTheme.navy)
                        Text(t("backup.optionalBody")).font(.caption).foregroundStyle(PBTheme.secondary)
                            .multilineTextAlignment(.center)
                        SignInWithAppleButton(.continue, onRequest: { $0.requestedScopes = [] }, onCompletion: handleAppleSignIn)
                            .signInWithAppleButtonStyle(.black).frame(height: 54)
                        Button(t("backup.continueWithout")) { finishOnboarding() }
                            .font(.headline).frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget)
                    }
                } else {
                    Label(t("onboarding.completeChecks"), systemImage: "checkmark.square")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(PBTheme.warningInk)
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
            }
            .padding(.horizontal, PBTheme.pagePadding).padding(.vertical, 18)
        }
        .background(PBTheme.canvasGradient.ignoresSafeArea()).tint(PBTheme.primary)
        .alert("PressBench", isPresented: $failed) {
            Button(t("accessibility.openSettings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button(t("common.ok"), role: .cancel) {}
        } message: { Text(t(failureMessageKey)) }
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

private struct AcknowledgementRow: View {
    @Binding var isOn: Bool; let titleKey: String
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square").font(.title3)
                    .foregroundStyle(isOn ? PBTheme.primary : PBTheme.secondary)
                Text(PBL10n.text(titleKey, language: language, locale: locale)).font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
                Spacer()
            }.frame(minHeight: PBTheme.minimumTarget)
        }.buttonStyle(.plain)
    }
}
