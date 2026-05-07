import Foundation

enum LocalServerError: LocalizedError {
    case invalidPort
    case failedToStart(String)
    case malformedRequest
    case payloadTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidPort:
            return "Invalid local server port."
        case let .failedToStart(message):
            return message
        case .malformedRequest:
            return "Malformed HTTP request."
        case .payloadTooLarge:
            return "Request payload is too large."
        }
    }
}
