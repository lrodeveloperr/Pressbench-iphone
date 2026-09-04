import AuthenticationServices
import Foundation
import OSLog

protocol AppleBackupKeyValueStoring: AnyObject {
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: AppleBackupKeyValueStoring {}

enum AppleBackupService {
    private static let userDefaultsKey = "pressbench.apple.user.id"
    private static let backupKey = "pressbench.backup.v1"
    private static let lastSuccessAtKey = "pressbench.backup.lastSuccessAt"
    private static let lastSuccessOwnerKey = "pressbench.backup.lastSuccessOwner"
    private static let observedBackupIDKey = "pressbench.backup.observedCloudID"
    private static let observedRevisionKey = "pressbench.backup.observedCloudRevision"
    private static let maximumBytes = 900_000
    private static let compressedHeader = Data("PBZ2".utf8)
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.goodusestudios.pressbench",
        category: "AppleBackup"
    )
    private static var externalChangeObserver: NSObjectProtocol?

    struct CloudVersion: Equatable {
        let backupID: String
        let revision: Int
    }

    static var isSignedIn: Bool {
        !(UserDefaults.standard.string(forKey: userDefaultsKey) ?? "").isEmpty
    }

    static func saveSignedInUser(_ user: String) {
        if UserDefaults.standard.string(forKey: userDefaultsKey) != user {
            clearSuccessRecord()
            clearObservedVersion()
        }
        UserDefaults.standard.set(user, forKey: userDefaultsKey)
    }

