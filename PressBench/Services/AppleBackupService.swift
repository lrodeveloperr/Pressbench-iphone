import Foundation

protocol AppleBackupKeyValueStoring: AnyObject {
    func data(forKey defaultName: String) -> Data?
    func removeObject(forKey defaultName: String)
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: AppleBackupKeyValueStoring {}

enum AppleBackupService {
    private static let userDefaultsKey = "pressbench.apple.user.id"
    private static let backupKey = "pressbench.backup.v1"
    private static let lastSuccessAtKey = "pressbench.backup.lastSuccessAt"
    private static let lastSuccessOwnerKey = "pressbench.backup.lastSuccessOwner"
    private static let maximumBytes = 900_000

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

    static func backup(payload: [String: Any]) throws {
        guard isSignedIn else { throw BackupError.notSignedIn }
        let envelope: [String: Any] = [
            "version": 1,
            "owner": UserDefaults.standard.string(forKey: userDefaultsKey) ?? "",
            "savedAt": Date().ISO8601Format(.iso8601(timeZone: .gmt, includingFractionalSeconds: true)),
            "payload": payload
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        guard data.count <= maximumBytes else { throw BackupError.tooLarge }
        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: backupKey)
        guard store.synchronize() else { throw BackupError.unavailable }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSuccessAtKey)
        UserDefaults.standard.set(envelope["owner"] as? String ?? "", forKey: lastSuccessOwnerKey)
    }

    private static func clearSuccessRecord() {
        UserDefaults.standard.removeObject(forKey: lastSuccessAtKey)
        UserDefaults.standard.removeObject(forKey: lastSuccessOwnerKey)
    }

    static func restoredPayload() throws -> String {
        guard isSignedIn else { throw BackupError.notSignedIn }
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
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
        try deleteBackup(from: NSUbiquitousKeyValueStore.default)
        clearSuccessRecord()
    }

    /// Removes only the private iCloud backup. Local PressBench records and the
    /// Sign in with Apple session are deliberately outside this operation.
    static func deleteBackup(from store: AppleBackupKeyValueStoring) throws {
        store.removeObject(forKey: backupKey)
        guard store.synchronize(), store.data(forKey: backupKey) == nil else {
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
