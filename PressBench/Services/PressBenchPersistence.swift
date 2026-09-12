import CryptoKit
import Foundation

/// Dual-replica, checksummed persistence for the canonical deterministic state.
///
/// Small, frequently changing state is stored in a compact manifest. Completed
/// batches are immutable, content-addressed records, so a timer or preference
/// change never rewrites the customer's entire production history. Version 5
/// monolithic files are read once and migrated on the next successful save.
/// Purchase entitlement remains local and is never included in portable backups.
final class PressBenchPersistence {
    enum PersistenceError: LocalizedError {
        case corrupt
        case replicaConflict
        case revisionExhausted

        var errorDescription: String? {
            switch self {
            case .corrupt: return "Saved PressBench data could not be verified."
            case .replicaConflict: return "Saved PressBench replicas disagree. Recovery is required."
            case .revisionExhausted: return "Saved PressBench data reached its revision limit."
            }
        }
    }

    private struct BatchManifestEntry {
        let id: String
        let fileName: String
        let checksum: String

        var dictionary: [String: Any] {
            ["id": id, "file": fileName, "checksum": checksum]
        }

        init(id: String, fileName: String, checksum: String) {
            self.id = id
            self.fileName = fileName
            self.checksum = checksum
        }

        init?(_ value: [String: Any]) {
            guard let id = value["id"] as? String, !id.isEmpty,
                  let fileName = value["file"] as? String,
                  fileName.range(of: #"^[a-f0-9]{64}\.record\.json$"#, options: .regularExpression) != nil,
                  let checksum = value["checksum"] as? String,
                  Self.isChecksum(checksum) else { return nil }
            self.init(id: id, fileName: fileName, checksum: checksum)
        }

        private static func isChecksum(_ value: String) -> Bool {
            value.count == 64 && value.unicodeScalars.allSatisfy {
                (48...57).contains($0.value) || (97...102).contains($0.value)
            }
        }
    }

    private struct BatchIndexReference {
        let fileName: String
        let checksum: String

        var dictionary: [String: Any] { ["file": fileName, "checksum": checksum] }

        init(fileName: String, checksum: String) {
            self.fileName = fileName
            self.checksum = checksum
        }

        init?(_ value: [String: Any]) {
            guard let fileName = value["file"] as? String,
                  fileName.range(of: #"^[a-f0-9]{64}\.index\.json$"#, options: .regularExpression) != nil,
                  let checksum = value["checksum"] as? String,
                  checksum.count == 64,
                  checksum.unicodeScalars.allSatisfy({
                      (48...57).contains($0.value) || (97...102).contains($0.value)
                  }) else { return nil }
            self.init(fileName: fileName, checksum: checksum)
        }
    }

    private struct Candidate {
        let revision: Int
        let savedAt: Date
        let checksum: String
        let data: [String: Any]
        let batchManifest: [BatchManifestEntry]
        let batchIndex: BatchIndexReference?
        let segmented: Bool
    }

    private let root: URL
    private let primaryURL: URL
    private let replicaURL: URL
    private let primaryBatchDirectory: URL
    private let replicaBatchDirectory: URL
    private let legacyPrimaryURL: URL
    private let legacyReplicaURL: URL
    private var storedBatchManifest = [BatchManifestEntry]()
    private var storedBatchIndex: BatchIndexReference?
    private var hasSegmentedState = false
    private(set) var revision: Int = 0

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            root = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            root = appSupport.appendingPathComponent("PressBench", isDirectory: true)
        }
        primaryURL = root.appendingPathComponent("state-v6.json")
        replicaURL = root.appendingPathComponent("state-v6.replica.json")
        primaryBatchDirectory = root.appendingPathComponent("batches-v6/primary", isDirectory: true)
        replicaBatchDirectory = root.appendingPathComponent("batches-v6/replica", isDirectory: true)
        legacyPrimaryURL = root.appendingPathComponent("state-v5.json")
        legacyReplicaURL = root.appendingPathComponent("state-v5.replica.json")

        try? FileManager.default.createDirectory(at: primaryBatchDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: replicaBatchDirectory, withIntermediateDirectories: true)
        var backupEligibleRoot = root
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try? backupEligibleRoot.setResourceValues(resourceValues)
    }

