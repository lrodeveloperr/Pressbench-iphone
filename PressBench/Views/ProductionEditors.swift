import SwiftUI

struct MachineEditorView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var draft: MachineDraft
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"

    init(draft: MachineDraft = MachineDraft()) { _draft = State(initialValue: draft) }
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(t("common.name"), text: $draft.nickname)
                    TextField(t("common.brand"), text: $draft.brand)
                    TextField(t("common.model"), text: $draft.model)
                    TextField(t("common.platen"), text: $draft.platen)
                }
                Section(t("common.notes")) {
                    TextEditor(text: $draft.notes).frame(minHeight: 100)
                }
            }
            .environment(\.defaultMinListRowHeight, PBTheme.minimumTarget)
            .scrollContentBackground(.hidden)
            .background(PBTheme.canvasGradient)
            .tint(PBTheme.primary)
            .navigationTitle(t("machines.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("common.save")) { save() }
                        .disabled(draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.platen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t(failureMessageKey)) }
        }
        .pbEditorSheetStyle()
    }

    private func save() {
        do { try store.saveMachine(draft); dismiss() }
        catch { failureMessageKey = store.errorLocalizationKey(error); failed = true }
    }
}

enum SetupEditorMode: Equatable {
    case full
    case sameProductVariant
    case materiallyDifferent
}

