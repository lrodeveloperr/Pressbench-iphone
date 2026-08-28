import SwiftUI
import Combine
import UIKit

private enum FirstPieceEvidenceAction: String, Identifiable {
    case adjust, stop
    var id: String { rawValue }
}

struct ActiveRunView: View {
    let runID: String
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var result = ResultDraftInput()
    @State private var failed = false
    @State private var showingQC = false
    @State private var showingEndConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var firstPieceAction: FirstPieceEvidenceAction?
    @State private var announcedTimerCompletion = false
    @State private var customCycleQuantity = "1"
    @State private var showingPause = false
    @State private var showingIssue = false
    @State private var failureMessageKey = "common.actionFailed"
    @AppStorage("pressbench.notifications.enabled") private var notificationsEnabled = true
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 48
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let issueSymptoms = ["unknown", "color_shift", "ghosting", "edge_lift", "adhesion", "scorch", "alignment", "incomplete_transfer", "uneven_heat_pressure", "moisture", "transfer_shift", "contamination", "substrate_defect", "design_setup", "print_supply", "equipment_power", "interrupted", "other"]
    private let issueCauses = ["unknown", "heat", "pressure", "time", "moisture", "placement", "transfer", "substrate", "design", "printer_ink_paper", "equipment_power", "operator_interruption", "other"]

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var run: BatchRun? { store.activeRun?.id == runID ? store.activeRun : store.runs.first(where: { $0.id == runID }) }

