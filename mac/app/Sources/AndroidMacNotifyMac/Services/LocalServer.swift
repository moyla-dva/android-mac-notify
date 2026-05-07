import Foundation
import Network

actor LocalServer {
    static let discoveryProtocolVersion = 1
    static let bonjourServiceType = "_amnotify._tcp"

    private static let pairingTokenLifetimeMillis: Int64 = 10 * 60 * 1000
    private static let pairingApprovalLifetimeMillis: Int64 = 5 * 60 * 1000
    private static let pairingApprovalPollAfterMillis = 2_000

    private let macDisplayName: String
    private let persistenceController: LocalServerPersistenceController
    private let runtime = LocalServerRuntime()

    private var listener: NWListener?
    private var endpoint: LocalServerEndpoint?
    private var routingState: LocalServerRoutingState
    private var eventSink: (@Sendable (LocalServerEvent) -> Void)?
    private let connectionRouter = LocalServerConnectionRouter()
    private let lifecycleCoordinator = LocalServerLifecycleCoordinator()
    private let stateCoordinator = LocalServerStateCoordinator()
    private let routeExecutor: LocalServerRouteExecutor
    private let listenerFactory: LocalServerListenerFactory

    init(
        macDeviceId: String = LocalServerRuntime.generateMacDeviceId(),
        macDisplayName: String = Host.current().localizedName ?? "Mac",
        stateStore: MacStateStore = MacStateStore()
    ) {
        self.macDisplayName = macDisplayName
        routingState = LocalServerRoutingState(
            macDeviceId: macDeviceId,
            pairingTokenLifetimeMillis: Self.pairingTokenLifetimeMillis
        )
        persistenceController = LocalServerPersistenceController(stateStore: stateStore)
        listenerFactory = LocalServerListenerFactory(
            discoveryProtocolVersion: Self.discoveryProtocolVersion,
            bonjourServiceType: Self.bonjourServiceType
        )
        let routeHandlers = LocalServerRouteHandlers(
            discovery: LocalDiscoveryHandler(
                protocolVersion: Self.discoveryProtocolVersion,
                serviceType: Self.bonjourServiceType
            ),
            pairing: LocalPairingHandler(
                approvalLifetimeMillis: Self.pairingApprovalLifetimeMillis,
                retainedTerminalRecordMillis: Self.pairingApprovalLifetimeMillis,
                approvalPollAfterMillis: Self.pairingApprovalPollAfterMillis
            )
        )
        routeExecutor = LocalServerRouteExecutor(handlers: routeHandlers)
    }

    func setEventSink(_ sink: @escaping @Sendable (LocalServerEvent) -> Void) {
        eventSink = sink
    }

    func setSharedFileDirectoryURL(_ directoryURL: URL?) {
        routingState.sharedFileDirectoryURL = directoryURL
    }

    func start(host: String, port: Int) async throws -> LocalServerSnapshot {
        try await loadPersistedStateIfNeeded()

        let startPlan = lifecycleCoordinator.prepareStart(
            endpoint: endpoint,
            pairingTokenManager: &routingState.pairingTokenManager,
            now: runtime.nowMillis(),
            tokenFactory: { runtime.generateToken(prefix: "pair") }
        )
        switch startPlan {
        case let .reuseRunningServer(endpoint, pairingToken):
            return snapshot(endpoint: endpoint, pairingToken: pairingToken)
        case let .startListener(pairingToken):
            let startedListener = try await listenerFactory.start(
                host: host,
                port: port,
                macDeviceId: routingState.macDeviceId,
                macDisplayName: macDisplayName,
                onConnection: { connection in
                    Task {
                        await self.handle(connection: connection)
                    }
                },
                onFailedAfterReady: { message in
                    Task {
                        await self.emit(.serverFailed(message))
                    }
                }
            )

            listener = startedListener.listener
            endpoint = startedListener.endpoint
            let snapshot = snapshot(endpoint: startedListener.endpoint, pairingToken: pairingToken)
            emit(.serverStarted(snapshot))
            return snapshot
        }
    }

    func stop() async {
        listener?.cancel()
        listener = nil
        endpoint = nil
        lifecycleCoordinator.stop(
            pairingTokenManager: &routingState.pairingTokenManager
        )
        routingState.sessionStore.resetReceiverState()
        emit(.serverStopped)
    }

    func setReceiverPaused(_ isPaused: Bool) async -> LocalServerSnapshot? {
        routingState.sessionStore.setReceiverPaused(isPaused)

        if let endpoint, let pairingToken = routingState.pairingTokenManager.currentToken {
            return snapshot(endpoint: endpoint, pairingToken: pairingToken)
        }
        return nil
    }

    func resetPairing() async -> LocalServerSnapshot? {
        routingState.mutateRouteStores { _, deviceRegistry, notificationIngestStore, pairingApprovalStore in
            stateCoordinator.resetPairingState(
                deviceRegistry: &deviceRegistry,
                notificationIngestStore: &notificationIngestStore,
                pairingApprovalStore: &pairingApprovalStore
            )
        }

        lifecycleCoordinator.rotatePairingTokenIfRunning(
            endpoint: endpoint,
            pairingTokenManager: &routingState.pairingTokenManager,
            now: runtime.nowMillis(),
            tokenFactory: { runtime.generateToken(prefix: "pair") }
        )

        do {
            _ = try await persistenceController.clear(defaultMacDeviceId: routingState.macDeviceId)
        } catch {
            emit(.serverFailed("Failed to clear Mac state: \(error.localizedDescription)"))
        }

        if let endpoint, let pairingToken = routingState.pairingTokenManager.currentToken {
            return snapshot(endpoint: endpoint, pairingToken: pairingToken)
        }
        return nil
    }

    func clearNotificationHistory() async -> LocalServerSnapshot? {
        do {
            try await loadPersistedStateIfNeeded()
        } catch {
            emit(.serverFailed("Failed to load Mac state before clearing history: \(error.localizedDescription)"))
        }

        stateCoordinator.clearNotificationHistory(notificationIngestStore: &routingState.notificationIngestStore)
        await persistCurrentState()

        guard let endpoint, let pairingToken = routingState.pairingTokenManager.currentToken else {
            return nil
        }
        return snapshot(endpoint: endpoint, pairingToken: pairingToken)
    }

    func clearNotification(eventId: String) async -> LocalServerSnapshot? {
        do {
            try await loadPersistedStateIfNeeded()
        } catch {
            emit(.serverFailed("Failed to load Mac state before clearing notification: \(error.localizedDescription)"))
        }

        stateCoordinator.clearNotification(eventId: eventId, notificationIngestStore: &routingState.notificationIngestStore)
        await persistCurrentState()

        guard let endpoint, let pairingToken = routingState.pairingTokenManager.currentToken else {
            return nil
        }
        return snapshot(endpoint: endpoint, pairingToken: pairingToken)
    }

    func approvePairingRequest(_ requestId: String) async -> PairingApprovalRequest? {
        let result = routeExecutor.approvePairingRequest(
            requestId: requestId,
            routingState: &routingState,
            macDisplayName: macDisplayName,
            runtime: runtime
        )
        await finalize(result)
        return result.request
    }

    func rejectPairingRequest(_ requestId: String) async -> PairingApprovalRequest? {
        let result = routeExecutor.rejectPairingRequest(
            requestId: requestId,
            routingState: &routingState,
            runtime: runtime
        )
        await finalize(result)
        return result.request
    }

    private func handle(connection: NWConnection) async {
        await connectionRouter.handle(
            connection: connection,
            server: self
        )
    }

    func route(request: HTTPRequest) async throws -> HTTPResponse {
        let execution = try routeExecutor.route(
            request: request,
            routingState: &routingState,
            endpoint: endpoint,
            macDisplayName: macDisplayName,
            runtime: runtime
        )
        await finalize(execution.finalization)
        return execution.response
    }

    func handleStreamedShareFile(_ head: HTTPRequestHead, on connection: NWConnection) async throws -> HTTPResponse {
        let preparation = try routeExecutor.prepareStreamedShareFile(
            head: head,
            routingState: &routingState,
            runtime: runtime
        )

        let execution: LocalServerRouteExecution
        switch preparation {
        case let .completed(completedResult):
            execution = LocalServerRouteExecution(result: completedResult)
        case let .ready(metadata):
            execution = try await routeExecutor.receiveStreamedShareFile(
                metadata: metadata,
                head: head,
                connection: connection,
                directoryURL: routingState.sharedFileDirectoryURL,
                progressEventSink: eventSink
            )
        }

        await finalize(execution.finalization)
        return execution.response
    }

    private func finalize(_ result: some LocalFinalizableRouteResult) async {
        await finalize(result.finalization)
    }

    private func finalize(_ finalization: LocalRouteFinalization) async {
        await persistState(for: finalization)
        if finalization.shouldEmitPairingTokenUpdate {
            emitPairingTokenUpdatedIfRunning()
        }
        for event in finalization.events {
            emit(event)
        }
    }

    private func loadPersistedStateIfNeeded() async throws {
        guard let state = try await persistenceController.loadIfNeeded(defaultMacDeviceId: routingState.macDeviceId) else {
            return
        }

        let now = runtime.nowMillis()
        let restoreResult = routingState.mutateRouteStores { _, deviceRegistry, notificationIngestStore, _ in
            stateCoordinator.applyLoadedState(
                state,
                deviceRegistry: &deviceRegistry,
                notificationIngestStore: &notificationIngestStore,
                now: now
            )
        }
        routingState.macDeviceId = restoreResult.macDeviceId
        if restoreResult.didPrunePersistedNotifications {
            await persistCurrentState()
        }
    }

    private func persistState(for finalization: LocalRouteFinalization) async {
        do {
            try await persistenceController.saveIfNeeded(currentPersistenceSnapshot(), for: finalization)
        } catch {
            emit(.serverFailed("Failed to persist Mac state: \(error.localizedDescription)"))
        }
    }

    private func persistCurrentState() async {
        do {
            try await persistenceController.save(currentPersistenceSnapshot())
        } catch {
            emit(.serverFailed("Failed to persist Mac state: \(error.localizedDescription)"))
        }
    }

    private func currentPersistenceSnapshot() -> LocalServerPersistenceSnapshot {
        LocalServerPersistenceSnapshot(
            macDeviceId: routingState.macDeviceId,
            registeredDevices: routingState.sessionStore.currentRegisteredDevices(),
            recentNotifications: routingState.notificationIngestStore.storedSummaries
        )
    }

    private func snapshot(endpoint: LocalServerEndpoint, pairingToken: String) -> LocalServerSnapshot {
        stateCoordinator.snapshot(
            endpoint: endpoint,
            pairingToken: pairingToken,
            pairingTokenExpiresAt: routingState.pairingTokenManager.expiresAt(defaultNow: runtime.nowMillis()),
            macDeviceId: routingState.macDeviceId,
            macDisplayName: macDisplayName,
            deviceRegistry: routingState.sessionStore.deviceRegistry,
            notificationIngestStore: routingState.notificationIngestStore
        )
    }

    private func emitPairingTokenUpdatedIfRunning() {
        guard let endpoint, let pairingToken = routingState.pairingTokenManager.currentToken else {
            return
        }
        emit(.pairingTokenUpdated(snapshot(endpoint: endpoint, pairingToken: pairingToken)))
    }

    private func emit(_ event: LocalServerEvent) {
        eventSink?(event)
    }
}