    func load() throws -> [String: Any]? {
        let segmentedExists = [primaryURL, replicaURL].contains {
            FileManager.default.fileExists(atPath: $0.path)
        }
        let locations: [(URL, URL, Bool)] = segmentedExists
            ? [(primaryURL, primaryBatchDirectory, true), (replicaURL, replicaBatchDirectory, true)]
            : [(legacyPrimaryURL, primaryBatchDirectory, false), (legacyReplicaURL, replicaBatchDirectory, false)]

        var candidates = [Candidate]()
        var firstReadError: Error?
        for (url, batchDirectory, segmented) in locations {
            do {
                let candidate: Candidate?
                if segmented {
                    candidate = try readSegmented(url, batchDirectory: batchDirectory)
                } else {
                    candidate = try readLegacy(url)
                }
                if let candidate {
                    candidates.append(candidate)
                }
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
        storedBatchManifest = sorted[0].batchManifest
        storedBatchIndex = sorted[0].batchIndex
        hasSegmentedState = sorted[0].segmented
        return sorted[0].data
    }

    /// `batchesChanged` is false for frequent active-run and settings transactions
    /// that cannot alter completed history. The first segmented save always imports
    /// the full batch collection regardless of this hint.
    func save(
        _ state: [String: Any],
        batchesChanged: Bool = true,
        changedBatchIDs: Set<String>? = nil
    ) throws {
        guard revision < Int.max else { throw PersistenceError.revisionExhausted }
        let batches = state["batches"] as? [[String: Any]] ?? []
        let currentIDs = batches.compactMap { $0["id"] as? String }
        let recordedIDs = storedBatchManifest.map(\.id)
        let rewriteBatches = batchesChanged || !hasSegmentedState || currentIDs != recordedIDs
        let batchState: (manifest: [BatchManifestEntry], index: BatchIndexReference)
        if rewriteBatches {
            batchState = try writeBatchRecords(batches, changedBatchIDs: changedBatchIDs)
        } else {
            guard let existingIndex = storedBatchIndex else { throw PersistenceError.corrupt }
            batchState = (storedBatchManifest, existingIndex)
        }
        let manifest = batchState.manifest
        let batchIndex = batchState.index

        var coreState = state
        coreState.removeValue(forKey: "batches")
        // Purchase authority is reconstructed from the native store on launch.
        // Keeping it out of editable operational JSON prevents forged cached
        // fields from being treated as a paid entitlement.
        coreState.removeValue(forKey: "entitlement")
        let body: [String: Any] = [
            "data": coreState,
            "batchIndex": batchIndex.dictionary
        ]
        let checksum = sha256(try canonicalData(body))
        let nextRevision = revision + 1
        let envelope: [String: Any] = [
            "format": 4,
            "revision": nextRevision,
            "savedAt": ISO8601DateFormatter().string(from: Date()),
            "checksum": checksum,
            "data": coreState,
            "batchIndex": batchIndex.dictionary
        ]
        let bytes = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        let priorPrimary = try existingData(at: primaryURL)
        let priorReplica = try existingData(at: replicaURL)
        do {
            try writeProtected(bytes, to: primaryURL)
            try writeProtected(bytes, to: replicaURL)
            revision = nextRevision
            storedBatchManifest = manifest
            storedBatchIndex = batchIndex
            hasSegmentedState = true
            removeUnreferencedBatchFiles(
                keeping: Set(manifest.map(\.fileName) + [batchIndex.fileName])
            )
            try? FileManager.default.removeItem(at: legacyPrimaryURL)
            try? FileManager.default.removeItem(at: legacyReplicaURL)
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

    private func writeBatchRecords(
        _ batches: [[String: Any]],
        changedBatchIDs: Set<String>?
    ) throws -> (manifest: [BatchManifestEntry], index: BatchIndexReference) {
        var seen = Set<String>()
        let previous = Dictionary(uniqueKeysWithValues: storedBatchManifest.map { ($0.id, $0) })
        let manifest = try batches.map { batch in
            guard let id = batch["id"] as? String, !id.isEmpty, seen.insert(id).inserted else {
                throw PersistenceError.corrupt
            }
            if let changedBatchIDs, !changedBatchIDs.contains(id), let existing = previous[id] {
                return existing
            }
            let bytes = try canonicalData(batch)
            let checksum = sha256(bytes)
            let fileName = sha256(Data("\(id)|\(checksum)".utf8)) + ".record.json"
            try writeBatchBytesIfNeeded(bytes, to: primaryBatchDirectory.appendingPathComponent(fileName))
            try writeBatchBytesIfNeeded(bytes, to: replicaBatchDirectory.appendingPathComponent(fileName))
            return BatchManifestEntry(id: id, fileName: fileName, checksum: checksum)
        }
        let indexBytes = try canonicalData(manifest.map(\.dictionary))
        let indexChecksum = sha256(indexBytes)
        let index = BatchIndexReference(
            fileName: indexChecksum + ".index.json", checksum: indexChecksum
        )
        try writeBatchBytesIfNeeded(
            indexBytes, to: primaryBatchDirectory.appendingPathComponent(index.fileName)
        )
        try writeBatchBytesIfNeeded(
            indexBytes, to: replicaBatchDirectory.appendingPathComponent(index.fileName)
        )
        return (manifest, index)
    }

    private func writeBatchBytesIfNeeded(_ bytes: Data, to url: URL) throws {
        if let existing = try existingData(at: url), existing == bytes { return }
        try writeProtected(bytes, to: url)
    }

    private func readSegmented(_ url: URL, batchDirectory: URL) throws -> Candidate? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let raw = try Data(contentsOf: url)
            guard let envelope = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
                  (envelope["format"] as? Int) == 4,
                  let revision = envelope["revision"] as? Int, revision >= 0,
                  let savedAtString = envelope["savedAt"] as? String,
                  let savedAt = ISO8601DateFormatter().date(from: savedAtString),
                  let checksum = envelope["checksum"] as? String, isChecksum(checksum),
                  var state = envelope["data"] as? [String: Any],
                  let rawBatchIndex = envelope["batchIndex"] as? [String: Any],
                  let batchIndex = BatchIndexReference(rawBatchIndex) else {
                throw PersistenceError.corrupt
            }
            let indexBytes = try Data(
                contentsOf: batchDirectory.appendingPathComponent(batchIndex.fileName)
            )
            guard sha256(indexBytes) == batchIndex.checksum,
                  let rawManifest = try JSONSerialization.jsonObject(with: indexBytes) as? [[String: Any]] else {
                throw PersistenceError.corrupt
            }
            let manifest = rawManifest.compactMap(BatchManifestEntry.init)
            guard manifest.count == rawManifest.count,
                  Set(manifest.map(\.id)).count == manifest.count else {
                throw PersistenceError.corrupt
            }
            let body: [String: Any] = [
                "data": state,
                "batchIndex": batchIndex.dictionary
            ]
            guard sha256(try canonicalData(body)) == checksum else { throw PersistenceError.corrupt }
            state["batches"] = try manifest.map { entry in
                let bytes = try Data(contentsOf: batchDirectory.appendingPathComponent(entry.fileName))
                guard sha256(bytes) == entry.checksum,
                      let batch = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                      batch["id"] as? String == entry.id else {
                    throw PersistenceError.corrupt
                }
                return batch
            }
            return Candidate(
                revision: revision, savedAt: savedAt, checksum: checksum,
                data: state, batchManifest: manifest, batchIndex: batchIndex, segmented: true
            )
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.corrupt
        }
    }

    private func readLegacy(_ url: URL) throws -> Candidate? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let raw = try Data(contentsOf: url)
            guard let envelope = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
                  (envelope["format"] as? Int) == 3,
                  let revision = envelope["revision"] as? Int, revision >= 0,
                  let savedAtString = envelope["savedAt"] as? String,
                  let savedAt = ISO8601DateFormatter().date(from: savedAtString),
                  let checksum = envelope["checksum"] as? String, isChecksum(checksum),
                  let state = envelope["data"] as? [String: Any] else {
                throw PersistenceError.corrupt
            }
            guard sha256(try canonicalData(state)) == checksum else { throw PersistenceError.corrupt }
            return Candidate(
                revision: revision, savedAt: savedAt, checksum: checksum,
                data: state, batchManifest: [], batchIndex: nil, segmented: false
            )
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.corrupt
        }
    }

    private func writeProtected(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        var mutableURL = url
        try? mutableURL.setResourceValues(values)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    private func removeUnreferencedBatchFiles(keeping fileNames: Set<String>) {
        for directory in [primaryBatchDirectory, replicaBatchDirectory] {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil
            ) else { continue }
            for url in urls where url.pathExtension == "json" && !fileNames.contains(url.lastPathComponent) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func restore(_ data: Data?, at url: URL) throws {
        if let data {
            try writeProtected(data, to: url)
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func existingData(at url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    private func canonicalData(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func isChecksum(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            (48...57).contains($0.value) || (97...102).contains($0.value)
        }
    }
}
