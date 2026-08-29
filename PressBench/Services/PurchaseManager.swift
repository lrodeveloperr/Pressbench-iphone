import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let productID = "pressbench_unlimited_monthly_ios"
    static let legacyLifetimeProductID = "pressbench_unlimited_lifetime_ios"
    static let recognizedProductIDs: Set<String> = [productID, legacyLifetimeProductID]

    enum PurchaseState: Equatable {
        case loading, free, purchased, pending, unavailable, failed(String)
    }

    @Published private(set) var product: Product?
    @Published private(set) var state: PurchaseState = .loading

    private var updatesTask: Task<Void, Never>?
    var onStoreEvent: (([String: Any]) -> Void)?

    deinit { updatesTask?.cancel() }

    func start() async {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.consume(result: result, action: "automatic_refresh")
            }
        }
        guard await loadProduct() else { return }
        await refresh(action: "automatic_refresh", userInitiated: false)
    }

    func reloadProduct() async {
        state = .loading
        guard await loadProduct() else { return }
        await refresh(action: "automatic_refresh", userInitiated: false)
    }

    func purchase() async {
        guard let product else {
            state = .unavailable
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await consume(result: verification, action: "purchase")
            case .pending:
                state = .pending
                onStoreEvent?(event(
                    action: "purchase", userInitiated: true, purchaseState: "pending",
                    productID: Self.productID, transactionID: "",
                    nativeID: "storekit2:pending:\(UUID().uuidString)", eventDate: Date()
                ))
            case .userCancelled:
                await refresh(action: "automatic_refresh", userInitiated: false)
            @unknown default:
                state = .failed("unknown_purchase_result")
            }
        } catch {
            state = .failed(String(describing: error))
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh(action: "explicit_restore", userInitiated: true)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    func refresh(action: String = "automatic_refresh", userInitiated: Bool = false) async {
        var found = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction) where Self.recognizedProductIDs.contains(transaction.productID):
                found = true
                await consumeVerified(transaction, action: action, userInitiated: userInitiated)
            case .unverified(let transaction, _ ) where Self.recognizedProductIDs.contains(transaction.productID):
                found = true
                state = .free
                onStoreEvent?(event(
                    action: action, userInitiated: userInitiated, purchaseState: "unverified",
                    productID: transaction.productID, transactionID: String(transaction.id),
                    nativeID: nativeIdentity(transaction), eventDate: Date(), expirationDate: transaction.expirationDate
                ))
            default:
                continue
            }
        }
        if !found {
            state = .free
            onStoreEvent?(event(
                action: action, userInitiated: userInitiated, purchaseState: "not_purchased",
                productID: Self.productID, transactionID: "",
                nativeID: "storekit2:none:\(Int(Date().timeIntervalSince1970))", eventDate: Date()
            ))
        }
    }

    @discardableResult
    private func loadProduct() async -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pressbench-ui-test-product-unavailable") {
            product = nil
            state = .unavailable
            return false
        }
        #endif
        do {
            let candidate = try await Product.products(for: [Self.productID]).first
            guard candidate?.type == .autoRenewable,
                  candidate?.subscription?.subscriptionPeriod.unit == .month,
                  candidate?.subscription?.subscriptionPeriod.value == 1 else {
                product = nil
                state = .unavailable
                return false
            }
            product = candidate
            return true
        } catch {
            product = nil
            state = .failed(String(describing: error))
            return false
        }
    }

    private func consume(result: VerificationResult<Transaction>, action: String) async {
        switch result {
        case .verified(let transaction):
            guard Self.recognizedProductIDs.contains(transaction.productID) else { return }
            await consumeVerified(transaction, action: action, userInitiated: action != "automatic_refresh")
            await transaction.finish()
        case .unverified(let transaction, _):
            guard Self.recognizedProductIDs.contains(transaction.productID) else { return }
            state = .free
            onStoreEvent?(event(
                action: action, userInitiated: action != "automatic_refresh", purchaseState: "unverified",
                productID: transaction.productID, transactionID: String(transaction.id),
                nativeID: nativeIdentity(transaction), eventDate: Date(), expirationDate: transaction.expirationDate
            ))
        }
    }

    private func consumeVerified(_ transaction: Transaction, action: String, userInitiated: Bool) async {
        let now = Date()
        let expired = transaction.expirationDate.map { $0 <= now } ?? false
        let terminal = transaction.revocationDate != nil || transaction.isUpgraded || expired
        let purchaseState = transaction.revocationDate != nil ? "revoked" : terminal ? "expired" : "purchased"
        onStoreEvent?(event(
            action: action, userInitiated: userInitiated, purchaseState: purchaseState,
            productID: transaction.productID, transactionID: String(transaction.id),
            nativeID: nativeIdentity(transaction), eventDate: now, expirationDate: transaction.expirationDate
        ))
        state = terminal ? .free : .purchased
    }

    private func nativeIdentity(_ transaction: Transaction) -> String {
        [
            "storekit2", String(transaction.id), String(transaction.originalID), transaction.productID,
            String(Int(transaction.purchaseDate.timeIntervalSince1970))
        ].joined(separator: ":")
    }

    private func event(
        action: String,
        userInitiated: Bool,
        purchaseState: String,
        productID: String,
        transactionID: String,
        nativeID: String,
        eventDate: Date,
        expirationDate: Date? = nil
    ) -> [String: Any] {
        var output: [String: Any] = [
            "action": action,
            "platform": "ios",
            "userInitiated": userInitiated,
            "nativeAdapterVerified": true,
            "verificationSource": "storekit2",
            "productId": productID,
            "productType": productID == Self.legacyLifetimeProductID ? "non_consumable" : "auto_renewable_subscription",
            "purchaseState": purchaseState,
            "transactionId": transactionID,
            "nativeVerificationId": nativeID,
            "storeEventAt": ISO8601DateFormatter().string(from: eventDate)
        ]
        if let expirationDate {
            output["expiresAt"] = ISO8601DateFormatter().string(from: expirationDate)
        }
        return output
    }
}
