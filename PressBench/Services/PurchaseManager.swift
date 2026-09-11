import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    enum Plan: String, CaseIterable, Identifiable {
        case monthly = "pressbench_unlimited_monthly_ios"
        case annual = "pressbench_unlimited_annual_ios"

        var id: String { rawValue }
    }

    static let monthlyProductID = Plan.monthly.rawValue
    static let annualProductID = Plan.annual.rawValue
    static let subscriptionProductIDs = Set(Plan.allCases.map(\.rawValue))
    static let recognizedProductIDs = subscriptionProductIDs

    enum PurchaseState: Equatable {
        case loading, free, purchased, pending, unavailable, failed(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var state: PurchaseState = .loading
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false

    var isWorking: Bool { isLoadingProduct || isPurchasing || isRestoring }
    var hasAvailableProduct: Bool { !products.isEmpty }

    private var updatesTask: Task<Void, Never>?
    var onStoreEvent: (([String: Any]) -> Void)?

    deinit { updatesTask?.cancel() }

    func product(for plan: Plan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    func start() async {
        guard !isWorking else { return }
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.consume(result: result, action: "automatic_refresh")
            }
        }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        let productsLoaded = await loadProducts()
        let productLoadState = state
        await refresh(action: "automatic_refresh", userInitiated: false)
        if !productsLoaded, state == .free { state = productLoadState }
    }

    func reloadProducts() async {
        guard !isWorking else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        state = .loading
        let productsLoaded = await loadProducts()
        let productLoadState = state
        await refresh(action: "automatic_refresh", userInitiated: false)
        if !productsLoaded, state == .free { state = productLoadState }
    }

    func purchase(_ plan: Plan) async {
        guard !isWorking, state != .purchased else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        guard let product = product(for: plan) else {
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
                    productID: product.id, transactionID: "",
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
        guard !isWorking else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refresh(action: "explicit_restore", userInitiated: true)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    func refresh(action: String = "automatic_refresh", userInitiated: Bool = false) async {
        var verifiedTransactions: [Transaction] = []
        var unverifiedTransactions: [Transaction] = []
        let now = Date()

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction) where Self.recognizedProductIDs.contains(transaction.productID):
                let expired = transaction.expirationDate.map { $0 <= now } ?? false
                guard transaction.revocationDate == nil, !transaction.isUpgraded, !expired else { continue }
                verifiedTransactions.append(transaction)
            case .unverified(let transaction, _) where Self.recognizedProductIDs.contains(transaction.productID):
                unverifiedTransactions.append(transaction)
            default:
                continue
            }
        }

        if let transaction = preferredTransaction(in: verifiedTransactions) {
            await consumeVerified(transaction, action: action, userInitiated: userInitiated)
            return
        }

        if let transaction = preferredTransaction(in: unverifiedTransactions) {
            state = .free
            onStoreEvent?(event(
                action: action, userInitiated: userInitiated, purchaseState: "unverified",
                productID: transaction.productID, transactionID: String(transaction.id),
                nativeID: nativeIdentity(transaction), eventDate: now, expirationDate: transaction.expirationDate
            ))
            return
        }

        state = .free
        onStoreEvent?(event(
            action: action, userInitiated: userInitiated, purchaseState: "not_purchased",
            productID: Self.monthlyProductID, transactionID: "",
            nativeID: "storekit2:none:\(Int(now.timeIntervalSince1970))", eventDate: now
        ))
    }

    @discardableResult
    private func loadProducts() async -> Bool {
        #if DEBUG || PRESSBENCH_UI_TESTING
        if ProcessInfo.processInfo.arguments.contains("--pressbench-ui-test-product-unavailable") {
            products = []
            state = .unavailable
            return false
        }
        #endif
        do {
            let loaded = try await Product.products(for: Plan.allCases.map(\.rawValue))
                .filter { $0.type == .autoRenewable }
            products = Plan.allCases.compactMap { plan in loaded.first { $0.id == plan.rawValue } }
            guard !products.isEmpty else {
                state = .unavailable
                return false
            }
            return true
        } catch {
            products = []
            state = .failed(String(describing: error))
            return false
        }
    }

    private func preferredTransaction(in transactions: [Transaction]) -> Transaction? {
        transactions.max { left, right in
            return (left.expirationDate ?? left.purchaseDate) < (right.expirationDate ?? right.purchaseDate)
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
            "productType": "auto_renewable_subscription",
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
