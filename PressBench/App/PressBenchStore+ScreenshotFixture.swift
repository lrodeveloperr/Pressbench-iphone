#if PRESSBENCH_UI_TESTING
import Foundation

@MainActor
extension PressBenchStore {
    /// Loads deterministic, non-production data only for App Store screenshot capture.
    func loadScreenshotFixture() throws {
        guard let url = Bundle.main.url(forResource: "PressBenchScreenshotFixture", withExtension: "json") else {
            throw StoreError.exportFailed
        }
        let raw = try String(contentsOf: url, encoding: .utf8)
        try restoreBackup(raw: raw)
        selectedTab = 0
    }
}
#endif
