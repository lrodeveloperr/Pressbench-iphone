import SwiftUI

struct SetupsView: View {
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var filter: SetupStatus? = nil
    @State private var search = ""
    @State private var showingEditor = false
    @State private var showingMachineEditor = false
    @State private var continueToSetup = false

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private var activeSetups: [Setup] { store.setups.filter { $0.status != .archived } }

    private var filtered: [Setup] {
        activeSetups.filter { setup in
            let matchesStatus = filter == nil || setup.status == filter
            let matchesSearch = search.isEmpty || [setup.title, setup.material, setup.transferMedium, setup.machineNickname]
                .contains { $0.localizedCaseInsensitiveContains(search) }
            return matchesStatus && matchesSearch
        }
    }

    var body: some View {
        ZStack {
            PBPageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: PBTheme.pageSpacing) {
                    PBPageHeader(
                        title: t("setups.title"),
                        addAccessibilityLabel: t("onboarding.ready.setup.title")
                    ) {
                        if !store.machines.contains(where: { $0.active }) { showingMachineEditor = true }
                        else { showingEditor = true }
                    }

                    PBSearchField(prompt: t("setups.search"), text: $search)
                    filterBar

                    if activeSetups.isEmpty {
                        VStack(spacing: 18) {
                            ContentUnavailableView(t("setups.title"), systemImage: "list.clipboard",
                                description: Text(t(!store.machines.contains(where: { $0.active }) ? "onboarding.ready.machine.body" : "onboarding.ready.setup.body")))
                            PBPrimaryButton(title: t(!store.machines.contains(where: { $0.active }) ? "onboarding.ready.machine.title" : "onboarding.ready.setup.title"), icon: "plus.circle.fill") {
                                if !store.machines.contains(where: { $0.active }) { showingMachineEditor = true } else { showingEditor = true }
                            }
                        }.frame(maxWidth: .infinity).padding(.top, 44)
                    } else if filtered.isEmpty {
                        ContentUnavailableView.search(text: search)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 44)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(filtered) { setup in SetupCard(setup: setup) }
                        }
                    }
                }
                .padding(.horizontal, PBTheme.pagePadding)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Setup.self) { SetupDetailView(setup: $0) }
        .sheet(isPresented: $showingEditor) { SetupEditorView(draft: store.setupDraft(for: nil)).environmentObject(store) }
        .sheet(isPresented: $showingMachineEditor, onDismiss: {
            if continueToSetup { continueToSetup = false; showingEditor = true }
        }) { MachineEditorView { _ in continueToSetup = true }.environmentObject(store) }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                FilterPill(titleKey: "common.all", selected: filter == nil) { filter = nil }
                ForEach([SetupStatus.proven, .trial, .draft], id: \.self) { item in
                    FilterPill(titleKey: item.localizationKey, selected: filter == item) { filter = item }
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityElement(children: .contain)
    }
}

struct SetupCard: View {
    let setup: Setup
    @EnvironmentObject private var store: PressBenchStore
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingDifference = false
    @State private var showingUpgrade = false
    @State private var resumeStartAfterUpgrade = false

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private func cleanRunText() -> String {
        PBL10n.format(
            setup.status == .proven ? "setups.cleanRunsCount" : "setups.recordedRunsCount",
            language: language,
            locale: locale,
            PBFormat.integer(setup.cleanRuns, locale: locale) as NSString
        )
    }

