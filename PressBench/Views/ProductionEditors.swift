import SwiftUI

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

    let onSaved: ((String) -> Void)?

    init(draft: MachineDraft = MachineDraft(), onSaved: ((String) -> Void)? = nil) {
        _draft = State(initialValue: draft)
        _originalDraft = State(initialValue: draft)
        _nicknameWasEdited = State(initialValue: !draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        self.onSaved = onSaved
    }
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if knownBrands.isEmpty {
                        TextField(t("common.brand"), text: $draft.brand)
                    } else {
                        PBChoiceField(
                            title: t("common.brand"),
                            selection: $draft.brand,
                            choices: knownBrands,
                            identifier: "pb.choice.machineBrand",
                            tapToSelectTitle: t("common.tapToSelect"),
                            otherTitle: t("issue.symptom.other"),
                            cancelTitle: t("common.cancel")
                        )
                    }
                    if knownModels.isEmpty {
                        TextField(t("common.model"), text: $draft.model)
                    } else {
                        PBChoiceField(
                            title: t("common.model"),
                            selection: $draft.model,
                            choices: knownModels,
                            identifier: "pb.choice.machineModel",
                            tapToSelectTitle: t("common.tapToSelect"),
                            otherTitle: t("issue.symptom.other"),
                            cancelTitle: t("common.cancel")
                        )
                    }
                    PBChoiceField(
                        title: t("common.platen") + " *",
                        selection: $draft.platen,
                        choices: knownPlatens,
                        identifier: "pb.choice.platen",
                        tapToSelectTitle: t("common.tapToSelect"),
                        otherTitle: t("issue.symptom.other"),
                        cancelTitle: t("common.cancel")
                    )
                    TextField(t("common.name"), text: nicknameBinding)
                    if !machineReady {
                        Label(t("error.machineRequired"), systemImage: "asterisk")
                            .font(.caption).foregroundStyle(PBTheme.warningInk)
                    }
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
            .environment(\.defaultMinListRowHeight, PBTheme.minimumTarget)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .pbKeyboardDismissToolbar(t("common.ok"))
            .background(PBTheme.canvasGradient)
            .tint(PBTheme.primary)
            .navigationTitle(t("machines.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { cancel() }
                        .accessibilityIdentifier("pb.editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("common.save")) { save() }
                        .disabled(!machineReady)
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
        .onChange(of: draft.brand) { _, _ in applySuggestedNickname() }
        .onChange(of: draft.model) { _, _ in applySuggestedNickname() }
        .onChange(of: draft.platen) { _, _ in applySuggestedNickname() }
    }

    private var machineReady: Bool {
        !draft.platen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var knownBrands: [String] {
        PBPrefillCatalog.prioritized([], recent: store.machines.map(\.brand))
    }
    private var knownModels: [String] {
        let matchingMachines = store.machines.filter {
            draft.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            $0.brand.compare(draft.brand, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        return PBPrefillCatalog.prioritized([], recent: matchingMachines.map(\.model))
    }
    private var knownPlatens: [String] {
        PBPrefillCatalog.customerVisibleChoices(
            for: .platenSizes,
            recent: store.machines.map(\.platen),
            language: language,
            locale: locale
        )
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
            var prepared = draft
            if prepared.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                prepared.nickname = suggestedNickname
            }
            let id = try store.saveMachine(prepared)
            draft = prepared
            originalDraft = prepared
            onSaved?(id)
            dismiss()
        }
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
    @State private var originalDraft: SetupDraft
    @State private var failed = false
    @State private var failureMessageKey = "common.actionFailed"
    @State private var saved = false
    @State private var showingDiscard = false
    @State private var pendingStageRemovalID: String?
    @State private var showingUpgrade = false
    let mode: SetupEditorMode
    let onSaved: ((String) -> Void)?

    init(draft: SetupDraft, mode: SetupEditorMode = .full, onSaved: ((String) -> Void)? = nil) {
        _draft = State(initialValue: draft)
        _originalDraft = State(initialValue: draft)
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
                    if mode != .sameProductVariant {
                        if activeMachines.count == 1, let machine = activeMachines.first {
                            LabeledContent(t("machines.title"), value: machine.nickname)
                        } else {
                            Picker(t("machines.title") + " *", selection: $draft.machineID) {
                                ForEach(activeMachines) { machine in Text(machine.nickname).tag(machine.id) }
                            }
                        }
                        PBChoiceField(
                            title: t("common.material") + " *",
                            selection: $draft.material,
                            choices: prioritizedMaterials,
                            identifier: "pb.choice.material",
                            tapToSelectTitle: t("common.tapToSelect"),
                            otherTitle: t("issue.symptom.other"),
                            cancelTitle: t("common.cancel")
                        )
                        PBChoiceField(
                            title: t("common.transferMedium") + " *",
                            selection: $draft.transferMedium,
                            choices: prioritizedTransferMedia,
                            identifier: "pb.choice.transfer",
                            tapToSelectTitle: t("common.tapToSelect"),
                            otherTitle: t("issue.symptom.other"),
                            cancelTitle: t("common.cancel")
                        )
                    }
                }
                if mode == .sameProductVariant {
                    Section(t("setup.processLocked")) {
                        LabeledContent(t("common.material"), value: draft.material)
                        LabeledContent(t("common.transferMedium"), value: draft.transferMedium)
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
                    .disabled(mode == .sameProductVariant)
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
                if mode != .sameProductVariant {
                    Section {
                        Button { draft.stages.append(SetupStageDraft(temperatureUnit: unit)) } label: {
                            Label(t("stage.add"), systemImage: "plus.circle.fill")
                        }
                        .frame(minHeight: PBTheme.minimumTarget)
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
            .environment(\.defaultMinListRowHeight, PBTheme.minimumTarget)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .pbKeyboardDismissToolbar(t("common.ok"))
            .background(PBTheme.canvasGradient)
            .tint(PBTheme.primary)
            .navigationTitle(t("setup.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) { cancel() }
                        .accessibilityIdentifier("pb.editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("common.save")) { save() }
                        .disabled(!isReady)
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

    private var isReady: Bool {
        if mode == .sameProductVariant {
            return !effectiveSetupTitle.isEmpty && (Int(draft.defaultQuantity).map { $0 > 0 } == true)
        }
        let hasPressStage = draft.stages.contains(where: { $0.stageType == "press" })
        return !draft.material.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.transferMedium.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.machineID.isEmpty && hasPressStage && draft.stages.allSatisfy { stage in
            let repeatReady = Int(stage.repeatCount.isEmpty ? "1" : stage.repeatCount).map { $0 > 0 } == true
            guard stage.stageType == "press" else { return repeatReady }
            return repeatReady && Int(stage.durationSeconds).map { $0 > 0 } == true &&
                localizedDecimal(stage.temperature).map { $0 > 0 } == true &&
                !stage.pressure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } &&
        !draft.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.sourceReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(draft.defaultQuantity).map { $0 > 0 } == true
    }

    private var missingRequiredFields: [String] {
        var fields: [String] = []
        func missing(_ value: String, _ label: String) {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append(label) }
        }
        if Int(draft.defaultQuantity).map({ $0 > 0 }) != true { fields.append(t("setup.defaultQuantity")) }
        guard mode != .sameProductVariant else { return fields }
        missing(draft.material, t("common.material"))
        missing(draft.transferMedium, t("common.transferMedium"))
        if draft.machineID.isEmpty { fields.append(t("machines.title")) }
        missing(draft.sourceName, t("report.instructionSource"))
        missing(draft.sourceReference, t("common.reference"))
        if !draft.stages.contains(where: { $0.stageType == "press" }) { fields.append(t("stage.press")) }
        for (index, stage) in draft.stages.enumerated() {
            let prefix = "\(t("stage.stage")) \(PBFormat.integer(index + 1, locale: locale))"
            if Int(stage.repeatCount.isEmpty ? "1" : stage.repeatCount).map({ $0 > 0 }) != true {
                fields.append("\(prefix): \(t("stage.repeatCount"))")
            }
            guard stage.stageType == "press" else { continue }
            if localizedDecimal(stage.temperature).map({ $0 > 0 }) != true { fields.append("\(prefix): \(t("common.temperature"))") }
            if Int(stage.durationSeconds).map({ $0 > 0 }) != true { fields.append("\(prefix): \(t("common.durationSeconds"))") }
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

struct StartRunSheet: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var selectedSetup: Setup?
    @State private var dismissAfterDifference = false
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
            List(availableSetups) { setup in
                Button {
                    dismissAfterDifference = false
                    selectedSetup = setup
                } label: {
                    SetupRow(setup: setup, compact: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pb.startRun.setup")
            }
            .environment(\.defaultMinListRowHeight, 64)
            .scrollContentBackground(.hidden)
            .background(PBTheme.canvasGradient)
            .tint(PBTheme.primary)
            .searchable(text: $search, prompt: t("setups.search"))
            .overlay {
                if availableSetups.isEmpty {
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
    @State private var selectedReuseClass: SetupReuseClass?
    @State private var childRoute: JobDifferenceChildRoute?
    @State private var pendingConfigurationSetupID: String?
    @State private var runStarted = false

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
                            subtitle: t("run.reuse.\(reuseClass.rawValue).help"),
                            icon: reuseClass.systemImage,
                            selected: selectedReuseClass == reuseClass
                        ) {
                            selectedReuseClass = reuseClass
                        }
                    }

                    PBPrimaryButton(title: t("common.continue")) { continueRun() }
                        .disabled(selectedReuseClass == nil)
                        .padding(.top, 10)
                }
                .padding(.horizontal, PBTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
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
                        pendingConfigurationSetupID = savedID
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
            guard let selectedReuseClass else { return }
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
    @State private var showingUpgrade = false
    @State private var resumeRunAfterUpgrade = false

    init(setup: Setup, onStarted: @escaping () -> Void) {
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
                            if draft.runMode == "test" { Text(t("run.testQuantityHelp")).font(.caption).foregroundStyle(PBTheme.secondary) }
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
            .pbKeyboardDismissToolbar(t("common.ok"))
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
    @State private var actionInProgress = false
    @State private var showingFailure = false
    @State private var failureMessageKey = "purchase.failed"
    @State private var restoreFoundNothing = false
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "infinity.circle.fill").font(.system(size: 64)).foregroundStyle(PBTheme.primary)
                    Text(t("upgrade.title")).font(.title.bold()).multilineTextAlignment(.center)
                    Text(t("upgrade.body")).foregroundStyle(PBTheme.secondary).multilineTextAlignment(.center)
                    if !store.isPro {
                        Text(PBL10n.format(
                            "usage.freeRunsRemaining", language: language, locale: locale,
                            PBFormat.integer(store.freePressesRemaining, locale: locale) as NSString,
                            PBFormat.integer(PBUsageMeter.freePressLimit, locale: locale) as NSString
                        ))
                        .font(.headline).foregroundStyle(PBTheme.text).multilineTextAlignment(.center)
                    }
                    if actionInProgress { ProgressView().controlSize(.large) }
                    if store.purchaseState == .pending {
                        Label(t("purchase.pending"), systemImage: "clock.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(PBTheme.warningInk)
                            .multilineTextAlignment(.center)
                    }
                    if store.productDisplayPrice == nil && store.purchaseState != .loading {
                        Label(t("purchase.unavailable"), systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(PBTheme.warningInk)
                            .multilineTextAlignment(.center)
                        Button(t("common.retry")) { retryProduct() }
                            .font(.headline).frame(minHeight: PBTheme.minimumTarget)
                            .disabled(actionInProgress)
                    }
                    PBPrimaryButton(title: subscribeTitle, icon: "creditcard.fill") { purchase() }
                        .disabled(actionInProgress || store.purchaseState == .pending || store.productDisplayPrice == nil)
                    Button(t("upgrade.restore")) { restore() }
                        .font(.headline).frame(minHeight: PBTheme.minimumTarget)
                        .disabled(actionInProgress)
                    if restoreFoundNothing {
                        Text(t("purchase.notFound"))
                            .font(.subheadline).foregroundStyle(PBTheme.secondary).multilineTextAlignment(.center)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 20) { policyLinks }
                        VStack(spacing: 12) { policyLinks }
                    }
                    .font(.footnote.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(PBTheme.pagePadding)
            }
            .background(PBTheme.canvasGradient.ignoresSafeArea())
            .navigationTitle(t("upgrade.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { dismiss() } } }
            .alert("PressBench", isPresented: $showingFailure) {
                Button(t("common.ok"), role: .cancel) {}
            } message: { Text(t(failureMessageKey)) }
        }
    }

    @ViewBuilder private var policyLinks: some View {
        Link(t("common.termsOfUse"), destination: PressBenchPolicyLinks.terms)
        Link(t("common.privacyPolicy"), destination: PressBenchPolicyLinks.privacy)
    }

    private var subscribeTitle: String {
        guard let price = store.productDisplayPrice else { return t("upgrade.unlock") }
        let monthlyPrice = PBL10n.format("upgrade.pricePerMonthFormat", language: language, locale: locale, price as NSString)
        return "\(t("upgrade.unlock")) · \(monthlyPrice)"
    }

    private func purchase() {
        restoreFoundNothing = false
        failureMessageKey = "purchase.failed"
        actionInProgress = true
        Task { @MainActor in
            await store.purchasePro()
            actionInProgress = false
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
        actionInProgress = true
        Task { @MainActor in
            await store.restorePurchases()
            actionInProgress = false
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
        actionInProgress = true
        Task { @MainActor in
            await store.reloadPurchases()
            actionInProgress = false
            if store.productDisplayPrice == nil { showingFailure = true }
        }
    }
}

private struct JobDifferenceOption: View {
    let title: String
    let subtitle: String
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(PBTheme.text)
                    Text(subtitle).font(.caption).foregroundStyle(PBTheme.secondary)
                }.fixedSize(horizontal: false, vertical: true)
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
