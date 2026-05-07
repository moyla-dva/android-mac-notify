import Foundation

struct AppPairingApprovalProjection: Equatable, Sendable {
    let pendingPairingRequests: [PairingApprovalRequest]
    let actionFeedbackMessage: String
}

enum AppPairingApprovalProjector {
    static func project(
        request: PairingApprovalRequest,
        currentPendingRequests: [PairingApprovalRequest]
    ) -> AppPairingApprovalProjection {
        var pendingRequests = currentPendingRequests
        pendingRequests.removeAll { $0.requestId == request.requestId }

        if request.status == .pending {
            pendingRequests.insert(request, at: 0)
        }

        return AppPairingApprovalProjection(
            pendingPairingRequests: pendingRequests,
            actionFeedbackMessage: feedbackMessage(for: request)
        )
    }

    static func feedbackMessage(for request: PairingApprovalRequest) -> String {
        switch request.status {
        case .pending:
            return "\(request.device.displayName) 请求配对"
        case .approved:
            return "已允许 \(request.device.displayName) 配对"
        case .rejected:
            return "已拒绝 \(request.device.displayName) 配对"
        case .expired:
            return "\(request.device.displayName) 配对请求已过期"
        }
    }
}
