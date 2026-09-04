import SwiftUI
import UIKit
import UserNotifications
import AudioToolbox

/// GoodUse Studios “Ocean Pearl” visual system.
///
/// The palette, spacing and depth are presentation-only. Domain state and all
/// production decisions remain owned by the deterministic PressBench engine.
struct PBTheme {
    // Canonical Ocean Pearl light tokens from the GoodUse UI System sheet.
    static let oceanBackgroundLight = UIColor(red: 238 / 255, green: 246 / 255, blue: 1, alpha: 1) // #EEF6FF
    static let oceanSurfaceLight = UIColor(red: 1, green: 1, blue: 1, alpha: 1) // #FFFFFF
    static let oceanSurface2Light = UIColor(red: 247 / 255, green: 251 / 255, blue: 1, alpha: 1) // #F7FBFF
    static let oceanTextLight = UIColor(red: 22 / 255, green: 52 / 255, blue: 81 / 255, alpha: 1) // #163451
    static let oceanMutedLight = UIColor(red: 105 / 255, green: 128 / 255, blue: 152 / 255, alpha: 1) // #698098
    static let oceanLineLight = UIColor(red: 215 / 255, green: 230 / 255, blue: 243 / 255, alpha: 1) // #D7E6F3
    static let oceanPrimaryLight = UIColor(red: 36 / 255, green: 123 / 255, blue: 209 / 255, alpha: 1) // #247BD1
    static let oceanPrimarySoftLight = UIColor(red: 231 / 255, green: 243 / 255, blue: 1, alpha: 1) // #E7F3FF
    static let oceanSuccessLight = UIColor(red: 39 / 255, green: 142 / 255, blue: 103 / 255, alpha: 1) // #278E67
    static let oceanSuccessSoftLight = UIColor(red: 231 / 255, green: 246 / 255, blue: 239 / 255, alpha: 1) // #E7F6EF
    static let oceanWarningLight = UIColor(red: 170 / 255, green: 113 / 255, blue: 20 / 255, alpha: 1) // #AA7114
    static let oceanWarningSoftLight = UIColor(red: 1, green: 245 / 255, blue: 221 / 255, alpha: 1) // #FFF5DD
    static let oceanErrorLight = UIColor(red: 191 / 255, green: 65 / 255, blue: 74 / 255, alpha: 1) // #BF414A
    static let oceanErrorSoftLight = UIColor(red: 1, green: 240 / 255, blue: 241 / 255, alpha: 1) // #FFF0F1

    // WCAG-safe semantic inks for copy on Ocean Pearl light surfaces. The
    // canonical palette above remains unchanged for fills, lines and artwork.
    static let oceanMutedInkLight = UIColor(red: 82 / 255, green: 109 / 255, blue: 137 / 255, alpha: 1) // #526D89
    static let oceanPrimaryStrongLight = UIColor(red: 23 / 255, green: 105 / 255, blue: 186 / 255, alpha: 1) // #1769BA
    static let oceanSuccessInkLight = UIColor(red: 29 / 255, green: 117 / 255, blue: 86 / 255, alpha: 1) // #1D7556
    static let oceanWarningInkLight = UIColor(red: 138 / 255, green: 87 / 255, blue: 12 / 255, alpha: 1) // #8A570C
    static let oceanErrorInkLight = UIColor(red: 168 / 255, green: 47 / 255, blue: 57 / 255, alpha: 1) // #A82F39

