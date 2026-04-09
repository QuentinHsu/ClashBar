import Foundation

@MainActor
extension AppSession {
    func startPolling() {
        self.teardownStreams()
        self.ensurePeriodicTasksForCurrentVisibility()
        self.updateDataAcquisitionPolicy()
    }

    func cancelPolling() {
        self.teardownStreams()
    }

    private func teardownStreams() {
        mediumFrequencyTask?.cancel()
        lowFrequencyTask?.cancel()
        for kind in StreamKind.allCases {
            cancelStream(kind)
        }
        mediumFrequencyTask = nil
        lowFrequencyTask = nil
        currentConnectionsStreamIntervalMilliseconds = nil
    }

    private func startPeriodicTask(
        intervalProvider: @escaping (AppSession) -> UInt64,
        operation: @escaping (AppSession) async -> Void) -> Task<Void, Never>
    {
        Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await operation(self)
                do {
                    let interval = max(1_000_000_000, intervalProvider(self))
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    return
                }
            }
        }
    }

    private func ensurePeriodicTasksForCurrentVisibility() {
        if isPanelPresented {
            if mediumFrequencyTask == nil {
                mediumFrequencyTask = self.startPeriodicTask(intervalProvider: { state in
                    state.mediumFrequencyIntervalNanoseconds
                }, operation: { state in
                    await state.refreshMediumFrequency()
                })
            }

            if lowFrequencyTask == nil {
                lowFrequencyTask = self.startPeriodicTask(intervalProvider: { state in
                    state.lowFrequencyIntervalNanoseconds
                }, operation: { state in
                    await state.refreshLowFrequency()
                })
            }
            return
        }

        mediumFrequencyTask?.cancel()
        lowFrequencyTask?.cancel()
        mediumFrequencyTask = nil
        lowFrequencyTask = nil
    }

    func refreshFromAPI(includeSlowCalls: Bool) async {
        await self.refreshHighFrequency()
        await self.refreshMediumFrequency()
        if includeSlowCalls {
            await self.refreshLowFrequency()
        }
    }

    private func refreshHighFrequency() async {
        self.updateDataAcquisitionPolicy()
    }

    func setPanelVisibility(_ presented: Bool) {
        guard self.setPresentedPanelVisibility(presented) else { return }
        if !presented {
            cancelProxyPortsAutoSave()
            self.clearTrafficPresentationHistory()
            self.releasePanelCachedData()
        }
        trimInMemoryLogsForCurrentVisibility()
        self.updateDataAcquisitionPolicy()

        guard presented else { return }
        self.flushPendingTrafficSnapshotIfNeeded(immediately: true)
        self.scheduleRefreshForActivatedTab(activeMenuTab)
    }

    func setActiveMenuTab(_ tab: RootTab) {
        let changed = self.setPresentedActiveMenuTab(tab)
        self.updateDataAcquisitionPolicy()

        guard changed else { return }
        self.scheduleRefreshForActivatedTab(tab)
    }

    func scheduleRefreshForActivatedTab(_ tab: RootTab) {
        activatedTabRefreshGeneration += 1
        let generation = activatedTabRefreshGeneration
        Task { [weak self] in
            guard let self else { return }
            await self.refreshForActivatedTab(tab, generation: generation)
        }
    }

    private func desiredDataAcquisitionPolicy(
        panelPresented: Bool,
        activeTab: RootTab) -> DataAcquisitionPolicy
    {
        self.makeDetermineDataAcquisitionPolicyUseCase().execute(.init(
            panelPresented: panelPresented,
            activeTab: activeTab,
            statusBarDisplayMode: self.statusBarDisplayMode,
            foregroundMediumFrequencyIntervalNanoseconds: self.foregroundMediumFrequencyIntervalNanoseconds,
            backgroundMediumFrequencyIntervalNanoseconds: self.backgroundMediumFrequencyIntervalNanoseconds,
            foregroundLowFrequencyPrimaryTabsIntervalNanoseconds: self
                .foregroundLowFrequencyPrimaryTabsIntervalNanoseconds,
            foregroundLowFrequencyOtherTabsIntervalNanoseconds: self.foregroundLowFrequencyOtherTabsIntervalNanoseconds,
            backgroundLowFrequencyIntervalNanoseconds: self.backgroundLowFrequencyIntervalNanoseconds))
    }

    func updateDataAcquisitionPolicy(forceRestartEnabledStreams: Bool = false) {
        guard self.isRemoteTarget || self.coreRepository.isRunning else {
            self.ensurePeriodicTasksForCurrentVisibility()
            mediumFrequencyIntervalNanoseconds = foregroundMediumFrequencyIntervalNanoseconds
            lowFrequencyIntervalNanoseconds = foregroundLowFrequencyPrimaryTabsIntervalNanoseconds
            return
        }

        let policy = self.desiredDataAcquisitionPolicy(
            panelPresented: isPanelPresented,
            activeTab: activeMenuTab)

        mediumFrequencyIntervalNanoseconds = policy.mediumFrequencyIntervalNanoseconds
        lowFrequencyIntervalNanoseconds = policy.lowFrequencyIntervalNanoseconds
        self.ensurePeriodicTasksForCurrentVisibility()
        self.applyStreamPolicy(policy, forceRestartEnabledStreams: forceRestartEnabledStreams)
    }

    func refreshForActivatedTab(_ tab: RootTab, generation: Int? = nil) async {
        guard self.isRemoteTarget || self.coreRepository.isRunning else { return }

        func shouldContinueRefresh() -> Bool {
            guard let generation else { return true }
            return generation == activatedTabRefreshGeneration
        }

        guard shouldContinueRefresh() else { return }

        switch tab {
        case .proxy:
            await self.refreshMediumFrequency()
            guard shouldContinueRefresh() else { return }
            if proxyProvidersDetail.isEmpty || ruleItems.isEmpty {
                await refreshProvidersAndRules()
            }
        case .nodes:
            await self.refreshMediumFrequency()
            guard shouldContinueRefresh() else { return }
            if proxyProvidersDetail.isEmpty {
                await refreshProvidersAndRules()
            }
        case .rules:
            await refreshProvidersAndRules()
        case .connections:
            await self.refreshConnections()
        case .logs:
            break
        case .system:
            await self.refreshMediumFrequency()
            guard shouldContinueRefresh() else { return }
            if !self.isRemoteTarget, self.hasSystemProxyOpenIntent {
                await self.refreshSystemProxyStatus()
            }
        }
    }

    private func refreshMediumFrequency() async {
        guard isPanelPresented else { return }
        await runRefresh {
            let client = try self.clientOrThrow()
            let snapshot = try await self.makeFetchMediumFrequencySnapshotUseCase(
                using: client,
                includeProxyGroups: self.activeMenuTab == .proxy || self.activeMenuTab == .nodes)
                .execute()

            self.version = snapshot.versionInfo.version
            self.applyRuntimeConfigSnapshot(snapshot.configSnapshot)

            if let proxyGroupsPayload = snapshot.proxyGroupsPayload {
                self.applyProxyGroupsResponse(
                    proxyGroupsPayload.groups,
                    proxyProviders: proxyGroupsPayload.providers)
            }
        }
    }

    func fetchRuntimeConfigSnapshot() async throws -> ConfigSnapshot {
        let client = try clientOrThrow()
        let config = try await self.makeFetchRuntimeConfigUseCase(using: client).execute()
        self.applyRuntimeConfigSnapshot(config)
        return config
    }

    private func applyRuntimeConfigSnapshot(_ config: ConfigSnapshot) {
        self.applyPresentedRuntimeConfigSnapshot(config, normalizeMode: self.normalizeMode)

        if !self.isRemoteTarget, let externalController = config.externalController {
            applyExternalControllerFromConfig(externalController)
        }
        syncEditableSettings(from: config)
        refreshLogsStreamLevelIfNeeded()
    }

    func resetTrafficPresentation() {
        traffic = TrafficSnapshot(up: 0, down: 0)
        self.clearTrafficPresentationHistory()
    }

    func clearTrafficPresentationHistory() {
        self.clearPresentedTrafficHistory(historyMaxPoints: historyMaxPoints)
    }

    private func releasePanelCachedData() {
        connectionsStore.connectionsCount = 0
        connectionsStore.connections.removeAll(keepingCapacity: false)

        memory = MemorySnapshot(inuse: 0)

        self.clearPresentedProxyGroups(keepingCapacity: false)
        clearMeasuredProxyDelays()

        self.clearPresentedProviderCollections(keepingCapacity: false)
    }

    func appendTrafficHistory(up: Int64, down: Int64) {
        self.appendPresentedTrafficHistory(
            up: up,
            down: down,
            historyMaxPoints: historyMaxPoints)
    }

    func updateTrafficTotals(from snapshot: TrafficSnapshot) {
        self.updatePresentedTrafficTotals(from: snapshot, now: Date())
    }

    private func refreshLowFrequency() async {
        guard isPanelPresented else { return }
        switch activeMenuTab {
        case .proxy:
            await refreshProvidersAndRules()
            if !self.isRemoteTarget {
                await self.refreshSystemProxyStatus()
            }
        case .nodes:
            await refreshProvidersAndRules()
        case .rules:
            await refreshProvidersAndRules()
        case .system:
            if !self.isRemoteTarget {
                await self.refreshSystemProxyStatus()
            }
        case .connections, .logs:
            break
        }
    }

    func refreshProxyGroups() async {
        await runRefresh {
            let client = try self.clientOrThrow()
            let payload = try await self.makeFetchProxyGroupsAndProvidersUseCase(using: client).execute()
            self.applyProxyGroupsResponse(payload.groups, proxyProviders: payload.providers)
        }
    }

    private func applyProxyGroupsResponse(
        _ response: ProxyGroupsResponse,
        proxyProviders: [String: ProviderDetail] = [:])
    {
        if !proxyProviders.isEmpty {
            let filteredProxyProviders = proxyProviders.filter { key, detail in
                self.shouldIncludeProxyProvider(named: key, detail: detail)
            }

            let previousProxyProviders = self.proxyProvidersDetail
            var nextProxyProviders: [String: ProviderDetail] = [:]
            nextProxyProviders.reserveCapacity(filteredProxyProviders.count)
            for (name, detail) in filteredProxyProviders {
                nextProxyProviders[name] = self.mergedProviderDetailPreservingNodes(
                    previous: previousProxyProviders[name],
                    incoming: detail)
            }
            self.proxyProvidersDetail = nextProxyProviders
        }

        let presentation = self.makeBuildProxyGroupsPresentationUseCase().execute(
            response: response,
            proxyProviders: proxyProviders,
            fallbackProxyProviders: self.proxyProvidersDetail)
        self.proxyGroups = presentation.groups
        self.proxyHistoryLatestDelay = presentation.history
        self.proxyNodeTypes = presentation.nodeTypes
        self.proxyNodeIDs = presentation.nodeIDs
    }

    func normalizedHealthcheckURL(_ value: String?) -> String? {
        HealthcheckNormalization.normalizedURL(value)
    }

    func normalizedHealthcheckTimeout(_ value: Int?) -> Int? {
        HealthcheckNormalization.normalizedTimeout(value)
    }

    func refreshConnections() async {
        let policy = self.desiredDataAcquisitionPolicy(panelPresented: isPanelPresented, activeTab: activeMenuTab)
        guard policy.enableConnectionsStream else {
            cancelStream(.connections)
            return
        }
        startConnectionsStream(intervalMilliseconds: policy.connectionsIntervalMilliseconds)
    }

    func refreshSystemProxyStatus() async {
        guard self.hasSystemProxyOpenIntent else {
            self.resetSystemProxyObservedState()
            return
        }

        do {
            let enabled = try await readSystemProxyEnabledState()
            isSystemProxyEnabled = enabled
            if enabled {
                systemProxyActiveDisplay = try await readSystemProxyActiveDisplay()
            } else {
                systemProxyActiveDisplay = nil
            }
            await self.refreshSystemProxyHelperRuntimeSnapshot()
            self.systemProxyHelperFailureReason = nil
            self.systemProxyHelperFailureMessage = nil
        } catch {
            appendLog(level: "error", message: tr("log.system_proxy.read_failed", systemProxyErrorMessage(error)))
            await self.refreshSystemProxyHelperStatus()
        }
    }

    private func applyStreamPolicy(
        _ policy: DataAcquisitionPolicy,
        forceRestartEnabledStreams: Bool = false)
    {
        self.syncStream(
            .traffic,
            enabled: policy.enableTrafficStream,
            forceRestart: forceRestartEnabledStreams,
            staleAfter: self.streamStaleInterval(for: .traffic, connectionsIntervalMilliseconds: nil))
        {
            startTrafficStream()
        }
        self.syncStream(
            .memory,
            enabled: policy.enableMemoryStream,
            forceRestart: forceRestartEnabledStreams,
            staleAfter: self.streamStaleInterval(for: .memory, connectionsIntervalMilliseconds: nil))
        {
            startMemoryStream()
        }
        self.syncConnectionsStream(
            enabled: policy.enableConnectionsStream,
            intervalMilliseconds: policy.connectionsIntervalMilliseconds,
            forceRestart: forceRestartEnabledStreams)
        self.syncStream(
            .logs,
            enabled: policy.enableLogsStream,
            forceRestart: forceRestartEnabledStreams || currentLogsStreamLevel != logsStreamLevelFilter())
        {
            startLogsStream()
        }
    }

    private func syncConnectionsStream(
        enabled: Bool,
        intervalMilliseconds: Int?,
        forceRestart: Bool = false)
    {
        self.syncStream(
            .connections,
            enabled: enabled,
            forceRestart: forceRestart || currentConnectionsStreamIntervalMilliseconds != intervalMilliseconds,
            staleAfter: self.streamStaleInterval(
                for: .connections,
                connectionsIntervalMilliseconds: intervalMilliseconds))
        {
            startConnectionsStream(intervalMilliseconds: intervalMilliseconds)
        }
    }

    private func syncStream(
        _ kind: StreamKind,
        enabled: Bool,
        forceRestart: Bool = false,
        staleAfter: TimeInterval? = nil,
        start: () -> Void)
    {
        guard enabled else {
            cancelStream(kind)
            return
        }

        let shouldRestart = self.shouldRestartStreamUseCase.execute(.init(
            enabled: enabled,
            forceRestart: forceRestart,
            taskExists: self.webSocketTask(for: kind) != nil,
            lastPayloadAt: self.streamLastPayloadAt(for: kind),
            now: Date(),
            staleAfter: staleAfter))

        guard shouldRestart else { return }
        start()
    }

    private func streamStaleInterval(
        for kind: StreamKind,
        connectionsIntervalMilliseconds: Int?) -> TimeInterval?
    {
        switch kind {
        case .traffic:
            return 6
        case .memory:
            return 12
        case .connections:
            let intervalSeconds = Double(connectionsIntervalMilliseconds ?? 1_000) / 1_000
            return max(6, intervalSeconds * 4)
        case .logs:
            return nil
        }
    }
}
