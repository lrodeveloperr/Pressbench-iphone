import AuthenticationServices
import Foundation
import OSLog

protocol AppleBackupKeyValueStoring: AnyObject {
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension NSUbiquitousKeyValueStore: AppleBackupKeyValueStoring {}

enum AppleBackupService {
    private static let userDefaultsKey = "pressbench.apple.user.id"
    private static let backupKey = "pressbench.backup.v1"
    private static let lastSuccessAtKey = "pressbench.backup.lastSuccessAt"
    private static let lastSuccessOwnerKey = "pressbench.backup.lastSuccessOwner"
    private static let maximumBytes = 900_000
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.goodusestudios.pressbench",
        category: "AppleBackup"
    )

    static var isSignedIn: Bool {
        !(UserDefaults.standard.string(forKey: userDefaultsKey) ?? "").isEmpty
    }

    static func saveSignedInUser(_ user: String) {
        if UserDefaults.standard.string(forKey: userDefaultsKey) != user { clearSuccessRecord() }
        UserDefaults.standard.set(user, forKey: userDefaultsKey)
    }

    static func signOut() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        clearSuccessRecord()
    }

    /// Reconciles the persisted UI state with Apple's current credential state.
    /// A transient lookup error keeps the local state unchanged; only definitive
    /// revoked, missing, or transferred states sign the backup session out.
    @MainActor
    static func refreshCredentialState() async {
        guard let user = UserDefaults.standard.string(forKey: userDefaultsKey), !user.isEmpty else { return }
        let result: Result<ASAuthorizationAppleIDProvider.CredentialState, Error> = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: user) { state, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(state))
                }
            }
        }
        switch result {
        case .success(let state):
            if shouldClearSavedUser(for: state) { signOut() }
        case .failure(let error):
            logAuthorizationFailure(error, operation: "credential-state")
        }
    }

    static func shouldClearSavedUser(
        for state: ASAuthorizationAppleIDProvider.CredentialState
    ) -> Bool {
        switch state {
        case .authorized:
            return false
        case .revoked, .notFound, .transferred:
            return true
        @unknown default:
            return false
        }
    }

    static func logAuthorizationFailure(_ error: Error, operation: String) {
        let nsError = error as NSError
        logger.error(
            "Apple authorization failed operation=\(operation, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }

    static func backup(payload: [String: Any]) throws {
        guard isSignedIn else { throw BackupError.notSignedIn }
        guard FileManager.default.ubiquityIdentityToken != nil else { throw BackupError.unavailable }
        try backup(
            payload: payload,
            owner: UserDefaults.standard.string(forKey: userDefaultsKey) ?? "",
            to: NSUbiquitousKeyValueStore.default
        )
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSuccessAtKey)
        UserDefaults.standard.set(
            UserDefaults.standard.string(forKey: userDefaultsKey) ?? "",
            forKey: lastSuccessOwnerKey
        )
    }

    /// Writes to the local iCloud key-value store without forcing a synchronous
    /// network round trip. The system propagates KVS changes automatically.
    static func backup(
        payload: [String: Any],
        owner: String,
        to store: AppleBackupKeyValueStoring
    ) throws {
        guard !owner.isEmpty else { throw BackupError.notSignedIn }
        let envelope: [String: Any] = [
            "version": 1,
            "owner": owner,
            "savedAt": Date().ISO8601Format(.iso8601(timeZone: .gmt, includingFractionalSeconds: true)),
            "payload": payload
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        guard data.count <= maximumBytes else { throw BackupError.tooLarge }
        store.set(data, forKey: backupKey)
        guard store.data(forKey: backupKey) == data else { throw BackupError.unavailable }
    }

    private static func clearSuccessRecord() {
        UserDefaults.standard.removeObject(forKey: lastSuccessAtKey)
        UserDefaults.standard.removeObject(forKey: lastSuccessOwnerKey)
    }

    static func restoredPayload() throws -> String {
        guard isSignedIn else { throw BackupError.notSignedIn }
        guard FileManager.default.ubiquityIdentityToken != nil else { throw BackupError.unavailable }
        let store = NSUbiquitousKeyValueStore.default
        guard let data = store.data(forKey: backupKey) else { throw BackupError.missing }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard object?["owner"] as? String == UserDefaults.standard.string(forKey: userDefaultsKey) else {
            throw BackupError.invalid
        }
        guard let payload = object?["payload"] as? [String: Any] else { throw BackupError.invalid }
        let raw = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        guard let text = String(data: raw, encoding: .utf8) else { throw BackupError.invalid }
        return text
    }

    static func deleteBackup() throws {
        guard isSignedIn else { throw BackupError.notSignedIn }
        guard FileManager.default.ubiquityIdentityToken != nil else { throw BackupError.unavailable }
        try deleteBackup(from: NSUbiquitousKeyValueStore.default)
        clearSuccessRecord()
    }

    /// Removes only the private iCloud backup. Local PressBench records and the
    /// Sign in with Apple session are deliberately outside this operation.
    static func deleteBackup(from store: AppleBackupKeyValueStoring) throws {
        store.removeObject(forKey: backupKey)
        guard store.data(forKey: backupKey) == nil else {
            throw BackupError.unavailable
        }
    }

    enum BackupError: LocalizedError {
        case notSignedIn, tooLarge, unavailable, missing, invalid
        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "apple_backup_not_signed_in"
            case .tooLarge: return "apple_backup_too_large"
            case .unavailable: return "apple_backup_unavailable"
            case .missing: return "apple_backup_missing"
            case .invalid: return "apple_backup_invalid"
            }
        }
    }
}
