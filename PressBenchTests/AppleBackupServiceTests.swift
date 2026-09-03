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

    func testBackupWritesLocallyWithoutForcingCloudSynchronization() throws {
        let store = BackupKeyValueStoreSpy()

        try AppleBackupService.backup(payload: ["setups": []], owner: "review-user", to: store)

        XCTAssertEqual(store.setKeys, ["pressbench.backup.v1"])
        let data = try XCTUnwrap(store.values["pressbench.backup.v1"])
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(envelope["owner"] as? String, "review-user")
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

}
