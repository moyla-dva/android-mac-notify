import SwiftUI

struct DashboardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            DashboardTopBar(appState: appState)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !appState.pendingPairingRequests.isEmpty {
                        PairingApprovalSection(appState: appState)
                    }

                    if let actionFeedbackMessage = appState.actionFeedbackMessage {
                        InlineFeedback(message: actionFeedbackMessage, isFailure: appState.actionFeedbackIsFailure)
                    }

                    if let lastError = appState.lastError {
                        InlineFeedback(message: lastError, isFailure: true)
                    }

                    DashboardWorkArea(appState: appState)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 860, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsButton(appState: appState)
            }
        }
    }
}
