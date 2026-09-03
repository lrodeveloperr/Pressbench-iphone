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
    private let account = "free-press-usage-v1"

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

    #if PRESSBENCH_UI_TESTING
    /// Test-build-only cleanup. This symbol is absent from App Store archives.
    func removeForUITesting() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw UsagePersistenceError.keychain(status)
        }
    }
    #endif

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
    static let freePressLimit = 5

    private static let completedKey = "pressbench.usage.completedPresses"
    private static let lastCreditedBatchKey = "pressbench.usage.lastCreditedBatchID"
    private static let creditedBatchIDsKey = "pressbench.usage.creditedBatchIDs"

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
            let migrated = mergedSnapshot(extraCount: 0)
            try secureStore.save(migrated)
            secureSnapshot = migrated
            writeCompatibilityCopy(migrated)
        } catch {
            persistenceHealthy = false
        }
    }

    var completedPresses: Int {
        min(
            Self.freePressLimit,
            max(0, max(defaults.integer(forKey: Self.completedKey), secureSnapshot?.completedPresses ?? 0))
        )
    }

    var freePressesRemaining: Int {
        max(0, Self.freePressLimit - completedPresses)
    }

    func reconcile(existingCompletedRuns: Int) {
        retrySecurePersistenceIfNeeded()
        let revised = mergedSnapshot(extraCount: existingCompletedRuns)
        guard revised.completedPresses > completedPresses || revised.creditedBatchIDs != currentCreditedIDs else { return }
        persist(revised)
    }

    func canStartFreePress(existingCompletedRuns: Int) -> Bool {
        retrySecurePersistenceIfNeeded()
        reconcile(existingCompletedRuns: existingCompletedRuns)
        return persistenceHealthy && completedPresses < Self.freePressLimit
    }

    func recordCompletedPress(batchID rawBatchID: String) {
        let batchID = rawBatchID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !batchID.isEmpty, batchID.utf8.count <= 128, completedPresses < Self.freePressLimit else { return }
        var creditedIDs = currentCreditedIDs
        guard creditedIDs.insert(batchID).inserted else { return }
        let revised = PBUsageSnapshot(
            completedPresses: min(Self.freePressLimit, max(completedPresses + 1, creditedIDs.count)),
            creditedBatchIDs: Set(creditedIDs.sorted().prefix(Self.freePressLimit))
        )
        persist(revised)
    }

    private var currentCreditedIDs: Set<String> {
        var result = Set(defaults.stringArray(forKey: Self.creditedBatchIDsKey) ?? [])
        result.formUnion(secureSnapshot?.creditedBatchIDs ?? [])
        if let legacyID = defaults.string(forKey: Self.lastCreditedBatchKey), !legacyID.isEmpty {
            result.insert(legacyID)
        }
        return Set(result.sorted().prefix(Self.freePressLimit))
    }

    private func mergedSnapshot(extraCount: Int) -> PBUsageSnapshot {
        var ids = currentCreditedIDs
        let count = min(Self.freePressLimit, max(0, max(completedPresses, extraCount)))
        var placeholder = 0
        while ids.count < count {
            placeholder += 1
            ids.insert("legacy-count-\(placeholder)")
        }
        return PBUsageSnapshot(
            completedPresses: max(count, min(Self.freePressLimit, ids.count)),
            creditedBatchIDs: Set(ids.sorted().prefix(Self.freePressLimit))
        )
    }

    private func persist(_ snapshot: PBUsageSnapshot) {
        do {
            if let secureStore { try secureStore.save(snapshot) }
            secureSnapshot = snapshot
            writeCompatibilityCopy(snapshot)
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
            writeCompatibilityCopy(fallback)
        }
    }

    private func retrySecurePersistenceIfNeeded() {
        guard !persistenceHealthy, let secureStore else { return }
        do {
            let revised = mergedSnapshot(extraCount: completedPresses)
            try secureStore.save(revised)
            secureSnapshot = revised
            writeCompatibilityCopy(revised)
            persistenceHealthy = true
        } catch {
            persistenceHealthy = false
        }
    }

    private func writeCompatibilityCopy(_ snapshot: PBUsageSnapshot) {
        defaults.set(snapshot.completedPresses, forKey: Self.completedKey)
        defaults.set(snapshot.creditedBatchIDs.sorted(), forKey: Self.creditedBatchIDsKey)
        defaults.set(snapshot.creditedBatchIDs.sorted().last, forKey: Self.lastCreditedBatchKey)
    }
}

private enum UsagePersistenceError: Error {
    case keychain(OSStatus)
}
