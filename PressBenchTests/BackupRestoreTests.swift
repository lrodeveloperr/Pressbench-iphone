import XCTest
@testable import PressBench

@MainActor
final class BackupRestoreTests: XCTestCase {
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