    var body: some View {
        PBCard {
            VStack(spacing: 14) {
                NavigationLink(value: setup) {
                    HStack(alignment: .top, spacing: 14) {
                        MaterialSwatch(status: setup.status)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(setup.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(PBTheme.text)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 6)
                                PBStatusBadge(status: setup.status)
                            }
                            Text([setup.material, setup.transferMedium].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(PBTheme.muted)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 6) {
                                Image(systemName: setup.status == .proven ? "checkmark.seal.fill" : "clock")
                                Text(cleanRunText())
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(setup.status == .proven ? PBTheme.successInk : PBTheme.mutedInk)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PBTactileButtonStyle())

                Divider().overlay(PBTheme.line)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        SetupMetric(value: setup.temperature, titleKey: "common.temperature")
                        Divider().overlay(PBTheme.line)
                        SetupMetric(value: setup.duration, titleKey: "common.durationSeconds")
                        Divider().overlay(PBTheme.line)
                        SetupMetric(value: setup.pressure, titleKey: "common.pressure")
                    }
                } else {
                    HStack(spacing: 0) {
                        SetupMetric(value: setup.temperature, titleKey: "common.temperature")
                        metricDivider
                        SetupMetric(value: setup.duration, titleKey: "common.durationSeconds")
                        metricDivider
                        SetupMetric(value: setup.pressure, titleKey: "common.pressure")
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
                        Image(systemName: "chevron.forward").font(.caption.weight(.bold)).foregroundStyle(PBTheme.muted)
                    }
                }

                PBPrimaryButton(title: t("setup.startRun"), icon: "arrow.clockwise") {
                    requestStart()
                }
                .disabled(store.activeRun != nil || setup.status == .draft || setup.status == .archived)
                .opacity(store.activeRun == nil && setup.status != .draft && setup.status != .archived ? 1 : 0.45)
            }
        }
        .sheet(isPresented: $showingDifference) { JobDifferenceSheet(setup: setup).environmentObject(store) }
        .sheet(isPresented: $showingUpgrade, onDismiss: {
            guard resumeStartAfterUpgrade else { return }
            resumeStartAfterUpgrade = false
            if store.isPro { showingDifference = true }
        }) { ProUpgradeView().environmentObject(store).pbEditorSheetStyle() }
    }

    private func requestStart() {
        if store.canStartAnotherRun { showingDifference = true }
        else { resumeStartAfterUpgrade = true; showingUpgrade = true }
    }

    private var metricDivider: some View {
        Rectangle().fill(PBTheme.line).frame(width: 1, height: 44)
    }
}

struct SetupRow: View {
    let setup: Setup
    let compact: Bool
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    private func t(_ key: String) -> String { PBL10n.text(key, language: language, locale: locale) }
    private func countText(_ key: String) -> String {
        let number = PBFormat.integer(setup.cleanRuns, locale: locale)
        return PBL10n.format(key, language: language, locale: locale, number as NSString)
    }

    var body: some View {
        HStack(spacing: 13) {
            MaterialSwatch(status: setup.status, compact: true)
            VStack(alignment: .leading, spacing: 5) {
                Text(setup.title)
                    .font(compact ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(PBTheme.text)
                    .multilineTextAlignment(.leading)
                Text(setup.status == .proven ? countText("setups.cleanRunsCount") : setup.status == .trial ? countText("setups.recordedRunsCount") : t("setups.notProven"))
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(PBTheme.muted)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            PBStatusBadge(status: setup.status)
            Image(systemName: "chevron.forward").font(.caption.weight(.bold)).foregroundStyle(PBTheme.muted)
        }
        .frame(minHeight: PBTheme.minimumTarget)
        .contentShape(Rectangle())
    }
}

private struct MaterialSwatch: View {
    let status: SetupStatus
    var compact = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 18 / 255, green: 42 / 255, blue: 65 / 255), Color(red: 7 / 255, green: 18 / 255, blue: 30 / 255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: status == .proven ? "tshirt.fill" : "square.grid.2x2")
                .font(.system(size: compact ? 17 : 21, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(width: compact ? 46 : 58, height: compact ? 46 : 76)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 13, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: compact ? 14 : 13, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1) }
        .accessibilityHidden(true)
    }
}

private struct SetupMetric: View {
    let value: String
    let titleKey: String
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PBTheme.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.72)
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

private struct FilterPill: View {
    let titleKey: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.pbLanguage) private var language
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            Text(PBL10n.text(titleKey, language: language, locale: locale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? .white : PBTheme.muted)
                .padding(.horizontal, 18)
                .frame(minHeight: PBTheme.minimumTarget)
                .background(selected ? PBTheme.selectionFill : PBTheme.paper, in: Capsule())
                .overlay { Capsule().stroke(selected ? Color.clear : PBTheme.line, lineWidth: 1) }
        }
        .buttonStyle(PBTactileButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
