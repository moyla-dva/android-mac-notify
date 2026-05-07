import Foundation

enum ConnectionState: Equatable {
    case unpaired
    case waitingForPair
    case connected(deviceName: String)
    case macReceiverPaused(deviceName: String)
    case deviceRelayPaused(deviceName: String)
    case disconnectedRetrying
    case authFailed
    case networkUnavailable

    var title: String {
        switch self {
        case .unpaired:
            return "未配对"
        case .waitingForPair:
            return "等待配对"
        case let .connected(deviceName):
            return "接力可用 \(deviceName)"
        case let .macReceiverPaused(deviceName):
            return "Mac 已暂停接收 \(deviceName)"
        case let .deviceRelayPaused(deviceName):
            return "手机已暂停接力 \(deviceName)"
        case .disconnectedRetrying:
            return "等待手机接力"
        case .authFailed:
            return "配对失效"
        case .networkUnavailable:
            return "本机网络不可用"
        }
    }

    var menuTitle: String {
        switch self {
        case .unpaired:
            return "Notify"
        case .waitingForPair:
            return "配对中"
        case .connected:
            return "可用"
        case .macReceiverPaused:
            return "Mac 暂停"
        case .deviceRelayPaused:
            return "手机暂停"
        case .disconnectedRetrying:
            return "等待"
        case .authFailed:
            return "配对失效"
        case .networkUnavailable:
            return "网络不可用"
        }
    }

    var symbolName: String {
        switch self {
        case .connected:
            return "iphone.gen3.radiowaves.left.and.right"
        case .macReceiverPaused, .deviceRelayPaused:
            return "pause.circle"
        case .waitingForPair:
            return "dot.radiowaves.left.and.right"
        case .disconnectedRetrying:
            return "arrow.triangle.2.circlepath"
        case .authFailed:
            return "exclamationmark.shield"
        case .networkUnavailable:
            return "wifi.slash"
        case .unpaired:
            return "bell.badge"
        }
    }
}

enum ServerStatus: Equatable {
    case stopped
    case running(host: String, port: Int)
    case failed(message: String)

    var title: String {
        switch self {
        case .stopped:
            return "本地接力服务未启动"
        case let .running(host, port):
            return "本地接力服务运行中: \(host):\(port)"
        case let .failed(message):
            return "本地接力服务失败: \(message)"
        }
    }
}
