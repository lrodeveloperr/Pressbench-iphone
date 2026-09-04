import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let pressBenchBackup = UTType(
        exportedAs: "com.goodusestudios.pressbench.backup",
        conformingTo: .json
    )
}

/// A user-owned PressBench backup that can be saved to any Files provider,
/// including iCloud Drive and On My iPhone. The document keeps backup storage
/// independent from app authentication and from PressBench's local database.
struct PressBenchBackupDocument: FileDocument {
    static let maximumBytes = 10_000_000
    static var readableContentTypes: [UTType] { [.pressBenchBackup] }

    let data: Data

    init(payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try Self.validateTopLevel(data)
        self.data = data
    }

    init(data: Data) throws {
        try Self.validateTopLevel(data)
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BackupDocumentError.unreadable
        }
        try self.init(data: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    func rawPayload() throws -> String {
        guard let raw = String(data: data, encoding: .utf8) else {
            throw BackupDocumentError.unreadable
        }
        return raw
    }

    static func defaultFilename(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "PressBench-Backup-\(formatter.string(from: date))"
    }

    private static func validateTopLevel(_ data: Data) throws {
        guard !data.isEmpty,
              data.count <= maximumBytes,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["schema"] as? String == "press-bench-log",
              let schemaVersion = (object["schemaVersion"] as? NSNumber)?.intValue,
              (1...4).contains(schemaVersion),
              (object["appId"] == nil || object["appId"] as? String == "APP-018")
        else {
            throw BackupDocumentError.invalid
        }
    }

    enum BackupDocumentError: LocalizedError {
        case unreadable, invalid

        var errorDescription: String? {
            switch self {
            case .unreadable: return "backup_file_unreadable"
            case .invalid: return "backup_file_invalid"
            }
        }
    }
}
