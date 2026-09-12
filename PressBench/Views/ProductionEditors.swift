import SwiftUI

private enum MachineStartMethod: Equatable {
    case catalog
    case manual
}

struct MachineEditorView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var draft: MachineDraft
    @State private var originalDraft: MachineDraft
    @State private var failed = false
    @State private var showingDiscard = false
    @State private var failureMessageKey = "common.actionFailed"
    @State private var nicknameWasEdited: Bool
    @State private var startMethod: MachineStartMethod?

    let onSaved: ((String) -> Void)?

    init(draft: MachineDraft = MachineDraft(), onSaved: ((String) -> Void)? = nil) {
        _draft = State(initialValue: draft)
        _originalDraft = State(initialValue: draft)
        _nicknameWasEdited = State(initialValue: !draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        _startMethod = State(initialValue: draft.id.isEmpty ? nil : .manual)
        self.onSaved = onSaved
    }
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            Form {
                if choosingStartMethod {
                    Section {
                        Button { startMethod = .catalog } label: {
                            Label(t("machine.start.catalog"), systemImage: "list.bullet")
                                .frame(minHeight: PBTheme.minimumTarget)
                        }
                        .accessibilityIdentifier("pb.machine.catalog")
                        Button { startMethod = .manual } label: {
                            Label(t("setup.start.manual"), systemImage: "square.and.pencil")
                                .frame(minHeight: PBTheme.minimumTarget)
                        }
                        .accessibilityIdentifier("pb.machine.manual")
                    } header: {
                        Text(t("machine.start.choose"))
                    }
                } else if startMethod == .catalog {
                    Section {
                        PBChoiceField(
                            title: t("common.brand") + " *",
                            selection: $draft.brand,
                            choices: knownBrands,
                            identifier: "pb.choice.machineBrand",
                            tapToSelectTitle: t("common.tapToSelect"),
                            otherTitle: t("issue.symptom.other"),
                            cancelTitle: t("common.cancel"),
                            allowsOther: false
                        )
                        if draft.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            LabeledContent(t("common.model") + " *", value: t("common.tapToSelect"))
                                .foregroundStyle(PBTheme.secondary)
                        } else {
                            PBChoiceField(
                                title: t("common.model") + " *",
                                selection: $draft.model,
                                choices: knownModels,
                                identifier: "pb.choice.machineModel",
                                tapToSelectTitle: t("common.tapToSelect"),
                                otherTitle: t("issue.symptom.other"),
                                cancelTitle: t("common.cancel"),
                                allowsOther: false
                            )
                        }
                    }
                } else {
                    Section {
                        TextField(t("common.brand") + " *", text: $draft.brand)
                        TextField(t("common.model") + " *", text: $draft.model)
                        TextField(t("common.platen") + " *", text: $draft.platen)
                        TextField(t("common.name"), text: nicknameBinding)
                    }
                    Section {
                        DisclosureGroup(t("common.more")) {
                            Text(t("common.notes"))
                                .font(.caption)
                                .foregroundStyle(PBTheme.secondary)
                            TextEditor(text: $draft.notes)
                                .frame(minHeight: 100)
                                .accessibilityLabel(t("common.notes"))
                        }
                    }
                }
                if !choosingStartMethod {
                    Section(t("common.maintenance")) {
                        LabeledContent(
                            t("report.date"),
                            value: draft.lastExternalCheckDate.isEmpty ? t("machines.calibrationDue") : draft.lastExternalCheckDate
                        )
                        Button {
                            draft.lastExternalCheckDate = Self.localCivilDate()
                            PBFeedback.success()
                        } label: {
                            Label(t("machine.markCheckedToday"), systemImage: "checkmark.seal")
                                .frame(minHeight: PBTheme.minimumTarget)
                        }
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, PBTheme.minimumTarget)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .pbKeyboardDismissToolbar(t("common.done"))
            .background(PBTheme.canvasGradient)
            .tint(PBTheme.primary)
            .navigationTitle(t("machines.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { cancel() }
                        .accessibilityIdentifier("pb.editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !choosingStartMethod {
                        Button(t("common.save")) { save() }
                            .disabled(!machineReady)
                    }
                }
            }
            .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t(failureMessageKey)) }
            .confirmationDialog(t("editor.discardChanges"), isPresented: $showingDiscard, titleVisibility: .visible) {
                Button(t("editor.discard"), role: .destructive) { dismiss() }
                Button(t("common.cancel"), role: .cancel) {}
            }
        }
        .pbEditorSheetStyle()
        .interactiveDismissDisabled(draft != originalDraft)
        .onChange(of: draft.brand) { oldValue, newValue in
            if startMethod == .catalog,
               oldValue != newValue,
               PBMachineCatalog.models(for: newValue).contains(draft.model) == false {
                draft.model = ""
            }
            applySuggestedNickname()
        }
        .onChange(of: draft.model) { _, _ in
            if startMethod == .catalog,
               let match = PBMachineCatalog.entry(brand: draft.brand, model: draft.model) {
                draft.platen = match.platen
            }
            applySuggestedNickname()
        }
        .onChange(of: draft.platen) { _, _ in applySuggestedNickname() }
    }

    private var machineReady: Bool {
        !draft.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.platen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var choosingStartMethod: Bool {
        draft.id.isEmpty && startMethod == nil
    }
    private var knownBrands: [String] {
        PBPrefillCatalog.prioritized(PBMachineCatalog.brands, recent: store.machines.map(\.brand))
    }
    private var knownModels: [String] {
        let recent = store.machines.filter {
            $0.brand.compare(draft.brand, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }.map(\.model)
        return PBPrefillCatalog.prioritized(PBMachineCatalog.models(for: draft.brand), recent: recent)
    }
    private var nicknameBinding: Binding<String> {
        Binding(
            get: { draft.nickname },
            set: { value in
                nicknameWasEdited = true
                draft.nickname = value
            }
        )
    }
    private var suggestedNickname: String {
        let identity = [draft.brand, draft.model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return identity.isEmpty ? draft.platen.trimmingCharacters(in: .whitespacesAndNewlines) : identity
    }
    private func applySuggestedNickname() {
        guard !nicknameWasEdited else { return }
        draft.nickname = suggestedNickname
    }
    private func cancel() {
        if draft == originalDraft { dismiss() } else { showingDiscard = true }
    }
    private func save() {
        do {
            let isNewMachine = draft.id.isEmpty
            var prepared = draft
            if prepared.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                prepared.nickname = suggestedNickname
            }
            let id = try store.saveMachine(prepared)
            draft = prepared
            originalDraft = prepared
            onSaved?(id)
            if isNewMachine { store.selectedTab = 0 }
            dismiss()
        }
        catch { failureMessageKey = store.errorLocalizationKey(error); failed = true }
    }

    private static func localCivilDate() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

enum SetupEditorMode: Equatable {
    case full
    case sameProductVariant
    case materiallyDifferent
}

private enum SetupStartMethod {
    case preset
    case presetBase
    case saved
    case manual
}

struct SetupEditorView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @AppStorage("pressbench.temperature.unit") private var unit = Locale.current.measurementSystem == .us ? "F" : "C"
    @State private var draft: SetupDraft
    @State private var originalDraft: SetupDraft
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @State private var saved = false
    @State private var showingDiscard = false
    @State private var pendingStageRemovalID: String?
    @State private var showingUpgrade = false
    @State private var showingPresetPicker = false
    @State private var showingSavedSetupPicker = false
    @State private var presetSelectionAsBase = false
    @State private var startMethod: SetupStartMethod?
    let mode: SetupEditorMode
    let onSaved: ((String) -> Void)?

    init(draft: SetupDraft, mode: SetupEditorMode = .full, onSaved: ((String) -> Void)? = nil) {
        _draft = State(initialValue: draft)
        _originalDraft = State(initialValue: draft)
        _startMethod = State(initialValue: mode == .full && draft.id.isEmpty ? nil : .manual)
        self.mode = mode
        self.onSaved = onSaved
    }
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            Form {
                if choosingStartMethod {
                    Section {
                        Button {
                            presetSelectionAsBase = false
                            showingPresetPicker = true
                        } label: {
                            Label(t("setup.selectPreset"), systemImage: "checkmark.seal")
                                .frame(minHeight: PBTheme.minimumTarget)
                        }
                        .accessibilityIdentifier("pb.setup.presetPicker")
                        Button {
                            presetSelectionAsBase = true
                            showingPresetPicker = true
                        } label: {
                            Label(t("setup.start.presetBase"), systemImage: "book.pages")
                                .frame(minHeight: PBTheme.minimumTarget)
                        }
                        .accessibilityIdentifier("pb.setup.presetBasePicker")
                        Button { showingSavedSetupPicker = true } label: {
                            Label(t("setup.start.saved"), systemImage: "doc.on.doc")
                                .frame(minHeight: PBTheme.minimumTarget)
                        }
                        .accessibilityIdentifier("pb.setup.savedBase")
                        .disabled(store.recentSetups.allSatisfy { $0.status == .archived })
                        Button { startMethod = .manual } label: {
                            Label(t("setup.start.manual"), systemImage: "square.and.pencil")
                                .frame(minHeight: PBTheme.minimumTarget)
                        }
                        .accessibilityIdentifier("pb.setup.manual")
                    } header: {
                        Text(t("setup.start.choose"))
                    }
                } else {
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
                    if mode != .sameProductVariant {
                        PBChoiceField(
                            title: t("common.material") + " *",
                            selection: $draft.material,
                            choices: prioritizedMaterials,
                            identifier: "pb.choice.material",
                            tapToSelectTitle: t("common.tapToSelect"),
                            otherTitle: t("issue.symptom.other"),
                            cancelTitle: t("common.cancel")
                        )
                        .disabled(startMethod == .preset)
                        PBChoiceField(
                            title: t("common.transferMedium") + " *",
                            selection: $draft.transferMedium,
                            choices: prioritizedTransferMedia,
                            identifier: "pb.choice.transfer",
                            tapToSelectTitle: t("common.tapToSelect"),
                            otherTitle: t("issue.symptom.other"),
                            cancelTitle: t("common.cancel")
                        )
                        .disabled(startMethod == .preset)
                    }
                }
                if mode == .sameProductVariant {
                    Section(t("setup.processLocked")) {
                        LabeledContent(t("common.material"), value: draft.material)
                        LabeledContent(t("common.transferMedium"), value: draft.transferMedium)
                        TextField(t("common.material") + " · " + t("common.reference"), text: $draft.blankColourSize)
                    }
                } else {
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
                        HStack {
                            TextField(t("common.temperature") + (stage.stageType == "press" ? " *" : ""), text: $stage.temperature)
                                .keyboardType(.decimalPad)
                                .accessibilityIdentifier("pb.stage.temperature")
                            Text("°\(stage.temperatureUnit)").foregroundStyle(PBTheme.secondary)
                        }
                        Picker(t("settings.temperatureUnit"), selection: $stage.temperatureUnit) {
                            Text("°F").tag("F")
                            Text("°C").tag("C")
                        }
                        .pickerStyle(.segmented)
                        .frame(minHeight: PBTheme.minimumTarget)
                        TextField(t("common.durationSeconds") + (stage.stageType == "press" ? " *" : ""), text: $stage.durationSeconds)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("pb.stage.duration")
                        PBChoiceField(
                            title: t("common.pressure") + (stage.stageType == "press" ? " *" : ""),
                            selection: $stage.pressure,
                            choices: prioritizedPressureDescriptions,
                            identifier: "pb.choice.pressure",
                            tapToSelectTitle: t("common.tapToSelect"),
                            otherTitle: t("issue.symptom.other"),
                            cancelTitle: t("common.cancel")
                        )
                        DisclosureGroup(t("setup.advanced")) {
                            TextField(t("stage.name"), text: $stage.name)
                            TextField(t("stage.instruction"), text: $stage.instruction)
                            TextField(t("stage.repeatCount"), text: $stage.repeatCount).keyboardType(.numberPad)
                            PBChoiceField(
                                title: t("stage.placementAction"),
                                selection: $stage.placementAction,
                                choices: prioritizedPlacementActions,
                                identifier: "pb.choice.placement",
                                tapToSelectTitle: t("common.tapToSelect"),
                                otherTitle: t("issue.symptom.other"),
                                cancelTitle: t("common.cancel")
                            )
                            PBChoiceField(
                                title: t("stage.finishAction"),
                                selection: $stage.finishAction,
                                choices: prioritizedFinishActions,
                                identifier: "pb.choice.finish",
                                tapToSelectTitle: t("common.tapToSelect"),
                                otherTitle: t("issue.symptom.other"),
                                cancelTitle: t("common.cancel")
                            )
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
                                Button(role: .destructive) { pendingStageRemovalID = stage.id } label: {
                                    Label(t("stage.remove"), systemImage: "trash")
                                }
                                .frame(minHeight: PBTheme.minimumTarget)
                            }
                        }
                    } header: {
                        Text(stage.canonicalLocalizationKey.map(t) ?? (stage.name.isEmpty ? t("stage.stage") : stage.name))
                    }
                    .disabled(mode == .sameProductVariant || startMethod == .preset)
                }
                Section(t("report.instructionSource")) {
                    PBChoiceField(
                        title: t("report.instructionSource") + " *",
                        selection: $draft.sourceName,
                        choices: prioritizedInstructionSources,
                        identifier: "pb.choice.source",
                        tapToSelectTitle: t("common.tapToSelect"),
                        otherTitle: t("issue.symptom.other"),
                        cancelTitle: t("common.cancel")
                    )
                    TextField(t("common.reference") + " *", text: $draft.sourceReference)
                        .accessibilityIdentifier("pb.setup.sourceReference")
                }
                .disabled(startMethod == .preset)
                if mode != .sameProductVariant {
                    Section {
                        Button { draft.stages.append(SetupStageDraft(temperatureUnit: unit)) } label: {
                            Label(t("stage.add"), systemImage: "plus.circle.fill")
                        }
                        .frame(minHeight: PBTheme.minimumTarget)
                        .disabled(startMethod == .preset || draft.stages.count >= PBInputLimits.maximumStages)
                    }
                }
                }
                if mode != .sameProductVariant {
                    Section(t("run.machine")) {
                        if activeMachines.count == 1, let machine = activeMachines.first {
                            LabeledContent(t("run.machine"), value: machine.nickname)
                        } else {
                            Picker(t("run.machine") + " *", selection: $draft.machineID) {
                                ForEach(activeMachines) { machine in Text(machine.nickname).tag(machine.id) }
                            }
                        }
                    }
                }
                Section {
                    DisclosureGroup(t("common.more")) {
                        TextField(t("setup.title"), text: $draft.title, prompt: Text(suggestedSetupTitle))
                            .accessibilityIdentifier("pb.setup.title")
                        TextField(t("setup.defaultQuantity") + " *", text: $draft.defaultQuantity)
                            .keyboardType(.numberPad)
                        Text(t("common.notes"))
                            .font(.caption)
                            .foregroundStyle(PBTheme.secondary)
                        TextEditor(text: $draft.notes)
                            .frame(minHeight: 100)
                            .accessibilityLabel(t("common.notes"))
                    }
                }
                if mode != .sameProductVariant {
                    Section {
                        DisclosureGroup(t("report.materialTransfer")) {
                            TextField(t("common.material") + " · " + t("common.reference"), text: $draft.blankSupplier)
                            TextField(t("common.transferMedium") + " · " + t("common.reference"), text: $draft.transferSupplier)
                            TextField(t("setup.title") + " · " + t("common.reference"), text: $draft.designRevision)
                            TextField(t("common.process") + " · " + t("common.reference"), text: $draft.printerInkPaperProfile)
                            TextField(t("common.process") + " · " + t("common.notes"), text: $draft.accessoriesPlacementCooling)
                        }
                    }
                }
                if !isReady {
                    Section {
                        Label(t("setup.completeRequired"), systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(PBTheme.warningInk)
                        ForEach(missingRequiredFields, id: \.self) { field in
                            Label(field, systemImage: "circle.fill")
                                .font(.caption)
                                .foregroundStyle(PBTheme.secondary)
                        }
                    }
                }
                }
            }
            .environment(\.defaultMinListRowHeight, PBTheme.minimumTarget)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .pbKeyboardDismissToolbar(t("common.done"))
            .background(PBTheme.canvasGradient)
            .tint(PBTheme.primary)
            .navigationTitle(t("setup.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { cancel() }
                        .accessibilityIdentifier("pb.editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !choosingStartMethod {
                        Button(t("common.save")) { save() }
                            .disabled(!isReady)
                    }
                }
            }
            .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t(failureMessageKey)) }
            .confirmationDialog(t("editor.discardChanges"), isPresented: $showingDiscard, titleVisibility: .visible) {
                Button(t("editor.discard"), role: .destructive) { dismiss() }
                Button(t("common.cancel"), role: .cancel) {}
            }
            .confirmationDialog(t("stage.remove"), isPresented: Binding(
                get: { pendingStageRemovalID != nil }, set: { if !$0 { pendingStageRemovalID = nil } }
            ), titleVisibility: .visible) {
                Button(t("stage.remove"), role: .destructive) {
                    if let id = pendingStageRemovalID { draft.stages.removeAll { $0.id == id } }
                    pendingStageRemovalID = nil
                }
                Button(t("common.cancel"), role: .cancel) { pendingStageRemovalID = nil }
            }
        }
        .pbEditorSheetStyle()
        .interactiveDismissDisabled(draft != originalDraft && !saved)
        .sheet(isPresented: $showingUpgrade) { ProUpgradeView().environmentObject(store).pbEditorSheetStyle() }
        .sheet(isPresented: $showingPresetPicker) {
            PBSetupPresetPicker { preset, selectedMaterial in
                applyPreset(preset, selectedMaterial: selectedMaterial)
                startMethod = presetSelectionAsBase ? .presetBase : .preset
            }
        }
        .sheet(isPresented: $showingSavedSetupPicker) {
            PBExistingSetupPicker { applySavedSetup($0) }
        }
        .onAppear { applyNewDraftDefaults() }
        .onDisappear {
            if !saved, !draft.id.isEmpty { store.discardPreparedSetupReuse(id: draft.id) }
        }
    }

    private var activeMachines: [MachineProfile] {
        let machines = store.machines.filter(\.active)
        guard let recentNickname = store.recentSetups.first?.machineNickname,
              let index = machines.firstIndex(where: { $0.nickname == recentNickname }) else { return machines }
        var prioritized = machines
        let recent = prioritized.remove(at: index)
        prioritized.insert(recent, at: 0)
        return prioritized
    }

    private var choosingStartMethod: Bool {
        mode == .full && draft.id.isEmpty && startMethod == nil
    }

    private var prioritizedMaterials: [String] {
        PBPrefillCatalog.customerVisibleChoices(
            for: .materials,
            recent: store.recentSetups.map(\.material),
            language: language,
            locale: locale
        )
    }

    private var prioritizedTransferMedia: [String] {
        PBPrefillCatalog.customerVisibleChoices(
            for: .transferMedia,
            recent: store.recentSetups.map(\.transferMedium),
            language: language,
            locale: locale
        )
    }

    private var prioritizedPressureDescriptions: [String] {
        PBPrefillCatalog.customerVisibleChoices(
            for: .pressureDescriptions,
            recent: store.recentSetups.map(\.pressure),
            language: language,
            locale: locale
        )
    }

    private var prioritizedInstructionSources: [String] {
        PBPrefillCatalog.customerVisibleChoices(
            for: .instructionSources,
            recent: store.recentSetups.map { store.setupDraft(for: $0.id).sourceName },
            language: language,
            locale: locale
        )
    }

    private var prioritizedPlacementActions: [String] {
        PBPrefillCatalog.customerVisibleChoices(
            for: .placementActions,
            recent: store.recentSetups.flatMap(\.stages).map(\.placementAction),
            language: language,
            locale: locale
        )
    }

    private var prioritizedFinishActions: [String] {
        PBPrefillCatalog.customerVisibleChoices(
            for: .finishActions,
            recent: store.recentSetups.flatMap(\.stages).map(\.finishAction),
            language: language,
            locale: locale
        )
    }

    private var suggestedSetupTitle: String {
        let machine = activeMachines.first(where: { $0.id == draft.machineID })?.nickname ?? ""
        return [draft.material, draft.transferMedium, machine]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var effectiveSetupTitle: String {
        let entered = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return entered.isEmpty ? suggestedSetupTitle : entered
    }

    private func applyNewDraftDefaults() {
        guard draft.id.isEmpty else { return }
        var changed = false
        if !activeMachines.contains(where: { $0.id == draft.machineID }), let machine = activeMachines.first {
            draft.machineID = machine.id
            changed = true
        }
        for index in draft.stages.indices where
            draft.stages[index].temperature.isEmpty &&
            draft.stages[index].durationSeconds.isEmpty &&
            draft.stages[index].pressure.isEmpty &&
            draft.stages[index].temperatureUnit != unit {
            draft.stages[index].temperatureUnit = unit
            changed = true
        }
        if changed { originalDraft = draft }
    }

    private func applyPreset(_ preset: PBSetupPresetCatalog.Entry, selectedMaterial: String) {
        let temperature: (Int) -> String = { fahrenheit in
            unit == "C" ? String(Int(round((Double(fahrenheit) - 32) * 5 / 9))) : String(fahrenheit)
        }
        draft.title = preset.name
        draft.material = PBSetupPresetCatalog.resolvedMaterial(
            for: preset, selectedMaterial: selectedMaterial
        )
        draft.transferMedium = preset.brand == "Siser" ? "Heat transfer vinyl (HTV)" : "Screen-printed transfer"
        draft.sourceName = "Manufacturer instructions"
        draft.sourceReference = "\(preset.brand) · \(preset.name) · \(preset.sourceURL.absoluteString)"
        draft.sourceCheckedDate = preset.sourceCheckedDate
        draft.sourceRevision = ""
        var stages = [SetupStageDraft(
            stageType: "prepress", name: "", instruction: "Remove moisture and wrinkles before placement.",
            durationSeconds: String(preset.prepressSeconds)
        ), SetupStageDraft(
            stageType: "press", name: "", instruction: preset.publishedGuidance, temperature: temperature(preset.temperatureF),
            temperatureUnit: unit, durationSeconds: String(preset.durationSeconds), pressure: preset.pressure
        )]
        if let second = preset.secondPress {
            stages.append(SetupStageDraft(
                stageType: "press", name: "", instruction: "", temperature: temperature(second.temperatureF),
                temperatureUnit: unit, durationSeconds: String(second.durationSeconds), pressure: second.pressure
            ))
        }
        stages.append(SetupStageDraft(stageType: "peel", name: "", instruction: preset.peel, finishAction: preset.peel))
        draft.stages = stages
        if !preset.aftercare.isEmpty { draft.notes = preset.aftercare }
    }

    private func applySavedSetup(_ setup: Setup) {
        do {
            let prepared = try store.prepareSetupReuse(setupID: setup.id, reuseClass: .materiallyDifferent)
            draft = prepared
            originalDraft = prepared
            startMethod = .saved
        } catch {
            failureMessageKey = store.errorLocalizationKey(error)
            failed = true
        }
    }

    private var isReady: Bool {
        if mode == .sameProductVariant {
            return !effectiveSetupTitle.isEmpty &&
                (Int(draft.defaultQuantity).map { (1...PBInputLimits.maximumQuantity).contains($0) } == true)
        }
        let hasPressStage = draft.stages.contains(where: { $0.stageType == "press" })
        return !draft.stages.isEmpty && draft.stages.count <= PBInputLimits.maximumStages &&
        !draft.material.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.transferMedium.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.machineID.isEmpty && hasPressStage && draft.stages.allSatisfy { stage in
            let repeatReady = Int(stage.repeatCount.isEmpty ? "1" : stage.repeatCount).map {
                (1...PBInputLimits.maximumRepeatCount).contains($0)
            } == true
            guard stage.stageType == "press" else { return repeatReady }
            return repeatReady && Int(stage.durationSeconds).map {
                (1...PBInputLimits.maximumDurationSeconds).contains($0)
            } == true && localizedDecimal(stage.temperature).map {
                $0 > 0 && $0 <= PBInputLimits.maximumTemperature
            } == true &&
                !stage.pressure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } &&
        !draft.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.sourceReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(draft.defaultQuantity).map { (1...PBInputLimits.maximumQuantity).contains($0) } == true
    }

    private var missingRequiredFields: [String] {
        var fields: [String] = []
        func missing(_ value: String, _ label: String) {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append(label) }
        }
        if Int(draft.defaultQuantity).map({ (1...PBInputLimits.maximumQuantity).contains($0) }) != true {
            fields.append(t("setup.defaultQuantity"))
        }
        guard mode != .sameProductVariant else { return fields }
        missing(draft.material, t("common.material"))
        missing(draft.transferMedium, t("common.transferMedium"))
        if draft.machineID.isEmpty { fields.append(t("machines.title")) }
        missing(draft.sourceName, t("report.instructionSource"))
        missing(draft.sourceReference, t("common.reference"))
        if !draft.stages.contains(where: { $0.stageType == "press" }) { fields.append(t("stage.press")) }
        for (index, stage) in draft.stages.enumerated() {
            let prefix = "\(t("stage.stage")) \(PBFormat.integer(index + 1, locale: locale))"
            if Int(stage.repeatCount.isEmpty ? "1" : stage.repeatCount).map({
                (1...PBInputLimits.maximumRepeatCount).contains($0)
            }) != true {
                fields.append("\(prefix): \(t("stage.repeatCount"))")
            }
            guard stage.stageType == "press" else { continue }
            if localizedDecimal(stage.temperature).map({ $0 > 0 && $0 <= PBInputLimits.maximumTemperature }) != true {
                fields.append("\(prefix): \(t("common.temperature"))")
            }
            if Int(stage.durationSeconds).map({ (1...PBInputLimits.maximumDurationSeconds).contains($0) }) != true {
                fields.append("\(prefix): \(t("common.durationSeconds"))")
            }
            if stage.pressure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("\(prefix): \(t("common.pressure"))") }
        }
        return fields
    }

    private func save() {
        do {
            var prepared = draft
            if prepared.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                prepared.title = suggestedSetupTitle
            }
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
            let savedID = try store.saveSetup(prepared, temperatureUnit: unit, locale: locale, reuseClass: reuseClass)
            saved = true
            originalDraft = draft
            onSaved?(savedID)
            dismiss()
        }
        catch {
            if store.requiresUpgrade(error) { showingUpgrade = true }
            else { failureMessageKey = store.errorLocalizationKey(error); failed = true }
        }
    }

    private func cancel() {
        if draft == originalDraft { dismiss() } else { showingDiscard = true }
    }

    private func localizedDecimal(_ text: String) -> Double? {
        let formatter = NumberFormatter(); formatter.locale = locale; formatter.numberStyle = .decimal
        return formatter.number(from: text)?.doubleValue ?? Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func moveStage(id: String, offset: Int) {
        guard let from = draft.stages.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard draft.stages.indices.contains(to) else { return }
        draft.stages.swapAt(from, to)
        PBFeedback.tap()
    }
}

