import SwiftUI
import XCTest
@testable import PressBench

final class PressBenchBackupDocumentTests: XCTestCase {
    func testBackupDocumentRoundTripsValidPayload() throws {
        let payload: [String: Any] = [
            "schema": "press-bench-log",
            "schemaVersion": 4,
            "appId": "APP-018",
            "exportedAt": "2026-09-03T12:00:00.000Z",
            "machines": [],
            "setups": [],
            "batches": [],
            "settings": [:],
            "freeRunsUsed": 3,
        ]

        let document = try PressBenchBackupDocument(payload: payload)
        let restored = try PressBenchBackupDocument(data: document.data)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(restored.rawPayload().utf8)) as? [String: Any]
        )

        XCTAssertEqual(object["schema"] as? String, "press-bench-log")
        XCTAssertEqual((object["freeRunsUsed"] as? NSNumber)?.intValue, 3)
    }

    func testBackupDocumentRejectsEmptyOrForeignFiles() {
        XCTAssertThrowsError(try PressBenchBackupDocument(data: Data()))
        XCTAssertThrowsError(
            try PressBenchBackupDocument(data: Data("{\"schema\":\"other\",\"appId\":\"APP-018\"}".utf8))
        )
        XCTAssertThrowsError(
            try PressBenchBackupDocument(data: Data("{\"schema\":\"press-bench-log\",\"appId\":\"other\"}".utf8))
        )
    }

    func testBackupDocumentAcceptsLegacyBackupWithoutAppID() {
        let data = Data("{\"schema\":\"press-bench-log\",\"schemaVersion\":1}".utf8)
        XCTAssertNoThrow(try PressBenchBackupDocument(data: data))
    }

    func testBackupDocumentRejectsOversizedInputBeforeRestore() {
        XCTAssertThrowsError(try PressBenchBackupDocument(data: Data(repeating: 0x20, count: 10_000_001)))
    }

    func testBackupFilenameIsPortableAndStable() {
        let name = PressBenchBackupDocument.defaultFilename(at: Date(timeIntervalSince1970: 1_725_192_000))
        XCTAssertTrue(name.hasPrefix("PressBench-Backup-"))
        XCTAssertFalse(name.contains(":"))
        XCTAssertFalse(name.contains("/"))
    }
}
