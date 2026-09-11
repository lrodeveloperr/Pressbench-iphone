import XCTest
@testable import PressBench

@MainActor
final class InputBoundaryTests: XCTestCase {
    func testSetupInputsStopAtCanonicalPerRecordBoundsWithoutOverflowing() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        var draft = fixture.store.setupDraft(for: nil)
        draft.material = "Cotton"
        draft.transferMedium = "DTF"
        draft.sourceName = "Supplier"
        draft.sourceReference = "S-1"
        draft.stages[0].temperature = "325"
        draft.stages[0].durationSeconds = "15"
        draft.stages[0].pressure = "Medium"

        var oversized = draft
        oversized.defaultQuantity = "1000000"
        XCTAssertThrowsError(try fixture.store.saveSetup(oversized, temperatureUnit: "F"))

        oversized = draft
        oversized.stages[0].repeatCount = "100"
        XCTAssertThrowsError(try fixture.store.saveSetup(oversized, temperatureUnit: "F"))

        oversized = draft
        oversized.stages[0].durationSeconds = "10000"
        XCTAssertThrowsError(try fixture.store.saveSetup(oversized, temperatureUnit: "F"))

        oversized = draft
        oversized.stages[0].temperature = "1000"
        XCTAssertThrowsError(try fixture.store.saveSetup(oversized, temperatureUnit: "F"))

        oversized = draft
        oversized.stages = Array(repeating: draft.stages[0], count: PBInputLimits.maximumStages + 1)
        XCTAssertThrowsError(try fixture.store.saveSetup(oversized, temperatureUnit: "F"))
    }

    func testCorrectionRejectsHostileQuantitiesBeforeAnyAddition() throws {
        let fixture = try makeStore()
        defer { fixture.cleanup() }
        let hostile = IssueDraftInput(quantity: String(Int.max), disposition: "discarded", note: "Invalid")

        XCTAssertThrowsError(try fixture.store.correctBatch(
            id: "missing", jobReference: "", planned: 1, processed: 1,
            notes: "", issues: [hostile, hostile], reason: "Boundary test"
        ))

        let tooMany = (0...PBInputLimits.maximumIssues).map { _ in
            IssueDraftInput(quantity: "1", disposition: "discarded", note: "Invalid")
        }
        XCTAssertThrowsError(try fixture.store.correctBatch(
            id: "missing", jobReference: "", planned: 1, processed: 1,
            notes: "", issues: tooMany, reason: "Boundary test"
        ))
    }

    private func makeStore() throws -> (store: PressBenchStore, cleanup: () -> Void) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsName = "PressBenchTests.InputBoundary.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        let store = try PressBenchStore(
            persistence: PressBenchPersistence(baseDirectory: directory),
            usageDefaults: defaults
        )
        try store.configurePreferences(language: .en, locale: Locale(identifier: "en_US"), temperatureUnit: "F")
        _ = try store.saveMachine(MachineDraft(nickname: "Boundary Press", platen: "15 × 15 in"))
        return (store, {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: defaultsName)
        })
    }
}