private struct PBExistingSetupPicker: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    let choose: (Setup) -> Void

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            List(store.recentSetups.filter { $0.status != .archived }) { setup in
                Button {
                    choose(setup)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(setup.title).font(.headline).foregroundStyle(PBTheme.text)
                        Text([setup.material, setup.transferMedium].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(PBTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .scrollContentBackground(.hidden)
            .background(PBTheme.canvasGradient)
            .navigationTitle(t("setup.start.saved"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { dismiss() }
                }
            }
        }
        .pbEditorSheetStyle()
    }
}

private struct PBSetupPresetPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var search = ""
    @State private var sourceFilter = ""
    @State private var materialFilter = ""
    let choose: (PBSetupPresetCatalog.Entry, String) -> Void

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var entries: [PBSetupPresetCatalog.Entry] {
        PBSetupPresetCatalog.filteredEntries(search: search, source: sourceFilter, material: materialFilter)
    }
    private func localizedMaterial(_ material: String) -> String {
        PBPrefillCatalog.localizedValue(material, for: .materials, language: language, locale: locale)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(t("report.instructionSource"), selection: $sourceFilter) {
                        Text(t("common.all")).tag("")
                        ForEach(PBSetupPresetCatalog.sources, id: \.self) { Text($0).tag($0) }
                    }
                    .accessibilityIdentifier("pb.setup.presetSourceFilter")
                    Picker(t("common.material"), selection: $materialFilter) {
                        Text(t("common.all")).tag("")
                        ForEach(PBSetupPresetCatalog.materials, id: \.self) { material in
                            Text(localizedMaterial(material)).tag(material)
                        }
                    }
                    .accessibilityIdentifier("pb.setup.presetMaterialFilter")
                }
                Section {
                    if entries.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                    ForEach(entries) { preset in
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                choose(preset, materialFilter)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name).font(.headline).foregroundStyle(PBTheme.text)
                                    Text(preset.compatibleMaterials.map(localizedMaterial).joined(separator: " · "))
                                        .font(.caption).foregroundStyle(PBTheme.muted)
                                    Text("\(preset.brand) · \(preset.temperatureLabel) · \(preset.durationLabel) · \(preset.pressure)")
                                        .font(.caption).foregroundStyle(PBTheme.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("pb.setup.preset.\(preset.id)")
                            Link(destination: preset.sourceURL) {
                                Label(preset.brand, systemImage: "arrow.up.right.square")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                } footer: {
                    Text(t("setup.presetDisclaimer"))
                }
            }
            .searchable(text: $search, prompt: t("setups.search"))
            .scrollContentBackground(.hidden)
            .background(PBTheme.canvasGradient)
            .navigationTitle(t("setup.selectPreset"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { dismiss() }
                }
            }
        }
        .pbEditorSheetStyle()
    }
}

