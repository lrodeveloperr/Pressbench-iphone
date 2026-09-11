import SwiftUI

struct SetupDetailView: View {
    private let setupID: String
    private let initialSetup: Setup
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var editing = false
    @State private var reuseEditorRoute: SetupReuseEditorRoute?
    @State private var showingConfiguration = false
    @State private var showingUpgrade = false
    @State private var resumeStartAfterUpgrade = false
    @State private var showingArchive = false
    @State private var failed = false

    init(setup: Setup) {
        setupID = setup.id
        initialSetup = setup
    }

    private var setup: Setup {
        store.setups.first(where: { $0.id == setupID }) ?? initialSetup
    }

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private func stageName(_ stage: ProcessStage) -> String {
        guard let key = stage.canonicalLocalizationKey else { return stage.name }
        return t(key)
    }

    var body: some View {
        ZStack {
            PBPageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: PBTheme.pageSpacing) {
                    header
                    savedFacts
                    if !setup.instructionSource.isEmpty || !setup.instructionReference.isEmpty { sourceCard }
                    if hasProductionDetails { productionDetailsCard }
                    processTimeline
                    evidence
                    if !setup.notes.isEmpty { notesCard }
                    PBPrimaryButton(title: t("setup.startRun"), icon: "play.fill") {
                        requestStart()
                    }
                    .disabled(store.activeRun != nil || setup.status == .draft || setup.status == .archived)
                    .opacity(store.activeRun == nil && setup.status != .draft && setup.status != .archived ? 1 : 0.45)
                    .padding(.top, 2)
                }
                .padding(.horizontal, PBTheme.pagePadding)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label(t("common.edit"), systemImage: "pencil") }
                    Button { prepareReuse(.sameProductVariant) } label: {
                        Label(t("run.sameProductVariant"), systemImage: SetupReuseClass.sameProductVariant.systemImage)
                    }
                    Button { prepareReuse(.materiallyDifferent) } label: {
                        Label(t("run.materiallyDifferent"), systemImage: SetupReuseClass.materiallyDifferent.systemImage)
                    }
                    Button(role: .destructive) { showingArchive = true } label: { Label(t("setup.archive"), systemImage: "archivebox") }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget).contentShape(Rectangle())
                }
                .accessibilityLabel(t("common.more"))
            }
        }
        .sheet(isPresented: $editing) { SetupEditorView(draft: store.setupDraft(for: setup.id)).environmentObject(store) }
        .sheet(item: $reuseEditorRoute) { route in
            SetupEditorView(
                draft: route.draft,
                mode: route.reuseClass == .sameProductVariant ? .sameProductVariant : .materiallyDifferent
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showingConfiguration) { RunConfigurationView(setup: setup).environmentObject(store) }
        .sheet(isPresented: $showingUpgrade, onDismiss: {
            guard resumeStartAfterUpgrade else { return }
            resumeStartAfterUpgrade = false
            if store.isPro { showingConfiguration = true }
        }) { ProUpgradeView().environmentObject(store).pbEditorSheetStyle() }
        .confirmationDialog(t("setup.archive"), isPresented: $showingArchive, titleVisibility: .visible) {
            Button(t("setup.archive"), role: .destructive) {
                do { try store.archiveSetup(id: setup.id); dismiss() } catch { failed = true }
            }
            Button(t("common.cancel"), role: .cancel) {}
        }
        .alert("PressBench", isPresented: $failed) { Button(t("common.ok"), role: .cancel) {} } message: { Text(t("common.actionFailed")) }
    }

    private func requestStart() {
        if store.canStartAnotherRun { showingConfiguration = true }
        else { resumeStartAfterUpgrade = true; showingUpgrade = true }
    }

    private func prepareReuse(_ reuseClass: SetupReuseClass) {
        do {
            let draft = try store.prepareSetupReuse(setupID: setup.id, reuseClass: reuseClass)
            reuseEditorRoute = SetupReuseEditorRoute(draft: draft, reuseClass: reuseClass)
        } catch {
            failed = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(setup.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(PBTheme.text)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                PBStatusBadge(status: setup.status)
            }
            Text([setup.material, setup.transferMedium].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(PBTheme.muted)
        }
        .padding(.top, 4)
    }

    private var savedFacts: some View {
        PBCard {
            VStack(spacing: 13) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        SavedFact(value: setup.temperature, titleKey: "common.temperature")
                        Divider().overlay(PBTheme.line)
                        SavedFact(value: setup.duration, titleKey: "common.durationSeconds")
                        Divider().overlay(PBTheme.line)
                        SavedFact(value: setup.pressure, titleKey: "common.pressure")
                    }
                } else {
                    HStack(spacing: 0) {
                        SavedFact(value: setup.temperature, titleKey: "common.temperature")
                        factDivider
                        SavedFact(value: setup.duration, titleKey: "common.durationSeconds")
                        factDivider
                        SavedFact(value: setup.pressure, titleKey: "common.pressure")
                    }
                }
                if !setup.machineNickname.isEmpty || !setup.platen.isEmpty {
                    Divider().overlay(PBTheme.line)
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.compress.vertical")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(PBTheme.primary)
                            .frame(width: 42, height: 42)
                            .background(PBTheme.primarySoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text([setup.machineNickname, setup.platen].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PBTheme.text)
                            Text(t("machines.title")).font(.caption).foregroundStyle(PBTheme.muted)
                        }
                        Spacer(minLength: 8)
                    }
                }
            }
        }
    }

    private var factDivider: some View {
        Rectangle().fill(PBTheme.line).frame(width: 1, height: 45)
    }

    private var sourceURL: URL? {
        guard let candidate = setup.instructionReference.split(whereSeparator: \.isWhitespace).last,
              let url = URL(string: String(candidate)), url.scheme == "https" else { return nil }
        return url
    }

    private var sourceCard: some View {
        PBCard {
            VStack(alignment: .leading, spacing: 9) {
                Label(t("report.instructionSource"), systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(PBTheme.text)
                if !setup.instructionSource.isEmpty { Text(setup.instructionSource).font(.subheadline.weight(.semibold)) }
                if !setup.instructionReference.isEmpty {
                    Text(setup.instructionReference)
                        .font(.caption)
                        .foregroundStyle(PBTheme.secondary)
                        .textSelection(.enabled)
                }
                if let sourceURL {
                    Link(destination: sourceURL) {
                        Label(t("common.reference"), systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: PBTheme.minimumTarget)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hasProductionDetails: Bool {
        [setup.blankSupplier, setup.blankSku, setup.blankLot, setup.blankColourSize,
         setup.transferSupplier, setup.transferSku, setup.transferLot, setup.designRevision,
         setup.printerInkPaperProfile, setup.accessoriesPlacementCooling].contains { !$0.isEmpty }
    }

    private var productionDetailsCard: some View {
        PBCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(t("report.materialTransfer"), systemImage: "shippingbox.and.arrow.backward")
                    .font(.headline)
                optionalDetail(t("common.material") + " · " + t("common.reference"), setup.blankSupplier)
                optionalDetail(t("common.transferMedium") + " · " + t("common.reference"), setup.transferSupplier)
                optionalDetail(t("setup.title") + " · " + t("common.reference"), setup.designRevision)
                optionalDetail(t("common.process") + " · " + t("common.reference"), setup.printerInkPaperProfile)
                optionalDetail(t("common.process") + " · " + t("common.notes"), setup.accessoriesPlacementCooling)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func optionalDetail(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            LabeledContent(label, value: value)
                .font(.subheadline)
        }
    }

    private var processTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("common.process"))
                .font(.title3.bold())
                .foregroundStyle(PBTheme.text)
            VStack(spacing: 0) {
                ForEach(Array(setup.stages.enumerated()), id: \.element.id) { index, stage in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Text(PBFormat.integer(index + 1, locale: locale))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(PBTheme.selectionFill, in: Circle())
                            if index < setup.stages.count - 1 {
                                Rectangle().fill(PBTheme.line).frame(width: 2, height: 64)
                            }
                        }
                        StageCard(name: stageName(stage), value: stage.value, icon: stageIcon(stage.stageType))
                            .padding(.bottom, index < setup.stages.count - 1 ? 12 : 0)
                    }
                }
            }
        }
    }

    private var evidence: some View {
        VStack(alignment: .leading, spacing: 10) {
            PBCard {
                VStack(spacing: 4) {
                    PBEvidenceRow(
                        title: t("setup.lastProven"),
                        detail: setup.lastProven.map { PBFormat.date($0, locale: locale) } ?? "N/A",
                        icon: "checkmark.shield.fill"
                    )
                    Divider().overlay(PBTheme.line)
                    PBEvidenceRow(
                        title: t("setup.cleanRuns"),
                        detail: PBFormat.integer(setup.cleanRuns, locale: locale),
                        icon: "checkmark.seal.fill"
                    )
                    if let value = setup.firstPassYield {
                        Divider().overlay(PBTheme.line)
                        PBEvidenceRow(
                            title: t("setup.firstPass"),
                            detail: PBFormat.percent(value, locale: locale),
                            icon: "chart.line.uptrend.xyaxis"
                        )
                    }
                }
            }
            if setup.status == .proven {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PBTheme.primary)
                    Text(t("setup.provenBoundary"))
                        .font(.caption)
                        .foregroundStyle(PBTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PBTheme.primarySoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var notesCard: some View {
        PBCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(PBTheme.primary)
                    .frame(width: 42, height: 42)
                    .background(PBTheme.primarySoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(t("common.notes")).font(.headline).foregroundStyle(PBTheme.text)
                    Text(setup.notes).font(.subheadline).foregroundStyle(PBTheme.muted)
                }
            }
        }
    }

    private func stageIcon(_ value: String) -> String {
        let normalized = value.lowercased()
        if normalized.contains("pre") { return "thermometer.medium" }
        if normalized.contains("cool") || normalized.contains("peel") { return "snowflake" }
        if normalized.contains("press") { return "rectangle.compress.vertical" }
        if normalized.contains("place") { return "scope" }
        return "list.number"
    }
}

private struct SetupReuseEditorRoute: Identifiable {
    let draft: SetupDraft
    let reuseClass: SetupReuseClass
    var id: String { "\(reuseClass.rawValue)-\(draft.id)" }
}

private struct SavedFact: View {
    let value: String
    let titleKey: String
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.isEmpty ? "N/A" : value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PBTheme.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.70)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            Text(PBL10n.text(titleKey, language: language, locale: locale))
                .font(.caption2)
                .foregroundStyle(PBTheme.muted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.68)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
}

private struct StageCard: View {
    let name: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(PBTheme.primary)
                .frame(width: 42, height: 42)
                .background(PBTheme.primarySoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.headline).foregroundStyle(PBTheme.text)
                if !value.isEmpty {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(PBTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(PBTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PBTheme.line, lineWidth: 1) }
        .shadow(color: PBTheme.cardShadow, radius: 8, x: 0, y: 4)
    }
}
