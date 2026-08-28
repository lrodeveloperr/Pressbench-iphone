import SwiftUI
import AuthenticationServices

struct OnboardingFlowView: View {
    @Binding var completed: Bool
    @EnvironmentObject private var store: PressBenchStore
    @EnvironmentObject private var appleBackup: AppleBackupManager

    @State private var page = 0
    @AppStorage(AppLanguageStorage.key) private var languageRaw = AppLanguage.detected().rawValue
    @AppStorage("pressbench.temperature.unit") private var temperatureUnitRaw = Locale.current.measurementSystem == .us ? "F" : "C"
    @State private var acceptedTerms = false
    @State private var acknowledgedSafety = false
    @State private var viewedPrivacy = false
    @State private var showingRestoreConfirmation = false
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageCount = 4
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        ZStack {
            PBPageBackground()
            VStack(spacing: 0) {
                topBar
                TabView(selection: $page) {
                    welcome.tag(0)
                    legalAndSafety.tag(1)
                    temperature.tag(2)
                    appleBackupPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .snappy, value: page)

                footer
            }
        }
        .tint(PBTheme.primary)
        .confirmationDialog(t("backup.restore"), isPresented: $showingRestoreConfirmation, titleVisibility: .visible) {
            Button(t("backup.restore"), role: .destructive) {
                Task { await restoreFromICloud() }
            }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t("backup.restoreWarning"))
        }
        .alert("PressBench", isPresented: $failed) {
            Button(t("common.ok"), role: .cancel) {}
        } message: {
            Text(t(failureMessageKey))
        }
    }

    private var topBar: some View {
        HStack {
            if page > 0 {
                Button {
                    if reduceMotion { page -= 1 }
                    else { withAnimation { page -= 1 } }
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.headline.weight(.semibold))
                        .frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)
                }
                .accessibilityLabel(t("common.back"))
            } else {
                Color.clear.frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)
            }

            Spacer()

            Text(PBL10n.format(
                "onboarding.pageProgress",
                language: language,
                locale: locale,
                PBFormat.integer(page + 1, locale: locale) as NSString,
                PBFormat.integer(pageCount, locale: locale) as NSString
            ))
            .font(.caption.weight(.semibold))
            .foregroundStyle(PBTheme.secondary)

            Spacer()
            Color.clear.frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var welcome: some View {
        OnboardingPage {
            BrandLogo(size: 126).padding(.bottom, 8)
            Text(t("onboarding.welcome.title"))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(PBTheme.navy)
                .fixedSize(horizontal: false, vertical: true)
            Text(t("onboarding.welcome.subtitle"))
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(PBTheme.secondary)
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 10) {
                Text(t("onboarding.language.title"))
                    .font(.headline)
                    .foregroundStyle(PBTheme.navy)
                Text(t("onboarding.language.body"))
                    .font(.subheadline)
                    .foregroundStyle(PBTheme.secondary)

                PBCard {
                    LanguageDropdown(selection: selectedLanguage, titleKey: "common.language", systemImage: "globe")
                        .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
        }
    }

    private var selectedLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguageStorage.resolved(rawValue: languageRaw) },
            set: { languageRaw = $0.rawValue }
        )
    }

    private var legalAndSafety: some View {
        OnboardingPage(alignment: .leading) {
            BrandLogo(size: 78)
            Text(t("onboarding.legal.title"))
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(PBTheme.navy)
            Text(t("onboarding.legal.body"))
                .font(.body)
                .foregroundStyle(PBTheme.secondary)

            if language != .en {
                Text(t("onboarding.legal.policyLanguageNotice"))
                    .font(.caption)
                    .foregroundStyle(PBTheme.secondary)
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

            VStack(spacing: 10) {
                AcknowledgementRow(isOn: $acceptedTerms, titleKey: "onboarding.legal.acceptTerms")
                AcknowledgementRow(isOn: $acknowledgedSafety, titleKey: "onboarding.legal.ackSafety")
                AcknowledgementRow(isOn: $viewedPrivacy, titleKey: "onboarding.legal.reviewPrivacy")
            }
        }
    }

    private var temperature: some View {
        OnboardingPage {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 58, weight: .medium))
                .foregroundStyle(PBTheme.primary)
                .frame(width: 104, height: 104)
                .background(PBTheme.primarySoft, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            Text(t("onboarding.temperature.title"))
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(PBTheme.navy)
            Text(t("onboarding.temperature.body"))
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(PBTheme.secondary)

            VStack(spacing: 12) {
                UnitChoice(title: "°F", subtitleKey: "onboarding.temperature.fahrenheit", selected: temperatureUnitRaw == "F") { temperatureUnitRaw = "F" }
                UnitChoice(title: "°C", subtitleKey: "onboarding.temperature.celsius", selected: temperatureUnitRaw == "C") { temperatureUnitRaw = "C" }
            }
            .padding(.top, 8)
        }
    }

    private var appleBackupPage: some View {
        OnboardingPage {
            Image(systemName: "icloud.and.arrow.up.fill")
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(PBTheme.primary)
                .frame(width: 104, height: 104)
                .background(PBTheme.primarySoft, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            Text(t("backup.onboardingTitle"))
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(PBTheme.navy)
            Text(t("backup.onboardingBody"))
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(PBTheme.secondary)

            PBCard {
                VStack(spacing: 14) {
                    if appleBackup.isCheckingCredential {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 52)
                    } else if appleBackup.isEnabled {
                        Label(t("backup.enabled"), systemImage: "checkmark.icloud.fill")
                            .font(.headline)
                            .foregroundStyle(PBTheme.successInk)
                            .frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget)

                        Button { showingRestoreConfirmation = true } label: {
                            Label(t("backup.restore"), systemImage: "arrow.clockwise.icloud")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PBTheme.primary)
                        .disabled(appleBackup.isWorking)
                    } else {
                        PBSignInWithAppleButton()
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                if page < pageCount - 1 {
                    if reduceMotion { page += 1 }
                    else { withAnimation { page += 1 } }
                } else {
                    do {
                        let chosen = AppLanguageStorage.resolved(rawValue: languageRaw)
                        let deviceLocale = Locale.current
                        try store.completeOnboarding(
                            language: chosen,
                            locale: deviceLocale,
                            temperatureUnit: temperatureUnitRaw
                        )
                        completed = true
                    } catch {
                        // Fail closed: the app stays in onboarding until readiness state is durably saved.
                    }
                }
            } label: {
                Text(t(footerButtonKey))
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: PBTheme.primaryHeight)
                    .foregroundStyle(.white)
                    .background(PBTheme.primaryGradient, in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
                    .shadow(color: PBTheme.controlShadow, radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(page == 1 && !(acceptedTerms && acknowledgedSafety && viewedPrivacy))
            .opacity(page == 1 && !(acceptedTerms && acknowledgedSafety && viewedPrivacy) ? 0.42 : 1)

            HStack(spacing: 14) {
                Link(destination: PressBenchPolicyLinks.privacy) {
                    Text(t("home.legal.privacy"))
                        .frame(minHeight: PBTheme.minimumTarget)
                        .contentShape(Rectangle())
                }
                Link(destination: PressBenchPolicyLinks.terms) {
                    Text(t("home.legal.terms"))
                        .frame(minHeight: PBTheme.minimumTarget)
                        .contentShape(Rectangle())
                }
                Link(destination: PressBenchPolicyLinks.safety) {
                    Text(t("home.legal.safety"))
                        .frame(minHeight: PBTheme.minimumTarget)
                        .contentShape(Rectangle())
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(PBTheme.secondary)
        }
        .padding(.horizontal, PBTheme.pagePadding)
        .padding(.bottom, 14)
    }

    private var footerButtonKey: String {
        guard page == pageCount - 1 else { return "common.continue" }
        return appleBackup.isEnabled ? "common.openPressBench" : "common.continueWithoutSigningIn"
    }

    private func restoreFromICloud() async {
        do {
            try await appleBackup.restoreFromICloud()
            PBFeedback.success()
        } catch let error as AppleBackupError {
            failureMessageKey = error.localizationKey
            failed = true
            PBFeedback.error()
        } catch {
            failureMessageKey = "error.backupRestore"
            failed = true
            PBFeedback.error()
        }
    }
}

struct PBSignInWithAppleButton: View {
    @EnvironmentObject private var appleBackup: AppleBackupManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            appleBackup.configure(request)
        } onCompletion: { result in
            Task { @MainActor in appleBackup.handleAuthorization(result) }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
        .accessibilityIdentifier("pressbench.signInWithApple")
    }
}

private struct OnboardingPage<Content: View>: View {
    var alignment: HorizontalAlignment = .center
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: alignment, spacing: 18) { content }
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
                .padding(.horizontal, PBTheme.pagePadding)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
    }
}

struct BrandLogo: View {
    var size: CGFloat
    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: PBTheme.cardShadow, radius: 11, y: 5)
            .accessibilityLabel("PressBench")
    }
}