struct StartRunSheet: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var selectedSetup: Setup?
    @State private var dismissAfterStart = false
    @State private var search = ""
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var availableSetups: [Setup] {
        store.recentSetups.filter {
            $0.status != .draft && (search.isEmpty || [$0.title, $0.material, $0.transferMedium, $0.machineNickname]
                .contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PBPageBackground()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availableSetups) { setup in
                            Button {
                                dismissAfterStart = false
                                selectedSetup = setup
                            } label: {
                                SetupRow(setup: setup, compact: true)
                                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        PBTheme.paper,
                                        in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous)
                                            .stroke(PBTheme.line, lineWidth: 1)
                                    }
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(setup.title)
                            .accessibilityIdentifier("pb.startRun.setup")
                            .buttonStyle(PBTactileButtonStyle())
                        }
                    }
                    .padding(.horizontal, PBTheme.pagePadding)
                    .padding(.vertical, 12)
                }
            }
            .searchable(text: $search, prompt: t("setups.search"))
            .overlay {
                if availableSetups.isEmpty {
                    ContentUnavailableView(t("setups.title"), systemImage: "list.clipboard")
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
            if dismissAfterStart {
                dismissAfterStart = false
                dismiss()
            }
        }) { setup in
            RunConfigurationView(setup: setup) {
                dismissAfterStart = true
            }
                .environmentObject(store)
        }
        .pbEditorSheetStyle()
    }
}

