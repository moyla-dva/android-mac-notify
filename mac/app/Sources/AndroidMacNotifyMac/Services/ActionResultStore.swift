import Foundation

actor ActionResultStore {
    struct StoredActionResults: Codable, Sendable {
        var schemaVersion: Int
        var results: [ActionResult]

        static var empty: StoredActionResults {
            StoredActionResults(schemaVersion: 1, results: [])
        }
    }

    static let maxStoredCount = 200
    static let maxStoredAgeMillis: Int64 = 24 * 60 * 60 * 1_000

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
            let directoryURL = baseURL.appendingPathComponent("Android Mac Notify", isDirectory: true)
            self.fileURL = directoryURL.appendingPathComponent("action-results.json", isDirectory: false)
        }

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    func load(now: Int64? = nil) async throws -> [ActionResult] {
        let now = now ?? Self.nowMillis()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            try saveStoredResults(.empty)
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let storedResults = try decoder.decode(StoredActionResults.self, from: data)
        let retainedResults = Self.retainedResults(from: storedResults.results, now: now)

        if retainedResults != storedResults.results {
            try saveStoredResults(StoredActionResults(schemaVersion: 1, results: retainedResults))
        }

        return retainedResults
    }

    func save(_ results: [ActionResult], now: Int64? = nil) async throws {
        let now = now ?? Self.nowMillis()
        let retainedResults = Self.retainedResults(from: results, now: now)
        try saveStoredResults(StoredActionResults(schemaVersion: 1, results: retainedResults))
    }

    func clear() async throws {
        try saveStoredResults(.empty)
    }

    static func retainedResults(from results: [ActionResult], now: Int64) -> [ActionResult] {
        var latestResultsById: [String: ActionResult] = [:]

        for result in results where shouldPersist(result, now: now) {
            let sanitizedResult = ActionResult(
                actionId: result.actionId,
                sourceEventId: result.sourceEventId,
                status: .success,
                executedAt: result.executedAt,
                message: nil
            )

            if let existing = latestResultsById[sanitizedResult.actionId],
               existing.executedAt >= sanitizedResult.executedAt {
                continue
            }

            latestResultsById[sanitizedResult.actionId] = sanitizedResult
        }

        return Array(
            latestResultsById.values
                .sorted { $0.executedAt > $1.executedAt }
                .prefix(maxStoredCount)
        )
    }

    private static func shouldPersist(_ result: ActionResult, now: Int64) -> Bool {
        guard result.status == .success else {
            return false
        }

        if result.executedAt > now {
            return true
        }

        return now - result.executedAt <= maxStoredAgeMillis
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func saveStoredResults(_ storedResults: StoredActionResults) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(storedResults)
        try data.write(to: fileURL, options: .atomic)
    }
}
