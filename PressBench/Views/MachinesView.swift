import SwiftUI

struct MachinesView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var showingEditor = false
    @State private var editDraft = MachineDraft()
    @State private var pendingArchiveID: String?
    @State private var failed = false

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var activeMachines: [MachineProfile] { store.machines.filter { $0.active } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PBTheme.pageSpacing) {
                PBPageHeader(title: t("machines.title"), addAccessibilityLabel: t("onboarding.ready.machine.title")) {
                        editDraft = store.machineDraft(for: nil)
                        showingEditor = true
                }

                if activeMachines.isEmpty {
                    VStack(spacing: 18) {
                        ContentUnavailableView(t("machines.title"), systemImage: "rectangle.stack", description: Text(t("onboarding.ready.machine.body")))
                        PBPrimaryButton(title: t("onboarding.ready.machine.title"), icon: "plus.circle.fill") {
                            editDraft = store.machineDraft(for: nil)
                            showingEditor = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 44)
                } else {
                    ForEach(activeMachines) { machine in
                        PBCard {
                            HStack(spacing: 8) {
                                Button {
                                    editDraft = store.machineDraft(for: machine.id)
                                    showingEditor = true
                                } label: {
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
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PBTactileButtonStyle())
                                Menu {
                                    Button { editDraft = store.machineDraft(for: machine.id); showingEditor = true } label: {
                                        Label(t("common.edit"), systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { pendingArchiveID = machine.id } label: {
                                        Label(t("machine.archive"), systemImage: "archivebox")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)
                                        .contentShape(Rectangle())
                                }
                                .accessibilityLabel(t("common.more"))
                            }
                        }
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
        .confirmationDialog(t("machine.archive"), isPresented: Binding(
            get: { pendingArchiveID != nil }, set: { if !$0 { pendingArchiveID = nil } }
        ), titleVisibility: .visible) {
            Button(t("machine.archive"), role: .destructive) {
                do { if let id = pendingArchiveID { try store.archiveMachine(id: id) } }
                catch { failed = true }
                pendingArchiveID = nil
            }
            Button(t("common.cancel"), role: .cancel) { pendingArchiveID = nil }
        }
        .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t("common.actionFailed")) }
    }

    private func machineIcon(_ machine: MachineProfile) -> String {
        let facts = "\(machine.brand) \(machine.model) \(machine.detail)".lowercased()
        if facts.contains("mug") || facts.contains("cup") { return "mug.fill" }
        if facts.contains("hat") || facts.contains("cap") { return "baseball.cap.fill" }
        if facts.contains("auto") || facts.contains("pneumatic") { return "gearshape.2.fill" }
        return "rectangle.compress.vertical"
    }
}
