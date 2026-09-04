import XCTest
@testable import PressBench

final class PersistenceTests: XCTestCase {
    func testDualReplicaRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = PressBenchPersistence(baseDirectory: directory)
        let state: [String: Any] = ["machines": [], "recipes": [], "batches": [], "settings": ["language": "en"], "session": NSNull(), "entitlement": [:]]
        try persistence.save(state)
        let loaded = try XCTUnwrap(persistence.load())
        XCTAssertEqual((loaded["settings"] as? [String: Any])?["language"] as? String, "en")
        XCTAssertEqual(persistence.revision, 1)
    }

    func testCorruptionFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("state-v5.json"))
        let persistence = PressBenchPersistence(baseDirectory: directory)
        XCTAssertThrowsError(try persistence.load())
    }

    @MainActor
    func testCorruptPersistenceCanBeRecoveredWithoutCompletingOnboarding() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("state-v5.json"))

        let store = try PressBenchStore(persistence: PressBenchPersistence(baseDirectory: directory))
        XCTAssertTrue(store.requiresPersistenceRecovery)
        XCTAssertThrowsError(try store.completeOnboarding(language: .en, locale: Locale(identifier: "en_US"), temperatureUnit: "F"))

        try store.deleteAllLocalData()
        XCTAssertFalse(store.requiresPersistenceRecovery)
        XCTAssertNil(store.persistenceWarning)
    }
}