    private static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }

    static let canvasTop = adaptive(
        UIColor(red: 248 / 255, green: 252 / 255, blue: 1, alpha: 1),
        UIColor(red: 7 / 255, green: 22 / 255, blue: 36 / 255, alpha: 1)
    )
    static let canvasBottom = adaptive(
        UIColor(red: 237 / 255, green: 246 / 255, blue: 1, alpha: 1),
        UIColor(red: 9 / 255, green: 29 / 255, blue: 47 / 255, alpha: 1)
    )
    static let background = adaptive(oceanBackgroundLight, UIColor(red: 7 / 255, green: 22 / 255, blue: 36 / 255, alpha: 1))
    static let card = adaptive(oceanSurfaceLight, UIColor(red: 15 / 255, green: 37 / 255, blue: 57 / 255, alpha: 1))
    static let elevated = adaptive(oceanSurface2Light, UIColor(red: 20 / 255, green: 47 / 255, blue: 71 / 255, alpha: 1))
    static let text = adaptive(oceanTextLight, UIColor(red: 244 / 255, green: 249 / 255, blue: 1, alpha: 1))
    static let mutedInk = adaptive(oceanMutedInkLight, UIColor(red: 165 / 255, green: 187 / 255, blue: 207 / 255, alpha: 1))
    static let muted = mutedInk
    static let divider = adaptive(oceanLineLight, UIColor(red: 43 / 255, green: 72 / 255, blue: 95 / 255, alpha: 1))
    static let primary = adaptive(oceanPrimaryLight, UIColor(red: 89 / 255, green: 170 / 255, blue: 245 / 255, alpha: 1))
    static let primarySoft = adaptive(oceanPrimarySoftLight, UIColor(red: 18 / 255, green: 58 / 255, blue: 91 / 255, alpha: 1))
    static let success = adaptive(oceanSuccessLight, UIColor(red: 87 / 255, green: 205 / 255, blue: 155 / 255, alpha: 1))
    static let successSoft = adaptive(oceanSuccessSoftLight, UIColor(red: 15 / 255, green: 64 / 255, blue: 49 / 255, alpha: 1))
    static let warning = adaptive(oceanWarningLight, UIColor(red: 239 / 255, green: 190 / 255, blue: 94 / 255, alpha: 1))
    static let warningSoft = adaptive(oceanWarningSoftLight, UIColor(red: 67 / 255, green: 49 / 255, blue: 17 / 255, alpha: 1))
    static let error = adaptive(oceanErrorLight, UIColor(red: 1, green: 139 / 255, blue: 148 / 255, alpha: 1))
    static let errorSoft = adaptive(oceanErrorSoftLight, UIColor(red: 72 / 255, green: 27 / 255, blue: 34 / 255, alpha: 1))
    static let primaryStrong = adaptive(oceanPrimaryStrongLight, UIColor(red: 89 / 255, green: 170 / 255, blue: 245 / 255, alpha: 1))
    static let successInk = adaptive(oceanSuccessInkLight, UIColor(red: 87 / 255, green: 205 / 255, blue: 155 / 255, alpha: 1))
    static let warningInk = adaptive(oceanWarningInkLight, UIColor(red: 239 / 255, green: 190 / 255, blue: 94 / 255, alpha: 1))
    static let errorInk = adaptive(oceanErrorInkLight, UIColor(red: 1, green: 139 / 255, blue: 148 / 255, alpha: 1))
    static let selectionFill = adaptive(oceanPrimaryStrongLight, oceanPrimaryStrongLight)
    // Fixed dark action fills retain white-label contrast in both appearances.
    // Adaptive semantic inks remain available for copy on dark surfaces.
    static let primaryActionFill = Color(uiColor: oceanPrimaryStrongLight)
    static let successActionFill = Color(uiColor: oceanSuccessInkLight)
    static let warningActionFill = Color(uiColor: oceanWarningInkLight)
    static let errorActionFill = Color(uiColor: oceanErrorInkLight)

    static let canvasGradient = LinearGradient(colors: [canvasTop, canvasBottom], startPoint: .top, endPoint: .bottom)
    static let primaryGradient = LinearGradient(
        colors: [Color(red: 52 / 255, green: 138 / 255, blue: 221 / 255), Color(red: 35 / 255, green: 120 / 255, blue: 203 / 255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Compatibility aliases used throughout the native presentation layer.
    static let charcoal = text
    static let cream = primarySoft
    static let ember = warningInk
    static let recordBlue = primary
    static let recordBlue2 = Color(red: 52 / 255, green: 138 / 255, blue: 221 / 255)
    static let recordBlue3 = Color(red: 89 / 255, green: 170 / 255, blue: 245 / 255)
    static let navy = text
    static let navy2 = primary
    static let canvas = background
    static let paper = card
    static let surface = elevated
    static let line = divider
    static let secondary = muted
    static let trial = primary
    static let draft = muted

    // Named depth only: no ad-hoc heavy shadows.
    static let cardShadow = adaptive(
        UIColor(red: 47 / 255, green: 94 / 255, blue: 139 / 255, alpha: 0.07),
        UIColor(white: 0, alpha: 0.28)
    )
    static let summaryShadow = adaptive(
        UIColor(red: 50 / 255, green: 98 / 255, blue: 143 / 255, alpha: 0.08),
        UIColor(white: 0, alpha: 0.32)
    )
    static let controlShadow = adaptive(
        UIColor(red: 38 / 255, green: 83 / 255, blue: 127 / 255, alpha: 0.11),
        UIColor(white: 0, alpha: 0.38)
    )

    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 16
    static let pagePadding: CGFloat = 16
    static let pageSpacing: CGFloat = 14
    static let minimumTarget: CGFloat = 48
    static let primaryHeight: CGFloat = 62

    static var pageBackground: LinearGradient { canvasGradient }
}

struct PBPageBackground: View {
    var body: some View { PBTheme.canvasGradient.ignoresSafeArea() }
}

enum PBCardTone {
    case standard, information, success, caution, production

    var tint: Color {
        switch self {
        case .standard, .information: return PBTheme.primary
        case .success: return PBTheme.success
        case .caution: return PBTheme.warning
        case .production: return PBTheme.text
        }
    }
}

struct PBCard<Content: View>: View {
    var tone: PBCardTone
    @ViewBuilder var content: Content

    init(tone: PBCardTone = .standard, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PBTheme.cardRadius, style: .continuous)
        content
            .padding(16)
            .background(
                LinearGradient(
                    colors: [PBTheme.paper, tone.tint.opacity(0.035)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: shape
            )
            .overlay { shape.stroke(PBTheme.line, lineWidth: 1) }
            .shadow(color: PBTheme.cardShadow, radius: 11, x: 0, y: 5)
    }
}

/// A restrained physical response for gloved, one-handed production use.
struct PBTactileButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 1.5 : 0)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .saturation(isEnabled ? 1 : 0.25)
            .opacity(isEnabled ? 1 : 0.48)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

enum PBFeedback {
    private static var enabled: Bool { UserDefaults.standard.object(forKey: "pressbench.haptics.enabled") as? Bool ?? true }
    static func tap() { if enabled { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.72) } }
    static func count() { if enabled { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.86) } }
    static func undo() { if enabled { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.66) } }
    static func success() { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func warning() { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
    static func error() { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.error) } }
}

