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

    func testFiveCompletedPressesUseTheFreeAllowance() {
        let meter = PBUsageMeter(defaults: defaults)

        for index in 1...PBUsageMeter.freePressLimit {
            XCTAssertTrue(meter.canStartFreePress(existingCompletedRuns: index - 1))
            meter.recordCompletedPress(batchID: "batch-\(index)")
        }

        XCTAssertEqual(meter.completedPresses, 5)
        XCTAssertEqual(meter.freePressesRemaining, 0)
        XCTAssertFalse(meter.canStartFreePress(existingCompletedRuns: 0))
    }

    func testDeletingRunsCannotRestoreFreeUsage() {
        let meter = PBUsageMeter(defaults: defaults)
        meter.reconcile(existingCompletedRuns: 5)

        XCTAssertFalse(meter.canStartFreePress(existingCompletedRuns: 0))
        XCTAssertEqual(meter.completedPresses, 5)
    }

    func testSameCompletionCannotBeCountedTwice() {
        let meter = PBUsageMeter(defaults: defaults)
        meter.recordCompletedPress(batchID: "same-batch")
        meter.recordCompletedPress(batchID: "same-batch")

        XCTAssertEqual(meter.completedPresses, 1)
    }

    func testNonAdjacentDuplicateCannotBeCountedTwice() {
        let meter = PBUsageMeter(defaults: defaults)
        meter.recordCompletedPress(batchID: "batch-a")
        meter.recordCompletedPress(batchID: "batch-b")
        meter.recordCompletedPress(batchID: "batch-a")

        XCTAssertEqual(meter.completedPresses, 2)
        XCTAssertEqual(meter.freePressesRemaining, 3)
    }

    func testCounterNeverExceedsTheFreeLimit() {
        let meter = PBUsageMeter(defaults: defaults)
        for index in 0..<20 { meter.recordCompletedPress(batchID: "batch-\(index)") }

        XCTAssertEqual(meter.completedPresses, PBUsageMeter.freePressLimit)
        XCTAssertEqual(meter.freePressesRemaining, 0)
    }

    func testSecureLedgerSurvivesPreferenceReset() {
        let secure = InMemoryUsageStore()
        let first = PBUsageMeter(defaults: defaults, secureStore: secure)
        first.recordCompletedPress(batchID: "batch-a")
        first.recordCompletedPress(batchID: "batch-b")

        defaults.removePersistentDomain(forName: suiteName)
        let relaunched = PBUsageMeter(defaults: defaults, secureStore: secure)

        XCTAssertEqual(relaunched.completedPresses, 2)
        XCTAssertEqual(relaunched.freePressesRemaining, 3)
        relaunched.recordCompletedPress(batchID: "batch-a")
        XCTAssertEqual(relaunched.completedPresses, 2)
    }

    func testOlderBackupCountCannotReduceExistingUsage() {
        let secure = InMemoryUsageStore()
        let meter = PBUsageMeter(defaults: defaults, secureStore: secure)
        meter.reconcile(existingCompletedRuns: 4)
        meter.reconcile(existingCompletedRuns: 1)

        XCTAssertEqual(meter.completedPresses, 4)
        XCTAssertEqual(meter.freePressesRemaining, 1)
    }

    func testImportedUsageCanRaiseButNeverExceedLimit() {
        let secure = InMemoryUsageStore()
        let meter = PBUsageMeter(defaults: defaults, secureStore: secure)

        meter.reconcile(existingCompletedRuns: 99)

        XCTAssertEqual(meter.completedPresses, PBUsageMeter.freePressLimit)
        XCTAssertFalse(meter.canStartFreePress(existingCompletedRuns: 0))
    }

    func testPersistenceFailureFailsClosed() {
        let secure = InMemoryUsageStore()
        secure.failSaves = true
        let meter = PBUsageMeter(defaults: defaults, secureStore: secure)

        XCTAssertFalse(meter.persistenceHealthy)
        XCTAssertFalse(meter.canStartFreePress(existingCompletedRuns: 0))
    }

    func testTransientPersistenceFailureRecoversWithoutResettingUsage() {
        let secure = InMemoryUsageStore()
        secure.failSaves = true
        let meter = PBUsageMeter(defaults: defaults, secureStore: secure)
        meter.reconcile(existingCompletedRuns: 3)
        XCTAssertFalse(meter.canStartFreePress(existingCompletedRuns: 0))

        secure.failSaves = false
        XCTAssertTrue(meter.canStartFreePress(existingCompletedRuns: 0))
        XCTAssertEqual(meter.completedPresses, 3)
        XCTAssertEqual(secure.snapshot?.completedPresses, 3)
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
