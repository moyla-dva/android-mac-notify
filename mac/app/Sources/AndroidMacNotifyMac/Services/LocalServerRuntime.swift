import Foundation

struct LocalServerRuntime: Sendable {
    static func generateMacDeviceId() -> String {
        "mac-\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
    }

    func generateToken(prefix: String) -> String {
        "\(prefix)_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
    }

    func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    func decodeBody<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
