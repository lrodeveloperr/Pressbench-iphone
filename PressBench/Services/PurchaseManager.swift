import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let productID = "pressbench_unlimited_lifetime_ios"

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
        await loadProduct()
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
                    transactionID: "", nativeID: "storekit2:pending:\(UUID().uuidString)", eventDate: Date()
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
            case .verified(let transaction) where transaction.productID == Self.productID:
                found = true
                await consumeVerified(transaction, action: action, userInitiated: userInitiated)
            case .unverified(let transaction, _ ) where transaction.productID == Self.productID:
                found = true
                state = .free
                onStoreEvent?(event(
                    action: action, userInitiated: userInitiated, purchaseState: "unverified",
                    transactionID: String(transaction.id), nativeID: nativeIdentity(transaction), eventDate: Date()
                ))
            default:
                continue
            }
        }
        if !found {
            state = .free
            onStoreEvent?(event(
                action: action, userInitiated: userInitiated, purchaseState: "not_purchased",
                transactionID: "", nativeID: "storekit2:none:\(Int(Date().timeIntervalSince1970))", eventDate: Date()
            ))
        }
    }

    private func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil { state = .unavailable }
        } catch {
            state = .failed(String(describing: error))
        }
    }

    private func consume(result: VerificationResult<Transaction>, action: String) async {
        switch result {
        case .verified(let transaction):
            guard transaction.productID == Self.productID else { return }
            await consumeVerified(transaction, action: action, userInitiated: action != "automatic_refresh")
            await transaction.finish()
        case .unverified(let transaction, _):
            guard transaction.productID == Self.productID else { return }
            state = .free
            onStoreEvent?(event(
                action: action, userInitiated: action != "automatic_refresh", purchaseState: "unverified",
                transactionID: String(transaction.id), nativeID: nativeIdentity(transaction), eventDate: Date()
            ))
        }
    }

    private func consumeVerified(_ transaction: Transaction, action: String, userInitiated: Bool) async {
        let terminal = transaction.revocationDate != nil
        let purchaseState = terminal ? "revoked" : "purchased"
        let eventDate = transaction.revocationDate ?? Date()
        onStoreEvent?(event(
            action: action, userInitiated: userInitiated, purchaseState: purchaseState,
            transactionID: String(transaction.id), nativeID: nativeIdentity(transaction), eventDate: eventDate
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
        transactionID: String,
        nativeID: String,
        eventDate: Date
    ) -> [String: Any] {
        [
            "action": action,
            "platform": "ios",
            "userInitiated": userInitiated,
            "nativeAdapterVerified": true,
            "verificationSource": "storekit2",
            "productId": Self.productID,
            "purchaseState": purchaseState,
            "transactionId": transactionID,
            "nativeVerificationId": nativeID,
            "storeEventAt": ISO8601DateFormatter().string(from: eventDate)
        ]
    }
}
