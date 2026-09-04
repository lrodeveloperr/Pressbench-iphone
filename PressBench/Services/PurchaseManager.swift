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

    struct EntitlementCandidate {
        let productID: String
        let purchaseDate: Date
        let expirationDate: Date?
        let revocationDate: Date?
        let isUpgraded: Bool
    }

    @Published private(set) var product: Product?
    @Published private(set) var state: PurchaseState = .loading

    private var updatesTask: Task<Void, Never>?
    var onStoreEvent: (([String: Any]) -> Bool)?

    deinit { updatesTask?.cancel() }

    func start() async {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.consume(result: result, action: "automatic_refresh")
            }
        }
        let productLoaded = await loadProduct()
        let productLoadState = state
        await refresh(action: "automatic_refresh", userInitiated: false)
        if !productLoaded, state == .free { state = productLoadState }
    }

    func reloadProduct() async {
        state = .loading
        let productLoaded = await loadProduct()
        let productLoadState = state
        await refresh(action: "automatic_refresh", userInitiated: false)
        if !productLoaded, state == .free { state = productLoadState }
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
        var verified = [Transaction]()
        var unverified = [Transaction]()
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction) where Self.recognizedProductIDs.contains(transaction.productID):
                verified.append(transaction)
            case .unverified(let transaction, _ ) where Self.recognizedProductIDs.contains(transaction.productID):
                unverified.append(transaction)
            default:
                continue
            }
        }

        if let transaction = preferredEntitlement(from: verified) {
            _ = await consumeVerified(transaction, action: action, userInitiated: userInitiated)
        } else if let transaction = unverified.max(by: { $0.purchaseDate < $1.purchaseDate }) {
            let applied = onStoreEvent?(event(
                action: action, userInitiated: userInitiated, purchaseState: "unverified",
                productID: transaction.productID, transactionID: String(transaction.id),
                nativeID: nativeIdentity(transaction), eventDate: Date(), expirationDate: transaction.expirationDate
            )) ?? false
            state = applied ? .free : .failed("entitlement_persistence_failed")
        } else {
            let applied = onStoreEvent?(event(
                action: action, userInitiated: userInitiated, purchaseState: "not_purchased",
                productID: Self.productID, transactionID: "",
                nativeID: "storekit2:none:\(Int(Date().timeIntervalSince1970))", eventDate: Date()
            )) ?? false
            state = applied ? .free : .failed("entitlement_persistence_failed")
        }
    }

    private func preferredEntitlement(from transactions: [Transaction]) -> Transaction? {
        let candidates = transactions.map {
            EntitlementCandidate(productID: $0.productID, purchaseDate: $0.purchaseDate,
                                 expirationDate: $0.expirationDate, revocationDate: $0.revocationDate,
                                 isUpgraded: $0.isUpgraded)
        }
        guard let index = Self.preferredEntitlementIndex(candidates, now: Date()) else { return nil }
        return transactions[index]
    }

    static func preferredEntitlementIndex(_ candidates: [EntitlementCandidate], now: Date) -> Int? {
        let activeIndices = candidates.indices.filter {
            let item = candidates[$0]
            return item.revocationDate == nil && !item.isUpgraded && (item.expirationDate.map { $0 > now } ?? true)
        }
        if let lifetime = activeIndices.filter({ candidates[$0].productID == legacyLifetimeProductID })
            .max(by: { candidates[$0].purchaseDate < candidates[$1].purchaseDate }) {
            return lifetime
        }
        if let subscription = activeIndices.filter({ candidates[$0].productID == productID })
            .max(by: {
                (candidates[$0].expirationDate ?? candidates[$0].purchaseDate) <
                    (candidates[$1].expirationDate ?? candidates[$1].purchaseDate)
            }) {
            return subscription
        }
        return candidates.indices.max(by: {
            (candidates[$0].revocationDate ?? candidates[$0].expirationDate ?? candidates[$0].purchaseDate) <
                (candidates[$1].revocationDate ?? candidates[$1].expirationDate ?? candidates[$1].purchaseDate)
        })
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

    @discardableResult
    private func consume(result: VerificationResult<Transaction>, action: String) async -> Bool {
        switch result {
        case .verified(let transaction):
            guard Self.recognizedProductIDs.contains(transaction.productID) else { return false }
            let applied: Bool
            if action == "purchase" {
                applied = await consumeVerified(transaction, action: action, userInitiated: true)
            } else {
                await refresh(action: action, userInitiated: action != "automatic_refresh")
                if case .failed = state { applied = false } else { applied = true }
            }
            if applied { await transaction.finish() }
            return applied
        case .unverified(let transaction, _):
            guard Self.recognizedProductIDs.contains(transaction.productID) else { return false }
            await refresh(action: action, userInitiated: action != "automatic_refresh")
            if case .failed = state { return false }
            return true
        }
    }

    @discardableResult
    private func consumeVerified(_ transaction: Transaction, action: String, userInitiated: Bool) async -> Bool {
        let now = Date()
        let expired = transaction.expirationDate.map { $0 <= now } ?? false
        let terminal = transaction.revocationDate != nil || transaction.isUpgraded || expired
        let purchaseState = transaction.revocationDate != nil ? "revoked" : terminal ? "expired" : "purchased"
        let applied = onStoreEvent?(event(
            action: action, userInitiated: userInitiated, purchaseState: purchaseState,
            productID: transaction.productID, transactionID: String(transaction.id),
            nativeID: nativeIdentity(transaction), eventDate: now, expirationDate: transaction.expirationDate
        )) ?? false
        state = applied ? (terminal ? .free : .purchased) : .failed("entitlement_persistence_failed")
        return applied
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
