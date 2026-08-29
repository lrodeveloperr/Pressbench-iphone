import SwiftUI

/// Shared native dropdown used in onboarding and Settings.
/// The menu is driven directly from the 31 canonical AppLanguage cases so both
/// entry points always expose the same language set and persist the same value.
struct LanguageDropdown: View {
    @Binding var selection: AppLanguage
    var titleKey: String = "common.language"
    var systemImage: String? = "globe"

    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { candidate in
                Button {
                    selection = candidate
                } label: {
                    HStack {
                        Text(candidate.nativeName)
                        if candidate == selection { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                if let systemImage {
                    Label { Text(t(titleKey)) } icon: { Image(systemName: systemImage) }
                        .foregroundStyle(.primary)
                } else {
                    Text(t(titleKey)).foregroundStyle(.primary)
                }

                Spacer(minLength: 12)

                Text(selection.nativeName)
                    .foregroundStyle(PBTheme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PBTheme.secondary)
            }
            .frame(minHeight: PBTheme.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t(titleKey))
        .accessibilityValue(selection.nativeName)
        .accessibilityHint(t("onboarding.language.dropdownHint"))
    }
}
