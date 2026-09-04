import XCTest
@testable import PressBench

@MainActor
final class DataEntryStreamliningTests: XCTestCase {
    func testMachineNicknameAndSetupTitleAreDerivedWithoutInventingOperatingValues() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsName = "PressBenchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let store = try PressBenchStore(
            persistence: PressBenchPersistence(baseDirectory: directory),
            usageDefaults: defaults
        )
        try store.completeOnboarding(language: .en, locale: Locale(identifier: "en_US"), temperatureUnit: "F")
        let machineID = try store.saveMachine(MachineDraft(platen: "15 × 15 in"))
        XCTAssertEqual(store.machines.first?.nickname, "15 × 15 in")

        var draft = store.setupDraft(for: nil)
        XCTAssertEqual(draft.machineID, machineID)
        XCTAssertEqual(draft.stages.first?.temperature, "")
        XCTAssertEqual(draft.stages.first?.durationSeconds, "")
        XCTAssertEqual(draft.stages.first?.pressure, "")

        draft.material = "100% cotton T-shirt"
        draft.transferMedium = "Direct-to-film transfer (DTF)"
        draft.sourceName = "Supplier instructions"
        draft.sourceReference = "S-1"
        draft.stages[0].temperature = "325"
        draft.stages[0].durationSeconds = "15"
        draft.stages[0].pressure = "Medium"

        let setupID = try store.saveSetup(draft, temperatureUnit: "F")
        let setup = try XCTUnwrap(store.setups.first { $0.id == setupID })
        XCTAssertEqual(
            setup.title,
            "100% cotton T-shirt · Direct-to-film transfer (DTF) · 15 × 15 in"
        )
    }

    func testFrenchGeneratedTitleContainsOnlyOperatorOwnedDisplayValues() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsName = "PressBenchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let store = try PressBenchStore(
            persistence: PressBenchPersistence(baseDirectory: directory),
            usageDefaults: defaults
        )
        try store.completeOnboarding(language: .fr, locale: Locale(identifier: "fr_FR"), temperatureUnit: "C")
        _ = try store.saveMachine(MachineDraft(nickname: "Presse principale", platen: "38 × 38 cm"))
        var draft = store.setupDraft(for: nil)
        draft.material = "T-shirt en coton"
        draft.transferMedium = "Transfert DTF"
        draft.sourceName = "Instructions du fournisseur"
        draft.sourceReference = "F-1"
        draft.stages[0].temperature = "160"
        draft.stages[0].temperatureUnit = "C"
        draft.stages[0].durationSeconds = "15"
        draft.stages[0].pressure = "Moyenne"

        let setupID = try store.saveSetup(draft, temperatureUnit: "C", locale: Locale(identifier: "fr_FR"))
        let setup = try XCTUnwrap(store.setups.first { $0.id == setupID })
        XCTAssertEqual(setup.title, "T-shirt en coton · Transfert DTF · Presse principale")
        XCTAssertFalse(setup.title.contains("100% cotton T-shirt"))
        XCTAssertFalse(setup.title.contains("Direct-to-film transfer"))
    }

    func testArchivedRecordsCanBeRestoredOrPermanentlyRemoved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsName = "PressBenchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: defaultsName)
        }
        let store = try PressBenchStore(
            persistence: PressBenchPersistence(baseDirectory: directory),
            usageDefaults: defaults
        )
        try store.completeOnboarding(language: .en, locale: Locale(identifier: "en_US"), temperatureUnit: "F")
        let machineID = try store.saveMachine(MachineDraft(nickname: "Archive Press", platen: "15 × 15 in"))
        var draft = store.setupDraft(for: nil)
        draft.material = "Cotton"
        draft.transferMedium = "DTF"
        draft.sourceName = "Supplier"
        draft.sourceReference = "A-1"
        draft.stages[0].temperature = "325"
        draft.stages[0].durationSeconds = "15"
        draft.stages[0].pressure = "Medium"
        let setupID = try store.saveSetup(draft, temperatureUnit: "F")

        try store.archiveSetup(id: setupID)
        XCTAssertEqual(store.setups.first?.status, .archived)
        try store.restoreSetup(id: setupID)
        XCTAssertNotEqual(store.setups.first?.status, .archived)
        try store.archiveSetup(id: setupID)
        try store.deleteArchivedSetup(id: setupID)
        XCTAssertTrue(store.setups.isEmpty)

        try store.archiveMachine(id: machineID)
        XCTAssertFalse(try XCTUnwrap(store.machines.first).active)
        try store.restoreMachine(id: machineID)
        XCTAssertTrue(try XCTUnwrap(store.machines.first).active)
        try store.archiveMachine(id: machineID)
        try store.deleteArchivedMachine(id: machineID)
        XCTAssertTrue(store.machines.isEmpty)
    }

    func testActiveRunLocksSnapshotsButDeleteAllRemainsAvailable() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsName = "PressBenchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: defaultsName)
        }
        let store = try PressBenchStore(
            persistence: PressBenchPersistence(baseDirectory: directory),
            usageDefaults: defaults
        )
        try store.completeOnboarding(language: .en, locale: Locale(identifier: "en_US"), temperatureUnit: "F")
        let machineID = try store.saveMachine(MachineDraft(nickname: "Original Press", platen: "15 × 15 in"))
        var draft = store.setupDraft(for: nil)
        draft.material = "Cotton"
        draft.transferMedium = "DTF"
        draft.sourceName = "Supplier"
        draft.sourceReference = "A-2"
        draft.stages[0].temperature = "325"
        draft.stages[0].durationSeconds = "15"
        draft.stages[0].pressure = "Medium"
        let setupID = try store.saveSetup(draft, temperatureUnit: "F")

        var renamed = store.machineDraft(for: machineID)
        renamed.nickname = "Renamed Press"
        _ = try store.saveMachine(renamed)
        XCTAssertEqual(store.setups.first?.machineNickname, "Renamed Press")

        try store.startRun(setupID: setupID)
        XCTAssertTrue(store.isSetupLockedByActiveRun(setupID))
        XCTAssertTrue(store.isMachineLockedByActiveRun(machineID))
        XCTAssertThrowsError(try store.saveMachine(renamed))
        XCTAssertThrowsError(try store.archiveSetup(id: setupID))

        try store.deleteAllLocalData()
        XCTAssertNil(store.activeRun)
        XCTAssertTrue(store.setups.isEmpty)
        XCTAssertTrue(store.machines.isEmpty)
    }
}
