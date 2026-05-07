import SwiftUI

struct PairingApprovalSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        DashboardSection(title: "配对请求", systemImage: "person.crop.circle.badge.questionmark") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(appState.pendingPairingRequests, id: \.requestId) { request in
                    PairingApprovalRow(request: request, appState: appState)
                }
            }
        }
    }
}

struct PairingApprovalRow: View {
    let request: PairingApprovalRequest
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "iphone.gen3")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(request.device.displayName)
                    .font(.headline)
                Text("请求时间 \(request.requestedDate, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("拒绝", role: .destructive) {
                appState.rejectPairingRequest(request)
            }
            Button("允许") {
                appState.approvePairingRequest(request)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        )
    }
}

private extension PairingApprovalRequest {
    var requestedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(requestedAt) / 1000)
    }
}
