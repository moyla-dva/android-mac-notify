import SwiftUI

struct DashboardWorkArea: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 22) {
                DashboardInboxSection(appState: appState)
            }
            .frame(minWidth: 520, maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 22) {
                RecentActivitySection(appState: appState, displayLimit: 6)
            }
            .frame(width: 340, alignment: .topLeading)
        }
    }

}