struct SetupEditorView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @AppStorage("pressbench.temperature.unit") private var unit = Locale.current.measurementSystem == .us ? "F" : "C"
    @State private var draft: SetupDraft
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @State private var saved = false
    let mode: SetupEditorMode
    let onSaved: ((String) -> Void)?

    init(draft: SetupDraft, mode: SetupEditorMode = .full, onSaved: ((String) -> Void)? = nil) {
        _draft = State(initialValue: draft)
        self.mode = mode
        self.onSaved = onSaved
    }
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            Form {
                if mode == .materiallyDifferent {
                    Section {
                        HStack {
                            Label(t("run.materiallyDifferent"), systemImage: "square.3.layers.3d")
                                .foregroundStyle(PBTheme.text)
                            Spacer()
                            PBStatusBadge(status: .draft)
                        }
                    }
                }
                Section {
                    TextField(t("setup.title"), text: $draft.title)
                    TextField(t("common.material"), text: $draft.material)
                        .disabled(mode == .sameProductVariant)
                    TextField(t("common.transferMedium"), text: $draft.transferMedium)
                        .disabled(mode == .sameProductVariant)
                    Picker(t("machines.title"), selection: $draft.machineID) {
                        ForEach(store.machines) { machine in Text(machine.nickname).tag(machine.id) }
                    }
                    .disabled(mode == .sameProductVariant)
                }
                Section {
                    TextField(t("setup.defaultQuantity"), text: $draft.defaultQuantity).keyboardType(.numberPad)
                }
                ForEach($draft.stages) { $stage in
                    Section {
                        Picker(t("stage.type"), selection: $stage.stageType) {
                            Text(t("stage.placement")).tag("placement")
                            Text(t("stage.prepress")).tag("prepress")
                            Text(t("stage.press")).tag("press")
                            Text(t("stage.peel")).tag("peel")
                            Text(t("stage.cool")).tag("cool")
                            Text(t("stage.postpress")).tag("postpress")
                        }
                        TextField(t("stage.name"), text: $stage.name)
                        TextField(t("stage.instruction"), text: $stage.instruction)
                        HStack {
                            TextField(t("common.temperature"), text: $stage.temperature).keyboardType(.decimalPad)
                            Text("°\(stage.temperatureUnit)").foregroundStyle(PBTheme.secondary)
                        }
                        Picker(t("settings.temperatureUnit"), selection: $stage.temperatureUnit) {
                            Text("°F").tag("F")
                            Text("°C").tag("C")
                        }
                        .pickerStyle(.segmented)
                        .frame(minHeight: PBTheme.minimumTarget)
                        TextField(t("common.durationSeconds"), text: $stage.durationSeconds).keyboardType(.numberPad)
                        TextField(t("common.pressure"), text: $stage.pressure)
                        TextField(t("stage.repeatCount"), text: $stage.repeatCount).keyboardType(.numberPad)
                        TextField(t("stage.placementAction"), text: $stage.placementAction)
                        TextField(t("stage.finishAction"), text: $stage.finishAction)
                        if mode != .sameProductVariant {
                            HStack {
                                Button { moveStage(id: stage.id, offset: -1) } label: {
                                    Label(t("stage.moveUp"), systemImage: "arrow.up")
                                }
                                .frame(minHeight: PBTheme.minimumTarget)
                                .disabled(draft.stages.first?.id == stage.id)
                                Spacer()
                                Button { moveStage(id: stage.id, offset: 1) } label: {
                                    Label(t("stage.moveDown"), systemImage: "arrow.down")
                                }
                                .frame(minHeight: PBTheme.minimumTarget)
                                .disabled(draft.stages.last?.id == stage.id)
                            }
                            if draft.stages.count > 1 {
                                Button(role: .destructive) { draft.stages.removeAll { $0.id == stage.id } } label: {
                                    Label(t("stage.remove"), systemImage: "trash")
                                }
                                .frame(minHeight: PBTheme.minimumTarget)
                            }
                        }
                    } header: {
                        Text(stage.name.isEmpty ? t("stage.stage") : stage.name)
                    }
                    .disabled(mode == .sameProductVariant)
                }
                if mode != .sameProductVariant {
                    Section {
                        Button { draft.stages.append(SetupStageDraft(temperatureUnit: unit)) } label: {
                            Label(t("stage.add"), systemImage: "plus.circle.fill")
                        }
                        .frame(minHeight: PBTheme.minimumTarget)
                    }
                }
                Section(t("report.instructionSource")) {
                    TextField(t("report.instructionSource"), text: $draft.sourceName)
                        .disabled(mode == .sameProductVariant)
                    TextField(t("common.reference"), text: $draft.sourceReference)
                        .disabled(mode == .sameProductVariant)
                }
                Section(t("common.notes")) {
                    TextEditor(text: $draft.notes).frame(minHeight: 100)
                }
            }
            .environment(\.defaultMinListRowHeight, PBTheme.minimumTarget)
            .scrollContentBackground(.hidden)
            .background(PBTheme.canvasGradient)
            .tint(PBTheme.primary)
            .navigationTitle(t("setup.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("common.save")) { save() }
                        .disabled(!isReady)
                }
            }
            .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t(failureMessageKey)) }
        }
        .pbEditorSheetStyle()
        .onDisappear {
            if !saved, !draft.id.isEmpty { store.discardPreparedSetupReuse(id: draft.id) }
        }
    }

    private var isReady: Bool {
        if mode == .sameProductVariant {
            return !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                (Int(draft.defaultQuantity).map { $0 > 0 } == true)
        }
        let hasPressStage = draft.stages.contains(where: { $0.stageType == "press" })
        return !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.material.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.transferMedium.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.machineID.isEmpty && hasPressStage && draft.stages.allSatisfy { stage in
            Int(stage.durationSeconds.isEmpty ? "0" : stage.durationSeconds) != nil &&
            Int(stage.repeatCount.isEmpty ? "1" : stage.repeatCount).map { $0 > 0 } == true &&
            (stage.temperature.isEmpty || Double(stage.temperature) != nil)
        } &&
        !draft.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Int(draft.defaultQuantity) != nil
    }

    private func save() {
        do {
            var prepared = draft
            if mode != .sameProductVariant {
                guard let primary = prepared.stages.first(where: { $0.stageType == "press" }) ?? prepared.stages.first else {
                    failed = true
                    return
                }
                prepared.temperature = primary.temperature.isEmpty ? "0" : primary.temperature
                prepared.durationSeconds = primary.durationSeconds.isEmpty ? "0" : primary.durationSeconds
                prepared.pressure = primary.pressure
            }
            let reuseClass: SetupReuseClass? = mode == .sameProductVariant ? .sameProductVariant : nil
            let savedID = try store.saveSetup(prepared, temperatureUnit: unit, reuseClass: reuseClass)
            saved = true
            onSaved?(savedID)
            dismiss()
        }
        catch { failureMessageKey = store.errorLocalizationKey(error); failed = true }
    }

    private func moveStage(id: String, offset: Int) {
        guard let from = draft.stages.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard draft.stages.indices.contains(to) else { return }
        draft.stages.swapAt(from, to)
        PBFeedback.tap()
    }
}

