import XCTest
@testable import PressBench

final class UsageMeterTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PressBenchTests.UsageMeter.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testCompletedPressesUseTheFreeAllowance() {
        let meter = PBUsageMeter(defaults: defaults)

        for index in 1...PBUsageMeter.freePressLimit {
            XCTAssertTrue(meter.canStartFreePress(qualifyingCompletedBatchIDs: []))
            meter.recordCompletedPress(batchID: "batch-\(index)", authorizationBasis: "free", recordedProduction: true)
        }

        XCTAssertEqual(meter.completedPresses, PBUsageMeter.freePressLimit)
        XCTAssertEqual(meter.freePressesRemaining, 0)
        XCTAssertFalse(meter.canStartFreePress(qualifyingCompletedBatchIDs: []))
    }

    func testDeletingRunsCannotRestoreFreeUsage() {
        let meter = PBUsageMeter(defaults: defaults)
        meter.reconcile(qualifyingCompletedBatchIDs: Set((1...PBUsageMeter.freePressLimit).map { "batch-\($0)" }))

        XCTAssertFalse(meter.canStartFreePress(qualifyingCompletedBatchIDs: []))
        XCTAssertEqual(meter.completedPresses, PBUsageMeter.freePressLimit)
    }

    func testSameCompletionCannotBeCountedTwice() {
        let meter = PBUsageMeter(defaults: defaults)
        meter.recordCompletedPress(batchID: "same-batch", authorizationBasis: "free", recordedProduction: true)
        meter.recordCompletedPress(batchID: "same-batch", authorizationBasis: "free", recordedProduction: true)

        XCTAssertEqual(meter.completedPresses, 1)
    }

    func testNonAdjacentDuplicateCannotBeCountedTwice() {
        let meter = PBUsageMeter(defaults: defaults)
        meter.recordCompletedPress(batchID: "batch-a", authorizationBasis: "free", recordedProduction: true)
        meter.recordCompletedPress(batchID: "batch-b", authorizationBasis: "free", recordedProduction: true)
        meter.recordCompletedPress(batchID: "batch-a", authorizationBasis: "free", recordedProduction: true)

        XCTAssertEqual(meter.completedPresses, 2)
        XCTAssertEqual(meter.freePressesRemaining, 8)
    }

    func testCounterNeverExceedsTheFreeLimit() {
        let meter = PBUsageMeter(defaults: defaults)
        for index in 0..<20 {
            meter.recordCompletedPress(batchID: "batch-\(index)", authorizationBasis: "free", recordedProduction: true)
        }

        XCTAssertEqual(meter.completedPresses, PBUsageMeter.freePressLimit)
        XCTAssertEqual(meter.freePressesRemaining, 0)
    }

    func testSecureLedgerSurvivesPreferenceReset() {
        let secure = InMemoryUsageStore()
        let first = PBUsageMeter(defaults: defaults, secureStore: secure)
        first.recordCompletedPress(batchID: "batch-a", authorizationBasis: "free", recordedProduction: true)
        first.recordCompletedPress(batchID: "batch-b", authorizationBasis: "free", recordedProduction: true)

        defaults.removePersistentDomain(forName: suiteName)
        let relaunched = PBUsageMeter(defaults: defaults, secureStore: secure)

        XCTAssertEqual(relaunched.completedPresses, 2)
        XCTAssertEqual(relaunched.freePressesRemaining, 8)
        relaunched.recordCompletedPress(batchID: "batch-a", authorizationBasis: "free", recordedProduction: true)
        XCTAssertEqual(relaunched.completedPresses, 2)
    }

    func testOlderBackupCountCannotReduceExistingUsage() {
        let secure = InMemoryUsageStore()
        let meter = PBUsageMeter(defaults: defaults, secureStore: secure)
        meter.reconcile(qualifyingCompletedBatchIDs: ["batch-a", "batch-b"])
        meter.reconcile(qualifyingCompletedBatchIDs: ["batch-a"])

        XCTAssertEqual(meter.completedPresses, 2)
        XCTAssertEqual(meter.freePressesRemaining, 8)
    }

    func testImportedUsageCanRaiseButNeverExceedLimit() {
        let secure = InMemoryUsageStore()
        let meter = PBUsageMeter(defaults: defaults, secureStore: secure)

        meter.reconcile(qualifyingCompletedBatchIDs: Set((0..<99).map { "batch-\($0)" }))

        XCTAssertEqual(meter.completedPresses, PBUsageMeter.freePressLimit)
        XCTAssertFalse(meter.canStartFreePress(qualifyingCompletedBatchIDs: []))
    }

    func testPersistenceFailureFailsClosed() {
        let secure = InMemoryUsageStore()
        secure.failSaves = true
        let meter = PBUsageMeter(defaults: defaults, secureStore: secure)

        XCTAssertFalse(meter.persistenceHealthy)
        XCTAssertFalse(meter.canStartFreePress(qualifyingCompletedBatchIDs: []))
    }

    func testTransientPersistenceFailureRecoversWithoutResettingUsage() {
        let secure = InMemoryUsageStore()
        secure.failSaves = true
        let meter = PBUsageMeter(defaults: defaults, secureStore: secure)
        meter.reconcile(qualifyingCompletedBatchIDs: ["batch-a", "batch-b"])
        XCTAssertFalse(meter.canStartFreePress(qualifyingCompletedBatchIDs: []))

        secure.failSaves = false
        XCTAssertTrue(meter.canStartFreePress(qualifyingCompletedBatchIDs: []))
        XCTAssertTrue(meter.persistenceHealthy)
        XCTAssertEqual(meter.completedPresses, 2)
        XCTAssertEqual(secure.snapshot?.completedPresses, 2)
    }

    func testPaidAndUnproducedRunsDoNotConsumeFreeAllowance() {
        let meter = PBUsageMeter(defaults: defaults)
        meter.recordCompletedPress(batchID: "paid", authorizationBasis: "verified_active", recordedProduction: true)
        meter.recordCompletedPress(batchID: "cancelled", authorizationBasis: "free", recordedProduction: false)

        XCTAssertEqual(meter.completedPresses, 0)
        XCTAssertEqual(meter.freePressesRemaining, 10)
    }
}

private final class InMemoryUsageStore: PBUsagePersisting {
    var snapshot: PBUsageSnapshot?
    var failSaves = false

    func load() throws -> PBUsageSnapshot? { snapshot }

    func save(_ snapshot: PBUsageSnapshot) throws {
        if failSaves { throw TestUsageError.failed }
        self.snapshot = snapshot
    }
}

private enum TestUsageError: Error {
    case failed
}
