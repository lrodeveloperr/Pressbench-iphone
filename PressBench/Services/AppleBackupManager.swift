import AuthenticationServices
import Combine
import Foundation
import Security

enum AppleBackupError: Error {
    case authorizationFailed
    case iCloudUnavailable
    case backupNotFound
    case invalidBackup

    var localizationKey: String {
        switch self {
        case .authorizationFailed: return "backup.authorizationFailed"
        case .iCloudUnavailable: return "backup.unavailable"
        case .backupNotFound: return "backup.notFound"
        case .invalidBackup: return "error.backupRestore"
        }
    }
}

/// Optional Sign in with Apple authorization plus private iCloud Drive backup.
/// PressBench never sends the credential or backup to a GoodUse Studios server.
@MainActor
final class AppleBackupManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isCheckingCredential = true
    @Published private(set) var isWorking = false
    @Published private(set) var lastBackupDate: Date?

    private var generationObservation: AnyCancellable?
    private var pendingAutomaticBackup: Task<Void, Never>?
    private weak var store: PressBenchStore?

    func attach(to store: PressBenchStore) {
        guard self.store !== store else { return }
        self.store = store
        generationObservation = store.$generation
            .dropFirst()
            .sink { [weak self, weak store] _ in
                Task { @MainActor in
                    guard let self, let store else { return }
                    self.scheduleAutomaticBackup(from: store)
                }
            }

        Task {
            await refreshCredentialState()
            if isEnabled { await refreshLastBackupDate() }
        }
    }

    nonisolated func configure(_ request: ASAuthorizationAppleIDRequest) {
        // No name or email is requested. The stable Apple credential identifier is
        // retained only in this device's Keychain so authorization can be checked.
        request.requestedScopes = []
    }

    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            do {
                try AppleBackupCredentialStore.save(credential.user)
                isEnabled = true
                isCheckingCredential = false
                Task { await refreshLastBackupDate() }
            } catch {
                isEnabled = false
            }
        case .failure:
            // Cancellation is intentionally silent; the app remains fully usable.
            break
        }
    }

    func backUpNow() async throws {
        guard isEnabled, let store else { throw AppleBackupError.authorizationFailed }
        let payload = try store.backupPayload()
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

        isWorking = true
        defer { isWorking = false }
        let date = try await ICloudBackupStore.write(data)
        lastBackupDate = date
    }

    func restoreFromICloud() async throws {
        guard isEnabled, let store else { throw AppleBackupError.authorizationFailed }
        isWorking = true
        defer { isWorking = false }

        let data = try await ICloudBackupStore.read()
        guard let raw = String(data: data, encoding: .utf8) else { throw AppleBackupError.invalidBackup }
        do {
            try store.restoreBackup(raw: raw)
        } catch {
            throw AppleBackupError.invalidBackup
        }
        lastBackupDate = try? await ICloudBackupStore.modificationDate()
    }

    func turnOff() {
        pendingAutomaticBackup?.cancel()
        AppleBackupCredentialStore.delete()
        isEnabled = false
        lastBackupDate = nil
    }

    func deleteFromICloud() async throws {
        guard isEnabled else { throw AppleBackupError.authorizationFailed }
        isWorking = true
        defer { isWorking = false }
        try await ICloudBackupStore.delete()
        lastBackupDate = nil
    }

    func refreshCredentialState() async {
        defer { isCheckingCredential = false }
        guard let user = AppleBackupCredentialStore.load() else {
            isEnabled = false
            return
        }

        let state = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: user) { state, _ in
                continuation.resume(returning: state)
            }
        }
        if state == .authorized {
            isEnabled = true
        } else {
            AppleBackupCredentialStore.delete()
            isEnabled = false
        }
    }

    func refreshLastBackupDate() async {
        lastBackupDate = try? await ICloudBackupStore.modificationDate()
    }

    private func scheduleAutomaticBackup(from store: PressBenchStore) {
        guard isEnabled else { return }
        pendingAutomaticBackup?.cancel()
        pendingAutomaticBackup = Task { [weak self, weak store] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self, let store, self.isEnabled else { return }
            do {
                let payload = try store.backupPayload()
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
                let date = try await ICloudBackupStore.write(data)
                guard !Task.isCancelled else { return }
                self.lastBackupDate = date
            } catch {
                // Automatic backup is best-effort. Explicit backup surfaces errors.
            }
        }
    }
}

private enum AppleBackupCredentialStore {
    private static let service = "com.goodusestudios.pressbench.apple-backup"
    private static let account = "apple-user-identifier"

    static func save(_ user: String) throws {
        guard let data = user.data(using: .utf8) else { throw AppleBackupError.authorizationFailed }
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw AppleBackupError.authorizationFailed
        }
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private enum ICloudBackupStore {
    private static let containerIdentifier = "iCloud.com.goodusestudios.pressbench"
    private static let relativePath = "Documents/PressBench/PressBench-Backup.json"

    static func write(_ data: Data) async throws -> Date {
        try await Task.detached(priority: .utility) {
            let url = try backupURL(createDirectory: true)
            try coordinatedWrite(data, to: url)
            return (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        }.value
    }

    static func read() async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let url = try backupURL(createDirectory: false)
            guard FileManager.default.fileExists(atPath: url.path) else { throw AppleBackupError.backupNotFound }
            try requestDownloadIfNeeded(url)
            return try coordinatedRead(from: url)
        }.value
    }

    static func modificationDate() async throws -> Date {
        try await Task.detached(priority: .utility) {
            let url = try backupURL(createDirectory: false)
            guard FileManager.default.fileExists(atPath: url.path) else { throw AppleBackupError.backupNotFound }
            return try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date()
        }.value
    }

    static func delete() async throws {
        try await Task.detached(priority: .utility) {
            let url = try backupURL(createDirectory: false)
            guard FileManager.default.fileExists(atPath: url.path) else { throw AppleBackupError.backupNotFound }
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            var operationError: Error?
            coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { coordinatedURL in
                do { try FileManager.default.removeItem(at: coordinatedURL) }
                catch { operationError = error }
            }
            if let coordinationError { throw coordinationError }
            if let operationError { throw operationError }
        }.value
    }

    private static func backupURL(createDirectory: Bool) throws -> URL {
        guard let root = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            throw AppleBackupError.iCloudUnavailable
        }
        let url = root.appendingPathComponent(relativePath)
        if createDirectory {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        return url
    }

    private static func coordinatedWrite(_ data: Data, to url: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do { try data.write(to: coordinatedURL, options: [.atomic, .completeFileProtection]) }
            catch { operationError = error }
        }
        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
    }

    private static func coordinatedRead(from url: URL) throws -> Data {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?
        var result: Data?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do { result = try Data(contentsOf: coordinatedURL) }
            catch { operationError = error }
        }
        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
        guard let result else { throw AppleBackupError.invalidBackup }
        return result
    }

    private static func requestDownloadIfNeeded(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        guard values.isUbiquitousItem == true,
              values.ubiquitousItemDownloadingStatus != .current else { return }
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        for _ in 0..<100 {
            let status = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
            if status == .current { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
}