    var body: some View {
        Group {
            if let run {
                ScrollView {
                    VStack(spacing: 20) {
                        header(run)
                        runFacts(run)
                        phaseCard(run)
                        actionArea(run)
                        if let code = store.lastErrorCode, !code.isEmpty {
                            Label(t(store.errorLocalizationKey()), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(PBTheme.errorInk).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(PBTheme.pagePadding)
                }
                .onAppear {
                    result.issues = store.loadOperatorIssues(runID: run.id)
                    seedResult(run, force: run.phase == "result_pending")
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                .onChange(of: run.phase) { _, phase in seedResult(run, force: phase == "result_pending") }
                .onChange(of: result.issues) { _, issues in store.saveOperatorIssues(issues, runID: run.id) }
                .onReceive(ticker) { _ in
                    store.tickStageTimer()
                    if store.activeRun?.timerCompleted == true && !announcedTimerCompletion {
                        announcedTimerCompletion = true
                        PBFeedback.success()
                        PBTimerSound.completion()
                        PBTimerNotification.cancel()
                    }
                }
            } else {
                ContentUnavailableView(t("runs.title"), systemImage: "checkmark.circle")
            }
        }
        .navigationTitle(t("runs.activeRun"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background(PBTheme.pageBackground.ignoresSafeArea())
        .sheet(isPresented: $showingQC) { QCCheckSheet().environmentObject(store).pbEditorSheetStyle() }
        .sheet(isPresented: $showingPause) { PauseRunSheet().environmentObject(store).pbEditorSheetStyle() }
        .sheet(isPresented: $showingIssue) { IssueCaptureSheet(issues: $result.issues).pbEditorSheetStyle() }
        .sheet(item: $firstPieceAction) { action in
            FirstPieceEvidenceSheet(action: action) { note in
                PBTimerNotification.cancel()
                if action == .adjust { store.recordFirstPieceAdjustment(note: note) }
                else { store.stopAfterFirstPiece(note: note) }
            }
            .environmentObject(store)
            .pbEditorSheetStyle()
        }
        .confirmationDialog(t("runs.end"), isPresented: $showingEndConfirmation, titleVisibility: .visible) {
            Button(t("runs.end"), role: .destructive) { PBTimerNotification.cancel(); store.endRun(); PBFeedback.warning() }
            Button(t("common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(t("run.discardUnstartedConfirm"), isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
            Button(t("run.discardUnstarted"), role: .destructive) {
                do { try store.discardUnstartedRun(); PBTimerNotification.cancel(); PBFeedback.warning(); dismiss() }
                catch { present(error) }
            }
            Button(t("common.cancel"), role: .cancel) {}
        }
        .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t(failureMessageKey)) }
    }

    private func header(_ run: BatchRun) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(run.title).font(.title2.bold()).foregroundStyle(PBTheme.navy)
            HStack(spacing: 8) {
                Text(t("runs.batch"))
                Text(String(run.id.prefix(12))).monospaced()
                Spacer()
                Label(PBFormat.clock(seconds: run.elapsed, locale: locale), systemImage: "clock")
            }
            .font(.caption).foregroundStyle(PBTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func runFacts(_ run: BatchRun) -> some View {
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            RunFact(value: run.temperature.isEmpty ? "—" : run.temperature, labelKey: "common.temperature")
            RunFact(value: run.duration.isEmpty ? "—" : run.duration, labelKey: "common.durationSeconds")
            RunFact(value: run.pressure.isEmpty ? "—" : run.pressure, labelKey: "common.pressure")
            RunFact(value: run.platen.isEmpty ? "—" : run.platen, labelKey: "common.platen")
        }
    }

    private func phaseCard(_ run: BatchRun) -> some View {
        PBCard(tone: .production) {
            VStack(spacing: 12) {
                if run.timerRemaining != nil {
                    Text(PBL10n.format("runs.stageProgress", language: language, locale: locale,
                        PBFormat.integer(run.stageIndex, locale: locale) as NSString,
                        PBFormat.integer(run.stageCount, locale: locale) as NSString))
                        .font(.caption.weight(.semibold)).foregroundStyle(PBTheme.secondary)
                }
                Text(stageText(run)).font(.title2.bold()).foregroundStyle(PBTheme.navy)
                if !run.currentStageInstruction.isEmpty || !run.currentStagePlacementAction.isEmpty || !run.currentStageFinishAction.isEmpty || run.currentStageRepeatCount > 1 {
                    VStack(alignment: .leading, spacing: 7) {
                        if !run.currentStageInstruction.isEmpty { stageDetail("stage.instruction", run.currentStageInstruction) }
                        if run.currentStageRepeatCount > 1 {
                            stageDetail("stage.repeat", "\(PBFormat.integer(run.currentStageRepeatIndex, locale: locale)) / \(PBFormat.integer(run.currentStageRepeatCount, locale: locale))")
                        }
                        if !run.currentStagePlacementAction.isEmpty { stageDetail("stage.placementAction", run.currentStagePlacementAction) }
                        if !run.currentStageFinishAction.isEmpty { stageDetail("stage.finishAction", run.currentStageFinishAction) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(PBTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if let remaining = run.timerRemaining {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(PBFormat.clock(seconds: remaining, locale: locale))
                            .font(.system(size: max(48, timerSize), weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(PBTheme.navy)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ZStack {
                            Circle().stroke(PBTheme.surface, lineWidth: 12)
                            Circle().trim(from: 0.05, to: run.timerCompleted ? 1 : 0.82)
                                .stroke(run.timerCompleted ? PBTheme.success : PBTheme.recordBlue,
                                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .shadow(color: PBTheme.summaryShadow, radius: 7)
                            Text(PBFormat.clock(seconds: remaining, locale: locale))
                                .font(.system(size: max(48, timerSize), weight: .semibold, design: .rounded))
                                .monospacedDigit().foregroundStyle(PBTheme.navy)
                        }
                        .frame(width: 190, height: 190)
                    }
                }
                Text(PBL10n.format("runs.unitsProgress", language: language, locale: locale,
                    PBFormat.integer(run.processed, locale: locale) as NSString,
                    PBFormat.integer(run.planned, locale: locale) as NSString))
                    .font(.headline).foregroundStyle(PBTheme.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func actionArea(_ run: BatchRun) -> some View {
        switch run.phase {
        case "preflight":
            preflightCard(run)
            primaryButton("run.confirmInstructions", icon: "checkmark.shield") { store.confirmInstructions() }
            discardButtonIfEligible(run)
        case "first_piece":
            timerControls(run)
            firstPieceActions
            discardButtonIfEligible(run)
        case "production_ready":
            primaryButton("run.startProduction", icon: "play.fill") { store.startProduction() }
            discardButtonIfEligible(run)
        case "running":
            timerControls(run)
            productionConsole(run)
        case "paused":
            primaryButton("runs.resume", icon: "play.fill") { store.resumeRun() }
            secondaryButton("qc.title", icon: "checkmark.shield") { showingQC = true }
            destructiveButton("runs.end", icon: "stop.fill") { showingEndConfirmation = true }
        case "result_pending":
            resultForm(run)
        case "completed":
            PBCard(tone: .success) {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(PBTheme.success)
                    Text(t("run.recordResult")).font(.title3.bold())
                    Text(PBL10n.format("runs.unitsProgress", language: language, locale: locale,
                        PBFormat.integer(run.processed, locale: locale) as NSString,
                        PBFormat.integer(run.planned, locale: locale) as NSString))
                }.frame(maxWidth: .infinity)
            }
            primaryButton("common.continue", icon: "checkmark") { dismiss() }
        default:
            EmptyView()
        }
    }

    private func preflightCard(_ run: BatchRun) -> some View {
        PBCard(tone: .caution) {
            VStack(alignment: .leading, spacing: 12) {
                Label(t("run.confirmInstructions"), systemImage: "checkmark.shield.fill")
                    .font(.title3.bold()).foregroundStyle(PBTheme.navy)
                LabeledContent(t("common.material"), value: run.material.isEmpty ? "—" : run.material)
                LabeledContent(t("common.transferMedium"), value: run.transferMedium.isEmpty ? "—" : run.transferMedium)
                LabeledContent(t("run.machine"), value: run.machineName.isEmpty ? "—" : run.machineName)
                Divider()
                Text(t("report.instructionSource")).font(.caption.weight(.bold)).foregroundStyle(PBTheme.secondary)
                Text(run.instructionSource.isEmpty ? "—" : run.instructionSource).font(.subheadline.weight(.semibold))
                if !run.instructionCheckedDate.isEmpty { Text(run.instructionCheckedDate).font(.caption).foregroundStyle(PBTheme.secondary) }
                if !run.processStages.isEmpty {
                    Divider()
                    ForEach(Array(run.processStages.enumerated()), id: \.element.id) { index, stage in
                        HStack(alignment: .top, spacing: 10) {
                            Text(PBFormat.integer(index + 1, locale: locale)).font(.caption.bold()).frame(width: 26, height: 26).background(PBTheme.surface, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stage.name).font(.subheadline.weight(.semibold))
                                if !stage.value.isEmpty { Text(stage.value).font(.caption).foregroundStyle(PBTheme.secondary) }
                                if !stage.instruction.isEmpty { stageDetail("stage.instruction", stage.instruction) }
                                if stage.repeatCount > 1 { stageDetail("stage.repeat", PBFormat.integer(stage.repeatCount, locale: locale)) }
                                if !stage.placementAction.isEmpty { stageDetail("stage.placementAction", stage.placementAction) }
                                if !stage.finishAction.isEmpty { stageDetail("stage.finishAction", stage.finishAction) }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timerControls(_ run: BatchRun) -> some View {
        if run.timerCompleted {
            HStack(spacing: 12) {
                if run.stageIndex > 1 { secondaryButton("run.previousStage", icon: "backward.end.fill") { store.previousStageTimer(); PBFeedback.tap() } }
                if run.stageIndex < run.stageCount { primaryButton("run.nextStage", icon: "forward.end.fill") { store.nextStageTimer(); PBFeedback.tap() } }
            }
        } else if run.timerRunning {
            secondaryButton("run.pauseTimer", icon: "pause.circle") {
                store.pauseStageTimer(); PBTimerNotification.cancel(); PBFeedback.tap()
            }
        } else {
            secondaryButton("run.startTimer", icon: "timer") {
                announcedTimerCompletion = false
                store.startOrRestartTimer(); PBFeedback.tap()
                if let seconds = store.activeRun?.timerRemaining ?? run.timerRemaining {
                    Task {
                        if notificationsEnabled {
                            let notificationPermissionGranted = await PBTimerNotification.requestPermissionIfNeeded()
                            if notificationPermissionGranted {
                                PBTimerNotification.schedule(seconds: seconds, title: "PressBench", body: stageText(run))
                            }
                        }
                    }
                }
            }
        }
    }

    private var firstPieceActions: some View {
        VStack(spacing: 12) {
            primaryButton("run.firstPiecePass", icon: "checkmark.circle.fill") { PBTimerNotification.cancel(); store.recordFirstPiecePass(); PBFeedback.success() }
            HStack(spacing: 12) {
                clearButton("run.adjustRetry", icon: "arrow.triangle.2.circlepath") { firstPieceAction = .adjust; PBFeedback.warning() }
                clearButton("run.stopWithNote", icon: "stop.fill", destructive: true) { firstPieceAction = .stop }
            }
        }
    }

    private func productionConsole(_ run: BatchRun) -> some View {
        VStack(spacing: 14) {
            PBCard(tone: .production) {
                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(PBFormat.integer(run.processed, locale: locale))
                                .font(.system(size: 50, weight: .bold, design: .rounded)).foregroundStyle(PBTheme.navy)
                            Text(t("report.processed")).font(.caption.weight(.semibold)).foregroundStyle(PBTheme.secondary)
                        }
                        Spacer()
                        Text("/ \(PBFormat.integer(run.planned, locale: locale))")
                            .font(.title2.weight(.semibold)).foregroundStyle(PBTheme.secondary)
                    }
                    ProgressView(value: Double(run.processed), total: Double(max(1, run.planned)))
                        .tint(PBTheme.recordBlue).scaleEffect(x: 1, y: 2.2)
                    if run.progressMode == "live_cycles" {
                        HStack(spacing: 10) {
                            ForEach([1, 2, 5], id: \.self) { quantity in
                            Button {
                                store.completeCycle(items: quantity); PBFeedback.count()
                            } label: {
                                Text("+\(quantity)").font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 54)
                                    .foregroundStyle(.white)
                                    .background(PBTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .shadow(color: PBTheme.controlShadow, radius: 8, x: 0, y: 5)
                            }
                            .buttonStyle(PBTactileButtonStyle())
                            .disabled(run.processed + quantity > run.planned)
                            }
                        }
                        HStack(spacing: 10) {
                            TextField(t("report.quantity"), text: $customCycleQuantity)
                                .keyboardType(.numberPad).textFieldStyle(.roundedBorder).frame(maxWidth: 110)
                            Button {
                                guard let quantity = Int(customCycleQuantity), quantity > 0 else {
                                    failureMessageKey = "error.invalidNumber"; failed = true; return
                                }
                                store.completeCycle(items: quantity); PBFeedback.count()
                            } label: {
                            Label(t("run.countItems"), systemImage: "plus.circle.fill")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                                .foregroundStyle(.white).background(PBTheme.primaryActionFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            }
                            .buttonStyle(PBTactileButtonStyle())
                            .disabled(Int(customCycleQuantity).map { $0 <= 0 || run.processed + $0 > run.planned } ?? true)
                        }
                        Button { store.undoCycle(); PBFeedback.undo() } label: {
                        Label(t("run.undoLastCount"), systemImage: "arrow.uturn.backward")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(PBTheme.navy)
                            .background(PBTheme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(PBTactileButtonStyle())
                        .disabled(run.processed <= 0)
                    } else {
                        Label(t("run.finalTotalsMode"), systemImage: "checklist.checked")
                            .font(.headline).foregroundStyle(PBTheme.recordBlue)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(PBTheme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                }
            }
            if run.qcEnabled {
                let nextQC = run.lastQCProcessed == 0 ? run.qcFirstAt : run.lastQCProcessed + run.qcEvery
                let due = run.processed >= nextQC
                Label(due ? t("qc.due") : PBL10n.format("qc.nextAt", language: language, locale: locale,
                    PBFormat.integer(nextQC, locale: locale) as NSString), systemImage: due ? "exclamationmark.shield.fill" : "checkmark.shield")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(due ? PBTheme.ember : PBTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                secondaryButton("qc.title", icon: "checkmark.shield") { showingQC = true; PBFeedback.tap() }
                secondaryButton("runs.pause", icon: "pause.fill") { showingPause = true; PBFeedback.tap() }
            }
            secondaryButton("report.issuesExceptions", icon: "exclamationmark.bubble") { showingIssue = true; PBFeedback.tap() }
            destructiveButton("runs.end", icon: "stop.fill") { showingEndConfirmation = true }
        }
    }

    private func resultForm(_ run: BatchRun) -> some View {
        PBCard(tone: .information) {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("run.recordResult")).font(.title3.bold()).foregroundStyle(PBTheme.navy)
                HStack {
                    VStack(alignment: .leading) { Text(result.processed).font(.system(size: 36, weight: .bold, design: .rounded)); Text(t("report.processed")).font(.caption).foregroundStyle(PBTheme.secondary) }
                    Spacer()
                    Text("/ \(run.planned)").font(.title3.weight(.semibold)).foregroundStyle(PBTheme.secondary)
                }
                ProgressView(value: Double(Int(result.processed) ?? 0), total: Double(max(1, run.planned))).tint(PBTheme.recordBlue)
                TextField(t("report.processed"), text: $result.processed).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                Divider()
                LabeledContent(t("report.wasteUnits")) {
                    TextField(t("report.wasteUnits"), text: $result.waste).keyboardType(.numberPad).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(maxWidth: 140)
                }
                Divider()
                LabeledContent(t("report.reworkedUnits")) {
                    TextField(t("report.reworkedUnits"), text: $result.rework).keyboardType(.numberPad).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(maxWidth: 140)
                }
                Divider()
                Toggle(isOn: $result.explicitAllGood) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("result.allGood")).font(.subheadline.weight(.semibold))
                        Text(t("result.allGoodHelp")).font(.caption).foregroundStyle(PBTheme.secondary)
                    }
                }
                .tint(PBTheme.success)
                .disabled(!result.issues.isEmpty || (Int(result.processed) ?? -1) != run.planned || (Int(result.waste) ?? -1) != 0 || (Int(result.rework) ?? -1) != 0)

                if !result.explicitAllGood {
                    Divider()
                    HStack {
                        Text(t("report.issuesExceptions")).font(.headline)
                        Spacer()
                        Button { addIssue() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(PBTheme.recordBlue)
                                .frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)
                                .contentShape(Rectangle())
                        }
                            .accessibilityLabel(t("report.issuesExceptions"))
                    }
                    ForEach($result.issues) { $issue in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(t("issue.title")).font(.subheadline.bold())
                                Spacer()
                                Button(role: .destructive) { result.issues.removeAll { $0.id == issue.id } } label: {
                                    Image(systemName: "trash")
                                        .frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)
                                        .contentShape(Rectangle())
                                }
                            }
                            TextField(t("report.quantity"), text: $issue.quantity).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                            Picker(t("report.disposition"), selection: $issue.disposition) {
                                Text(t("issue.disposition.discarded")).tag("discarded")
                                Text(t("issue.disposition.reworked")).tag("reworked")
                            }
                            .pickerStyle(.segmented)
                            .frame(minHeight: PBTheme.minimumTarget)
                            Picker(t("report.symptom"), selection: $issue.symptom) {
                                ForEach(issueSymptoms, id: \.self) { Text(t("issue.symptom.\($0)")).tag($0) }
                            }.pickerStyle(.menu)
                            Picker(t("report.suspectedCause"), selection: $issue.suspectedCause) {
                                ForEach(issueCauses, id: \.self) { Text(t("issue.cause.\($0)")).tag($0) }
                            }.pickerStyle(.menu)
                            TextField(t("report.note"), text: $issue.note).textFieldStyle(.roundedBorder)
                        }
                        .padding(12).background(PBTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Divider()
                Picker(t("result.saveOutcome"), selection: $result.saveChoice) {
                    Text(t("result.batchOnly")).tag("batch_only")
                    Text(t("result.updateSetup")).tag("update_recipe")
                    Text(t("result.saveVariant")).tag("save_variant")
                }.pickerStyle(.menu)
                if result.saveChoice == "save_variant" {
                    TextField(t("result.variantTitle"), text: $result.variantTitle).textFieldStyle(.roundedBorder)
                }
                Divider()
                VStack(alignment: .leading, spacing: 7) {
                    Text(t("common.notes")).font(.subheadline.weight(.semibold))
                    TextEditor(text: $result.notes).frame(minHeight: 88)
                }
                primaryButton("run.recordResult", icon: "checkmark") {
                    do { PBTimerNotification.cancel(); try store.completeResult(result); PBFeedback.success() }
                    catch { present(error) }
                }
            }
        }
    }

    private func primaryButton(_ key: String, icon: String, action: @escaping () -> Void) -> some View {
        PBPrimaryButton(title: t(key), icon: icon, action: action)
    }

    private func secondaryButton(_ key: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(t(key), systemImage: icon).font(.headline).frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget).padding(.vertical, 6)
                .foregroundStyle(PBTheme.navy).background(PBTheme.paper, in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: PBTheme.controlRadius).stroke(PBTheme.line, lineWidth: 1) }
                .shadow(color: PBTheme.cardShadow, radius: 8, x: 0, y: 4)
        }.buttonStyle(PBTactileButtonStyle())
    }

    private func destructiveButton(_ key: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label(t(key), systemImage: icon).font(.headline).frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget).padding(.vertical, 6)
                .background(PBTheme.paper, in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: PBTheme.controlRadius).stroke(PBTheme.line, lineWidth: 1) }
                .shadow(color: PBTheme.cardShadow, radius: 8, x: 0, y: 4)
        }.buttonStyle(PBTactileButtonStyle())
    }

    @ViewBuilder
    private func discardButtonIfEligible(_ run: BatchRun) -> some View {
        if run.canDiscardUnstarted {
            destructiveButton("run.discardUnstarted", icon: "trash") { showingDiscardConfirmation = true }
        }
    }

    private func clearButton(_ key: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(role: destructive ? .destructive : nil, action: action) {
            Label(t(key), systemImage: icon).font(.headline).frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget).padding(.vertical, 6)
                .foregroundStyle(destructive ? PBTheme.errorInk : PBTheme.navy)
                .background(PBTheme.paper, in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: PBTheme.controlRadius).stroke(PBTheme.line, lineWidth: 1) }
                .shadow(color: PBTheme.cardShadow, radius: 8, x: 0, y: 4)
        }.buttonStyle(PBTactileButtonStyle())
    }

    private func stageText(_ run: BatchRun) -> String {
        if run.timerRemaining != nil && !run.stage.isEmpty { return run.stage }
        switch run.phase {
        case "preflight": return t("stage.placement")
        case "first_piece": return t("onboarding.process.firstPiece")
        case "production_ready", "running", "paused": return run.stage.isEmpty ? t("stage.press") : run.stage
        case "result_pending": return t("onboarding.process.result")
        default: return run.canonicalStageLocalizationKey.map(t) ?? run.stage
        }
    }

    private func seedResult(_ run: BatchRun, force: Bool = false) {
        if force || result.processed.isEmpty { result.processed = String(run.processed) }
    }

    private func addIssue() {
        let disposition = (Int(result.waste) ?? 0) > 0 ? "discarded" : "reworked"
        let quantity = disposition == "discarded" ? max(1, Int(result.waste) ?? 1) : max(1, Int(result.rework) ?? 1)
        result.issues.append(IssueDraftInput(quantity: String(quantity), disposition: disposition))
    }

    @ViewBuilder
    private func stageDetail(_ key: String, _ value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(t(key) + ":").font(.caption.weight(.bold)).foregroundStyle(PBTheme.secondary)
                Text(value).font(.body).foregroundStyle(PBTheme.navy).fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(t(key) + ":").font(.caption2.weight(.bold)).foregroundStyle(PBTheme.secondary)
                Text(value).font(.caption).foregroundStyle(PBTheme.navy)
            }
        }
    }

    private func present(_ error: Error) {
        failureMessageKey = store.errorLocalizationKey(error)
        failed = true
        PBFeedback.error()
    }
}

private struct FirstPieceEvidenceSheet: View {
    let action: FirstPieceEvidenceAction
    let onCommit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var note = ""
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                PBCard(tone: .caution) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(t(action == .adjust ? "run.adjustRetry" : "run.stopWithNote"), systemImage: action == .adjust ? "arrow.triangle.2.circlepath" : "stop.circle.fill")
                            .font(.title3.bold())
                        Text(t("common.notes")).font(.subheadline.weight(.semibold))
                        TextEditor(text: $note)
                            .frame(minHeight: 130).padding(8)
                            .background(PBTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                Button {
                    onCommit(note.trimmingCharacters(in: .whitespacesAndNewlines))
                    action == .adjust ? PBFeedback.warning() : PBFeedback.error()
                    dismiss()
                } label: {
                    Label(t(action == .adjust ? "run.saveAdjustmentRetry" : "run.saveNoteStop"), systemImage: "checkmark.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 58)
                        .foregroundStyle(.white)
                        .background(action == .adjust ? PBTheme.warningActionFill : PBTheme.errorActionFill, in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
                }.buttonStyle(PBTactileButtonStyle())
                Spacer()
            }
            .padding(PBTheme.pagePadding).background(PBTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(t("onboarding.process.firstPiece"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { dismiss() } } }
        }
    }
}

private struct RunFact: View {
    let value: String
    let labelKey: String
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundStyle(PBTheme.navy)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(PBL10n.text(labelKey, language: language, locale: locale))
                .font(.caption)
                .foregroundStyle(PBTheme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(PBTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(PBTheme.line, lineWidth: 1) }
        .shadow(color: PBTheme.cardShadow, radius: 9, x: 0, y: 4)
    }
}

private struct QCCheckSheet: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var note = ""
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PBCard(tone: .information) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(t("qc.title"), systemImage: "checkmark.shield.fill")
                                .font(.title3.bold()).foregroundStyle(PBTheme.navy)
                            TextEditor(text: $note)
                                .frame(minHeight: 110).padding(8)
                                .background(PBTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay { RoundedRectangle(cornerRadius: 14).stroke(PBTheme.line, lineWidth: 1) }
                                .accessibilityLabel(t("common.notes"))
                        }
                    }
                    qcButton("qc.pass", icon: "checkmark.circle.fill", color: PBTheme.successActionFill, result: "pass")
                    qcButton("qc.adjust", icon: "wrench.adjustable.fill", color: PBTheme.warningActionFill, result: "adjust")
                    qcButton("qc.endEarly", icon: "stop.circle.fill", color: PBTheme.errorActionFill, result: "end_early")
                }.padding(PBTheme.pagePadding)
            }
            .background(PBTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(t("qc.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { dismiss() } } }
        }
    }

    private func qcButton(_ key: String, icon: String, color: Color, result: String) -> some View {
        Button {
            store.recordQC(result: result, note: note)
            result == "pass" ? PBFeedback.success() : PBFeedback.warning()
            dismiss()
        } label: {
            Label(t(key), systemImage: icon).font(.headline).frame(maxWidth: .infinity, minHeight: 58)
                .foregroundStyle(.white).background(color, in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
                .shadow(color: PBTheme.controlShadow, radius: 10, x: 0, y: 6)
        }.buttonStyle(PBTactileButtonStyle())
    }
}

private struct PauseRunSheet: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var reason = ""
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                PBCard(tone: .caution) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(t("runs.pause"), systemImage: "pause.circle.fill").font(.title3.bold())
                        TextField(t("run.pauseReason"), text: $reason).textFieldStyle(.roundedBorder)
                    }
                }
                Button { store.pauseRun(reason: reason.isEmpty ? "operator_pause" : reason); PBFeedback.tap(); dismiss() } label: {
                    Label(t("runs.pause"), systemImage: "pause.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 58)
                        .foregroundStyle(.white).background(PBTheme.warningActionFill, in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
                }.buttonStyle(PBTactileButtonStyle())
                Spacer()
            }.padding(PBTheme.pagePadding).background(PBTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(t("runs.pause")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { dismiss() } } }
        }
    }
}

private struct IssueCaptureSheet: View {
    @Binding var issues: [IssueDraftInput]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var issue = IssueDraftInput()
    private let symptoms = ["unknown", "color_shift", "ghosting", "edge_lift", "adhesion", "scorch", "alignment", "incomplete_transfer", "uneven_heat_pressure", "moisture", "transfer_shift", "contamination", "substrate_defect", "design_setup", "print_supply", "equipment_power", "interrupted", "other"]
    private let causes = ["unknown", "heat", "pressure", "time", "moisture", "placement", "transfer", "substrate", "design", "printer_ink_paper", "equipment_power", "operator_interruption", "other"]
    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    var body: some View {
        NavigationStack {
            ScrollView {
                PBCard(tone: .caution) {
                    VStack(spacing: 12) {
                        TextField(t("report.quantity"), text: $issue.quantity).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        Picker(t("report.disposition"), selection: $issue.disposition) {
                            Text(t("issue.disposition.discarded")).tag("discarded"); Text(t("issue.disposition.reworked")).tag("reworked")
                        }
                        .pickerStyle(.segmented)
                        .frame(minHeight: PBTheme.minimumTarget)
                        Picker(t("report.symptom"), selection: $issue.symptom) { ForEach(symptoms, id: \.self) { Text(t("issue.symptom.\($0)")).tag($0) } }.pickerStyle(.menu)
                        Picker(t("report.suspectedCause"), selection: $issue.suspectedCause) { ForEach(causes, id: \.self) { Text(t("issue.cause.\($0)")).tag($0) } }.pickerStyle(.menu)
                        TextField(t("report.note"), text: $issue.note).textFieldStyle(.roundedBorder)
                        Button { issues.append(issue); PBFeedback.success(); dismiss() } label: {
                            Label(t("issue.add"), systemImage: "checkmark.circle.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 58)
                                .foregroundStyle(.white).background(PBTheme.primaryActionFill, in: RoundedRectangle(cornerRadius: PBTheme.controlRadius, style: .continuous))
                        }.buttonStyle(PBTactileButtonStyle()).disabled(Int(issue.quantity).map { $0 <= 0 } ?? true)
                    }
                }.padding(PBTheme.pagePadding)
            }.background(PBTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(t("report.issuesExceptions")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(t("common.cancel")) { dismiss() } } }
        }
    }
}
