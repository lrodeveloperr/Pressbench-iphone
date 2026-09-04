import SwiftUI

struct LanguagePickerView: View {
    @Binding var language: AppLanguage
    @State private var query = ""
    @Environment(\.pbLanguage) private var appLanguage
    @Environment(\.locale) private var locale

    private func t(_ key: String) -> String { PBL10n.text(key, language: appLanguage, locale: locale) }

    private var filtered: [AppLanguage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AppLanguage.allCases }
        return AppLanguage.allCases.filter {
            $0.nativeName.localizedCaseInsensitiveContains(trimmed) ||
            $0.rawValue.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(filtered) { candidate in
                    Button {
                        language = candidate
                    } label: {
                        HStack(spacing: 14) {
                            Text(candidate.nativeName).foregroundStyle(.primary)
                            Spacer()
                            if candidate == language {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(PBTheme.primary)
                            }
                        }
                        .pbFullSurfaceTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(candidate == language ? t("language.selected") : "")
                }
            } footer: {
                Text(t("language.footer"))
            }
        }
        .environment(\.defaultMinListRowHeight, PBTheme.minimumTarget)
        .scrollContentBackground(.hidden)
        .background(PBTheme.canvasGradient)
        .tint(PBTheme.primary)
        .searchable(text: $query, prompt: Text(t("language.search")))
        .navigationTitle(t("common.language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
