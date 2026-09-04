import Foundation
import XCTest
@testable import PressBench

final class AppleBackupServiceTests: XCTestCase {
    func testAppleCredentialStateControlsPersistedSignInState() {
        XCTAssertFalse(AppleBackupService.shouldClearSavedUser(for: .authorized))
        XCTAssertTrue(AppleBackupService.shouldClearSavedUser(for: .revoked))
        XCTAssertTrue(AppleBackupService.shouldClearSavedUser(for: .notFound))
        XCTAssertTrue(AppleBackupService.shouldClearSavedUser(for: .transferred))
    }

    func testBackupSynchronizesAndWritesVersionedCompressedEnvelope() throws {
        let store = BackupKeyValueStoreSpy()

        try AppleBackupService.backup(payload: ["setups": []], owner: "review-user", to: store)

        XCTAssertEqual(store.setKeys, ["pressbench.backup.v1"])
        let data = try XCTUnwrap(store.values["pressbench.backup.v1"])
        let envelope = try AppleBackupService.decodeStoredEnvelope(data)
        XCTAssertEqual(envelope["owner"] as? String, "review-user")
        XCTAssertEqual(envelope["version"] as? Int, 2)
        XCTAssertEqual(envelope["revision"] as? Int, 1)
        XCTAssertGreaterThanOrEqual(store.synchronizeCalls, 1)
    }

    func testStaleDeviceCannotOverwriteNewerCloudRevision() throws {
        let store = BackupKeyValueStoreSpy()
        let first = try AppleBackupService.backup(payload: ["setups": []], owner: "review-user", to: store)

        XCTAssertThrowsError(
            try AppleBackupService.backup(payload: ["setups": []], owner: "review-user", to: store)
        ) { error in
            XCTAssertEqual((error as? AppleBackupService.BackupError)?.errorDescription,
                           "apple_backup_conflict")
        }

        let second = try AppleBackupService.backup(
            payload: ["setups": []], owner: "review-user", to: store, expected: first
        )
        XCTAssertEqual(second.backupID, first.backupID)
        XCTAssertEqual(second.revision, 2)
    }

    func testStructuredLargeBackupIsCompressedBelowKVSWriteLimit() throws {
        let store = BackupKeyValueStoreSpy()
        let repeatedRows = (0..<1_000).map { ["id": "setup-\($0)", "notes": String(repeating: "press-data-", count: 600)] }

        _ = try AppleBackupService.backup(payload: ["setups": repeatedRows], owner: "review-user", to: store)

        let stored = try XCTUnwrap(store.values["pressbench.backup.v1"])
        XCTAssertLessThanOrEqual(stored.count, 900_000)
        let envelope = try AppleBackupService.decodeStoredEnvelope(stored)
        XCTAssertEqual(((envelope["payload"] as? [String: Any])?["setups"] as? [Any])?.count, 1_000)
    }

    func testBackupFailsWhenLocalWriteCannotBeReadBack() {
        let store = BackupKeyValueStoreSpy()
        store.discardSetValues = true

        XCTAssertThrowsError(
            try AppleBackupService.backup(payload: ["setups": []], owner: "review-user", to: store)
        ) { error in
            XCTAssertEqual((error as? AppleBackupService.BackupError)?.errorDescription,
                           "apple_backup_unavailable")
        }
    }

    func testDeleteBackupRemovesOnlyPressBenchBackup() throws {
        let store = BackupKeyValueStoreSpy()
        store.values["pressbench.backup.v1"] = Data("backup".utf8)
        store.values["unrelated.key"] = Data("keep".utf8)

        try AppleBackupService.deleteBackup(from: store)

        XCTAssertEqual(store.removedKeys, ["pressbench.backup.v1"])
        XCTAssertNil(store.values["pressbench.backup.v1"])
        XCTAssertEqual(store.values["unrelated.key"], Data("keep".utf8))
    }

    func testDeleteBackupFailsWhenBackupRemainsAfterRemoval() {
        let store = BackupKeyValueStoreSpy()
        store.values["pressbench.backup.v1"] = Data("backup".utf8)
        store.retainRemovedValues = true

        XCTAssertThrowsError(try AppleBackupService.deleteBackup(from: store)) { error in
            XCTAssertEqual((error as? AppleBackupService.BackupError)?.errorDescription,
                           "apple_backup_unavailable")
        }
    }
}

private final class BackupKeyValueStoreSpy: AppleBackupKeyValueStoring {
    var values: [String: Data] = [:]
    var setKeys: [String] = []
    var removedKeys: [String] = []
    var discardSetValues = false
    var retainRemovedValues = false
    var synchronizeCalls = 0

    func data(forKey defaultName: String) -> Data? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        setKeys.append(defaultName)
        if !discardSetValues, let data = value as? Data {
            values[defaultName] = data
        }
    }

    func removeObject(forKey defaultName: String) {
        removedKeys.append(defaultName)
        if !retainRemovedValues {
            values.removeValue(forKey: defaultName)
        }
    }

    func synchronize() -> Bool {
        synchronizeCalls += 1
        return true
    }

}