enum PBTimerNotification {
    static let identifier = "pressbench.active-stage-timer"

    static func requestPermissionIfNeeded() async -> Bool {
        let enabled = UserDefaults.standard.object(forKey: "pressbench.notifications.enabled") as? Bool ?? false
        guard enabled else { return false }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        default: return false
        }
    }

    static func schedule(seconds: TimeInterval, title: String, body: String) {
        let enabled = UserDefaults.standard.object(forKey: "pressbench.notifications.enabled") as? Bool ?? false
        guard enabled, seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let soundEnabled = UserDefaults.standard.object(forKey: "pressbench.sound.enabled") as? Bool ?? true
        content.sound = soundEnabled ? .default : nil
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        )
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func scheduleIfAuthorized(seconds: TimeInterval, title: String, body: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }
            schedule(seconds: seconds, title: title, body: body)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

enum PBTimerSound {
    static func completion() {
        let enabled = UserDefaults.standard.object(forKey: "pressbench.sound.enabled") as? Bool ?? false
        if enabled { AudioServicesPlaySystemSound(1005) }
    }
}

struct PBPrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    @ScaledMetric(relativeTo: .headline) private var labelSize: CGFloat = 19

    var body: some View {
        Button(action: action) {
            Group {
                if let icon { Label(title, systemImage: icon) }
                else { Text(title) }
            }
            .font(.system(size: max(19, labelSize), weight: .bold))
            .frame(maxWidth: .infinity, minHeight: PBTheme.primaryHeight)
            .contentShape(Rectangle())
            .foregroundStyle(.white)
            .background(PBTheme.primaryGradient, in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
            .shadow(color: PBTheme.controlShadow, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PBTactileButtonStyle())
    }
}

extension View {
    /// Expands a composite control label to one predictable, accessible hit surface.
    func pbFullSurfaceTarget(
        minHeight: CGFloat = PBTheme.minimumTarget,
        alignment: Alignment = .leading
    ) -> some View {
        frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .contentShape(Rectangle())
    }
}

struct PBPageHeader: View {
    let title: String
    var addAccessibilityLabel: String? = nil
    var addAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(PBTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: 8)
            if let addAction {
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)
                        .background(PBTheme.primaryGradient, in: Circle())
                        .shadow(color: PBTheme.controlShadow, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PBTactileButtonStyle())
                .accessibilityLabel(Text(addAccessibilityLabel ?? title))
            }
        }
        .padding(.top, 8)
    }
}

