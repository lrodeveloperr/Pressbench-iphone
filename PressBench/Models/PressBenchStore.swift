import Combine
import Foundation
import SwiftUI

@MainActor
final class PressBenchStore: ObservableObject {
    private struct PendingSetupReuse {
        let sourceSetupID: String
        let reuseClass: SetupReuseClass
        let seed: [String: Any]
    }

    @Published var selectedTab = 0
    @Published private(set) var generation = 0
    @Published private(set) var lastErrorCode: String?
    @Published private(set) var errorEventID = 0
    @Published private(set) var persistenceWarning: String?
    @Published var activeRunRouteID: String?
    @Published private(set) var lastCompletedBatchID: String?

    let purchases = PurchaseManager()

    private let bridge: PressBenchLogicBridge
    private let persistence: PressBenchPersistence
    private let usageMeter: PBUsageMeter
    private var state: [String: Any]
    private var persistenceBlocked = false
    private var pendingReusedSetups: [String: PendingSetupReuse] = [:]
    private var purchaseObservation: AnyCancellable?

    static func production() -> PressBenchStore {
        do { return try PressBenchStore() }
        catch { fatalError("PressBench production core failed to initialize: \(error)") }
    }

    init(
        bridge: PressBenchLogicBridge? = nil,
        persistence: PressBenchPersistence? = nil,
        usageDefaults: UserDefaults = .standard
    ) throws {
        self.bridge = try bridge ?? PressBenchLogicBridge()
        self.persistence = persistence ?? PressBenchPersistence()
        self.usageMeter = PBUsageMeter(defaults: usageDefaults)

        let defaultSettings = try self.bridge.dictionary(
            self.bridge.domain("defaultSettings"), context: "default settings"
        )
        let defaultEntitlement = try self.bridge.dictionary(
            self.bridge.entitlement("normalizeEntitlement", [[:]]), context: "default entitlement"
        )

        let loaded: [String: Any]?
        do { loaded = try self.persistence.load() }
        catch {
            loaded = nil
            persistenceBlocked = true
            persistenceWarning = String(describing: error)
        }

        if let loaded {
            let storedEntitlement = (loaded["entitlement"] as? [String: Any]) ?? defaultEntitlement
            let migrated = try self.bridge.dictionary(
                self.bridge.process("migrateLoadedData", [loaded, Self.isoNow()]), context: "migrated state"
            )
            let loadedSession = loaded["session"] as? [String: Any]
            let migratedSession = migrated["session"] as? [String: Any]
            let loadedActiveRun = loadedSession?["activeRun"] as? [String: Any]
            let migratedActiveRun = migratedSession?["activeRun"] as? [String: Any]
            let rejectedSession = loaded["rejectedSession"] as? [String: Any] ??
                (loadedActiveRun != nil && migratedActiveRun == nil ? loadedSession : nil)
            self.state = [
                "machines": migrated["machines"] as? [[String: Any]] ?? [],
                "recipes": migrated["recipes"] as? [[String: Any]] ?? [],
                "batches": migrated["batches"] as? [[String: Any]] ?? [],
                "settings": migrated["settings"] as? [String: Any] ?? defaultSettings,
                "session": migrated["session"] ?? NSNull(),
                "entitlement": try self.bridge.dictionary(
                    self.bridge.entitlement("normalizeEntitlement", [storedEntitlement]), context: "stored entitlement"
                ),
                "preRestoreRecovery": loaded["preRestoreRecovery"] ?? NSNull(),
                "operatorIssueDrafts": loaded["operatorIssueDrafts"] as? [String: Any] ?? [:],
                "rejectedSession": rejectedSession ?? NSNull()
            ]
            if rejectedSession != nil {
                persistenceBlocked = true
                persistenceWarning = "run_permit_invalid"
            }
        } else {
            self.state = [
                "machines": [[String: Any]](),
                "recipes": [[String: Any]](),
                "batches": [[String: Any]](),
                "settings": defaultSettings,
                "session": NSNull(),
                "entitlement": defaultEntitlement,
                "operatorIssueDrafts": [String: Any](),
                "rejectedSession": NSNull()
            ]
        }

        purchases.onStoreEvent = { [weak self] event in
            self?.applyStoreEvent(event)
        }
        purchaseObservation = purchases.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        usageMeter.reconcile(existingCompletedRuns: (state["batches"] as? [[String: Any]] ?? []).count)
    }

    func start() async {
        await purchases.start()
    }

    // MARK: - Public projections

    var setups: [Setup] {
        rawRecipes.compactMap(projectSetup).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var recentSetups: [Setup] {
        rawRecipes.compactMap(projectSetup).filter { $0.status != .archived }.sorted {
            ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast)
        }
    }

    var machines: [MachineProfile] {
        rawMachines.compactMap(projectMachine).sorted { $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending }
    }

    var runs: [BatchRun] {
        var output = rawBatches.compactMap(projectBatch)
        if let active = activeRunDictionary, let projected = projectActiveRun(active) { output.insert(projected, at: 0) }
        return output.sorted { left, right in
            if left.state == .running && right.state != .running { return true }
            if right.state == .running && left.state != .running { return false }
            return (left.completedAt ?? .distantFuture) > (right.completedAt ?? .distantFuture)
        }
    }

    var metrics: DashboardMetrics {
        do {
            let value = try bridge.dictionary(bridge.domain("metrics", [rawRecipes, rawBatches]), context: "metrics")
            return DashboardMetrics(
                setups: int(value["setups"]),
                batches: int(value["batches"]),
                firstPassYield: double(value["firstPassYield"]) ?? 0,
                wasteRate: double(value["wasteRate"]) ?? 0
            )
        } catch {
            return DashboardMetrics(setups: rawRecipes.count, batches: rawBatches.count, firstPassYield: 0, wasteRate: 0)
        }
    }

    var activeRun: BatchRun? {
        activeRunDictionary.flatMap(projectActiveRun)
    }

    var activeRunPhase: String { activeRunDictionary?["phase"] as? String ?? "" }

    var operationalReady: Bool {
        guard let settings = state["settings"] as? [String: Any] else { return false }
        do {
            let readiness = try bridge.dictionary(bridge.process("operationalReadiness", [settings]), context: "readiness")
            return readiness["ready"] as? Bool == true
        } catch { return false }
    }

