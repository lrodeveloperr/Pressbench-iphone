import Foundation

/// A monotonic, device-local count of successfully saved press runs.
/// Deleting a run or clearing operational data must not create another free use.
struct PBUsageMeter {
    static let freePressLimit = 5

    private static let completedKey = "pressbench.usage.completedPresses"
    private static let lastCreditedBatchKey = "pressbench.usage.lastCreditedBatchID"
    private static let creditedBatchIDsKey = "pressbench.usage.creditedBatchIDs"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var completedPresses: Int {
        min(Self.freePressLimit, max(0, defaults.integer(forKey: Self.completedKey)))
    }

    var freePressesRemaining: Int {
        max(0, Self.freePressLimit - completedPresses)
    }

    func reconcile(existingCompletedRuns: Int) {
        let safeExistingCount = max(0, existingCompletedRuns)
        guard safeExistingCount > completedPresses else { return }
        defaults.set(safeExistingCount, forKey: Self.completedKey)
    }

    func canStartFreePress(existingCompletedRuns: Int) -> Bool {
        reconcile(existingCompletedRuns: existingCompletedRuns)
        return completedPresses < Self.freePressLimit
    }

    func recordCompletedPress(batchID: String) {
        guard !batchID.isEmpty, completedPresses < Self.freePressLimit else { return }
        var creditedIDs = Set(defaults.stringArray(forKey: Self.creditedBatchIDsKey) ?? [])
        if let legacyID = defaults.string(forKey: Self.lastCreditedBatchKey), !legacyID.isEmpty {
            creditedIDs.insert(legacyID)
        }
        guard creditedIDs.insert(batchID).inserted else { return }
        defaults.set(min(Self.freePressLimit, completedPresses + 1), forKey: Self.completedKey)
        defaults.set(Array(creditedIDs.sorted().prefix(Self.freePressLimit)), forKey: Self.creditedBatchIDsKey)
        defaults.set(batchID, forKey: Self.lastCreditedBatchKey)
    }
}
