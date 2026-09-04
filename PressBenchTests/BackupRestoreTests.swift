import XCTest
@testable import PressBench

@MainActor
final class BackupRestoreTests: XCTestCase {
    func testDeleteAllClearsOperationalDataButPreservesFreeUsage() throws {
        let directory = temporaryDirectory()
        let defaultsName = "PressBenchTests.DeleteAll.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        let usage = MemoryUsageStore(snapshot: PBUsageSnapshot(
            completedPresses: 3,
            creditedBatchIDs: Set((1...3).map { "used-\($0)" })
        ))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let persistence = PressBenchPersistence(baseDirectory: directory)
        let store = try PressBenchStore(
            persistence: persistence,
            usageDefaults: defaults,
            usageStore: usage
        )
        try store.completeOnboarding(language: .fr, locale: Locale(identifier: "fr_FR"), temperatureUnit: "C")
        _ = try store.saveMachine(MachineDraft(nickname: "Delete me", platen: "38 × 38 cm"))
        store.selectedTab = 3

        try store.deleteAllLocalData()

        XCTAssertTrue(store.machines.isEmpty)
        XCTAssertTrue(store.setups.isEmpty)
        XCTAssertTrue(store.runs.isEmpty)
        XCTAssertNil(store.activeRun)
        XCTAssertFalse(store.hasRejectedRun)
        XCTAssertEqual(store.selectedTab, 0)
        XCTAssertEqual(store.freePressesRemaining, 2)
        XCTAssertEqual(usage.snapshot?.completedPresses, 3)

        let reloaded = try PressBenchStore(
            persistence: persistence,
            usageDefaults: defaults,
            usageStore: usage
        )
        XCTAssertTrue(reloaded.machines.isEmpty)
        XCTAssertTrue(reloaded.setups.isEmpty)
        XCTAssertTrue(reloaded.runs.isEmpty)
        XCTAssertEqual(reloaded.freePressesRemaining, 2)
    }

    func testRestoreCarriesUsageToAnotherDeviceWithoutImportingEntitlement() throws {
        let sourceDirectory = temporaryDirectory()
        let targetDirectory = temporaryDirectory()
        let sourceDefaultsName = "PressBenchTests.BackupRestore.\(UUID().uuidString)"
        let targetDefaultsName = "PressBenchTests.BackupRestore.\(UUID().uuidString)"
        let sourceDefaults = try XCTUnwrap(UserDefaults(suiteName: sourceDefaultsName))
        let targetDefaults = try XCTUnwrap(UserDefaults(suiteName: targetDefaultsName))
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: targetDirectory)
            sourceDefaults.removePersistentDomain(forName: sourceDefaultsName)
            targetDefaults.removePersistentDomain(forName: targetDefaultsName)
        }

        let sourceUsage = MemoryUsageStore(snapshot: PBUsageSnapshot(
            completedPresses: 4,
            creditedBatchIDs: Set((1...4).map { "source-\($0)" })
        ))
        let source = try PressBenchStore(
            persistence: PressBenchPersistence(baseDirectory: sourceDirectory),
            usageDefaults: sourceDefaults,
            usageStore: sourceUsage
        )
        try source.completeOnboarding(language: .en, locale: Locale(identifier: "en_US"), temperatureUnit: "F")
        _ = try source.saveMachine(MachineDraft(nickname: "Backup machine", platen: "15 × 15 in"))
        let raw = try jsonString(source.backupPayload())

        let targetUsage = MemoryUsageStore(snapshot: PBUsageSnapshot(completedPresses: 1, creditedBatchIDs: ["target-1"]))
        let target = try PressBenchStore(
            persistence: PressBenchPersistence(baseDirectory: targetDirectory),
            usageDefaults: targetDefaults,
            usageStore: targetUsage
        )
        let preview = try target.previewBackup(raw: raw)
        XCTAssertEqual(preview.machines, 1)
        XCTAssertEqual(preview.freeRunsUsed, 4)

        try target.restoreBackup(raw: raw)

        XCTAssertEqual(target.machines.map(\.nickname), ["Backup machine"])
        XCTAssertEqual(target.freePressesRemaining, 1)
        XCTAssertEqual(targetUsage.snapshot?.completedPresses, 4)
        XCTAssertFalse(target.isPro)
    }

    func testOlderRestoreNeverReducesCurrentUsage() throws {
        let sourceDirectory = temporaryDirectory()
        let targetDirectory = temporaryDirectory()
        let sourceDefaultsName = "PressBenchTests.BackupRestore.\(UUID().uuidString)"
        let targetDefaultsName = "PressBenchTests.BackupRestore.\(UUID().uuidString)"
        let sourceDefaults = try XCTUnwrap(UserDefaults(suiteName: sourceDefaultsName))
        let targetDefaults = try XCTUnwrap(UserDefaults(suiteName: targetDefaultsName))
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: targetDirectory)
            sourceDefaults.removePersistentDomain(forName: sourceDefaultsName)
            targetDefaults.removePersistentDomain(forName: targetDefaultsName)
        }

        let sourceUsage = MemoryUsageStore(snapshot: PBUsageSnapshot(completedPresses: 1, creditedBatchIDs: ["old-1"]))
        let source = try PressBenchStore(
            persistence: PressBenchPersistence(baseDirectory: sourceDirectory),
            usageDefaults: sourceDefaults,
            usageStore: sourceUsage
        )
        let raw = try jsonString(source.backupPayload())

        let targetUsage = MemoryUsageStore(snapshot: PBUsageSnapshot(
            completedPresses: 4,
            creditedBatchIDs: Set((1...4).map { "current-\($0)" })
        ))
        let target = try PressBenchStore(
            persistence: PressBenchPersistence(baseDirectory: targetDirectory),
            usageDefaults: targetDefaults,
            usageStore: targetUsage
        )

        try target.restoreBackup(raw: raw)

        XCTAssertEqual(target.freePressesRemaining, 1)
        XCTAssertEqual(targetUsage.snapshot?.completedPresses, 4)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func jsonString(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }
}

private final class MemoryUsageStore: PBUsagePersisting {
    var snapshot: PBUsageSnapshot?

    init(snapshot: PBUsageSnapshot?) {
        self.snapshot = snapshot
    }

    func load() throws -> PBUsageSnapshot? { snapshot }
    func save(_ snapshot: PBUsageSnapshot) throws { self.snapshot = snapshot }
}