struct PBSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PBTheme.muted)
            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(PBTheme.muted)
                }
                .frame(minWidth: PBTheme.minimumTarget, minHeight: PBTheme.minimumTarget)
                .accessibilityLabel(Text(prompt))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: PBTheme.minimumTarget)
        .background(PBTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PBTheme.line, lineWidth: 1) }
        .shadow(color: PBTheme.cardShadow, radius: 8, x: 0, y: 4)
    }
}

struct PBEvidenceRow: View {
    let title: String
    let detail: String
    var icon: String = "checkmark.shield.fill"

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(PBTheme.successActionFill, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(PBTheme.text)
                Text(detail).font(.caption).foregroundStyle(PBTheme.muted)
            }
            Spacer(minLength: 8)
        }
        .frame(minHeight: 48)
    }
}

struct PBStatusBadge: View {
    let status: SetupStatus
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    var body: some View {
        Text(PBL10n.text(status.localizationKey, language: language, locale: locale))
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(status.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.background, in: Capsule())
            .accessibilityLabel(PBL10n.text(status.localizationKey, language: language, locale: locale))
    }
}

extension SetupStatus {
    var foreground: Color {
        switch self {
        case .proven: return PBTheme.successInk
        case .trial: return PBTheme.primaryStrong
        case .draft: return PBTheme.warningInk
        case .archived: return PBTheme.mutedInk
        }
    }

    var background: Color {
        switch self {
        case .proven: return PBTheme.successSoft
        case .trial: return PBTheme.primarySoft
        case .draft: return PBTheme.warningSoft
        case .archived: return PBTheme.surface
        }
    }
}

enum PBAppearancePreference: String, CaseIterable, Identifiable {
    // Keep the shipped preference key so upgrades retain the selected theme.
    static let storageKey = "pressbench.theme"
    case system, light, dark

    var id: String { rawValue }
    var localizationKey: String { "appearance.\(rawValue)" }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct PBEditorSheetStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationDetents([.fraction(0.88), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
    }
}

extension View {
    func pbEditorSheetStyle() -> some View { modifier(PBEditorSheetStyle()) }

    func pbKeyboardDismissToolbar(_ title: String) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(title) {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .accessibilityIdentifier("pb.keyboard.dismiss")
            }
        }
    }
}
