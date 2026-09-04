import XCTest
@testable import PressBench

@MainActor
final class PurchaseManagerTests: XCTestCase {
    func testVerifiedLifetimeWinsOverActiveMonthlyEntitlement() {
        let now = Date()
        let candidates = [
            PurchaseManager.EntitlementCandidate(
                productID: PurchaseManager.productID,
                purchaseDate: now.addingTimeInterval(-100),
                expirationDate: now.addingTimeInterval(2_592_000),
                revocationDate: nil,
                isUpgraded: false
            ),
            PurchaseManager.EntitlementCandidate(
                productID: PurchaseManager.legacyLifetimeProductID,
                purchaseDate: now.addingTimeInterval(-200),
                expirationDate: nil,
                revocationDate: nil,
                isUpgraded: false
            )
        ]

        XCTAssertEqual(PurchaseManager.preferredEntitlementIndex(candidates, now: now), 1)
    }

    func testActiveVerifiedEntitlementWinsOverTerminalTransaction() {
        let now = Date()
        let candidates = [
            PurchaseManager.EntitlementCandidate(
                productID: PurchaseManager.legacyLifetimeProductID,
                purchaseDate: now.addingTimeInterval(-500),
                expirationDate: nil,
                revocationDate: nil,
                isUpgraded: false
            ),
            PurchaseManager.EntitlementCandidate(
                productID: PurchaseManager.productID,
                purchaseDate: now.addingTimeInterval(-100),
                expirationDate: now.addingTimeInterval(-1),
                revocationDate: nil,
                isUpgraded: false
            )
        ]

        XCTAssertEqual(PurchaseManager.preferredEntitlementIndex(candidates, now: now), 0)
    }
}
