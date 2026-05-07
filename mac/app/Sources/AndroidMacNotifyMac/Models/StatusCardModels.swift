import Foundation

enum StatusCardCategory: String, Codable, Equatable, Sendable {
    case delivery

    var title: String {
        switch self {
        case .delivery:
            return "外卖"
        }
    }

    var systemImageName: String {
        switch self {
        case .delivery:
            return "fork.knife"
        }
    }
}

enum StatusCardStage: String, Codable, Equatable, Sendable {
    case queued
    case preparing
    case handoff
    case inProgress
    case completed
    case issue

    var progress: Double {
        switch self {
        case .queued:
            return 0.18
        case .preparing:
            return 0.38
        case .handoff:
            return 0.58
        case .inProgress:
            return 0.78
        case .completed, .issue:
            return 1.0
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .issue:
            return true
        case .queued, .preparing, .handoff, .inProgress:
            return false
        }
    }
}

struct StatusCardState: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let category: StatusCardCategory
    let sourceEventId: String
    let appName: String
    let title: String
    let detail: String
    let stage: StatusCardStage
    let etaText: String?
    let updatedAt: Int64
}

enum SharedFileReceiveStage: String, Codable, Equatable, Sendable {
    case receiving
    case failed
}

struct SharedFileReceiveStatus: Codable, Equatable, Identifiable, Sendable {
    let transferId: String
    let batchId: String?
    let batchIndex: Int?
    let batchTotal: Int?
    let fileName: String
    let receivedBytes: Int64
    let totalBytes: Int64
    let speedBytesPerSecond: Int64?
    let remainingSeconds: Int64?
    let stage: SharedFileReceiveStage
    let message: String?
    let updatedAt: Int64

    var id: String {
        transferId
    }

    var batchPositionText: String? {
        guard let batchIndex, let batchTotal, batchTotal > 1, batchIndex >= 0, batchIndex < batchTotal else {
            return nil
        }
        return "第 \(batchIndex + 1) / \(batchTotal) 个"
    }

    var progress: Double {
        guard totalBytes > 0 else {
            return 0
        }
        return min(max(Double(receivedBytes) / Double(totalBytes), 0), 1)
    }
}
