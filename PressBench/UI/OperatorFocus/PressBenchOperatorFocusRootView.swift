import SwiftUI

/// The approved three-destination PressBench interface.
///
/// This layer owns presentation only. Every mutation continues to pass through
/// `PressBenchStore`, preserving the tested domain, persistence and entitlement
/// boundaries.
struct PressBenchOperatorFocusRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: PressBenchStore
    @AppStorage(AppLanguageStorage.key) private var storedLanguage = AppLanguage.detected().rawValue

    @State private var destination: OFDestination = .today
    @State private var showsSettings = false
    @State private var showsUpgrade = false
    @State private var selectedSetupID: String?

    private var language: AppLanguage { AppLanguageStorage.resolved(rawValue: storedLanguage) }

    var body: some View {
        Group {
            if store.persistenceWarning != nil {
                NavigationStack { SettingsView() }
            } else {
                Group {
                    if horizontalSizeClass == .regular {
                        tabletLayout
                    } else {
                        phoneLayout
                    }
                }
            }
        }
        .tint(OFTheme.accent)
        .environment(\.pbLanguage, language)
        .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                SettingsView()
            }
            .environment(\.pbLanguage, language)
            .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight)
        }
        .sheet(isPresented: $showsUpgrade) {
            ProUpgradeView()
                .environmentObject(store)
                .pbEditorSheetStyle()
                .environment(\.pbLanguage, language)
                .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await store.purchases.refresh() }
        }
    }

    private var phoneLayout: some View {
        TabView(selection: $destination) {
            NavigationStack { today }
                .tabItem { Label(text("nav.today"), systemImage: "house.fill") }
                .tag(OFDestination.today)

            NavigationStack { run }
                .tabItem { Label(text("runs.title"), systemImage: "play.square.fill") }
                .tag(OFDestination.run)

            NavigationStack { library }
                .tabItem { Label(text("nav.library"), systemImage: "square.grid.2x2.fill") }
                .tag(OFDestination.library)
        }
    }

    private var tabletLayout: some View {
        NavigationSplitView {
            List(OFDestination.allCases) { item in
                Button {
                    destination = item
                } label: {
                    Label(text(item.localizationKey), systemImage: item.systemImage)
                        .foregroundStyle(destination == item ? OFTheme.accent : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(destination == item ? .isSelected : [])
            }
            .navigationTitle(text("app.name"))
            .safeAreaInset(edge: .bottom) {
                Button {
                    showsSettings = true
                } label: {
                    Label(text("common.settings"), systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                .background(.thinMaterial)
            }
        } detail: {
            NavigationStack {
                switch destination {
                case .today: today
                case .run: run
                case .library: library
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var today: some View {
        OFTodayView(destination: $destination, showsUpgrade: $showsUpgrade, selectedSetupID: $selectedSetupID)
            .operatorFocusToolbar(showsSettings: $showsSettings, accessibilityLabel: text("common.settings"))
    }

    private var run: some View {
        OFRunView(destination: $destination, showsUpgrade: $showsUpgrade, selectedSetupID: $selectedSetupID)
            .operatorFocusToolbar(showsSettings: $showsSettings, accessibilityLabel: text("common.settings"))
    }

    private var library: some View {
        OFLibraryView()
            .operatorFocusToolbar(showsSettings: $showsSettings, accessibilityLabel: text("common.settings"))
    }

    private func text(_ key: String) -> String {
        PBL10n.text(key, language: language, locale: locale)
    }
}

private enum OFDestination: String, CaseIterable, Identifiable {
    case today, run, library

    var id: String { rawValue }
    var localizationKey: String {
        switch self {
        case .today: return "nav.today"
        case .run: return "runs.title"
        case .library: return "nav.library"
        }
    }
    var systemImage: String {
        switch self {
        case .today: return "house.fill"
        case .run: return "play.square.fill"
        case .library: return "square.grid.2x2.fill"
        }
    }
}

private enum OFLibrarySection: String, CaseIterable, Identifiable {
    case setups, history, machines
    var id: String { rawValue }
    var localizationKey: String {
        switch self {
        case .setups: return "setups.title"
        case .history: return "common.batchHistory"
        case .machines: return "machines.title"
        }
    }
}

private enum OFTheme {
    static let accent = Color(red: 0.14, green: 0.38, blue: 0.88)
    static let success = Color(red: 0.05, green: 0.52, blue: 0.34)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

private extension View {
    func operatorFocusToolbar(showsSettings: Binding<Bool>, accessibilityLabel: String) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsSettings.wrappedValue = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(accessibilityLabel)
            }
        }
    }
}

private struct OFTodayView: View {
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @EnvironmentObject private var store: PressBenchStore
    @Binding var destination: OFDestination
    @Binding var showsUpgrade: Bool
    @Binding var selectedSetupID: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(text("nav.today"))
                            .font(.largeTitle.bold())
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(locale)))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(store.operationalReady ? text("common.ok") : text("setup.completeRequired"),
                          systemImage: store.operationalReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(store.operationalReady ? OFTheme.success : .orange)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Button {
                        if store.canStartAnotherRun || store.activeRun != nil {
                            destination = .run
                        } else {
                            showsUpgrade = true
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(store.activeRun == nil ? text("home.startRun.title") : text("runs.activeRun"))
                                    .font(.title2.bold())
                                Spacer()
                                Image(systemName: "arrow.forward.circle.fill")
                                    .font(.title2)
                                    .accessibilityHidden(true)
                            }
                            if let run = store.activeRun {
                                Text(run.title)
                                Text(PBL10n.format("runs.unitsProgress", language: language, locale: locale,
                                                 PBFormat.integer(run.processed, locale: locale) as NSString,
                                                 PBFormat.integer(run.planned, locale: locale) as NSString))
                                    .font(.subheadline)
                                    .opacity(0.82)
                            } else if store.isPro {
                                Text(text("upgrade.body"))
                                    .font(.subheadline)
                                    .opacity(0.82)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    if store.activeRun == nil && !store.isPro {
                        Divider().overlay(.white.opacity(0.28))
                        HStack(spacing: 12) {
                            Text(PBL10n.format("usage.freeRunsRemaining", language: language, locale: locale,
                                             PBFormat.integer(store.freePressesRemaining, locale: locale) as NSString,
                                             PBFormat.integer(PBUsageMeter.freePressLimit, locale: locale) as NSString))
                                .font(.subheadline)
                                .opacity(0.86)
                            Spacer()
                            Button {
                                showsUpgrade = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text(text("upgrade.unlock"))
                                        .font(.subheadline.bold())
                                    Image(systemName: "chevron.forward")
                                        .font(.caption.bold())
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(text("upgrade.body"))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .foregroundStyle(.white)
                .background(OFTheme.accent.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                OFMetricGrid(metrics: store.metrics)

                HStack {
                    Text(text("home.recentSetups"))
                        .font(.headline)
                    Spacer()
                    Button(text("home.viewAll")) { destination = .library }
                        .font(.subheadline.bold())
                }

                if store.recentSetups.isEmpty {
                    OFEmptyState(
                        icon: "slider.horizontal.3",
                        title: text("setup.start.choose"),
                        message: text("onboarding.ready.setup.body"),
                        button: text("setup.start.manual")
                    ) { destination = .library }
                } else {
                    ForEach(store.recentSetups.prefix(3)) { setup in
                        OFSetupRow(setup: setup) {
                            selectedSetupID = setup.id
                            destination = .run
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(text("app.name"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func text(_ key: String) -> String {
        PBL10n.text(key, language: language, locale: locale)
    }
}

private struct OFMetricGrid: View {
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    let metrics: DashboardMetrics

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metric(PBFormat.percent(metrics.firstPassYield, locale: locale), "home.metric.firstPass", "checkmark.seal.fill")
            metric(PBFormat.integer(metrics.batches, locale: locale), "home.metric.batches", "square.stack.3d.up.fill")
            metric(PBFormat.percent(metrics.wasteRate, locale: locale), "home.metric.waste", "arrow.down.right.circle.fill")
        }
    }

    private func metric(_ value: String, _ key: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).foregroundStyle(OFTheme.accent)
            Text(value).font(.title3.bold()).minimumScaleFactor(0.7)
            Text(PBL10n.text(key, language: language, locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(12)
        .background(OFTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OFRunView: View {
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @EnvironmentObject private var store: PressBenchStore
    @Binding var destination: OFDestination
    @Binding var showsUpgrade: Bool
    @Binding var selectedSetupID: String?

    var body: some View {
        Group {
            if let run = store.activeRun {
                ActiveRunView(runID: run.id)
            } else {
                OFRunStartView(destination: $destination, showsUpgrade: $showsUpgrade,
                               selectedSetupID: $selectedSetupID)
            }
        }
        .navigationTitle(text("runs.title"))
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func text(_ key: String) -> String {
        PBL10n.text(key, language: language, locale: locale)
    }
}

private struct OFRunStartView: View {
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @EnvironmentObject private var store: PressBenchStore
    @Binding var destination: OFDestination
    @Binding var showsUpgrade: Bool
    @Binding var selectedSetupID: String?

    @State private var setupID = ""
    @State private var quantity = "1"
    @State private var jobReference = ""
    @State private var errorMessage = ""
    @State private var showsError = false

    var body: some View {
        Form {
            if activeSetups.isEmpty {
                Section {
                    OFEmptyState(icon: "slider.horizontal.3", title: text("setup.start.choose"),
                                 message: text("onboarding.ready.setup.body"), button: text("setups.title")) {
                        destination = .library
                    }
                }
            } else {
                Section(text("setup.start.choose")) {
                    Picker(text("setups.title"), selection: $setupID) {
                        ForEach(activeSetups) { setup in
                            Text(setup.title).tag(setup.id)
                        }
                    }
                }
                Section(text("run.mode")) {
                    TextField(text("run.plannedQuantity"), text: $quantity)
                        .keyboardType(.numberPad)
                    TextField(text("run.jobReference"), text: $jobReference)
                }
                Section {
                    Button {
                        begin()
                    } label: {
                        Label(text("home.startRun.title"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(setupID.isEmpty)
                } footer: {
                    if !store.isPro {
                        HStack(spacing: 12) {
                            Text(PBL10n.format("usage.freeRunsRemaining", language: language, locale: locale,
                                             PBFormat.integer(store.freePressesRemaining, locale: locale) as NSString,
                                             PBFormat.integer(PBUsageMeter.freePressLimit, locale: locale) as NSString))
                            Spacer()
                            Button(text("upgrade.unlock")) { showsUpgrade = true }
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .onAppear {
            guard setupID.isEmpty else { return }
            let requested = selectedSetupID.flatMap { id in activeSetups.first(where: { $0.id == id }) }
            guard let setup = requested ?? store.recentSetups.first ?? activeSetups.first else { return }
            setupID = setup.id
            quantity = String(setup.defaultQuantity)
        }
        .onChange(of: setupID) { _, id in
            selectedSetupID = id
            guard let setup = store.setups.first(where: { $0.id == id }) else { return }
            quantity = String(setup.defaultQuantity)
        }
        .onChange(of: selectedSetupID) { _, id in
            guard let id, let setup = activeSetups.first(where: { $0.id == id }) else { return }
            setupID = setup.id
            quantity = String(setup.defaultQuantity)
        }
        .alert(text("common.actionFailed"), isPresented: $showsError) {
            Button(text("common.ok"), role: .cancel) { }
        } message: { Text(errorMessage) }
    }

    private func begin() {
        guard let setup = store.setups.first(where: { $0.id == setupID }) else { return }
        guard store.canStartAnotherRun else { showsUpgrade = true; return }
        var draft = RunStartDraft(setupID: setupID)
        draft.quantity = quantity
        draft.jobReference = jobReference
        draft.runMode = setup.status == .proven ? "production" : "test"
        draft.progressMode = "live_cycles"
        do { try store.startRun(draft) }
        catch {
            if store.requiresUpgrade(error) { showsUpgrade = true }
            else {
                errorMessage = text(store.errorLocalizationKey(error))
                showsError = true
            }
        }
    }

    private var activeSetups: [Setup] {
        store.setups.filter { $0.status != .archived }
    }

    private func text(_ key: String) -> String {
        PBL10n.text(key, language: language, locale: locale)
    }
}

private struct OFLibraryView: View {
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @EnvironmentObject private var store: PressBenchStore
    @State private var section: OFLibrarySection = .setups
    @State private var search = ""
    @State private var setupDraft: SetupDraft?
    @State private var machineDraft: MachineDraft?

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ReportsView()
            } label: {
                HStack(spacing: 12) {
                    Label(text("report.productionReport"), systemImage: "chart.bar.doc.horizontal")
                        .font(.headline)
                    Spacer()
                    Text(["PDF", "XLSX"].joined(separator: " · "))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .padding(14)
                .background(OFTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top)

            Picker(text("nav.library"), selection: $section) {
                ForEach(OFLibrarySection.allCases) { item in
                    Text(text(item.localizationKey)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: PBTheme.minimumTarget)
            .padding()

            switch section {
            case .setups: setupList
            case .history: historyList
            case .machines: machineList
            }
        }
        .navigationTitle(text("nav.library"))
        .background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $search, prompt: text("setups.search"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if section != .history {
                    Button { add() } label: { Image(systemName: "plus") }
                        .accessibilityLabel(text(section == .setups ? "setup.start.manual" : "machine.start.catalog"))
                }
            }
        }
        .sheet(item: $setupDraft) { draft in
            OFSetupEditor(initialDraft: draft)
        }
        .sheet(item: $machineDraft) { draft in
            OFMachineEditor(initialDraft: draft)
        }
    }

    private var setupList: some View {
        List(filteredSetups) { setup in
            OFSetupRow(setup: setup) { setupDraft = store.setupDraft(for: setup.id) }
        }
        .overlay {
            if filteredSetups.isEmpty {
                OFEmptyState(icon: "slider.horizontal.3", title: text("setup.start.choose"),
                             message: text("onboarding.ready.setup.body"), button: text("setup.start.manual")) {
                    setupDraft = store.setupDraft(for: nil)
                }
                .padding()
            }
        }
    }

    private var historyList: some View {
        List(filteredRuns) { run in
            NavigationLink {
                CompletedRunDetailView(run: run)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(run.title).font(.headline)
                        Spacer()
                        Text(PBFormat.integer(run.processed, locale: locale))
                            .font(.headline)
                    }
                    Text([run.machineName, run.completedAt.map { PBFormat.date($0, locale: locale, time: true) } ?? ""]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: run.firstPassYield ?? 0)
                        .tint(OFTheme.success)
                }
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
        }
    }

    private var machineList: some View {
        List(filteredMachines) { machine in
            Button { machineDraft = store.machineDraft(for: machine.id) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "printer.fill")
                        .frame(width: 42, height: 42)
                        .foregroundStyle(OFTheme.accent)
                        .background(OFTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(machine.nickname).font(.headline)
                        Text([machine.brand, machine.model, machine.platen].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .overlay {
            if filteredMachines.isEmpty {
                OFEmptyState(icon: "printer", title: text("machine.start.choose"),
                             message: text("onboarding.ready.machine.body"), button: text("machine.start.catalog")) {
                    machineDraft = store.machineDraft(for: nil)
                }
                .padding()
            }
        }
    }

    private var filteredSetups: [Setup] {
        store.setups.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.material.localizedCaseInsensitiveContains(search) }
    }
    private var filteredRuns: [BatchRun] {
        store.runs.filter { $0.state == .completed && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.jobReference.localizedCaseInsensitiveContains(search)) }
    }
    private var filteredMachines: [MachineProfile] {
        store.machines.filter { search.isEmpty || $0.nickname.localizedCaseInsensitiveContains(search) || $0.brand.localizedCaseInsensitiveContains(search) || $0.model.localizedCaseInsensitiveContains(search) }
    }

    private func add() {
        switch section {
        case .setups: setupDraft = store.setupDraft(for: nil)
        case .machines: machineDraft = store.machineDraft(for: nil)
        case .history: break
        }
    }

    private func text(_ key: String) -> String {
        PBL10n.text(key, language: language, locale: locale)
    }
}

private struct OFSetupEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @EnvironmentObject private var store: PressBenchStore
    @State private var draft: SetupDraft
    @State private var showsPresets = false
    @State private var errorMessage = ""
    @State private var showsError = false

    init(initialDraft: SetupDraft) { _draft = State(initialValue: initialDraft) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(text("setup.selectPreset")) { showsPresets = true }
                } footer: {
                    Text(text("setup.presetDisclaimer"))
                }
                Section(text("setup.title")) {
                    TextField(text("common.name"), text: $draft.title)
                    Picker(text("run.machine"), selection: $draft.machineID) {
                        Text(text("common.tapToSelect")).tag("")
                        ForEach(store.machines.filter(\.active)) { machine in Text(machine.nickname).tag(machine.id) }
                    }
                    TextField(text("common.material"), text: $draft.material)
                    TextField(text("common.transferMedium"), text: $draft.transferMedium)
                }
                ForEach(draft.stages.indices, id: \.self) { index in
                    Section {
                        Picker(text("stage.type"), selection: stageBinding(index, \.stageType)) {
                            ForEach(["placement", "prepress", "press", "peel", "cool", "postpress"], id: \.self) { type in
                                Text(text("stage.\(type)" )).tag(type)
                            }
                        }
                        TextField(text("stage.name"), text: stageBinding(index, \.name))
                        if draft.stages[index].stageType == "press" || draft.stages[index].stageType == "prepress" || draft.stages[index].stageType == "postpress" {
                            TextField(text("common.temperature"), text: stageBinding(index, \.temperature))
                                .keyboardType(.decimalPad)
                            TextField(text("common.durationSeconds"), text: stageBinding(index, \.durationSeconds))
                                .keyboardType(.numberPad)
                            TextField(text("common.pressure"), text: stageBinding(index, \.pressure))
                            TextField(text("stage.repeatCount"), text: stageBinding(index, \.repeatCount))
                                .keyboardType(.numberPad)
                        }
                        TextField(text("stage.instruction"), text: stageBinding(index, \.instruction), axis: .vertical)
                        if draft.stages.count > 1 {
                            Button(text("stage.remove"), role: .destructive) { draft.stages.remove(at: index) }
                        }
                    } header: {
                        Text(text("stage.stage") + " " + PBFormat.integer(index + 1, locale: locale))
                    }
                }
                Section {
                    Button(text("stage.add")) {
                        guard draft.stages.count < PBInputLimits.maximumStages else { return }
                        draft.stages.append(SetupStageDraft(temperatureUnit: store.temperatureUnit))
                    }
                    TextField(text("setup.defaultQuantity"), text: $draft.defaultQuantity)
                        .keyboardType(.numberPad)
                        .keyboardType(.numberPad)
                }
                Section(text("report.instructionSource")) {
                    TextField(text("common.name"), text: $draft.sourceName)
                    TextField(text("common.reference"), text: $draft.sourceReference)
                }
                Section(text("common.notes")) { TextField(text("common.notes"), text: $draft.notes, axis: .vertical) }
            }
            .navigationTitle(text("setup.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(text("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(text("common.save")) { save() }.bold() }
            }
            .sheet(isPresented: $showsPresets) {
                OFPresetPicker { entry in
                    apply(entry)
                    showsPresets = false
                }
            }
            .alert(text("common.actionFailed"), isPresented: $showsError) {
                Button(text("common.ok"), role: .cancel) { }
            } message: { Text(errorMessage) }
        }
    }

    private func stageBinding(_ index: Int, _ keyPath: WritableKeyPath<SetupStageDraft, String>) -> Binding<String> {
        Binding {
            guard draft.stages.indices.contains(index) else { return "" }
            return draft.stages[index][keyPath: keyPath]
        } set: { value in
            if draft.stages.isEmpty { draft.stages = [SetupStageDraft(temperatureUnit: store.temperatureUnit)] }
            guard draft.stages.indices.contains(index) else { return }
            draft.stages[index][keyPath: keyPath] = value
        }
    }

    private func apply(_ entry: PBSetupPresetCatalog.Entry) {
        var stages = [SetupStageDraft(
            stageType: "press", name: "", instruction: entry.applicationNote,
            temperature: String(entry.temperatureF), temperatureUnit: "F",
            durationSeconds: String(entry.durationSeconds), pressure: entry.pressure
        )]
        if let second = entry.secondPress {
            stages.append(SetupStageDraft(
                stageType: "postpress", name: "", instruction: entry.aftercare,
                temperature: String(second.temperatureF), temperatureUnit: "F",
                durationSeconds: String(second.durationSeconds), pressure: second.pressure
            ))
        }
        draft.title = entry.name
        draft.material = PBPrefillCatalog.localizedValue(entry.material, for: .materials, language: language, locale: locale)
        draft.transferMedium = entry.name
        draft.sourceName = entry.brand
        draft.sourceReference = entry.sourceURL.absoluteString
        draft.sourceCheckedDate = entry.sourceCheckedDate
        draft.stages = stages
    }

    private func save() {
        do {
            _ = try store.saveSetup(draft, temperatureUnit: store.temperatureUnit, locale: locale)
            dismiss()
        } catch {
            errorMessage = text(store.errorLocalizationKey(error))
            showsError = true
        }
    }

    private func text(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
}

private struct OFPresetPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var search = ""
    let select: (PBSetupPresetCatalog.Entry) -> Void

    var body: some View {
        NavigationStack {
            List(PBSetupPresetCatalog.entries.filter { entry in
                search.isEmpty || entry.name.localizedCaseInsensitiveContains(search) || entry.brand.localizedCaseInsensitiveContains(search)
            }) { entry in
                Button { select(entry) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.name).font(.headline)
                        Text("\(entry.brand) · \(entry.temperatureLabel) · \(entry.durationLabel) · \(entry.pressure)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $search, prompt: text("setups.search"))
            .navigationTitle(text("setup.selectPreset"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(text("common.cancel")) { dismiss() } } }
        }
    }

    private func text(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
}

private struct OFMachineEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @EnvironmentObject private var store: PressBenchStore
    @State private var draft: MachineDraft
    @State private var errorMessage = ""
    @State private var showsError = false

    init(initialDraft: MachineDraft) { _draft = State(initialValue: initialDraft) }

    var body: some View {
        NavigationStack {
            Form {
                Section(text("machine.start.catalog")) {
                    Picker(text("common.brand"), selection: $draft.brand) {
                        Text(text("common.tapToSelect")).tag("")
                        ForEach(PBMachineCatalog.brands, id: \.self) { Text($0).tag($0) }
                    }
                    Picker(text("common.model"), selection: $draft.model) {
                        Text(text("common.tapToSelect")).tag("")
                        ForEach(PBMachineCatalog.models(for: draft.brand), id: \.self) { Text($0).tag($0) }
                    }
                    .disabled(draft.brand.isEmpty)
                }
                Section {
                    TextField(text("common.name"), text: $draft.nickname)
                    TextField(text("common.platen"), text: $draft.platen)
                    TextField(text("common.notes"), text: $draft.notes, axis: .vertical)
                }
            }
            .navigationTitle(text("machines.title"))
            .onChange(of: draft.brand) { _ in
                guard !PBMachineCatalog.models(for: draft.brand).contains(draft.model) else { return }
                draft.model = ""
                draft.platen = ""
            }
            .onChange(of: draft.model) { model in
                guard let entry = PBMachineCatalog.entry(brand: draft.brand, model: model) else { return }
                draft.platen = entry.platen
                if draft.nickname.isEmpty { draft.nickname = [entry.brand, entry.model].joined(separator: " ") }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(text("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(text("common.save")) { save() }.bold() }
            }
            .alert(text("common.actionFailed"), isPresented: $showsError) {
                Button(text("common.ok"), role: .cancel) { }
            } message: { Text(errorMessage) }
        }
    }

    private func save() {
        do { _ = try store.saveMachine(draft); dismiss() }
        catch { errorMessage = text(store.errorLocalizationKey(error)); showsError = true }
    }
    private func text(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
}

private struct OFSetupRow: View {
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    let setup: Setup
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: setup.status == .proven ? "checkmark.seal.fill" : "slider.horizontal.3")
                    .frame(width: 42, height: 42)
                    .foregroundStyle(setup.status == .proven ? OFTheme.success : OFTheme.accent)
                    .background((setup.status == .proven ? OFTheme.success : OFTheme.accent).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(setup.title).font(.headline).foregroundStyle(.primary)
                    Text([setup.material, setup.temperature, setup.duration, setup.pressure].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                OFStatusPill(text: PBL10n.text(setup.status.localizationKey, language: language, locale: locale),
                             color: setup.status == .proven ? OFTheme.success : .orange)
            }
            .contentShape(Rectangle())
            .padding(13)
            .background(OFTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct OFStatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.caption2.bold()).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct OFKeyValueCard: View {
    let rows: [(String, String)]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack { Text(row.0).foregroundStyle(.secondary); Spacer(); Text(row.1).bold() }
                    .font(.subheadline).padding(.vertical, 11)
                if index < rows.count - 1 { Divider() }
            }
        }
        .padding(.horizontal)
        .background(OFTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OFEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let button: String
    let action: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(OFTheme.accent)
            Text(title).font(.headline).multilineTextAlignment(.center)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(button, action: action).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding(22)
        .background(OFTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension SetupDraft: Identifiable {}
extension MachineDraft: Identifiable {}
