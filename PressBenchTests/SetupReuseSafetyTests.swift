import XCTest
@testable import PressBench

@MainActor
final class SetupReuseSafetyTests: XCTestCase {
    func testSameProductVariantSavePreservesMultiStageDefinition() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let bridge = try PressBenchLogicBridge()
        let persistence = PressBenchPersistence(baseDirectory: directory)
        let now = Date().ISO8601Format(.iso8601(timeZone: .gmt, includingFractionalSeconds: true))
        let civil = Self.localCivilDate()

        var settings = try bridge.dictionary(bridge.domain("defaultSettings"), context: "test settings")
        settings = try bridge.dictionary(bridge.process("acceptLegal", [settings, [
            "termsAccepted": true,
            "safetyAccepted": true,
            "privacyPresented": true
        ], now]), context: "test legal acceptance")
        settings = try bridge.dictionary(
            bridge.process("confirmTemperatureUnit", [settings, "F", now]), context: "test temperature unit"
        )
        let entitlement = try bridge.dictionary(
            bridge.entitlement("normalizeEntitlement", [[:]]), context: "test entitlement"
        )
        var context: [String: Any] = [
            "machines": [[String: Any]](), "recipes": [[String: Any]](), "setups": [[String: Any]](),
            "batches": [[String: Any]](), "settings": settings, "session": NSNull(),
            "entitlement": entitlement, "storageMode": "native"
        ]

        let machinePlan = try bridge.dictionary(bridge.process("planSaveMachine", [context, [
            "nickname": "Press A", "brand": "Sample", "model": "P1", "pressureMethod": "",
            "pressureScale": "", "platenOrZone": "Main platen", "lastExternalCheckDate": "",
            "notes": "", "archived": false
        ], now]), context: "test machine")
        let machines = try XCTUnwrap(machinePlan["machines"] as? [[String: Any]])
        let machine = try XCTUnwrap(machines.first)
        let machineID = try XCTUnwrap(machine["id"] as? String)
        let machineNickname = try XCTUnwrap(machine["nickname"] as? String)
        let platen = try XCTUnwrap(machine["platenOrZone"] as? String)
        context["machines"] = machines

        var setup = try bridge.dictionary(bridge.domain("emptySetup", ["F"]), context: "test setup")
        let snapshot = try bridge.dictionary(bridge.domain("machineProfileSnapshot", [machine]), context: "test machine snapshot")
        setup["title"] = "Two-stage cotton + DTF"
        setup["blankMaterial"] = "Cotton tee"
        setup["transferMedium"] = "DTF transfer"
        setup["processStructure"] = "multi_stage"
        setup["machineProfileId"] = machineID
        setup["machineProfile"] = snapshot
        setup["machineNickname"] = machineNickname
        setup["platenZone"] = platen
        setup["temperature"] = 325
        setup["temperatureUnit"] = "F"
        setup["pressTimeSeconds"] = 15
        setup["pressure"] = "Medium"
        setup["pressCount"] = 2
        setup["defaultQuantity"] = 10
        setup["instructionSource"] = [
            "type": "supplier", "name": "Supplier sheet", "reference": "S-1", "checkedDate": civil,
            "revision": "R2", "priorBatchId": ""
        ]
        setup["steps"] = [
            [
                "stageType": "press", "name": "Press", "instruction": "Main press",
                "machineNickname": machineNickname, "machineProfileId": machineID,
                "platenZone": platen, "temperature": 325, "temperatureUnit": "F",
                "durationSeconds": 15, "pressure": "Medium", "repeatCount": 1,
                "placementAction": "Center", "finishAction": ""
            ],
            [
                "stageType": "postpress", "name": "Post-press", "instruction": "Seal finish",
                "machineNickname": machineNickname, "machineProfileId": machineID,
                "platenZone": platen, "temperature": 300, "temperatureUnit": "F",
                "durationSeconds": 8, "pressure": "Light", "repeatCount": 1,
                "placementAction": "", "finishAction": "Cool flat"
            ]
        ]

        let setupPlan = try bridge.dictionary(bridge.process("planSaveSetup", [context, setup, now]), context: "test setup plan")
        let setups = try XCTUnwrap(setupPlan["setups"] as? [[String: Any]])
        try persistence.save([
            "machines": machines, "recipes": setups, "batches": [[String: Any]](), "settings": settings,
            "session": NSNull(), "entitlement": entitlement
        ])

        let store = try PressBenchStore(bridge: bridge, persistence: persistence)
        let source = try XCTUnwrap(store.canonicalReportSetups.first)
        let sourceID = try XCTUnwrap(source["id"] as? String)
        var draft = try store.prepareSetupReuse(setupID: sourceID, reuseClass: .sameProductVariant)
        draft.title = "Navy product variant"
        draft.notes = "Variant note"
        draft.defaultQuantity = "12"
        let savedID = try store.saveSetup(draft, temperatureUnit: "F", reuseClass: .sameProductVariant)
        let saved = try XCTUnwrap(store.canonicalReportSetups.first { ($0["id"] as? String) == savedID })

        XCTAssertNotEqual(savedID, sourceID)
        XCTAssertEqual(saved["status"] as? String, "trial")
        XCTAssertEqual(saved["title"] as? String, "Navy product variant")
        XCTAssertEqual((saved["defaultQuantity"] as? NSNumber)?.intValue, 12)

        for key in [
            "processStructure", "blankMaterial", "transferMedium", "instructionSource", "machineProfileId",
            "machineProfile", "machineNickname", "platenZone", "temperature", "temperatureUnit",
            "pressTimeSeconds", "pressure"
        ] {
            XCTAssertEqual(try Self.canonical(saved[key]), try Self.canonical(source[key]), "Unsafe same-variant mutation: \(key)")
        }
        XCTAssertEqual(try Self.canonical(Self.stepsWithoutIDs(saved)), try Self.canonical(Self.stepsWithoutIDs(source)))
    }

    private static func stepsWithoutIDs(_ setup: [String: Any]) -> [[String: Any]] {
        (setup["steps"] as? [[String: Any]] ?? []).map { step in
            var copy = step
            copy.removeValue(forKey: "id")
            return copy
        }
    }

    private static func canonical(_ value: Any?) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["value": value ?? NSNull()], options: [.sortedKeys])
    }

    private static func localCivilDate() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }
}
