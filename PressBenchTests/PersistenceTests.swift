import CryptoKit
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

    func testRevisionExhaustionFailsClosedInsteadOfOverflowing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let state: [String: Any] = ["machines": [], "recipes": [], "batches": [], "settings": [:], "session": NSNull()]
        let canonical = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
        let checksum = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
        let envelope: [String: Any] = [
            "format": 3,
            "revision": Int.max,
            "savedAt": "2040-01-01T00:00:00Z",
            "checksum": checksum,
            "data": state,
        ]
        let bytes = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        try bytes.write(to: directory.appendingPathComponent("state-v5.json"))
        try bytes.write(to: directory.appendingPathComponent("state-v5.replica.json"))

        let persistence = PressBenchPersistence(baseDirectory: directory)
        _ = try persistence.load()
        XCTAssertThrowsError(try persistence.save(state)) { error in
            guard case PressBenchPersistence.PersistenceError.revisionExhausted = error else {
                return XCTFail("Expected revisionExhausted, got \(error)")
            }
        }
    }

    func testNegativeRevisionIsRejectedAsCorrupt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let state: [String: Any] = ["machines": [], "recipes": [], "batches": []]
        let canonical = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
        let checksum = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
        let envelope: [String: Any] = [
            "format": 3,
            "revision": -1,
            "savedAt": "2040-01-01T00:00:00Z",
            "checksum": checksum,
            "data": state,
        ]
        let bytes = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        try bytes.write(to: directory.appendingPathComponent("state-v5.json"))

        XCTAssertThrowsError(try PressBenchPersistence(baseDirectory: directory).load())
    }

    func testCompletedBatchesAreSegmentedAndCoreOnlySavesReuseTheirRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = PressBenchPersistence(baseDirectory: directory)
        var state: [String: Any] = [
            "machines": [], "recipes": [], "settings": ["language": "en"],
            "session": NSNull(), "entitlement": [:],
            "batches": [["id": "batch-1", "quantityProcessed": 24]]
        ]

        try persistence.save(state)
        let batchDirectory = directory.appendingPathComponent("batches-v6/primary", isDirectory: true)
        let firstFiles = try FileManager.default.contentsOfDirectory(atPath: batchDirectory.path)
            .filter { $0.hasSuffix(".record.json") }
        XCTAssertEqual(firstFiles.count, 1)
        let firstBytes = try Data(contentsOf: batchDirectory.appendingPathComponent(try XCTUnwrap(firstFiles.first)))

        state["session"] = ["activeRun": ["id": "run-1"]]
        try persistence.save(state, batchesChanged: false)
        let secondFiles = try FileManager.default.contentsOfDirectory(atPath: batchDirectory.path)
            .filter { $0.hasSuffix(".record.json") }
        XCTAssertEqual(secondFiles, firstFiles)
        XCTAssertEqual(
            try Data(contentsOf: batchDirectory.appendingPathComponent(try XCTUnwrap(secondFiles.first))),
            firstBytes
        )

        let loaded = try XCTUnwrap(PressBenchPersistence(baseDirectory: directory).load())
        XCTAssertEqual((loaded["batches"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual(
            ((loaded["batches"] as? [[String: Any]])?.first?["quantityProcessed"] as? NSNumber)?.intValue,
            24
        )

        state["batches"] = [["id": "batch-1", "quantityProcessed": 25]]
        try persistence.save(state, batchesChanged: true, changedBatchIDs: ["batch-1"])
        let correctedFiles = try FileManager.default.contentsOfDirectory(atPath: batchDirectory.path)
            .filter { $0.hasSuffix(".record.json") }
        XCTAssertEqual(correctedFiles.count, 1)
        XCTAssertNotEqual(correctedFiles, firstFiles)
        let corrected = try XCTUnwrap(PressBenchPersistence(baseDirectory: directory).load())
        XCTAssertEqual(
            ((corrected["batches"] as? [[String: Any]])?.first?["quantityProcessed"] as? NSNumber)?.intValue,
            25
        )
    }

    func testCorruptPrimaryBatchRecoversFromReplica() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = PressBenchPersistence(baseDirectory: directory)
        let state: [String: Any] = [
            "machines": [], "recipes": [], "settings": [:], "session": NSNull(),
            "entitlement": [:], "batches": [["id": "batch-1", "quantityGood": 10]]
        ]
        try persistence.save(state)

        let primaryDirectory = directory.appendingPathComponent("batches-v6/primary", isDirectory: true)
        let file = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(atPath: primaryDirectory.path)
                .first { $0.hasSuffix(".record.json") }
        )
        try Data("corrupt".utf8).write(to: primaryDirectory.appendingPathComponent(file), options: [.atomic])

        let recovered = try XCTUnwrap(PressBenchPersistence(baseDirectory: directory).load())
        XCTAssertEqual((recovered["batches"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual(
            ((recovered["batches"] as? [[String: Any]])?.first?["quantityGood"] as? NSNumber)?.intValue,
            10
        )
    }

    func testLegacyStateMigratesOnNextSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let state: [String: Any] = [
            "machines": [], "recipes": [], "settings": [:], "session": NSNull(),
            "entitlement": [:], "batches": [["id": "legacy-batch"]]
        ]
        let canonical = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
        let checksum = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
        let envelope: [String: Any] = [
            "format": 3, "revision": 7, "savedAt": "2040-01-01T00:00:00Z",
            "checksum": checksum, "data": state
        ]
        let bytes = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        try bytes.write(to: directory.appendingPathComponent("state-v5.json"))
        try bytes.write(to: directory.appendingPathComponent("state-v5.replica.json"))

        let persistence = PressBenchPersistence(baseDirectory: directory)
        let loaded = try XCTUnwrap(persistence.load())
        XCTAssertEqual((loaded["batches"] as? [[String: Any]])?.count, 1)
        try persistence.save(loaded, batchesChanged: false)

        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("state-v6.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("state-v5.json").path))
        XCTAssertEqual(
            (try PressBenchPersistence(baseDirectory: directory).load()?["batches"] as? [[String: Any]])?.count,
            1
        )
    }
}
