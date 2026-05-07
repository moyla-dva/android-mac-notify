import Foundation

actor MacStateStore {
    struct StoredState: Codable, Sendable {
        var schemaVersion: Int
        var macDeviceId: String
        var registeredDevices: [LocalRegisteredDevice]
        var recentNotifications: [LocalNotificationSummary]

        static func empty(macDeviceId: String) -> StoredState {
            StoredState(
                schemaVersion: 1,
                macDeviceId: macDeviceId,
                registeredDevices: [],
                recentNotifications: []
            )
        }
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
            let directoryURL = baseURL.appendingPathComponent("Android Mac Notify", isDirectory: true)
            self.fileURL = directoryURL.appendingPathComponent("state.json", isDirectory: false)
        }
        self.fileManager = fileManager

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    func load(defaultMacDeviceId: String) async throws -> StoredState {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            let state = StoredState.empty(macDeviceId: defaultMacDeviceId)
            try save(state)
            return state
        }

        let data = try Data(contentsOf: fileURL)
        do {
            return try decoder.decode(StoredState.self, from: data)
        } catch {
            try? quarantineCorruptStateFile()
            let state = StoredState.empty(macDeviceId: defaultMacDeviceId)
            try save(state)
            return state
        }
    }

    func save(_ state: StoredState) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    func clear(defaultMacDeviceId: String) throws -> StoredState {
        let state = StoredState.empty(macDeviceId: defaultMacDeviceId)
        try save(state)
        return state
    }

    private func quarantineCorruptStateFile() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        let timestamp = Int(Date().timeIntervalSince1970)
        var backupURL = directoryURL.appendingPathComponent("state-corrupt-\(timestamp).json", isDirectory: false)
        if fileManager.fileExists(atPath: backupURL.path) {
            backupURL = directoryURL.appendingPathComponent(
                "state-corrupt-\(timestamp)-\(UUID().uuidString).json",
                isDirectory: false
            )
        }
        try fileManager.moveItem(at: fileURL, to: backupURL)
    }
}
