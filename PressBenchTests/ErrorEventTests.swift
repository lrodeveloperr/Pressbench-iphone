import XCTest
@testable import PressBench

@MainActor
final class ErrorEventTests: XCTestCase {
    func testIdenticalConsecutiveFailuresPublishDistinctEvents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try PressBenchStore(persistence: PressBenchPersistence(baseDirectory: directory))

        let initial = store.errorEventID
        store.confirmInstructions()
        let first = store.errorEventID
        store.confirmInstructions()

        XCTAssertEqual(first, initial + 1)
        XCTAssertEqual(store.errorEventID, first + 1)
        XCTAssertNotNil(store.lastErrorCode)
    }

    func testRejectedSessionIsQuarantinedUntilOperatorDiscardsIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = PressBenchPersistence(baseDirectory: directory)
        let bridge = try PressBenchLogicBridge()
        let settings = try bridge.dictionary(bridge.domain("defaultSettings"), context: "test settings")
        let entitlement = try bridge.dictionary(
            bridge.entitlement("normalizeEntitlement", [[:]]), context: "test entitlement"
        )
        let now = Date().ISO8601Format(.iso8601(timeZone: .gmt, includingFractionalSeconds: true))
        let emptySetup = try bridge.dictionary(bridge.domain("emptySetup", ["F"]), context: "test setup draft")
        var session = try bridge.dictionary(
            bridge.process("saveSetupDraft", [NSNull(), emptySetup, ["now": now]]), context: "test saved draft"
        )
        session["activeRun"] = ["id": "unverifiable"]
        let issueID = UUID()
        try persistence.save([
            "machines": [[String: Any]](), "recipes": [[String: Any]](), "batches": [[String: Any]](),
            "settings": settings, "entitlement": entitlement,
            "session": session,
            "operatorIssueDrafts": ["unverifiable": [[
                "id": issueID.uuidString, "quantity": "1", "symptom": "unknown",
                "suspectedCause": "unknown", "disposition": "discarded", "note": "Unsaved evidence"
            ]]]
        ])

        let store = try PressBenchStore(bridge: bridge, persistence: persistence)
        XCTAssertTrue(store.hasRejectedRun)
        XCTAssertTrue(store.hasSetupDraft)
        XCTAssertNotNil(store.persistenceWarning)
        XCTAssertEqual(store.loadOperatorIssues(runID: "unverifiable").count, 1)

        let reopenedBeforeDiscard = try PressBenchStore(persistence: PressBenchPersistence(baseDirectory: directory))
        XCTAssertTrue(reopenedBeforeDiscard.hasRejectedRun)
        XCTAssertTrue(reopenedBeforeDiscard.hasSetupDraft)
        reopenedBeforeDiscard.activeRunRouteID = "stale-run-route"
        reopenedBeforeDiscard.selectedTab = 2
        try reopenedBeforeDiscard.discardRejectedRun()
        XCTAssertFalse(reopenedBeforeDiscard.hasRejectedRun)
        XCTAssertTrue(reopenedBeforeDiscard.hasSetupDraft)
        XCTAssertNil(reopenedBeforeDiscard.persistenceWarning)
        XCTAssertNil(reopenedBeforeDiscard.activeRunRouteID)
        XCTAssertEqual(reopenedBeforeDiscard.selectedTab, 0)
        XCTAssertTrue(reopenedBeforeDiscard.loadOperatorIssues(runID: "unverifiable").isEmpty)

        let reopenedAfterDiscard = try PressBenchStore(persistence: PressBenchPersistence(baseDirectory: directory))
        XCTAssertFalse(reopenedAfterDiscard.hasRejectedRun)
        XCTAssertTrue(reopenedAfterDiscard.hasSetupDraft)
        XCTAssertNil(reopenedAfterDiscard.persistenceWarning)
    }
}
