import Foundation
import XCTest
@testable import PressBench

final class AppleBackupServiceTests: XCTestCase {
    func testDeleteBackupRemovesOnlyPressBenchBackupAndSynchronizes() throws {
        let store = BackupKeyValueStoreSpy()
        store.values["pressbench.backup.v1"] = Data("backup".utf8)
        store.values["unrelated.key"] = Data("keep".utf8)

        try AppleBackupService.deleteBackup(from: store)

        XCTAssertEqual(store.removedKeys, ["pressbench.backup.v1"])
        XCTAssertEqual(store.synchronizeCallCount, 1)
        XCTAssertNil(store.values["pressbench.backup.v1"])
        XCTAssertEqual(store.values["unrelated.key"], Data("keep".utf8))
    }

    func testDeleteBackupFailsWhenICloudCannotConfirmSynchronization() {
        let store = BackupKeyValueStoreSpy()
        store.synchronizeResult = false

        XCTAssertThrowsError(try AppleBackupService.deleteBackup(from: store)) { error in
            XCTAssertEqual((error as? AppleBackupService.BackupError)?.errorDescription,
                           "apple_backup_unavailable")
        }
    }

    func testDeleteBackupFailsWhenBackupRemainsAfterSynchronization() {
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
    var removedKeys: [String] = []
    var synchronizeResult = true
    var synchronizeCallCount = 0
    var retainRemovedValues = false

    func data(forKey defaultName: String) -> Data? {
        values[defaultName]
    }

    func removeObject(forKey defaultName: String) {
        removedKeys.append(defaultName)
        if !retainRemovedValues {
            values.removeValue(forKey: defaultName)
        }
    }

    func synchronize() -> Bool {
        synchronizeCallCount += 1
        return synchronizeResult
    }
}
