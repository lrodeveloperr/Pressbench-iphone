import CryptoKit
import Foundation

/// Dual-replica, checksummed persistence for the canonical deterministic state.
/// Purchase entitlement is stored locally but is never included in portable backups.
final class PressBenchPersistence {
    enum PersistenceError: LocalizedError {
        case corrupt
        case replicaConflict

        var errorDescription: String? {
            switch self {
            case .corrupt: return "Saved PressBench data could not be verified."
            case .replicaConflict: return "Saved PressBench replicas disagree. Recovery is required."
            }
        }
    }

    private let primaryURL: URL
    private let replicaURL: URL
    private(set) var revision: Int = 0

    init(baseDirectory: URL? = nil) {
        let root: URL
        if let baseDirectory {
            root = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            root = appSupport.appendingPathComponent("PressBench", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        primaryURL = root.appendingPathComponent("state-v5.json")
        replicaURL = root.appendingPathComponent("state-v5.replica.json")
    }

    func load() throws -> [String: Any]? {
        var candidates = [Candidate]()
        var firstReadError: Error?
        for url in [primaryURL, replicaURL] {
            do {
                if let candidate = try read(url) { candidates.append(candidate) }
            } catch {
                firstReadError = firstReadError ?? error
            }
        }
        guard !candidates.isEmpty else {
            if let firstReadError { throw firstReadError }
            return nil
        }
        let sorted = candidates.sorted { lhs, rhs in
            if lhs.revision != rhs.revision { return lhs.revision > rhs.revision }
            return lhs.savedAt > rhs.savedAt
        }
        if sorted.count > 1, sorted[0].revision == sorted[1].revision,
           sorted[0].checksum != sorted[1].checksum {
            throw PersistenceError.replicaConflict
        }
        revision = sorted[0].revision
        return sorted[0].data
    }

    func save(_ state: [String: Any]) throws {
        let payload = try canonicalData(state)
        let checksum = sha256(payload)
        let envelope: [String: Any] = [
            "format": 3,
            "revision": revision + 1,
            "savedAt": ISO8601DateFormatter().string(from: Date()),
            "checksum": checksum,
            "data": state
        ]
        let bytes = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        let priorPrimary = try existingData(at: primaryURL)
        let priorReplica = try existingData(at: replicaURL)
        do {
            try bytes.write(to: primaryURL, options: [.atomic])
            try bytes.write(to: replicaURL, options: [.atomic])
            revision += 1
        } catch {
            do {
                try restore(priorPrimary, at: primaryURL)
                try restore(priorReplica, at: replicaURL)
            } catch {
                throw PersistenceError.replicaConflict
            }
            throw error
        }
    }

    private func restore(_ data: Data?, at url: URL) throws {
        if let data {
            try data.write(to: url, options: [.atomic])
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func existingData(at url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    private struct Candidate {
        let revision: Int
        let savedAt: Date
        let checksum: String
        let data: [String: Any]
    }

    private func read(_ url: URL) throws -> Candidate? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let raw = try Data(contentsOf: url)
            guard let envelope = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
                  (envelope["format"] as? Int) == 3,
                  let revision = envelope["revision"] as? Int,
                  let savedAtString = envelope["savedAt"] as? String,
                  let savedAt = ISO8601DateFormatter().date(from: savedAtString),
                  let checksum = envelope["checksum"] as? String,
                  let state = envelope["data"] as? [String: Any] else {
                throw PersistenceError.corrupt
            }
            let actual = sha256(try canonicalData(state))
            guard actual == checksum else { throw PersistenceError.corrupt }
            return Candidate(revision: revision, savedAt: savedAt, checksum: checksum, data: state)
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.corrupt
        }
    }

    private func canonicalData(_ value: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
