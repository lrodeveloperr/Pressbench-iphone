import SwiftUI

struct MachinesView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var showingEditor = false
    @State private var editDraft = MachineDraft()

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PBTheme.pageSpacing) {
                PBPageHeader(title: t("machines.title"), addAccessibilityLabel: t("onboarding.ready.machine.title")) {
                        editDraft = store.machineDraft(for: nil)
                        showingEditor = true
                }

                if store.machines.isEmpty {
                    ContentUnavailableView(t("machines.title"), systemImage: "rectangle.stack", description: Text(t("onboarding.ready.machine.body")))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    ForEach(store.machines) { machine in
                        Button {
                            editDraft = store.machineDraft(for: machine.id)
                            showingEditor = true
                        } label: {
                            PBCard {
                                HStack(spacing: 16) {
                                    Image(systemName: machineIcon(machine))
                                        .font(.title2)
                                        .foregroundStyle(PBTheme.secondary)
                                        .frame(width: 54, height: 54)
                                        .background(PBTheme.surface, in: Circle())
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(machine.nickname).font(.headline).foregroundStyle(.primary)
                                        if !machine.platen.isEmpty { Text(machine.platen).foregroundStyle(PBTheme.secondary) }
                                        if !machine.detail.isEmpty { Text(machine.detail).font(.subheadline).foregroundStyle(PBTheme.secondary) }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.forward").foregroundStyle(PBTheme.secondary)
                                }
                            }
                        }
                        .buttonStyle(PBTactileButtonStyle())
                    }
                }
            }
            .padding(.horizontal, PBTheme.pagePadding)
            .padding(.bottom, 24)
        }
        .background(PBTheme.canvasGradient)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) { MachineEditorView(draft: editDraft).environmentObject(store) }
    }

    private func machineIcon(_ machine: MachineProfile) -> String {
        let facts = "\(machine.brand) \(machine.model) \(machine.detail)".lowercased()
        if facts.contains("mug") || facts.contains("cup") { return "mug.fill" }
        if facts.contains("hat") || facts.contains("cap") { return "baseball.cap.fill" }
        if facts.contains("auto") || facts.contains("pneumatic") { return "gearshape.2.fill" }
        return "rectangle.compress.vertical"
    }
}