struct StartRunSheet: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var selectedSetup: Setup?
    @State private var dismissAfterDifference = false
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            List(store.setups.filter { $0.status != .archived }) { setup in
                Button {
                    dismissAfterDifference = false
                    selectedSetup = setup
                } label: {
                    SetupRow(setup: setup, compact: true)
                }
                .buttonStyle(.plain)
            }
            .environment(\.defaultMinListRowHeight, 64)
            .scrollContentBackground(.hidden)
            .background(PBTheme.canvasGradient)
            .tint(PBTheme.primary)
            .overlay {
                if store.setups.isEmpty {
                    ContentUnavailableView(t("setups.title"), systemImage: "list.clipboard", description: Text(t("onboarding.ready.setup.body")))
                }
            }
            .navigationTitle(t("setup.startRun"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { dismiss() }
                }
            }
        }
        .sheet(item: $selectedSetup, onDismiss: {
            if dismissAfterDifference {
                dismissAfterDifference = false
                dismiss()
            }
        }) { setup in
            JobDifferenceSheet(setup: setup) {
                dismissAfterDifference = true
            }
                .environmentObject(store)
        }
        .pbEditorSheetStyle()
    }
}

struct JobDifferenceSheet: View {
    let setup: Setup
    var onStarted: (() -> Void)? = nil
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var failed = false
    @State private var selectedReuseClass: SetupReuseClass = .exactRepeat
    @State private var childRoute: JobDifferenceChildRoute?
    @State private var pendingConfigurationSetupID: String?
    @State private var runStarted = false
    @State private var materiallyDifferentSaved = false

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(t("run.jobDifference"))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(PBTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    ForEach(SetupReuseClass.allCases) { reuseClass in
                        JobDifferenceOption(
                            title: t(reuseClass.localizationKey),
                            icon: reuseClass.systemImage,
                            selected: selectedReuseClass == reuseClass
                        ) {
                            selectedReuseClass = reuseClass
                        }
                    }

                    PBPrimaryButton(title: t("common.continue")) { continueRun() }
                        .padding(.top, 10)
                }
                .padding(.horizontal, PBTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .background(PBTheme.canvasGradient)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { dismiss() }
                }
            }
            .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t("common.actionFailed")) }
        }
        .sheet(item: $childRoute, onDismiss: childDismissed) { route in
            switch route {
            case .editor(let prepared):
                SetupEditorView(
                    draft: prepared.draft,
                    mode: prepared.reuseClass == .sameProductVariant ? .sameProductVariant : .materiallyDifferent,
                    onSaved: { savedID in
                        if prepared.reuseClass == .sameProductVariant {
                            pendingConfigurationSetupID = savedID
                        } else {
                            materiallyDifferentSaved = true
                        }
                    }
                )
                .environmentObject(store)
            case .configuration(let configuredSetup):
                RunConfigurationView(setup: configuredSetup) {
                    runStarted = true
                }
                .environmentObject(store)
            }
        }
        .pbEditorSheetStyle()
    }

    private func continueRun() {
        do {
            if selectedReuseClass == .exactRepeat {
                childRoute = .configuration(setup)
            } else {
                let draft = try store.prepareSetupReuse(setupID: setup.id, reuseClass: selectedReuseClass)
                childRoute = .editor(PreparedReuseRoute(draft: draft, reuseClass: selectedReuseClass))
            }
        } catch {
            failed = true
        }
    }

    private func finishStartedRun() {
        onStarted?()
        dismiss()
    }

    private func childDismissed() {
        if runStarted {
            runStarted = false
            finishStartedRun()
            return
        }
        if materiallyDifferentSaved {
            materiallyDifferentSaved = false
            dismiss()
            return
        }
        guard let savedID = pendingConfigurationSetupID else { return }
        pendingConfigurationSetupID = nil
        guard let savedSetup = store.setups.first(where: { $0.id == savedID }) else {
            failed = true
            return
        }
        Task { @MainActor in
            await Task.yield()
            childRoute = .configuration(savedSetup)
        }
    }
}