    var isPro: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pressbench-ui-test-pro") { return true }
        #endif
        do {
            let evaluated = try bridge.dictionary(
                bridge.entitlement("evaluateEntitlement", [currentEntitlement, Self.isoNow()]), context: "entitlement evaluation"
            )
            return evaluated["paidAccess"] as? Bool == true
        } catch { return false }
    }

    var productDisplayPrice: String? { purchases.product?.displayPrice }
    var purchaseState: PurchaseManager.PurchaseState { purchases.state }
    var adEligibilityResolved: Bool { purchases.entitlementsResolved }
    var canManageMonthlySubscription: Bool {
        isPro && string(currentEntitlement["productId"]) == PurchaseManager.productID
    }
    var freePressesRemaining: Int {
        usageMeter.reconcile(existingCompletedRuns: rawBatches.count)
        return usageMeter.freePressesRemaining
    }
    var canStartAnotherRun: Bool { isPro || freePressesRemaining > 0 }
    var hasRestoreRecovery: Bool { state["preRestoreRecovery"] is [String: Any] }
    var hasRejectedRun: Bool { state["rejectedSession"] is [String: Any] }
    var hasSetupDraft: Bool { (state["session"] as? [String: Any])?["setupDraft"] is [String: Any] }
    var rejectedRunLabel: String {
        let run = (state["rejectedSession"] as? [String: Any])?["activeRun"] as? [String: Any]
        let setup = run?["setup"] as? [String: Any] ?? run?["recipe"] as? [String: Any]
        return [string(run?["jobReference"]), string(run?["jobName"]), string(setup?["title"]), string(run?["id"])]
            .first(where: { !$0.isEmpty }) ?? "PressBench"
    }
    var temperatureUnit: String {
        let settings = state["settings"] as? [String: Any]
        return string(settings?["confirmedTemperatureUnit"]).isEmpty ?
            (string(settings?["defaultUnit"]).isEmpty ? "F" : string(settings?["defaultUnit"])) :
            string(settings?["confirmedTemperatureUnit"])
    }

    // MARK: - Onboarding / preferences

    func completeOnboarding(language: AppLanguage, locale: Locale, temperatureUnit: String) throws {
        guard var settings = state["settings"] as? [String: Any] else { return }
        settings["language"] = language.rawValue
        settings["locale"] = language.localeIdentifier(deviceLocale: locale)
        settings["region"] = locale.region?.identifier.uppercased() ?? "US"
        settings = try bridge.dictionary(bridge.domain("normalizeSettings", [settings]), context: "localized settings")
        settings = try bridge.dictionary(bridge.process("acceptLegal", [settings, [
            "termsAccepted": true,
            "safetyAccepted": true,
            "privacyPresented": true
        ], Self.isoNow()]), context: "legal acceptance")
        settings = try bridge.dictionary(
            bridge.process("confirmTemperatureUnit", [settings, temperatureUnit, Self.isoNow()]), context: "temperature confirmation"
        )
        try withStateTransaction {
            state["settings"] = settings
        }
    }

    func updateLanguage(_ language: AppLanguage, locale: Locale) {
        do {
            guard var settings = state["settings"] as? [String: Any] else { return }
            settings["language"] = language.rawValue
            settings["locale"] = language.localeIdentifier(deviceLocale: locale)
            settings["region"] = locale.region?.identifier.uppercased() ?? settings["region"]
            let normalized = try bridge.dictionary(bridge.domain("normalizeSettings", [settings]), context: "language settings")
            try withStateTransaction { state["settings"] = normalized }
        } catch { record(error) }
    }

    func updateTemperatureUnit(_ unit: String) {
        do {
            guard let settings = state["settings"] as? [String: Any] else { return }
            let updated = try bridge.dictionary(
                bridge.process("confirmTemperatureUnit", [settings, unit, Self.isoNow()]), context: "temperature unit"
            )
            try withStateTransaction { state["settings"] = updated }
        } catch { record(error) }
    }

    func updatePresentationPreferences(haptics: Bool, sound: Bool, theme: String) {
        do {
            guard var settings = state["settings"] as? [String: Any] else { return }
            settings["hapticsEnabled"] = haptics
            settings["soundEnabled"] = sound
            settings["theme"] = theme
            let normalized = try bridge.dictionary(bridge.domain("normalizeSettings", [settings]), context: "presentation settings")
            try withStateTransaction { state["settings"] = normalized }
        } catch { record(error) }
    }

    // MARK: - Machines

    func machineDraft(for id: String?) -> MachineDraft {
        guard let id, let raw = rawMachines.first(where: { ($0["id"] as? String) == id }) else { return MachineDraft() }
        return MachineDraft(
            id: id,
            nickname: string(raw["nickname"]),
            brand: string(raw["brand"]),
            model: string(raw["model"]),
            platen: string(raw["platenOrZone"]),
            notes: string(raw["notes"])
        )
    }

    @discardableResult
    func saveMachine(_ draft: MachineDraft) throws -> String {
        let brand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let platen = draft.platen.trimmingCharacters(in: .whitespacesAndNewlines)
        let enteredNickname = draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let identity = [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        let nickname = enteredNickname.isEmpty ? (identity.isEmpty ? platen : identity) : enteredNickname
        var raw: [String: Any] = [
            "nickname": nickname,
            "brand": brand,
            "model": model,
            "pressureMethod": "",
            "pressureScale": "",
            "platenOrZone": platen,
            "lastExternalCheckDate": "",
            "notes": draft.notes,
            "archived": false
        ]
        if !draft.id.isEmpty { raw["id"] = draft.id }
        let plan = try bridge.dictionary(bridge.process("planSaveMachine", [context, raw, Self.isoNow()]), context: "machine save plan")
        try withStateTransaction {
            state["machines"] = plan["machines"] as? [[String: Any]] ?? rawMachines
            state["recipes"] = plan["recipes"] as? [[String: Any]] ?? rawRecipes
        }
        return string((plan["machine"] as? [String: Any])?["id"])
    }

    func archiveMachine(id: String) throws {
        guard !rawRecipes.contains(where: { string($0["machineProfileId"]) == id && $0["archived"] as? Bool != true }) else {
            throw StoreError.machineInUse
        }
        guard var raw = rawMachines.first(where: { string($0["id"]) == id }) else { throw StoreError.invalidMachine }
        raw["archived"] = true
        let plan = try bridge.dictionary(bridge.process("planSaveMachine", [context, raw, Self.isoNow()]), context: "machine archive plan")
        try withStateTransaction {
            state["machines"] = plan["machines"] as? [[String: Any]] ?? rawMachines
            state["recipes"] = plan["recipes"] as? [[String: Any]] ?? rawRecipes
        }
    }

    // MARK: - Setups

    func setupDraft(for id: String?) -> SetupDraft {
        guard let id, let raw = rawRecipes.first(where: { ($0["id"] as? String) == id }) else {
            let activeMachineIDs = Set(rawMachines.compactMap { machine in
                machine["archived"] as? Bool == true ? nil : machine["id"] as? String
            })
            let recentMachineID = rawRecipes
                .filter { $0["archived"] as? Bool != true && activeMachineIDs.contains(string($0["machineProfileId"])) }
                .max { (date($0["lastUsedAt"]) ?? .distantPast) < (date($1["lastUsedAt"]) ?? .distantPast) }
                .map { string($0["machineProfileId"]) }
            let firstActiveMachineID = rawMachines.first(where: { $0["archived"] as? Bool != true })?["id"] as? String
            let defaultMachineID = recentMachineID ?? firstActiveMachineID ?? ""
            return SetupDraft(machineID: defaultMachineID,
                              stages: [SetupStageDraft(temperatureUnit: temperatureUnit)])
        }
        return setupDraft(from: raw)
    }

    func prepareSetupReuse(setupID: String, reuseClass: SetupReuseClass) throws -> SetupDraft {
        guard reuseClass != .exactRepeat else { throw StoreError.invalidReuseClass }
        guard let raw = rawRecipes.first(where: { ($0["id"] as? String) == setupID }) else { throw StoreError.setupMissing }
        let result = try bridge.dictionary(
            bridge.domain("reuseSetup", [raw, reuseClass.rawValue, [String: Any](), Self.isoNow()]),
            context: "setup reuse"
        )
        guard result["createsSetup"] as? Bool == true,
              let reused = result["setup"] as? [String: Any],
              let id = reused["id"] as? String, !id.isEmpty else {
            throw StoreError.invalidReuseClass
        }
        pendingReusedSetups[id] = PendingSetupReuse(sourceSetupID: setupID, reuseClass: reuseClass, seed: reused)
        return setupDraft(from: reused)
    }

    func discardPreparedSetupReuse(id: String) {
        pendingReusedSetups.removeValue(forKey: id)
    }

    func archiveSetup(id: String) throws {
        guard let raw = rawRecipes.first(where: { string($0["id"]) == id }) else { throw StoreError.setupMissing }
        let archived = try bridge.dictionary(bridge.domain("archiveSetup", [raw, Self.isoNow()]), context: "archived setup")
        let plan = try bridge.dictionary(bridge.process("planSaveSetup", [context, archived, Self.isoNow()]), context: "setup archive plan")
        try withStateTransaction { state["recipes"] = plan["setups"] as? [[String: Any]] ?? rawRecipes }
    }

    private func setupDraft(from raw: [String: Any]) -> SetupDraft {
        let rawStages = raw["steps"] as? [[String: Any]] ?? []
        return SetupDraft(
            id: string(raw["id"]),
            title: string(raw["title"]),
            material: string(raw["blankMaterial"]),
            transferMedium: string(raw["transferMedium"]),
            machineID: string(raw["machineProfileId"]),
            temperature: numberText(raw["temperature"]),
            durationSeconds: numberText(raw["pressTimeSeconds"]),
            pressure: string(raw["pressure"]),
            sourceName: string((raw["instructionSource"] as? [String: Any])?["name"]),
            sourceReference: string((raw["instructionSource"] as? [String: Any])?["reference"]),
            defaultQuantity: numberText(raw["defaultQuantity"]),
            notes: string(raw["notes"]),
            stages: rawStages.map { step in
                SetupStageDraft(
                    id: string(step["id"]).isEmpty ? UUID().uuidString : string(step["id"]),
                    stageType: string(step["stageType"]).isEmpty ? "press" : string(step["stageType"]),
                    name: string(step["name"]),
                    instruction: string(step["instruction"]),
                    temperature: numberText(step["temperature"]),
                    temperatureUnit: string(step["temperatureUnit"]).isEmpty ? string(raw["temperatureUnit"]) : string(step["temperatureUnit"]),
                    durationSeconds: numberText(step["durationSeconds"]),
                    pressure: string(step["pressure"]),
                    repeatCount: numberText(step["repeatCount"]).isEmpty ? "1" : numberText(step["repeatCount"]),
                    placementAction: string(step["placementAction"]),
                    finishAction: string(step["finishAction"])
                )
            }
        )
    }

    @discardableResult
    func saveSetup(_ draft: SetupDraft, temperatureUnit: String, locale: Locale = .current, reuseClass: SetupReuseClass? = nil) throws -> String {
        if reuseClass == .sameProductVariant {
            return try saveSameProductVariant(draft)
        }
        let stageDrafts = draft.stages.isEmpty ? [SetupStageDraft(
            stageType: "press", name: "Press", temperature: draft.temperature,
            temperatureUnit: temperatureUnit, durationSeconds: draft.durationSeconds,
            pressure: draft.pressure)] : draft.stages
        guard let primaryPressStage = stageDrafts.first(where: { $0.stageType == "press" }),
              let temperature = decimal(primaryPressStage.temperature, locale: locale),
              let duration = Int(primaryPressStage.durationSeconds),
              temperature > 0, duration > 0,
              !primaryPressStage.pressure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoreError.invalidSetup
        }
        guard let machine = rawMachines.first(where: { ($0["id"] as? String) == draft.machineID }) else {
            throw StoreError.invalidMachine
        }
        let enteredTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let generatedTitle = [draft.material, draft.transferMedium, string(machine["nickname"])]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let title = enteredTitle.isEmpty ? generatedTitle : enteredTitle
        guard let quantity = Int(draft.defaultQuantity), quantity > 0 else { throw StoreError.invalidNumber }
        guard !title.isEmpty,
              !draft.material.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !draft.transferMedium.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !draft.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !draft.sourceReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoreError.invalidSetup
        }

        let machineSnapshot = try bridge.dictionary(bridge.domain("machineProfileSnapshot", [machine]), context: "machine snapshot")
        var raw: [String: Any]
        if !draft.id.isEmpty, let existing = rawRecipes.first(where: { ($0["id"] as? String) == draft.id }) {
            raw = existing
        } else if !draft.id.isEmpty, let prepared = pendingReusedSetups[draft.id] {
            raw = prepared.seed
        } else {
            raw = try bridge.dictionary(bridge.domain("emptySetup", [temperatureUnit]), context: "empty setup")
        }
        raw["title"] = title
        raw["blankMaterial"] = draft.material.trimmingCharacters(in: .whitespacesAndNewlines)
        raw["transferMedium"] = draft.transferMedium.trimmingCharacters(in: .whitespacesAndNewlines)
        raw["processStructure"] = "other"
        raw["machineProfileId"] = draft.machineID
        raw["machineProfile"] = machineSnapshot
        raw["machineNickname"] = string(machineSnapshot["nickname"])
        raw["platenZone"] = string(machineSnapshot["platenOrZone"])
        raw["temperature"] = temperature
        let primaryTemperatureUnit = primaryPressStage.temperatureUnit.isEmpty ? temperatureUnit : primaryPressStage.temperatureUnit
        raw["temperatureUnit"] = primaryTemperatureUnit
        raw["pressTimeSeconds"] = duration
        raw["pressure"] = primaryPressStage.pressure.trimmingCharacters(in: .whitespacesAndNewlines)
        raw["pressCount"] = 1
        raw["defaultQuantity"] = quantity
        raw["notes"] = draft.notes
        raw["instructionSource"] = [
            "type": "supplier",
            "name": draft.sourceName.trimmingCharacters(in: .whitespacesAndNewlines),
            "reference": draft.sourceReference.trimmingCharacters(in: .whitespacesAndNewlines),
            "checkedDate": Self.localCivilDate(),
            "revision": "",
            "priorBatchId": ""
        ]
        raw["steps"] = try stageDrafts.map { stage -> [String: Any] in
            guard let repeatCount = Int(stage.repeatCount.isEmpty ? "1" : stage.repeatCount), repeatCount > 0 else {
                throw StoreError.invalidNumber
            }
            let stageDuration: Any
            if stage.durationSeconds.isEmpty { stageDuration = "" }
            else if let value = Int(stage.durationSeconds), value > 0 { stageDuration = value }
            else { throw StoreError.invalidNumber }
            let stageTemperature: Any
            if stage.temperature.isEmpty { stageTemperature = "" }
            else if let value = decimal(stage.temperature, locale: locale), value > 0 { stageTemperature = value }
            else { throw StoreError.invalidNumber }
            if stage.stageType == "press" && (stage.durationSeconds.isEmpty || stage.temperature.isEmpty ||
                stage.pressure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                throw StoreError.invalidSetup
            }
            return [
                "id": stage.id,
                "stageType": stage.stageType,
                "name": stage.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stageName(stage.stageType) : stage.name.trimmingCharacters(in: .whitespacesAndNewlines),
                "instruction": stage.instruction,
                "machineNickname": string(machineSnapshot["nickname"]),
                "machineProfileId": draft.machineID,
                "platenZone": string(machineSnapshot["platenOrZone"]),
                "temperature": stageTemperature,
                "temperatureUnit": stage.temperatureUnit.isEmpty ? temperatureUnit : stage.temperatureUnit,
                "durationSeconds": stageDuration,
                "pressure": stage.pressure,
                "repeatCount": repeatCount,
                "placementAction": stage.placementAction,
                "finishAction": stage.finishAction
            ]
        }
        raw["pressCount"] = stageDrafts.filter { $0.stageType == "press" }.reduce(0) { total, stage in
            total + (Int(stage.repeatCount.isEmpty ? "1" : stage.repeatCount) ?? 1)
        }

        let plan = try bridge.dictionary(bridge.process("planSaveSetup", [context, raw, Self.isoNow()]), context: "setup save plan")
        try withStateTransaction {
            state["recipes"] = plan["setups"] as? [[String: Any]] ?? rawRecipes
        }
        let savedID = string((plan["setup"] as? [String: Any])?["id"])
        pendingReusedSetups.removeValue(forKey: draft.id)
        return savedID
    }

    /// Same-product reuse is deliberately narrower than the full editor: only
    /// title, notes and default quantity may change. Re-running the deterministic
    /// reuse function keeps every source, machine and multi-stage operating field
    /// byte/field stable instead of canonicalizing the prepared clone.
    private func saveSameProductVariant(_ draft: SetupDraft) throws -> String {
        guard let pending = pendingReusedSetups[draft.id], pending.reuseClass == .sameProductVariant,
              let source = rawRecipes.first(where: { ($0["id"] as? String) == pending.sourceSetupID }),
              let quantity = Int(draft.defaultQuantity), quantity > 0,
              !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoreError.invalidReuseClass
        }
        let edits: [String: Any] = [
            "title": draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            "notes": draft.notes,
            "defaultQuantity": quantity
        ]
        let reuse = try bridge.dictionary(
            bridge.domain("reuseSetup", [source, SetupReuseClass.sameProductVariant.rawValue, edits, Self.isoNow()]),
            context: "same-product variant reuse"
        )
        guard let variant = reuse["setup"] as? [String: Any] else { throw StoreError.invalidReuseClass }
        let plan = try bridge.dictionary(
            bridge.process("planSaveSetup", [context, variant, Self.isoNow()]), context: "same-product variant save plan"
        )
        try withStateTransaction {
            state["recipes"] = plan["setups"] as? [[String: Any]] ?? rawRecipes
        }
        pendingReusedSetups.removeValue(forKey: draft.id)
        return string((plan["setup"] as? [String: Any])?["id"])
    }

    // MARK: - Run lifecycle

    func startRun(setupID: String) throws {
        let setup = setups.first(where: { $0.id == setupID })
        var draft = RunStartDraft(setupID: setupID)
        draft.quantity = String(setup?.defaultQuantity ?? 1)
        draft.runMode = setup?.status == .proven ? "production" : "test"
        try startRun(draft)
    }

    func startRun(_ draft: RunStartDraft) throws {
        guard isPro || usageMeter.canStartFreePress(existingCompletedRuns: rawBatches.count) else {
            throw StoreError.pressLimitReached
        }
        guard let raw = rawRecipes.first(where: { ($0["id"] as? String) == draft.setupID }) else { throw StoreError.setupMissing }
        guard let quantity = Int(draft.quantity), quantity > 0 else { throw StoreError.invalidNumber }
        let plan = try bridge.dictionary(bridge.process("authorizeRun", [context, raw, [
            "now": Self.isoNow(),
            "utcOffsetMinutes": TimeZone.current.secondsFromGMT() / 60,
            "progressMode": draft.progressMode,
            "firstPiecePolicy": "required_for_unproven",
            "runMode": draft.runMode,
            "quantity": quantity,
            "jobReference": draft.jobReference.trimmingCharacters(in: .whitespacesAndNewlines),
            "confirmUnprovenProduction": draft.confirmUnprovenProduction
        ]]), context: "run authorization")
        guard plan["authorized"] as? Bool == true, let session = plan["session"] as? [String: Any] else {
            throw StoreError.activeRunConflict
        }
        try withStateTransaction { state["session"] = session }
        selectedTab = 2
        activeRunRouteID = string((session["activeRun"] as? [String: Any])?["id"])
    }

    func confirmInstructions() { transition(event: ["type": "CONFIRM_INSTRUCTIONS", "confirmed": true]) }
    func recordFirstPiecePass() { transition(event: ["type": "RECORD_FIRST_PIECE", "outcome": "pass", "note": ""]) }
    func recordFirstPieceAdjustment(note: String = "") throws {
        try transitionThrowing(event: ["type": "RECORD_FIRST_PIECE", "outcome": "adjust_retry", "note": note])
    }
    func stopAfterFirstPiece(note: String = "") throws {
        try transitionThrowing(event: ["type": "RECORD_FIRST_PIECE", "outcome": "stop", "note": note])
    }
    func startProduction() { transition(event: ["type": "START_PRODUCTION"]) }
    func completeCycle(items: Int) { transition(event: ["type": "COMPLETE_CYCLE", "cycleComplete": true, "items": items]) }
    func undoCycle() { transition(event: ["type": "UNDO_CYCLE"]) }
    func recordQC(result: String, note: String) throws {
        try transitionThrowing(event: ["type": "RECORD_QC", "result": result, "note": note])
    }
    func pauseRun(reason: String = "operator_pause") { transition(event: ["type": "PAUSE", "reason": reason]) }
    func resumeRun() { transition(event: ["type": "RESUME"]) }
    func endRun(early: Bool = false) {
        transition(event: ["type": "END_RUN", "reason": early ? "operator_end_early" : "operator_finish"])
    }

    func discardUnstartedRun() throws {
        guard let run = activeRunDictionary else { throw StoreError.activeRunMissing }
        let plan: [String: Any]
        do {
            plan = try bridge.dictionary(
                bridge.process("planDiscardUnstarted", [run, Self.isoNow()]), context: "discard unstarted run"
            )
        } catch {
            quarantineIfPermitInvalid(error)
            throw error
        }
        guard plan["clearSession"] as? Bool == true else { throw StoreError.activeRunConflict }
        try withStateTransaction {
            state["session"] = NSNull()
            removeOperatorIssues(runID: string(run["id"]))
        }
    }

    func discardRejectedRun() throws {
        guard let rejected = state["rejectedSession"] as? [String: Any] else { throw StoreError.activeRunMissing }
        let rejectedRunID = string((rejected["activeRun"] as? [String: Any])?["id"])
        try withStateTransaction(allowBlockedRecovery: true) {
            state["rejectedSession"] = NSNull()
            if !rejectedRunID.isEmpty { removeOperatorIssues(runID: rejectedRunID) }
        }
        activeRunRouteID = nil
        selectedTab = 0
    }

    func loadOperatorIssues(runID: String) -> [IssueDraftInput] {
        guard let drafts = (state["operatorIssueDrafts"] as? [String: Any])?[runID] as? [[String: Any]] else { return [] }
        return drafts.compactMap { raw in
            guard let id = UUID(uuidString: string(raw["id"])) else { return nil }
            return IssueDraftInput(
                id: id,
                quantity: string(raw["quantity"]),
                symptom: string(raw["symptom"]),
                suspectedCause: string(raw["suspectedCause"]),
                disposition: string(raw["disposition"]),
                note: string(raw["note"])
            )
        }
    }

    func saveOperatorIssues(_ issues: [IssueDraftInput], runID: String) {
        do { try commitOperatorIssues(issues, runID: runID) }
        catch { record(error) }
    }

    func commitOperatorIssues(_ issues: [IssueDraftInput], runID: String) throws {
        try withStateTransaction {
            var all = state["operatorIssueDrafts"] as? [String: Any] ?? [:]
            if issues.isEmpty {
                all.removeValue(forKey: runID)
            } else {
                all[runID] = issues.map { issue in
                    ["id": issue.id.uuidString, "quantity": issue.quantity,
                     "symptom": issue.symptom, "suspectedCause": issue.suspectedCause,
                     "disposition": issue.disposition, "note": issue.note]
                }
            }
            state["operatorIssueDrafts"] = all
        }
    }

    func clearOperatorIssues(runID: String) {
        do { try withStateTransaction { removeOperatorIssues(runID: runID) } }
        catch { record(error) }
    }

    func ensureTimer() {
        guard let run = activeRunDictionary, ["first_piece", "production_ready", "running", "paused"].contains(string(run["phase"])) else { return }
        if run["timer"] is [String: Any] { return }
        transition(event: ["type": "TIMER_INITIALIZE", "index": 0])
    }

    func startOrRestartTimer() {
        guard var run = activeRunDictionary else { return }
        do {
            if run["timer"] as? [String: Any] == nil {
                run = try transitionRun(run, event: ["type": "TIMER_INITIALIZE", "index": 0])
            } else if let timer = run["timer"] as? [String: Any], timer["completed"] as? Bool == true {
                run = try transitionRun(run, event: ["type": "TIMER_RESET"])
            }
            run = try transitionRun(run, event: ["type": "TIMER_START"])
            try withStateTransaction { replaceActiveRun(run) }
        } catch { record(error) }
    }

    func pauseStageTimer() { transition(event: ["type": "TIMER_PAUSE"]) }
    func nextStageTimer() { transition(event: ["type": "TIMER_NEXT"]) }
    func previousStageTimer() { transition(event: ["type": "TIMER_PREVIOUS"]) }
    func restartTimerPlan() { transition(event: ["type": "TIMER_RESTART_PLAN"]) }
    func tickStageTimer() {
        guard let timer = activeRunDictionary?["timer"] as? [String: Any], timer["running"] as? Bool == true else { return }
        transition(event: ["type": "TIMER_TICK"])
    }

    func completeResult(_ input: ResultDraftInput) throws {
        guard var run = activeRunDictionary else { throw StoreError.activeRunMissing }
        guard let processed = Int(input.processed) else {
            throw StoreError.invalidNumber
        }
        let issues = try input.issues.map { issue -> [String: Any] in
            guard let quantity = Int(issue.quantity), quantity > 0,
                  !issue.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError.invalidIssue }
            return ["id": issue.id.uuidString, "quantity": quantity, "symptom": issue.symptom,
                    "suspectedCause": issue.suspectedCause, "disposition": issue.disposition, "note": issue.note]
        }
        let waste = input.issues.filter { $0.disposition == "discarded" }
            .reduce(0) { $0 + (Int($1.quantity) ?? 0) }
        let rework = input.issues.filter { $0.disposition == "reworked" }
            .reduce(0) { $0 + (Int($1.quantity) ?? 0) }
        let planned = int(run["quantity"])
        let cleanAllGood = input.issues.isEmpty && processed == planned && waste == 0 && rework == 0
        if cleanAllGood {
            run = try transitionRun(run, event: [
                "type": "CONFIRM_ALL_GOOD",
                "confirmedPlannedQuantity": planned,
                "explicitConfirmation": true,
                "notes": input.notes,
                "saveChoice": input.saveChoice,
                "variantTitle": input.variantTitle
            ])
        } else {
            run = try transitionRun(run, event: [
                "type": "SAVE_RESULT_DRAFT",
                "result": [
                    "quantityProcessed": processed,
                    "quantityWaste": waste,
                    "quantityReworked": rework,
                    "issues": issues,
                    "notes": input.notes,
                    "saveChoice": input.saveChoice,
                    "variantTitle": input.variantTitle
                ]
            ])
        }
        run = try transitionRun(run, event: ["type": "BEGIN_COMMIT"])
        let plan: [String: Any]
        do {
            plan = try bridge.dictionary(bridge.process("planResultCommit", [context, run]), context: "result commit plan")
        } catch {
            quarantineActiveRun(error)
            throw error
        }
        let committedID = string((plan["batch"] as? [String: Any])?["id"])
        try withStateTransaction {
            state["recipes"] = plan["recipes"] as? [[String: Any]] ?? rawRecipes
            state["batches"] = plan["batches"] as? [[String: Any]] ?? rawBatches
            state["session"] = NSNull()
            removeOperatorIssues(runID: string(run["id"]))
        }
        lastCompletedBatchID = committedID.isEmpty ? string(run["resultId"]) : committedID
        if plan["alreadyCommitted"] as? Bool != true {
            usageMeter.recordCompletedPress(batchID: lastCompletedBatchID ?? "")
        }
        activeRunRouteID = lastCompletedBatchID
    }

    func correctBatch(
        id: String,
        jobReference: String,
        planned: Int,
        processed: Int,
        notes: String,
        issues: [IssueDraftInput],
        reason: String
    ) throws {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              planned > 0, processed >= 0, processed <= planned else { throw StoreError.invalidNumber }
        let rawIssues = try issues.map { issue -> [String: Any] in
            guard let quantity = Int(issue.quantity), quantity > 0,
                  ["discarded", "reworked"].contains(issue.disposition),
                  !issue.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StoreError.invalidIssue
            }
            return ["id": issue.id.uuidString, "quantity": quantity, "symptom": issue.symptom,
                    "suspectedCause": issue.suspectedCause, "disposition": issue.disposition,
                    "note": issue.note.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        let waste = issues.filter { $0.disposition == "discarded" }.reduce(0) { $0 + (Int($1.quantity) ?? 0) }
        let reworked = issues.filter { $0.disposition == "reworked" }.reduce(0) { $0 + (Int($1.quantity) ?? 0) }
        guard waste <= processed, reworked <= processed - waste else { throw StoreError.invalidIssue }
        let plan = try bridge.dictionary(bridge.process("planCorrection", [context, id, [
            "reason": reason,
            "correctedAt": Self.isoNow(),
            "changes": [
                "jobReference": jobReference.trimmingCharacters(in: .whitespacesAndNewlines),
                "quantityPlanned": planned,
                "quantityProcessed": processed,
                "quantityWaste": waste,
                "quantityReworked": reworked,
                "issues": rawIssues,
                "notes": notes
            ]
        ]]), context: "batch correction plan")
        try withStateTransaction {
            state["recipes"] = plan["recipes"] as? [[String: Any]] ?? rawRecipes
            state["batches"] = plan["batches"] as? [[String: Any]] ?? rawBatches
        }
    }

    func deleteBatch(id: String) throws {
        let plan = try bridge.dictionary(bridge.process("planDeleteBatch", [context, id]), context: "batch delete plan")
        try withStateTransaction {
            state["recipes"] = plan["recipes"] as? [[String: Any]] ?? rawRecipes
            state["batches"] = plan["batches"] as? [[String: Any]] ?? rawBatches
        }
    }

    // MARK: - Reports / backup

    func reportPlan(format: String) throws -> [String: Any] {
        try bridge.dictionary(bridge.process("planReport", [context, format, rawBatches, Self.isoNow()]), context: "report plan")
    }

    func backupPayload() throws -> [String: Any] {
        try bridge.dictionary(bridge.domain("makeBackup", [rawRecipes, rawBatches, state["settings"] ?? NSNull(), rawMachines]), context: "backup")
    }

    func deleteAllLocalData() throws {
        let entitlement = currentEntitlement
        let plan = try bridge.dictionary(
            bridge.process("planDeleteAll", [context, "DELETE"]), context: "delete all local data"
        )
        try withStateTransaction(allowBlockedRecovery: true) {
            state = [
                "machines": plan["machines"] as? [[String: Any]] ?? [],
                "recipes": plan["recipes"] as? [[String: Any]] ?? [],
                "batches": plan["batches"] as? [[String: Any]] ?? [],
                "settings": plan["settings"] as? [String: Any] ?? [:],
                "session": plan["session"] ?? NSNull(),
                "entitlement": entitlement,
                "preRestoreRecovery": NSNull(),
                "operatorIssueDrafts": [String: Any](),
                "rejectedSession": NSNull()
            ]
            pendingReusedSetups.removeAll()
        }
    }

    func restoreBackup(raw: String) throws {
        guard activeRun == nil else { throw StoreError.activeRunConflict }
        guard !hasRejectedRun else { throw StoreError.persistenceBlocked }
        let plan = try bridge.dictionary(bridge.process("planRestore", [context, raw]), context: "restore plan")
        guard let target = plan["target"] as? [String: Any], var recovery = plan["recoveryEnvelope"] as? [String: Any] else {
            throw StoreError.exportFailed
        }
        recovery["state"] = "applied"
        try withStateTransaction(allowBlockedRecovery: true) {
            state["machines"] = target["machines"] as? [[String: Any]] ?? []
            state["recipes"] = target["setups"] as? [[String: Any]] ?? []
            state["batches"] = target["batches"] as? [[String: Any]] ?? []
            state["settings"] = target["settings"] as? [String: Any] ?? state["settings"]
            state["session"] = NSNull()
            state["operatorIssueDrafts"] = [String: Any]()
            state["preRestoreRecovery"] = recovery
        }
        usageMeter.reconcile(existingCompletedRuns: rawBatches.count)
    }

    func rollbackRestore() throws {
        guard activeRun == nil else { throw StoreError.activeRunConflict }
        guard !hasRejectedRun else { throw StoreError.persistenceBlocked }
        guard let recovery = state["preRestoreRecovery"] as? [String: Any] else { throw StoreError.exportFailed }
        let plan = try bridge.dictionary(bridge.process("planRollback", [context, recovery]), context: "rollback plan")
        guard let target = plan["target"] as? [String: Any] else { throw StoreError.exportFailed }
        try withStateTransaction {
            state["machines"] = target["machines"] as? [[String: Any]] ?? []
            state["recipes"] = target["setups"] as? [[String: Any]] ?? []
            state["batches"] = target["batches"] as? [[String: Any]] ?? []
            state["settings"] = target["settings"] as? [String: Any] ?? state["settings"]
            state["session"] = NSNull()
            state["operatorIssueDrafts"] = [String: Any]()
            state["preRestoreRecovery"] = NSNull()
        }
        usageMeter.reconcile(existingCompletedRuns: rawBatches.count)
    }

    var canonicalReportBatches: [[String: Any]] { rawBatches }
    var canonicalReportSetups: [[String: Any]] { rawRecipes }

    // MARK: - Purchase bridge

    func purchasePro() async { await purchases.purchase() }
    func restorePurchases() async { await purchases.restore() }
    func reloadPurchases() async { await purchases.reloadProduct() }

    private func applyStoreEvent(_ event: [String: Any]) {
        do {
            let output = try bridge.dictionary(
                bridge.entitlement("applyStoreEvent", [currentEntitlement, event, Self.isoNow()]), context: "store event"
            )
            if let entitlement = output["entitlement"] as? [String: Any] {
                try withStateTransaction { state["entitlement"] = entitlement }
            }
        } catch { record(error) }
    }

    // MARK: - Canonical state helpers

    private var rawMachines: [[String: Any]] { state["machines"] as? [[String: Any]] ?? [] }
    private var rawRecipes: [[String: Any]] { state["recipes"] as? [[String: Any]] ?? [] }
    private var rawBatches: [[String: Any]] { state["batches"] as? [[String: Any]] ?? [] }
    private var currentEntitlement: [String: Any] { state["entitlement"] as? [String: Any] ?? [:] }

    private var context: [String: Any] {
        [
            "machines": rawMachines,
            "recipes": rawRecipes,
            "setups": rawRecipes,
            "batches": rawBatches,
            "settings": state["settings"] ?? NSNull(),
            "session": state["session"] ?? NSNull(),
            "entitlement": currentEntitlement,
            "storageMode": "native",
            "preRestoreRecovery": state["preRestoreRecovery"] ?? NSNull()
        ]
    }

    private var activeRunDictionary: [String: Any]? {
        guard let session = state["session"] as? [String: Any] else { return nil }
        return session["activeRun"] as? [String: Any]
    }

    private func transition(event: [String: Any]) {
        do { try transitionThrowing(event: event) }
        catch { record(error) }
    }

    private func transitionThrowing(event: [String: Any]) throws {
        guard let run = activeRunDictionary else { throw StoreError.activeRunMissing }
        let next = try transitionRun(run, event: event)
        try withStateTransaction { replaceActiveRun(next) }
    }

    private func transitionRun(_ run: [String: Any], event: [String: Any]) throws -> [String: Any] {
        var value = event
        value["at"] = Self.isoNow()
        do {
            return try bridge.dictionary(bridge.process("transitionRun", [run, value]), context: "run transition")
        } catch {
            quarantineIfPermitInvalid(error)
            throw error
        }
    }

    private func replaceActiveRun(_ run: [String: Any]) {
        var session = state["session"] as? [String: Any] ?? [:]
        session["schemaVersion"] = session["schemaVersion"] ?? 4
        session["activeRun"] = run
        session["savedAt"] = Self.isoNow()
        state["session"] = session
        generation &+= 1
    }

    private func removeOperatorIssues(runID: String) {
        var all = state["operatorIssueDrafts"] as? [String: Any] ?? [:]
        all.removeValue(forKey: runID)
        state["operatorIssueDrafts"] = all
    }

    private func quarantineActiveRun(_ error: Error) {
        guard let session = state["session"] as? [String: Any],
              let run = session["activeRun"] as? [String: Any] else { return }
        state["rejectedSession"] = session
        var safeSession = session
        safeSession["activeRun"] = NSNull()
        state["session"] = safeSession["setupDraft"] is [String: Any] ? safeSession : NSNull()
        removeOperatorIssues(runID: string(run["id"]))
        do {
            try persistence.save(state)
            persistenceBlocked = true
            persistenceWarning = String(describing: error)
        } catch {
            persistenceBlocked = true
            persistenceWarning = String(describing: error)
        }
        generation &+= 1
    }

    private func quarantineIfPermitInvalid(_ error: Error) {
        if String(describing: error).lowercased().contains("run_permit_invalid") {
            quarantineActiveRun(error)
        }
    }

    private func stateSnapshot() throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
        guard let snapshot = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StoreError.exportFailed
        }
        return snapshot
    }

    /// Every user-visible mutation either reaches both guarded replicas or is rolled
    /// back in memory. This prevents the UI from getting ahead of durable state.
    private func withStateTransaction(
        allowBlockedRecovery: Bool = false,
        _ mutation: () throws -> Void
    ) throws {
        let priorState = try stateSnapshot()
        let priorBlocked = persistenceBlocked
        let priorWarning = persistenceWarning
        do {
            if allowBlockedRecovery {
                persistenceBlocked = false
                persistenceWarning = nil
            }
            try mutation()
            try persist()
        } catch {
            state = priorState
            if error is PressBenchPersistence.PersistenceError {
                persistenceBlocked = true
                persistenceWarning = String(describing: error)
            } else {
                persistenceBlocked = priorBlocked
                persistenceWarning = priorWarning
            }
            generation &+= 1
            throw error
        }
    }

    private func persist() throws {
        if persistenceBlocked { throw StoreError.persistenceBlocked }
        try persistence.save(state)
        lastErrorCode = nil
        generation &+= 1
    }

    private func record(_ error: Error) {
        lastErrorCode = String(describing: error)
        errorEventID &+= 1
        generation &+= 1
    }

    func errorLocalizationKey(_ error: Error? = nil) -> String {
        let code = (error.map { String(describing: $0) } ?? lastErrorCode ?? "").lowercased()
        if code.contains("capacity_required") || code.contains("presslimitreached") { return "error.freeLimit" }
        if code.contains("timer_plan_incomplete") || code.contains("timer_stage_incomplete") { return "run.completeTimerFirst" }
        if code.contains("qc_required") { return "qc.due" }
        if code.contains("invalid_number") || code.contains("invalidnumber") { return "error.invalidNumber" }
        if code.contains("machine_in_use") { return "error.machineInUse" }
        if code.contains("issue") || code.contains("coverage") { return "error.issueCoverage" }
        if code.contains("machine") { return "error.machineRequired" }
        if code.contains("setup") { return "error.setupRequired" }
        if code.contains("active_run_conflict") { return "error.activeRunConflict" }
        if code.contains("transition") || code.contains("result_state") || code.contains("active_run_missing") { return "error.runState" }
        if code.contains("permit") { return "error.storageRecovery" }
        if code.contains("persistence") || code.contains("replica") || code.contains("corrupt") { return "error.storageRecovery" }
        if code.contains("backup") || code.contains("restore") || code.contains("export") { return "error.backupRestore" }
        return "common.actionFailed"
    }

    func requiresUpgrade(_ error: Error) -> Bool {
        if let storeError = error as? StoreError, case .pressLimitReached = storeError { return true }
        let code = String(describing: error).lowercased()
        return code.contains("capacity_required") || code.contains("presslimitreached")
    }

    // MARK: - Projection helpers

    private func projectSetup(_ raw: [String: Any]) -> Setup? {
        guard let id = raw["id"] as? String, !id.isEmpty else { return nil }
        let status: SetupStatus
        if raw["archived"] as? Bool == true { status = .archived }
        else {
            switch string(raw["status"]) {
            case "verified": status = .proven
            case "trial": status = .trial
            default: status = .draft
            }
        }
        let related = rawBatches.filter { string($0["recipeId"]) == id }
        let yields = related.compactMap { batch -> Double? in
            let processed = double(batch["quantityProcessed"]) ?? 0
            guard processed > 0 else { return nil }
            let good = double(batch["quantityGood"]) ?? 0
            let rework = double(batch["quantityReworked"]) ?? 0
            return max(0, good - rework) / processed
        }
        let yield = yields.isEmpty ? nil : yields.reduce(0, +) / Double(yields.count)
        let stages = (raw["steps"] as? [[String: Any]] ?? []).enumerated().map { index, step in
            let name = string(step["name"]).isEmpty ? stageName(string(step["stageType"])) : string(step["name"])
            var facts = [String]()
            if let temp = double(step["temperature"]) { facts.append("\(trimNumber(temp))°\(string(step["temperatureUnit"]))") }
            if let duration = intOptional(step["durationSeconds"]), duration > 0 { facts.append("\(duration) sec") }
            if !string(step["pressure"]).isEmpty { facts.append(string(step["pressure"])) }
            return ProcessStage(
                id: string(step["id"]).isEmpty ? "\(id)-\(index)" : string(step["id"]),
                name: name,
                value: facts.joined(separator: " · "),
                instruction: string(step["instruction"]),
                repeatCount: max(1, int(step["repeatCount"])),
                placementAction: string(step["placementAction"]),
                finishAction: string(step["finishAction"]),
                stageType: string(step["stageType"])
            )
        }
        return Setup(
            id: id,
            title: string(raw["title"]),
            material: string(raw["blankMaterial"]),
            transferMedium: string(raw["transferMedium"]),
            status: status,
            cleanRuns: int(raw["provenEvidenceCount"]),
            firstPassYield: yield,
            lastProven: date(raw["verifiedAt"]),
            stages: stages,
            notes: string(raw["notes"]),
            defaultQuantity: max(1, int(raw["defaultQuantity"])),
            temperature: temperatureText(raw),
            duration: durationText(raw),
            pressure: string(raw["pressure"]),
            machineNickname: string(raw["machineNickname"]),
            platen: string(raw["platenZone"]),
            lastUsedAt: date(raw["lastUsedAt"])
        )
    }

    private func projectMachine(_ raw: [String: Any]) -> MachineProfile? {
        guard let id = raw["id"] as? String, !id.isEmpty else { return nil }
        let brand = string(raw["brand"]), model = string(raw["model"])
        let identity = [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        return MachineProfile(
            id: id,
            nickname: string(raw["nickname"]),
            platen: string(raw["platenOrZone"]),
            detail: identity,
            active: raw["archived"] as? Bool != true,
            brand: brand,
            model: model,
            notes: string(raw["notes"])
        )
    }

    private func projectBatch(_ raw: [String: Any]) -> BatchRun? {
        guard let id = raw["id"] as? String, !id.isEmpty else { return nil }
        let recipe = raw["recipe"] as? [String: Any]
        let processed = int(raw["quantityProcessed"]), good = int(raw["quantityGood"]), rework = int(raw["quantityReworked"])
        let firstPass = processed > 0 ? Double(max(0, good - rework)) / Double(processed) : nil
        return BatchRun(
            id: id,
            title: string(raw["jobName"]).isEmpty ? string(recipe?["title"]) : string(raw["jobName"]),
            state: .completed,
            processed: processed,
            planned: int(raw["quantityPlanned"]),
            stage: "Completed",
            stageIndex: 4,
            stageCount: 4,
            elapsed: double(raw["durationSeconds"]) ?? 0,
            firstPassYield: firstPass,
            completedAt: date(raw["completedAt"]),
            phase: "completed",
            temperature: temperatureText(recipe),
            pressure: string(recipe?["pressure"]),
            platen: string(recipe?["platenZone"]),
            jobReference: string(raw["jobReference"]),
            duration: durationText(recipe),
            material: string(recipe?["blankMaterial"]),
            transferMedium: string(recipe?["transferMedium"]),
            machineName: string(recipe?["machineNickname"]),
            processStages: (recipe?["steps"] as? [[String: Any]] ?? []).enumerated().map { index, stage in
                ProcessStage(id: string(stage["id"]).isEmpty ? "stage-\(index)" : string(stage["id"]),
                             name: string(stage["name"]).isEmpty ? stageName(string(stage["stageType"])) : string(stage["name"]),
                             value: stageValue(stage), instruction: string(stage["instruction"]),
                             repeatCount: max(1, int(stage["repeatCount"])),
                             placementAction: string(stage["placementAction"]),
                             finishAction: string(stage["finishAction"]), stageType: string(stage["stageType"]))
            },
            setupID: string(raw["recipeId"]),
            waste: int(raw["quantityWaste"]),
            reworked: int(raw["quantityReworked"]),
            notes: string(raw["notes"]),
            issues: (raw["issues"] as? [[String: Any]] ?? []).compactMap(projectIssue),
            qcCheckCountTotal: (raw["qcChecks"] as? [[String: Any]] ?? []).count,
            interruptionCount: (raw["interruptions"] as? [[String: Any]] ?? []).count
        )
    }

    private func projectActiveRun(_ raw: [String: Any]) -> BatchRun? {
        guard let id = raw["id"] as? String, !id.isEmpty else { return nil }
        let setup = raw["setup"] as? [String: Any]
        let phase = string(raw["phase"])
        let started = date(raw["productionStartedAt"]) ?? date(raw["startedAt"])
        let elapsed = started.map { max(0, Date().timeIntervalSince($0)) } ?? 0
        let stageInfo = stageForPhase(phase)
        let timer = raw["timer"] as? [String: Any]
        let timerStages = timer?["stages"] as? [[String: Any]] ?? []
        let timerIndex = int(timer?["index"])
        let currentTimerStage = timerStages.indices.contains(timerIndex) ? timerStages[timerIndex] : nil
        let setupStages = setup?["steps"] as? [[String: Any]] ?? []
        let sourceStepID = string(currentTimerStage?["sourceStepId"])
        let sourceStep = setupStages.first { string($0["id"]) == sourceStepID }
        let source = setup?["instructionSource"] as? [String: Any]
        let remaining = double(timer?["remainingMs"]).map { max(0, $0 / 1000) }
        let total = double(timer?["totalMs"]).map { max(0, $0 / 1000) }
        let qcChecks = raw["qcChecks"] as? [[String: Any]] ?? []
        let qcPolicy = (try? bridge.dictionary(bridge.process("qcPolicy", [raw]), context: "qc policy")) ?? [:]
        return BatchRun(
            id: id,
            title: string(raw["jobReference"]).isEmpty ? string(setup?["title"]) : string(raw["jobReference"]),
            state: .running,
            processed: int(raw["processedCount"]),
            planned: int(raw["quantity"]),
            stage: string(currentTimerStage?["name"]).isEmpty ? stageInfo.name : string(currentTimerStage?["name"]),
            stageIndex: timerStages.isEmpty ? stageInfo.index : timerIndex + 1,
            stageCount: timerStages.isEmpty ? max(1, setupStages.count) : timerStages.count,
            elapsed: elapsed,
            firstPassYield: nil,
            completedAt: nil,
            phase: phase,
            temperature: temperatureText(setup),
            pressure: string(setup?["pressure"]),
            platen: string(setup?["platenZone"]),
            jobReference: string(raw["jobReference"]),
            duration: durationText(setup),
            timerRemaining: remaining,
            timerTotal: total,
            timerRunning: timer?["running"] as? Bool == true,
            timerCompleted: timer?["completed"] as? Bool == true,
            material: string(setup?["blankMaterial"]),
            transferMedium: string(setup?["transferMedium"]),
            machineName: string(setup?["machineNickname"]),
            instructionSource: [string(source?["type"]), string(source?["name"]), string(source?["reference"])].filter { !$0.isEmpty }.joined(separator: " · "),
            instructionCheckedDate: string(source?["checkedDate"]),
            processStages: setupStages.enumerated().map { index, stage in
                ProcessStage(id: string(stage["id"]).isEmpty ? "stage-\(index)" : string(stage["id"]),
                             name: string(stage["name"]).isEmpty ? stageName(string(stage["stageType"])) : string(stage["name"]),
                             value: stageValue(stage),
                             instruction: string(stage["instruction"]),
                             repeatCount: max(1, int(stage["repeatCount"])),
                             placementAction: string(stage["placementAction"]),
                             finishAction: string(stage["finishAction"]),
                             stageType: string(stage["stageType"]))
            },
            progressMode: string(raw["progressMode"]).isEmpty ? "final_confirmation" : string(raw["progressMode"]),
            qcCheckCount: qcChecks.count,
            lastQCProcessed: int(qcChecks.last?["processedCount"]),
            qcEnabled: qcPolicy["enabled"] as? Bool == true,
            qcFirstAt: int(qcPolicy["firstAt"]),
            qcEvery: int(qcPolicy["every"]),
            currentStageInstruction: string(currentTimerStage?["instruction"]).isEmpty ? string(sourceStep?["instruction"]) : string(currentTimerStage?["instruction"]),
            currentStageRepeatIndex: max(1, int(currentTimerStage?["repeat"])),
            currentStageRepeatCount: string(currentTimerStage?["stageType"]) == string(sourceStep?["stageType"])
                ? max(1, int(sourceStep?["repeatCount"])) : 1,
            currentStagePlacementAction: string(sourceStep?["placementAction"]),
            currentStageFinishAction: string(sourceStep?["finishAction"]),
            canDiscardUnstarted: raw["productionStarted"] as? Bool != true,
            currentStageType: string(currentTimerStage?["stageType"]),
            setupID: string(raw["sourceSetupId"])
        )
    }

    private func stageForPhase(_ phase: String) -> (name: String, index: Int) {
        switch phase {
        case "preflight": return ("Placement", 1)
        case "first_piece": return ("First piece", 2)
        case "production_ready", "running", "paused": return ("Press", 3)
        case "result_pending", "committing": return ("Result", 4)
        default: return ("Press", 3)
        }
    }

    private func temperatureText(_ raw: [String: Any]?) -> String {
        guard let raw, let value = double(raw["temperature"]) else { return "" }
        return "\(trimNumber(value))°\(string(raw["temperatureUnit"]))"
    }

    private func durationText(_ raw: [String: Any]?) -> String {
        guard let raw, let value = intOptional(raw["pressTimeSeconds"]), value > 0 else { return "" }
        return "\(value) s"
    }

    private func stageValue(_ raw: [String: Any]) -> String {
        [double(raw["temperature"]).map(trimNumber), string(raw["temperatureUnit"]), intOptional(raw["durationSeconds"]).map { "\($0)s" }, string(raw["pressure"])]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func stageName(_ type: String) -> String {
        switch type {
        case "placement": return "Placement"
        case "prepress": return "Pre-press"
        case "press": return "Press"
        case "peel": return "Peel"
        case "cool": return "Cool"
        case "postpress": return "Post-press"
        default: return type.capitalized
        }
    }

    private func string(_ value: Any?) -> String { value as? String ?? "" }
    private func int(_ value: Any?) -> Int { intOptional(value) ?? 0 }
    private func intOptional(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? Double { return Int(value) }
        return nil
    }
    private func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
    private func decimal(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        if let value = formatter.number(from: trimmed)?.doubleValue { return value }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
    private func projectIssue(_ raw: [String: Any]) -> IssueDraftInput? {
        let quantity = int(raw["quantity"])
        guard quantity > 0 else { return nil }
        return IssueDraftInput(
            id: UUID(uuidString: string(raw["id"])) ?? UUID(),
            quantity: String(quantity), symptom: string(raw["symptom"]),
            suspectedCause: string(raw["suspectedCause"]), disposition: string(raw["disposition"]),
            note: string(raw["note"])
        )
    }
    private func numberText(_ value: Any?) -> String {
        if let value = double(value) { return trimNumber(value) }
        return ""
    }
    private func trimNumber(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
    private func date(_ value: Any?) -> Date? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        if let parsed = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) { return parsed }
        return try? Date.ISO8601FormatStyle().parse(text)
    }

    private static func isoNow() -> String {
        Date().ISO8601Format(.iso8601(timeZone: .gmt, includingFractionalSeconds: true))
    }

    private static func localCivilDate() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    enum StoreError: LocalizedError {
        case invalidMachine, machineInUse, invalidNumber, invalidIssue, invalidSetup, setupMissing, activeRunConflict, activeRunMissing, exportFailed, persistenceBlocked, invalidReuseClass, pressLimitReached
        var errorDescription: String? {
            switch self {
            case .invalidMachine: return "machine_required"
            case .machineInUse: return "machine_in_use"
            case .invalidNumber: return "invalid_number"
            case .invalidIssue: return "issue_note_required"
            case .invalidSetup: return "setup_required"
            case .setupMissing: return "setup_missing"
            case .activeRunConflict: return "active_run_conflict"
            case .activeRunMissing: return "active_run_missing"
            case .exportFailed: return "export_failed"
            case .persistenceBlocked: return "persistence_recovery_required"
            case .invalidReuseClass: return "reuse_class"
            case .pressLimitReached: return "batch_capacity_required"
            }
        }
    }
}
