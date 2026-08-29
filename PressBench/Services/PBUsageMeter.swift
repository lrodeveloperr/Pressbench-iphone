import Foundation

/// A monotonic, device-local count of successfully saved press runs.
/// Deleting a run or clearing operational data must not create another free use.
struct PBUsageMeter {
    static let freePressLimit = 5

    private static let completedKey = "pressbench.usage.completedPresses"
    private static let lastCreditedBatchKey = "pressbench.usage.lastCreditedBatchID"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var completedPresses: Int {
        max(0, defaults.integer(forKey: Self.completedKey))
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
        guard !batchID.isEmpty,
              defaults.string(forKey: Self.lastCreditedBatchKey) != batchID else { return }
        defaults.set(completedPresses + 1, forKey: Self.completedKey)
        defaults.set(batchID, forKey: Self.lastCreditedBatchKey)
    }
}