    static func signOut() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        clearSuccessRecord()
        clearObservedVersion()
    }

    @MainActor
    static func startMonitoring() {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        guard externalChangeObserver == nil else { return }
        externalChangeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { notification in
            guard let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { return }
            logger.notice("iCloud KVS changed externally reason=\(reason, privacy: .public)")
            let owner = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
            guard !owner.isEmpty else { clearSuccessRecord(); return }
            let confirmed: CloudVersion?
            do {
                confirmed = try cloudVersion(data: store.data(forKey: backupKey), owner: owner)
            } catch {
                clearSuccessRecord()
                return
            }
            if let confirmed, confirmed == observedVersion() {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSuccessAtKey)
                UserDefaults.standard.set(owner, forKey: lastSuccessOwnerKey)
            } else {
                clearSuccessRecord()
            }
        }
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

    static func backup(payload: [String: Any]) async throws {
        guard isSignedIn else { throw BackupError.notSignedIn }
        guard FileManager.default.ubiquityIdentityToken != nil else { throw BackupError.unavailable }
        let owner = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        let version = try backup(
            payload: payload,
            owner: owner,
            to: store,
            expected: observedVersion()
        )
        saveObservedVersion(version)
    }

    /// Writes a versioned payload to the local iCloud KVS cache. The system
    /// propagates that cache automatically; external notifications confirm it.
    @discardableResult
    static func backup(
        payload: [String: Any],
        owner: String,
        to store: AppleBackupKeyValueStoring,
        expected: CloudVersion? = nil
    ) throws -> CloudVersion {
        guard !owner.isEmpty else { throw BackupError.notSignedIn }
        store.synchronize()
        let current = try cloudVersion(data: store.data(forKey: backupKey), owner: owner)
        if let current, current != expected { throw BackupError.conflict }
        let version = CloudVersion(
            backupID: current?.backupID == "legacy-v1" ? UUID().uuidString : current?.backupID ?? UUID().uuidString,
            revision: (current?.revision ?? 0) + 1
        )
        let envelope: [String: Any] = [
            "version": 2,
            "owner": owner,
            "backupID": version.backupID,
            "revision": version.revision,
            "savedAt": Date().ISO8601Format(.iso8601(timeZone: .gmt, includingFractionalSeconds: true)),
            "payload": payload
        ]
        let envelopeData = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        let storedData = try encodeForCloud(envelopeData)
        guard storedData.count <= maximumBytes else { throw BackupError.tooLarge }
        store.set(storedData, forKey: backupKey)
        guard store.data(forKey: backupKey) == storedData else { throw BackupError.unavailable }
        return version
    }

    private static func clearSuccessRecord() {
        UserDefaults.standard.removeObject(forKey: lastSuccessAtKey)
        UserDefaults.standard.removeObject(forKey: lastSuccessOwnerKey)
    }

    static func restoredPayload() async throws -> String {
        guard isSignedIn else { throw BackupError.notSignedIn }
        guard FileManager.default.ubiquityIdentityToken != nil else { throw BackupError.unavailable }
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        var backupData: Data?
        var lastRead: Data?
        var stableReadCount = 0
        for attempt in 0..<15 {
            let current = store.data(forKey: backupKey)
            if current != nil, current == lastRead {
                stableReadCount += 1
            } else {
                stableReadCount = 0
            }
            backupData = current
            lastRead = current
            // Even when a local cache exists, allow synchronization time for a
            // newer remote revision to arrive before presenting the restore.
            if attempt >= 5, backupData != nil, stableReadCount >= 2 { break }
            if attempt < 14 { try await Task.sleep(for: .milliseconds(200)) }
        }
        guard let data = backupData else { throw BackupError.missing }
        let envelopeData = try decodeFromCloud(data)
        let object = try JSONSerialization.jsonObject(with: envelopeData) as? [String: Any]
        guard object?["owner"] as? String == UserDefaults.standard.string(forKey: userDefaultsKey) else {
            throw BackupError.invalid
        }
        guard let payload = object?["payload"] as? [String: Any] else { throw BackupError.invalid }
        guard let version = try cloudVersion(data: data, owner: UserDefaults.standard.string(forKey: userDefaultsKey) ?? "") else {
            throw BackupError.invalid
        }
        saveObservedVersion(version)
        let raw = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        guard let text = String(data: raw, encoding: .utf8) else { throw BackupError.invalid }
        return text
    }

    static func deleteBackup() throws {
        guard isSignedIn else { throw BackupError.notSignedIn }
        guard FileManager.default.ubiquityIdentityToken != nil else { throw BackupError.unavailable }
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        let owner = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        let current = try cloudVersion(data: store.data(forKey: backupKey), owner: owner)
        guard current == observedVersion() else { throw BackupError.conflict }
        try deleteBackup(from: store)
        clearSuccessRecord()
        clearObservedVersion()
    }

    /// Removes only the private iCloud backup. Local PressBench records and the
    /// Sign in with Apple session are deliberately outside this operation.
    static func deleteBackup(from store: AppleBackupKeyValueStoring) throws {
        store.synchronize()
        store.removeObject(forKey: backupKey)
        guard store.data(forKey: backupKey) == nil else {
            throw BackupError.unavailable
        }
    }

    private static func cloudVersion(data: Data?, owner: String) throws -> CloudVersion? {
        guard let data else { return nil }
        let envelopeData = try decodeFromCloud(data)
        guard let object = try JSONSerialization.jsonObject(with: envelopeData) as? [String: Any],
              object["owner"] as? String == owner else { throw BackupError.invalid }
        let format = object["version"] as? Int ?? 1
        if format == 1 { return CloudVersion(backupID: "legacy-v1", revision: 1) }
        guard format == 2, let backupID = object["backupID"] as? String, !backupID.isEmpty,
              let revision = object["revision"] as? Int, revision > 0 else { throw BackupError.invalid }
        return CloudVersion(backupID: backupID, revision: revision)
    }

    static func decodeStoredEnvelope(_ data: Data) throws -> [String: Any] {
        let decoded = try decodeFromCloud(data)
        guard let object = try JSONSerialization.jsonObject(with: decoded) as? [String: Any] else {
            throw BackupError.invalid
        }
        return object
    }

    private static func encodeForCloud(_ data: Data) throws -> Data {
        let compressed = try (data as NSData).compressed(using: .zlib) as Data
        var result = compressedHeader
        result.append(compressed)
        return result
    }

    private static func decodeFromCloud(_ data: Data) throws -> Data {
        guard data.starts(with: compressedHeader) else { return data }
        let compressed = data.dropFirst(compressedHeader.count)
        do {
            return try (Data(compressed) as NSData).decompressed(using: .zlib) as Data
        } catch {
            throw BackupError.invalid
        }
    }

    private static func observedVersion() -> CloudVersion? {
        guard let backupID = UserDefaults.standard.string(forKey: observedBackupIDKey), !backupID.isEmpty else { return nil }
        let revision = UserDefaults.standard.integer(forKey: observedRevisionKey)
        return revision > 0 ? CloudVersion(backupID: backupID, revision: revision) : nil
    }

    private static func saveObservedVersion(_ version: CloudVersion) {
        UserDefaults.standard.set(version.backupID, forKey: observedBackupIDKey)
        UserDefaults.standard.set(version.revision, forKey: observedRevisionKey)
    }

    private static func clearObservedVersion() {
        UserDefaults.standard.removeObject(forKey: observedBackupIDKey)
        UserDefaults.standard.removeObject(forKey: observedRevisionKey)
    }

    enum BackupError: LocalizedError {
        case notSignedIn, tooLarge, unavailable, missing, invalid, conflict
        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "apple_backup_not_signed_in"
            case .tooLarge: return "apple_backup_too_large"
            case .unavailable: return "apple_backup_unavailable"
            case .missing: return "apple_backup_missing"
            case .invalid: return "apple_backup_invalid"
            case .conflict: return "apple_backup_conflict"
            }
        }
    }
}
