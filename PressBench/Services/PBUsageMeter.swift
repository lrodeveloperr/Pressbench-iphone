import Foundation
import Security

struct PBUsageSnapshot: Codable, Equatable {
    var completedPresses: Int
    var creditedBatchIDs: Set<String>
}

protocol PBUsagePersisting {
    func load() throws -> PBUsageSnapshot?
    func save(_ snapshot: PBUsageSnapshot) throws
}

/// The production usage ledger survives ordinary app deletion and reinstall on
/// the same device. It is deliberately device-only: a user-owned backup carries
/// the monotonic count to a replacement device without exporting Keychain data.
struct PBKeychainUsageStore: PBUsagePersisting {
    private let service: String
    private let account = "free-press-usage-v2"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.goodusestudios.pressbench") {
        self.service = service
    }

    func load() throws -> PBUsageSnapshot? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw UsagePersistenceError.keychain(status)
        }
        return try JSONDecoder().decode(PBUsageSnapshot.self, from: data)
    }

    func save(_ snapshot: PBUsageSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = baseQuery
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw UsagePersistenceError.keychain(insertStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw UsagePersistenceError.keychain(updateStatus)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// A monotonic count of successfully committed press runs. Deleting data,
/// restoring an older backup, retrying a commit, or reinstalling the app must
/// never create another free use.
final class PBUsageMeter {
    static let freePressLimit = 10

    private static let completedKey = "pressbench.usage.v2.completedPresses"
    private static let creditedBatchIDsKey = "pressbench.usage.v2.creditedBatchIDs"

    private let defaults: UserDefaults
    private let secureStore: (any PBUsagePersisting)?
    private var secureSnapshot: PBUsageSnapshot?
    private(set) var persistenceHealthy = true

    init(defaults: UserDefaults = .standard, secureStore: (any PBUsagePersisting)? = nil) {
        self.defaults = defaults
        self.secureStore = secureStore

        guard let secureStore else { return }
        do {
            secureSnapshot = try secureStore.load()
            let normalized = mergedSnapshot(extraBatchIDs: [])
            try secureStore.save(normalized)
            secureSnapshot = normalized
            writeLocalCopy(normalized)
        } catch {
            persistenceHealthy = false
        }
    }

    var completedPresses: Int {
        currentCreditedIDs.count
    }

    var creditedFreeBatchIDs: Set<String> { currentCreditedIDs }

    var freePressesRemaining: Int {
        max(0, Self.freePressLimit - completedPresses)
    }

    func reconcile(qualifyingCompletedBatchIDs: Set<String>) {
        retrySecurePersistenceIfNeeded()
        let revised = mergedSnapshot(extraBatchIDs: qualifyingCompletedBatchIDs)
        guard revised.completedPresses > completedPresses || revised.creditedBatchIDs != currentCreditedIDs else { return }
        persist(revised)
    }

    func canStartFreePress(qualifyingCompletedBatchIDs: Set<String>) -> Bool {
        retrySecurePersistenceIfNeeded()
        reconcile(qualifyingCompletedBatchIDs: qualifyingCompletedBatchIDs)
        return persistenceHealthy && completedPresses < Self.freePressLimit
    }

    func recordCompletedPress(batchID rawBatchID: String, authorizationBasis: String, recordedProduction: Bool) {
        let batchID = rawBatchID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard authorizationBasis == "free", recordedProduction,
              !batchID.isEmpty, batchID.utf8.count <= 128,
              completedPresses < Self.freePressLimit else { return }
        var creditedIDs = currentCreditedIDs
        guard creditedIDs.insert(batchID).inserted else { return }
        let revised = PBUsageSnapshot(
            completedPresses: min(Self.freePressLimit, creditedIDs.count),
            creditedBatchIDs: Set(creditedIDs.sorted().prefix(Self.freePressLimit))
        )
        persist(revised)
    }

    private var currentCreditedIDs: Set<String> {
        var result = Set(defaults.stringArray(forKey: Self.creditedBatchIDsKey) ?? [])
        result.formUnion(secureSnapshot?.creditedBatchIDs ?? [])
        return normalizedIDs(result)
    }

    private func mergedSnapshot(extraBatchIDs: Set<String>) -> PBUsageSnapshot {
        var ids = currentCreditedIDs
        ids.formUnion(normalizedIDs(extraBatchIDs))
        ids = normalizedIDs(ids)
        return PBUsageSnapshot(
            completedPresses: ids.count,
            creditedBatchIDs: ids
        )
    }

    private func normalizedIDs(_ ids: Set<String>) -> Set<String> {
        let valid = ids.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.utf8.count <= 128 }
        return Set(valid.sorted().prefix(Self.freePressLimit))
    }

    private func persist(_ snapshot: PBUsageSnapshot) {
        do {
            if let secureStore { try secureStore.save(snapshot) }
            secureSnapshot = snapshot
            writeLocalCopy(snapshot)
        } catch {
            // A free action must never be granted when the durable ledger cannot
            // be trusted. The successfully committed run remains local, while
            // subsequent starts fail closed until persistence is healthy again.
            persistenceHealthy = false
            let fallback = PBUsageSnapshot(
                completedPresses: max(completedPresses, snapshot.completedPresses),
                creditedBatchIDs: snapshot.creditedBatchIDs
            )
            secureSnapshot = fallback
            writeLocalCopy(fallback)
        }
    }

    private func retrySecurePersistenceIfNeeded() {
        guard !persistenceHealthy, let secureStore else { return }
        do {
            let revised = mergedSnapshot(extraBatchIDs: currentCreditedIDs)
            try secureStore.save(revised)
            secureSnapshot = revised
            writeLocalCopy(revised)
            persistenceHealthy = true
        } catch {
            persistenceHealthy = false
        }
    }

    private func writeLocalCopy(_ snapshot: PBUsageSnapshot) {
        defaults.set(snapshot.completedPresses, forKey: Self.completedKey)
        defaults.set(snapshot.creditedBatchIDs.sorted(), forKey: Self.creditedBatchIDsKey)
    }
}

private enum UsagePersistenceError: Error {
    case keychain(OSStatus)
}
