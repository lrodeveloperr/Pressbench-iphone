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
}