private struct PolicyLinkRow: View {
    let titleKey: String
    let icon: String
    let url: URL
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 13) {
                Image(systemName: icon).frame(width: 25).foregroundStyle(PBTheme.primary)
                Text(PBL10n.text(titleKey, language: language, locale: locale)).font(.headline).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward").foregroundStyle(PBTheme.secondary)
            }
            .frame(minHeight: PBTheme.minimumTarget)
            .padding(.vertical, 13)
        }
    }
}

private struct AcknowledgementRow: View {
    @Binding var isOn: Bool
    let titleKey: String
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isOn ? PBTheme.primary : PBTheme.secondary)
                Text(PBL10n.text(titleKey, language: language, locale: locale))
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .frame(minHeight: PBTheme.minimumTarget)
        }
        .buttonStyle(.plain)
    }
}

private struct UnitChoice: View {
    let title: String
    let subtitleKey: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.largeTitle.bold()).foregroundStyle(PBTheme.navy)
                VStack(alignment: .leading) {
                    Text(PBL10n.text(subtitleKey, language: language, locale: locale)).font(.headline)
                    Text(PBL10n.text(selected ? "common.selected" : "common.tapToSelect", language: language, locale: locale))
                        .font(.caption)
                        .foregroundStyle(PBTheme.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? PBTheme.primary : PBTheme.secondary)
            }
            .frame(minHeight: PBTheme.minimumTarget)
            .padding(18)
            .background(selected ? PBTheme.primarySoft : PBTheme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(selected ? PBTheme.primary : PBTheme.line, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}
