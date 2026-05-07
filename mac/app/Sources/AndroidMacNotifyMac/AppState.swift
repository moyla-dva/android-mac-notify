import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var connectionState: ConnectionState = .unpaired
    @Published private(set) var serverStatus: ServerStatus = .stopped
    @Published var currentHost: String = NetworkAddressResolver.preferredIPv4Address() ?? "127.0.0.1"
    @Published var currentPort: Int = 38471
    @Published var pairedDeviceName: String?
    @Published private(set) var pairingToken: String?
    @Published private(set) var pairingTokenExpiresAt: Int64?
    @Published private(set) var macDeviceId: String?
    @Published private(set) var macDisplayName: String = Host.current().localizedName ?? "Mac"
    @Published private(set) var notificationsReceived: Int = 0
    @Published private(set) var lastNotificationSummary: LocalNotificationSummary?
    @Published private(set) var recentNotifications: [LocalNotificationSummary] = []
    @Published private(set) var transientNotifications: [LocalNotificationSummary] = []
    @Published private(set) var pendingPairingRequests: [PairingApprovalRequest] = []
    @Published private(set) var statusCard: StatusCardState?
    @Published private(set) var sharedFileReceiveStatus: SharedFileReceiveStatus?
    @Published var actionFeedbackMessage: String?
    @Published var lastActionResult: ActionResult?
    @Published var actionResultsById: [String: ActionResult] = [:]
    @Published private(set) var isReceiverPaused: Bool = false
    @Published private(set) var sharedFileSaveDirectoryPath: String?
    @Published var lastError: String?

    let actionPromptSubject = PassthroughSubject<LocalNotificationSummary, Never>()
    let actionCompletedSubject = PassthroughSubject<ActionResult, Never>()
    let commandCompletedSubject = PassthroughSubject<AppCommandResult, Never>()

    private static let maxStatusCardHistoryCount = 20
    private static let sharedFileSaveDirectoryDefaultsKey = "sharedFileSaveDirectoryPath"
    private static let networkUnavailableErrorMessage = "当前网络不可用"

    private let localServer: LocalServer
    private let localServerLifecycleController: AppLocalServerLifecycleController
    let actionResultPersistenceController = AppActionResultPersistenceController()
    let diagnosticStateWriter = AppDiagnosticStateWriter()
    let connectionStateProjector = AppConnectionStateProjector()
    var lastDiagnosticStateWriteAt: Date?
    var pendingDiagnosticStateWriteTask: Task<Void, Never>?
    private let connectivityMonitor = AppConnectivityMonitor()
    private let pairingApprovalPresenter = AppPairingApprovalPresenter()
    private let statusCardPanelPresenter = AppStatusCardPanelPresenter()
    private let sharedFileCommandController: AppSharedFileCommandController
    var registeredDevices: [LocalRegisteredDevice] = []
    var transientActionSummaries: [String: LocalNotificationSummary] = [:]
    var recentStatusCards: [StatusCardState] = []
    init(localServer: LocalServer = LocalServer()) {
        self.localServer = localServer
        localServerLifecycleController = AppLocalServerLifecycleController(localServer: localServer)
        let sharedFileCommandController = AppSharedFileCommandController()
        self.sharedFileCommandController = sharedFileCommandController
        sharedFileSaveDirectoryPath = sharedFileCommandController.savedDirectoryPath(
            forKey: Self.sharedFileSaveDirectoryDefaultsKey
        )
        startConnectivityMonitoring()
        Task { [weak self] in
            guard let self else { return }
            await self.localServer.setEventSink { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handle(serverEvent: event)
                }
            }
            await self.localServer.setSharedFileDirectoryURL(self.sharedFileSaveDirectoryURL)
            await self.loadPersistedActionResults()
            self.startLocalServer()
        }
    }

    var actionPromptPublisher: AnyPublisher<LocalNotificationSummary, Never> {
        actionPromptSubject.eraseToAnyPublisher()
    }

    var actionCompletedPublisher: AnyPublisher<ActionResult, Never> {
        actionCompletedSubject.eraseToAnyPublisher()
    }

    var commandCompletedPublisher: AnyPublisher<AppCommandResult, Never> {
        commandCompletedSubject.eraseToAnyPublisher()
    }

    func chooseSharedFileSaveDirectory() {
        guard let directoryURL = sharedFileCommandController.chooseSaveDirectory(
            currentDirectoryURL: effectiveSharedFileSaveDirectoryURL
        ) else {
            return
        }

        setSharedFileSaveDirectoryURL(directoryURL)
    }

    func resetSharedFileSaveDirectory() {
        setSharedFileSaveDirectoryURL(nil)
    }

    func revealSharedFileSaveDirectory() {
        apply(commandResult: sharedFileCommandController.revealSaveDirectory(effectiveSharedFileSaveDirectoryURL))
        writeDiagnosticState()
    }

    func startLocalServer() {
        lastError = nil
        currentHost = NetworkAddressResolver.preferredIPv4Address() ?? currentHost

        localServerLifecycleController.start(
            host: currentHost,
            port: currentPort,
            onSuccess: { [weak self] snapshot in
                self?.isReceiverPaused = false
                self?.apply(snapshot: snapshot)
            },
            onFailure: { [weak self] message in
                self?.applyLocalServerFailure(message: message)
            }
        )
    }

    func stopLocalServer() {
        localServerLifecycleController.stop { [weak self] in
            self?.applyLocalServerStopped()
        }
    }

    func pauseReceiver() {
        guard case .running = serverStatus else {
            return
        }

        localServerLifecycleController.setReceiverPaused(true) { [weak self] _ in
            guard let self else { return }
            self.isReceiverPaused = true
            if let pairedDeviceName {
                self.connectionState = .macReceiverPaused(deviceName: pairedDeviceName)
            }
            self.actionFeedbackMessage = "Mac 已暂停接收"
            self.writeDiagnosticState()
        }
    }

    func resumeReceiver() {
        guard case .running = serverStatus else {
            startLocalServer()
            return
        }

        localServerLifecycleController.setReceiverPaused(false) { [weak self] _ in
            guard let self else { return }
            self.isReceiverPaused = false
            self.actionFeedbackMessage = "Mac 已恢复接收"
            self.refreshConnectionFreshness()
            self.writeDiagnosticState()
        }
    }

    func toggleReceiverPause() {
        if isReceiverPaused {
            resumeReceiver()
        } else {
            pauseReceiver()
        }
    }

    private func setSharedFileSaveDirectoryURL(_ directoryURL: URL?) {
        sharedFileSaveDirectoryPath = sharedFileCommandController.storeSaveDirectory(
            directoryURL,
            defaultsKey: Self.sharedFileSaveDirectoryDefaultsKey
        )
        Task {
            await localServer.setSharedFileDirectoryURL(directoryURL?.standardizedFileURL)
        }
        actionFeedbackMessage = directoryURL == nil ? "已恢复默认保存位置" : "已更新文件保存位置"
        writeDiagnosticState()
    }

    func resetPairing() {
        Task {
            let snapshot = await localServer.resetPairing()
            pairedDeviceName = nil
            notificationsReceived = 0
            lastNotificationSummary = nil
            recentNotifications = []
            transientNotifications = []
            registeredDevices = []
            pendingPairingRequests = []
            dismissStatusCard()
            sharedFileReceiveStatus = nil
            pairingApprovalPresenter.reset()
            transientActionSummaries = [:]
            actionFeedbackMessage = nil
            lastActionResult = nil
            actionResultsById = [:]
            await clearPersistedActionResults()
            if let snapshot {
                apply(snapshot: snapshot)
            } else {
                connectionState = .unpaired
            }
            writeDiagnosticState()
        }
    }

    func approvePairingRequest(_ request: PairingApprovalRequest) {
        Task {
            _ = await localServer.approvePairingRequest(request.requestId)
        }
    }

    func rejectPairingRequest(_ request: PairingApprovalRequest) {
        Task {
            _ = await localServer.rejectPairingRequest(request.requestId)
        }
    }

    func dismissStatusCard() {
        statusCard = nil
        statusCardPanelPresenter.dismiss()
        writeDiagnosticState()
    }

    func dismissSharedFileReceiveStatus() {
        sharedFileReceiveStatus = nil
        writeDiagnosticState()
    }

    func revealSharedFileDeliveryGroup(_ group: SharedFileDeliveryGroup) {
        apply(commandResult: sharedFileCommandController.revealDeliveryGroup(group))
        writeDiagnosticState()
    }

    func copySharedFileDeliveryGroupPaths(_ group: SharedFileDeliveryGroup) {
        apply(commandResult: sharedFileCommandController.copyDeliveryGroupPaths(group))
        writeDiagnosticState()
    }

    func clearNotification(_ summary: LocalNotificationSummary) {
        Task {
            _ = await localServer.clearNotification(eventId: summary.eventId)
            apply(
                notificationCommandProjection: AppNotificationCommandProjector.remove(
                    eventId: summary.eventId,
                    notificationsReceived: notificationsReceived,
                    lastNotificationSummary: lastNotificationSummary,
                    recentNotifications: recentNotifications,
                    transientNotifications: transientNotifications,
                    transientActionSummaries: transientActionSummaries,
                    actionResultsById: actionResultsById
                )
            )
            persistActionResults()
            writeDiagnosticState()
        }
    }

    func clearNotificationHistory() {
        Task {
            let snapshot = await localServer.clearNotificationHistory()
            await clearPersistedActionResults()
            if let snapshot {
                apply(snapshot: snapshot)
            }
            apply(notificationCommandProjection: AppNotificationCommandProjector.clearHistory())
            writeDiagnosticState()
        }
    }

    func applyLocalServerStopped() {
        apply(localServerStoppedProjection: AppLocalServerRuntimeProjector.stopped(pairedDeviceName: pairedDeviceName))
    }

    func applyLocalServerFailure(message: String) {
        apply(localServerFailureProjection: AppLocalServerRuntimeProjector.failed(message: message))
        writeDiagnosticState()
    }

    private func apply(localServerSnapshotProjection projection: AppLocalServerSnapshotProjection) {
        currentHost = projection.currentHost
        currentPort = projection.currentPort
        pairingToken = projection.pairingToken
        pairingTokenExpiresAt = projection.pairingTokenExpiresAt
        macDeviceId = projection.macDeviceId
        macDisplayName = projection.macDisplayName
        serverStatus = projection.serverStatus
        registeredDevices = projection.registeredDevices
        recentNotifications = projection.recentNotifications
        transientNotifications = projection.transientNotifications
        transientActionSummaries = projection.transientActionSummaries
        lastNotificationSummary = projection.lastNotificationSummary
        notificationsReceived = projection.notificationsReceived
        pairedDeviceName = projection.pairedDeviceName
        connectionState = projection.connectionState
    }

    private func apply(localServerStoppedProjection projection: AppLocalServerStoppedProjection) {
        serverStatus = projection.serverStatus
        isReceiverPaused = projection.isReceiverPaused
        pairingToken = projection.pairingToken
        pairingTokenExpiresAt = projection.pairingTokenExpiresAt
        connectionState = projection.connectionState
        sharedFileReceiveStatus = projection.sharedFileReceiveStatus
    }

    private func apply(localServerFailureProjection projection: AppLocalServerFailureProjection) {
        lastError = projection.lastError
        serverStatus = projection.serverStatus
        connectionState = projection.connectionState
    }

    func apply(deviceSessionProjection projection: AppDeviceSessionProjection) {
        registeredDevices = projection.registeredDevices
        pairedDeviceName = projection.pairedDeviceName
        connectionState = projection.connectionState
    }

    func apply(pairingApprovalProjection projection: AppPairingApprovalProjection) {
        pendingPairingRequests = projection.pendingPairingRequests
        actionFeedbackMessage = projection.actionFeedbackMessage
    }

    func apply(notificationEventProjection projection: AppNotificationEventProjection) {
        notificationsReceived = projection.notificationsReceived
        lastNotificationSummary = projection.lastNotificationSummary
        recentNotifications = projection.recentNotifications
        transientActionSummaries = projection.transientActionSummaries
        transientNotifications = projection.transientNotifications
        actionFeedbackMessage = projection.actionFeedbackMessage
    }

    func apply(sharedFileTransferProjection projection: AppSharedFileTransferProjection) {
        sharedFileReceiveStatus = projection.sharedFileReceiveStatus
    }

    func apply(sharedFileReceiptProjection projection: AppSharedFileReceiptProjection) {
        sharedFileReceiveStatus = projection.sharedFileReceiveStatus
        notificationsReceived = projection.notificationsReceived
        lastNotificationSummary = projection.lastNotificationSummary
        recentNotifications = projection.recentNotifications
        transientActionSummaries = projection.transientActionSummaries
        transientNotifications = projection.transientNotifications
        actionFeedbackMessage = projection.actionFeedbackMessage
    }

    private func apply(notificationCommandProjection projection: AppNotificationCommandProjection) {
        notificationsReceived = projection.notificationsReceived
        lastNotificationSummary = projection.lastNotificationSummary
        recentNotifications = projection.recentNotifications
        transientNotifications = projection.transientNotifications
        transientActionSummaries = projection.transientActionSummaries
        actionResultsById = projection.actionResultsById
        actionFeedbackMessage = projection.actionFeedbackMessage
    }

    private func apply(commandResult result: AppCommandResult) {
        actionFeedbackMessage = result.feedbackMessage
        if let errorMessage = result.errorMessage {
            lastError = errorMessage
        } else {
            commandCompletedSubject.send(result)
        }
    }

    func presentPairingApprovalAlertIfNeeded(for request: PairingApprovalRequest) {
        pairingApprovalPresenter.presentIfNeeded(
            for: request,
            onApprove: approvePairingRequest,
            onReject: rejectPairingRequest
        )
    }

    func updateStatusCardIfNeeded(from summary: LocalNotificationSummary) {
        guard AppFeatureFlags.statusCardRoutingEnabled else {
            return
        }

        guard let card = StatusCardClassifier.cardState(from: summary) else {
            return
        }

        let projection = AppStatusCardProjector.project(
            incomingCard: card,
            currentCard: statusCard,
            recentCards: recentStatusCards,
            maxHistoryCount: Self.maxStatusCardHistoryCount
        )
        apply(statusCardProjection: projection)
        statusCardPanelPresenter.show(appState: self)
        writeDiagnosticState()

        if projection.statusCard.stage == .completed {
            scheduleStatusCardDismiss(for: projection.statusCard)
        } else {
            statusCardPanelPresenter.cancelScheduledDismiss()
        }
    }

    private func apply(statusCardProjection projection: AppStatusCardProjection) {
        statusCard = projection.statusCard
        recentStatusCards = projection.recentStatusCards
    }

    private func scheduleStatusCardDismiss(for card: StatusCardState) {
        statusCardPanelPresenter.scheduleCompletedDismiss(
            for: card,
            isCurrentCompleted: { [weak self] in
                self?.statusCard?.id == card.id
                    && self?.statusCard?.updatedAt == card.updatedAt
                    && self?.statusCard?.stage == .completed
            },
            onDismiss: { [weak self] in
                self?.dismissStatusCard()
            }
        )
    }

    func apply(snapshot: LocalServerSnapshot) {
        apply(
            localServerSnapshotProjection: AppLocalServerRuntimeProjector.snapshot(
                snapshot,
                isReceiverPaused: isReceiverPaused,
                now: nowMillis(),
                connectionStateProjector: connectionStateProjector
            )
        )
    }

    private func startConnectivityMonitoring() {
        connectivityMonitor.start(
            onNetworkPathUpdate: { [weak self] isSatisfied in
                self?.handleNetworkPathUpdate(isSatisfied: isSatisfied)
            },
            onConnectionFreshnessTick: { [weak self] in
                self?.refreshConnectionFreshness()
            }
        )
    }

    private func handleNetworkPathUpdate(isSatisfied: Bool) {
        guard isSatisfied else {
            lastError = Self.networkUnavailableErrorMessage
            connectionState = .networkUnavailable
            writeDiagnosticState()
            return
        }

        let clearedNetworkError = clearNetworkUnavailableErrorIfNeeded()
        let resolvedHost = NetworkAddressResolver.preferredIPv4Address() ?? currentHost
        if resolvedHost != currentHost {
            currentHost = resolvedHost
            if case .running = serverStatus {
                restartLocalServerForNetworkChange(host: resolvedHost)
            }
        } else if case .networkUnavailable = connectionState {
            refreshConnectionFreshness()
        } else if clearedNetworkError {
            writeDiagnosticState()
        }
    }

    @discardableResult
    func clearNetworkUnavailableErrorIfNeeded() -> Bool {
        guard lastError == Self.networkUnavailableErrorMessage else {
            return false
        }
        lastError = nil
        return true
    }

    private func restartLocalServerForNetworkChange(host: String) {
        let shouldRestorePaused = isReceiverPaused
        localServerLifecycleController.restartForNetworkChange(
            host: host,
            port: currentPort,
            shouldRestorePaused: shouldRestorePaused,
            onSuccess: { [weak self] snapshot in
                guard let self else { return }
                self.isReceiverPaused = shouldRestorePaused
                self.apply(snapshot: snapshot)
                if shouldRestorePaused, let pairedDeviceName = self.pairedDeviceName {
                    self.connectionState = .macReceiverPaused(deviceName: pairedDeviceName)
                }
                self.lastError = nil
                self.writeDiagnosticState()
            },
            onFailure: { [weak self] message in
                self?.applyLocalServerFailure(message: message)
            }
        )
    }

    private func refreshConnectionFreshness() {
        guard case .running = serverStatus else {
            return
        }
        let projection = connectionStateProjector.project(
            devices: registeredDevices,
            isReceiverPaused: isReceiverPaused,
            now: nowMillis()
        )
        if projection.connectionState != connectionState || projection.pairedDeviceName != pairedDeviceName {
            pairedDeviceName = projection.pairedDeviceName
            connectionState = projection.connectionState
            writeDiagnosticState()
        }
    }

    func markConnectedIfPairedDeviceExists() {
        if let pairedDeviceName {
            connectionState = .connected(deviceName: pairedDeviceName)
        }
    }

    func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

}