private enum JobDifferenceChildRoute: Identifiable {
    case editor(PreparedReuseRoute)
    case configuration(Setup)

    var id: String {
        switch self {
        case .editor(let route): return "editor-\(route.id)"
        case .configuration(let setup): return "configuration-\(setup.id)"
        }
    }
}

private struct PreparedReuseRoute: Identifiable {
    let draft: SetupDraft
    let reuseClass: SetupReuseClass
    var id: String { draft.id }
}

struct RunConfigurationView: View {
    let setup: Setup
    let onStarted: () -> Void
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var draft: RunStartDraft
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"

    init(setup: Setup, onStarted: @escaping () -> Void) {
        self.setup = setup
        self.onStarted = onStarted
        _draft = State(initialValue: RunStartDraft(
            setupID: setup.id,
            runMode: setup.status == .proven ? "production" : "test",
            quantity: String(setup.defaultQuantity),
            progressMode: "live_cycles"
        ))
    }

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PBCard(tone: setup.status == .proven ? .success : .information) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text(setup.title).font(.title3.bold()); Spacer(); PBStatusBadge(status: setup.status) }
                            LabeledContent(t("common.material"), value: setup.material)
                            LabeledContent(t("common.transferMedium"), value: setup.transferMedium)
                            ForEach(setup.stages) { stage in LabeledContent(stage.name, value: stage.value) }
                        }
                    }
                    PBCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker(t("run.mode"), selection: $draft.runMode) {
                                Text(t("run.mode.test")).tag("test")
                                Text(t("run.mode.production")).tag("production")
                            }
                            .pickerStyle(.segmented)
                            .frame(minHeight: PBTheme.minimumTarget)
                            LabeledContent(t("run.plannedQuantity")) {
                                TextField(t("run.plannedQuantity"), text: $draft.quantity)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider()
                            LabeledContent(t("run.jobReference")) {
                                TextField(t("run.jobReference"), text: $draft.jobReference)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider()
                            Picker(t("run.progressTracking"), selection: $draft.progressMode) {
                                Text(t("run.progress.live")).tag("live_cycles")
                                Text(t("run.progress.final")).tag("final_confirmation")
                            }
                            .pickerStyle(.menu)
                            if setup.status != .proven && draft.runMode == "production" {
                                Toggle(isOn: $draft.confirmUnprovenProduction) {
                                    Text(t("run.confirmUnproven"))
                                        .font(.subheadline.weight(.semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .tint(PBTheme.warningInk)
                            }
                        }
                    }
                    PBPrimaryButton(title: t("setup.startRun"), icon: "chevron.forward.circle.fill") { start() }
                        .disabled(!isReady)
                }
                .padding(PBTheme.pagePadding)
            }
            .background(PBTheme.canvasGradient)
            .navigationTitle(t("setup.startRun"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { dismiss() } }
            }
            .alert("PressBench", isPresented: $failed) {
                Button(t("common.ok"), role: .cancel) {}
            } message: {
                Text(t(failureMessageKey))
            }
        }
        .pbEditorSheetStyle()
    }

    private var isReady: Bool {
        Int(draft.quantity).map { $0 > 0 } == true &&
            !(setup.status != .proven && draft.runMode == "production" && !draft.confirmUnprovenProduction)
    }

    private func start() {
        do {
            try store.startRun(draft)
            PBFeedback.success()
            onStarted()
            dismiss()
        } catch {
            failureMessageKey = store.errorLocalizationKey(error)
            failed = true
            PBFeedback.error()
        }
    }
}

private struct JobDifferenceOption: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(selected ? PBTheme.primaryStrong : PBTheme.text)
                    .frame(width: 46, height: 46)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PBTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? PBTheme.primaryStrong : PBTheme.mutedInk)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(selected ? PBTheme.primarySoft : PBTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? PBTheme.primaryStrong : PBTheme.line, lineWidth: selected ? 2 : 1)
            }
            .shadow(color: PBTheme.cardShadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PBTactileButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