struct RunConfigurationView: View {
    let setup: Setup
    let onStarted: (() -> Void)?
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var draft: RunStartDraft
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @State private var showingUpgrade = false
    @State private var resumeRunAfterUpgrade = false

    init(setup: Setup, onStarted: (() -> Void)? = nil) {
        self.setup = setup
        self.onStarted = onStarted
        _draft = State(initialValue: RunStartDraft(
            setupID: setup.id,
            runMode: setup.status == .proven ? "production" : "test",
            quantity: setup.status == .proven ? String(setup.defaultQuantity) : "1",
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
                            ForEach(setup.stages) { stage in LabeledContent(stage.canonicalLocalizationKey.map(t) ?? stage.name, value: stage.value) }
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
                            Text(t(draft.runMode == "test" ? "run.mode.test.help" : "run.mode.production.help"))
                                .font(.caption).foregroundStyle(PBTheme.secondary)
                            LabeledContent(t("run.plannedQuantity")) {
                                TextField(t("run.plannedQuantity"), text: $draft.quantity)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .disabled(draft.runMode == "test")
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
                            Text(t(draft.progressMode == "live_cycles" ? "run.progress.live.help" : "run.progress.final.help"))
                                .font(.caption).foregroundStyle(PBTheme.secondary)
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
            .scrollDismissesKeyboard(.interactively)
            .pbKeyboardDismissToolbar(t("common.done"))
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
        .onChange(of: draft.runMode) { _, mode in if mode == "test" { draft.quantity = "1" } }
        .sheet(isPresented: $showingUpgrade, onDismiss: {
            guard resumeRunAfterUpgrade else { return }
            resumeRunAfterUpgrade = false
            if store.isPro { start() }
        }) { ProUpgradeView().environmentObject(store).pbEditorSheetStyle() }
    }

    private var isReady: Bool {
        Int(draft.quantity).map { (1...PBInputLimits.maximumQuantity).contains($0) } == true &&
            !(setup.status != .proven && draft.runMode == "production" && !draft.confirmUnprovenProduction)
    }

    private func start() {
        do {
            try store.startRun(draft)
            PBFeedback.success()
            onStarted?()
            dismiss()
        } catch {
            if store.requiresUpgrade(error) { resumeRunAfterUpgrade = true; showingUpgrade = true }
            else { failureMessageKey = store.errorLocalizationKey(error); failed = true }
            PBFeedback.error()
        }
    }
}

struct ProUpgradeView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var showingFailure = false
    @State private var failureMessageKey = "purchase.failed"
    @State private var restoreFoundNothing = false
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        subscriptionSummary

                        if let price = monthlyPrice {
                            monthlyPlan(price: price)
                        } else if store.purchaseOperationInProgress || store.purchaseState == .loading {
                            ProgressView()
                                .controlSize(.large)
                                .frame(maxWidth: .infinity, minHeight: 88)
                                .accessibilityLabel(t("purchase.unavailable"))
                        } else {
                            unavailableMessage
                        }

                        if store.purchaseState == .pending {
                            Label(t("purchase.pending"), systemImage: "clock.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PBTheme.warningInk)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Text(t("upgrade.renewalTerms"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button { restore() } label: {
                            Text(t("upgrade.restore"))
                                .font(.headline)
                                .pbFullSurfaceTarget(alignment: .center)
                        }
                        .accessibilityIdentifier("pb.upgrade.restore")
                        .disabled(store.purchaseOperationInProgress)

                        if restoreFoundNothing {
                            Text(t("purchase.notFound"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 20) { policyLinks }
                            VStack(spacing: 12) { policyLinks }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                }
            }
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .tint(PBTheme.operatorAccent)
            .navigationTitle(t("upgrade.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { dismiss() } } }
            .alert("PressBench", isPresented: $showingFailure) {
                Button(t("common.ok"), role: .cancel) {}
            } message: { Text(t(failureMessageKey)) }
        }
    }

    private var subscriptionSummary: some View {
        VStack(spacing: 10) {
            Text(t("upgrade.body"))
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            if !store.isPro {
                Text(PBL10n.format(
                    "usage.freeRunsRemaining", language: language, locale: locale,
                    PBFormat.integer(store.freePressesRemaining, locale: locale) as NSString,
                    PBFormat.integer(PBUsageMeter.freePressLimit, locale: locale) as NSString
                ))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder private var policyLinks: some View {
        Link(t("common.termsOfUse"), destination: PressBenchPolicyLinks.terms)
            .frame(minHeight: PBTheme.minimumTarget)
        Link(t("common.privacyPolicy"), destination: PressBenchPolicyLinks.privacy)
            .frame(minHeight: PBTheme.minimumTarget)
    }

    private func monthlyPlan(price: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.monochrome)
                .font(.title3)
                .foregroundStyle(PBTheme.operatorAccent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(t("upgrade.monthly"))
                    .font(.headline)
                Text(monthlyPriceText(price))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(PBTheme.operatorAccent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous)
                .stroke(PBTheme.operatorAccent, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isSelected)
        .accessibilityIdentifier("pb.upgrade.monthly")
    }

    private var unavailableMessage: some View {
        Label(t("purchase.unavailable"), systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PBTheme.warningInk)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 88)
            .padding(.horizontal)
    }

    @ViewBuilder private var purchaseBar: some View {
        if let price = monthlyPrice {
            PBPrimaryButton(
                title: "\(t("upgrade.unlock")) · \(monthlyPriceText(price))",
                icon: "creditcard.fill",
                isLoading: store.purchaseOperationInProgress
            ) { purchase() }
            .accessibilityIdentifier("pb.upgrade.purchase")
            .disabled(store.purchaseOperationInProgress || store.purchaseState == .pending)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        } else if !store.purchaseOperationInProgress && store.purchaseState != .loading {
            PBPrimaryButton(title: t("common.retry"), icon: "arrow.clockwise") { retryProduct() }
                .accessibilityIdentifier("pb.upgrade.retry")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
        }
    }

    private var monthlyPrice: String? {
        store.subscriptionDisplayPrice(for: .monthly)
    }

    private func monthlyPriceText(_ price: String) -> String {
        PBL10n.format("upgrade.pricePerMonthFormat", language: language, locale: locale, price as NSString)
    }

    private func purchase() {
        restoreFoundNothing = false
        failureMessageKey = "purchase.failed"
        Task { @MainActor in
            await store.purchasePro(.monthly)
            if store.isPro { dismiss(); return }
            switch store.purchaseState {
            case .pending, .free: break
            case .loading, .unavailable, .failed: showingFailure = true
            case .purchased: dismiss()
            }
        }
    }

    private func restore() {
        restoreFoundNothing = false
        failureMessageKey = "restore.failed"
        Task { @MainActor in
            await store.restorePurchases()
            if store.isPro { dismiss(); return }
            switch store.purchaseState {
            case .free: restoreFoundNothing = true
            case .pending: break
            case .loading, .unavailable, .failed: showingFailure = true
            case .purchased: dismiss()
            }
        }
    }

    private func retryProduct() {
        Task { @MainActor in
            await store.reloadPurchases()
            if monthlyPrice == nil { showingFailure = true }
        }
    }
}
