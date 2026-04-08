import Foundation

private struct SystemProxyToggleTarget {
    let host: String
    let ports: SystemProxyPorts
}

struct RefCountedPresence<Key: Hashable> {
    private var counts: [Key: Int] = [:]

    mutating func begin(_ key: Key, into published: inout Set<Key>) {
        let next = (self.counts[key] ?? 0) + 1
        self.counts[key] = next
        published.insert(key)
    }

    mutating func end(_ key: Key, from published: inout Set<Key>) {
        let current = self.counts[key] ?? 0
        guard current > 1 else {
            self.counts.removeValue(forKey: key)
            published.remove(key)
            return
        }
        self.counts[key] = current - 1
    }

    mutating func reset() {
        self.counts.removeAll()
    }
}

struct NestedRefCountedPresence<Outer: Hashable, Inner: Hashable> {
    private var counts: [Outer: [Inner: Int]] = [:]

    mutating func begin(outer: Outer, inner: Inner, into published: inout [Outer: Set<Inner>]) {
        let next = (self.counts[outer]?[inner] ?? 0) + 1
        self.counts[outer, default: [:]][inner] = next
        published[outer, default: []].insert(inner)
    }

    mutating func end(outer: Outer, inner: Inner, from published: inout [Outer: Set<Inner>]) {
        let current = self.counts[outer]?[inner] ?? 0
        guard current > 1 else {
            self.counts[outer]?.removeValue(forKey: inner)
            if self.counts[outer]?.isEmpty == true {
                self.counts.removeValue(forKey: outer)
            }

            published[outer]?.remove(inner)
            if published[outer]?.isEmpty == true {
                published.removeValue(forKey: outer)
            }
            return
        }
        self.counts[outer, default: [:]][inner] = current - 1
    }

    mutating func reset() {
        self.counts.removeAll()
    }
}

@MainActor
extension AppSession {
    private var resolveManagedProxyCommandHostUseCase: ResolveManagedProxyCommandHostUseCase {
        ResolveManagedProxyCommandHostUseCase()
    }

    private var resolveProxyCommandPortsUseCase: ResolveProxyCommandPortsUseCase {
        ResolveProxyCommandPortsUseCase()
    }

    private var resolveSystemProxyTogglePlanUseCase: ResolveSystemProxyTogglePlanUseCase {
        ResolveSystemProxyTogglePlanUseCase()
    }

    private var resolveProxyLatencyMeasurementPlanUseCase: ResolveProxyLatencyMeasurementPlanUseCase {
        ResolveProxyLatencyMeasurementPlanUseCase()
    }

    private func proxyRuntimeConfigRepository(using transport: any MihomoAPITransporting) -> RuntimeConfigRepository {
        DefaultRuntimeConfigRepository(transport: transport)
    }

    private func proxyRepository(using transport: any MihomoAPITransporting) -> ProxyRepository {
        DefaultProxyRepository(transport: transport)
    }

    private func switchCoreModeUseCase() throws -> SwitchCoreModeUseCase {
        try SwitchCoreModeUseCase(repository: self.proxyRuntimeConfigRepository(using: self.modeSwitchTransport()))
    }

    private func patchRuntimeConfigUseCase() throws -> PatchRuntimeConfigUseCase {
        try PatchRuntimeConfigUseCase(repository: self.proxyRuntimeConfigRepository(using: self.clientOrThrow()))
    }

    private func switchProxyNodeUseCase() throws -> SwitchProxyNodeUseCase {
        try SwitchProxyNodeUseCase(repository: self.proxyRepository(using: self.clientOrThrow()))
    }

    private func measureGroupLatencyUseCase() throws -> MeasureGroupLatencyUseCase {
        try MeasureGroupLatencyUseCase(repository: self.proxyRepository(using: self.clientOrThrow()))
    }

    func switchMode(to target: CoreMode) async {
        if !isModeSwitchEnabled || modeSwitchInFlight || target == currentMode { return }
        modeSwitchInFlight = true
        defer { modeSwitchInFlight = false }

        currentMode = target

        do {
            try await self.switchCoreModeUseCase().execute(mode: target)
        } catch {
        }
    }

    func toggleSystemProxy(_ enabled: Bool) async {
        isProxySyncing = true
        self.systemProxyEnableIntentInFlight = enabled
        self.clearSystemProxyOpenFailureHint()
        defer { isProxySyncing = false }
        defer { self.systemProxyEnableIntentInFlight = false }

        let plan = self.resolveSystemProxyTogglePlanUseCase.execute(
            enabled: enabled,
            isRemoteTarget: self.isRemoteTarget,
            isRuntimeRunning: self.isRuntimeRunning,
            wasSystemProxyEnabled: self.isSystemProxyEnabled)

        self.applyOptimisticSystemProxyToggleStateIfNeeded(enabled: enabled, plan: plan)
        self.appendSystemProxyToggleLogIfNeeded(enabled: enabled, shouldAppend: plan.shouldAppendToggleLogBeforeExecution)

        do {
            let target = try self.resolveSystemProxyToggleTarget(enabled: enabled, plan: plan)
            try await self.executeSystemProxyToggle(target: target, enabled: enabled, plan: plan)
            await self.completeSystemProxyToggleSuccess(
                enabled: enabled,
                target: target,
                plan: plan)
        } catch {
            await self.handleSystemProxyToggleFailure(error, plan: plan)
        }
    }

    func copyProxyCommand() {
        self.copyLocalProxyCommand()
    }

    func copyLocalProxyCommand() {
        self.copyProxyCommand(host: "127.0.0.1")
    }

    func copyManagedEndpointProxyCommand() {
        self.copyProxyCommand(host: self.managedEndpointProxyCommandHost())
    }

    func localProxyCommandTargetDisplay() -> String {
        let ports = currentSystemProxyPortsFromState()
        return self.buildSystemProxyDisplayString(host: "127.0.0.1", ports: ports) ?? "127.0.0.1"
    }

    func localProxyCommandHostDisplay() -> String {
        "127.0.0.1"
    }

    func managedEndpointProxyCommandTargetDisplay() -> String {
        let ports = currentSystemProxyPortsFromState()
        let host = self.managedEndpointProxyCommandHost()
        return self.buildSystemProxyDisplayString(host: host, ports: ports) ?? host
    }

    func managedEndpointProxyCommandHostDisplay() -> String {
        self.managedEndpointProxyCommandHost()
    }

    private func copyProxyCommand(host: String) {
        let ports = self.resolveProxyCommandPortsUseCase.execute(
            systemProxyPorts: currentSystemProxyPortsFromState(),
            effectiveMixedPort: effectiveMixedPort())
        let script = BuildTerminalProxyCommandUseCase().execute(
            host: host,
            httpPort: ports.httpPort,
            socksPort: ports.socksPort)
        copyTextToPasteboard(script)
        appendLog(level: "info", message: tr("log.proxy_export.copied"))
    }

    func switchProxy(group: String, target: String) async {
        await runNoResponseAction(tr("log.action_name.switch_proxy", group, target)) {
            try await self.switchProxyNodeUseCase().execute(group: group, target: target)
            await self.refreshProxyGroups()
        }
    }

    func refreshGroupLatency(_ group: ProxyGroup) async {
        await self.refreshResolvedGroupLatencies(startingFrom: [group])
    }

    func testSingleNodeLatency(
        nodeName: String,
        testURL: String? = nil,
        timeout: Int? = nil) async -> Int?
    {
        let url = normalizedHealthcheckURL(testURL) ?? defaultHealthcheckURL
        let resolvedTimeout = normalizedHealthcheckTimeout(timeout) ?? defaultHealthcheckTimeoutMilliseconds
        do {
            let repo = try self.proxyRepository(using: self.clientOrThrow())
            let result = try await repo.measureNodeLatency(name: nodeName, url: url, timeout: resolvedTimeout)
            let delay = max(result.delay, 0)
            self.recordMeasuredProxyDelays([nodeName: delay], useProxyIdentityLookup: true)
            return delay
        } catch {
            self.recordMeasuredProxyDelays([nodeName: 0], useProxyIdentityLookup: true)
            return 0
        }
    }

    func testSingleNodeLatencyWithLoading(
        nodeName: String,
        groupName: String? = nil,
        testURL: String? = nil,
        timeout: Int? = nil) async
    {
        if let referencedGroup = self.proxyGroup(named: nodeName) {
            self.beginNodeLatencyLoading(nodeName)
            defer { self.endNodeLatencyLoading(nodeName) }
            await self.refreshGroupLatency(referencedGroup)
            return
        }

        self.beginNodeLatencyLoading(nodeName)
        defer { self.endNodeLatencyLoading(nodeName) }

        let delay = await self.testSingleNodeLatency(nodeName: nodeName, testURL: testURL, timeout: timeout)

        if let groupName, let finalDelay = delay {
            self.setPresentedGroupLatency(
                groupName: groupName,
                delayKey: self.proxyDelayLookupKey(nodeName: nodeName),
                delay: finalDelay)
        }
    }

    func refreshAllGroupLatencies(includeHiddenGroups: Bool = false) async {
        let groups = includeHiddenGroups
            ? proxyGroups
            : proxyGroups.filter { $0.hidden != true }
        await self.refreshResolvedGroupLatencies(startingFrom: groups)
    }

    func delayText(group: String, node: String, fallbackToGroupHistory: Bool = false) -> String {
        guard let value = delayValue(
            group: group,
            node: node,
            fallbackToGroupHistory: fallbackToGroupHistory)
        else { return tr("ui.common.unknown") }
        if value == 0 { return tr("ui.common.timeout") }
        return tr("ui.common.latency_ms", value)
    }

    func delayValue(group: String, node: String, fallbackToGroupHistory: Bool = false) -> Int? {
        self.resolvedDelayValue(
            currentGroup: group,
            proxyName: node,
            fallbackGroupName: fallbackToGroupHistory ? group : nil,
            visitedGroups: [group])
    }

    func groupDisplayDelayText(_ group: ProxyGroup) -> String {
        guard let value = self.groupDisplayDelayValue(group) else {
            return tr("ui.common.unknown")
        }
        if value == 0 { return tr("ui.common.timeout") }
        return tr("ui.common.latency_ms", value)
    }

    func groupDisplayDelayValue(_ group: ProxyGroup) -> Int? {
        let currentNode = group.now?.trimmedNonEmpty ?? ""
        if self.usesWholeGroupLatencyPresentation(group),
           self.isWholeGroupLatencyMeasurementInProgress(group)
        {
            return self.groupDelayValue(for: group.name)
        }

        guard !currentNode.isEmpty else {
            return self.groupDelayValue(for: group.name)
        }

        return self.delayValue(
            group: group.name,
            node: currentNode,
            fallbackToGroupHistory: true)
    }

    func latestDelay(for proxyName: String, nodeID: String? = nil) -> Int? {
        let key = self.proxyDelayLookupKey(nodeName: proxyName, nodeID: nodeID)
        return self.liveProxyLatestDelay[key] ?? self.proxyHistoryLatestDelay[key]
    }

    func clearMeasuredProxyDelays() {
        self.clearPresentedProxyLatencyState()
        self.proxyHistoryLatestDelay = [:]
    }

    func rebuildProxyGroupIndex() {
        self.rebuildPresentedProxyGroupIndex()
    }

    func isLatencyTesting(group: ProxyGroup, nodeName: String) -> Bool {
        self.resolvedLatencyTesting(
            currentGroup: group.name,
            proxyName: nodeName,
            visitedGroups: [group.name])
    }

    func isLatencyTesting(group: ProxyGroup) -> Bool {
        if self.usesWholeGroupLatencyPresentation(group) {
            return self.isWholeGroupLatencyMeasurementInProgress(group)
        }

        guard let currentNode = group.now?.trimmedNonEmpty else {
            return !(self.groupLatencyPendingDelayKeys[group.name]?.isEmpty ?? true)
        }
        return self.resolvedLatencyTesting(
            currentGroup: group.name,
            proxyName: currentNode,
            visitedGroups: [group.name])
    }

    private func recordMeasuredProxyDelays(_ delays: [String: Int]) {
        guard !delays.isEmpty else { return }
        self.recordMeasuredProxyDelays(delays, useProxyIdentityLookup: false)
    }

    private func recordMeasuredProxyDelays(_ delays: [String: Int], useProxyIdentityLookup: Bool) {
        guard !delays.isEmpty else { return }
        for (name, delay) in delays {
            let key = useProxyIdentityLookup
                ? self.proxyDelayLookupKey(nodeName: name)
                : name
            self.recordPresentedLiveProxyDelay(key: key, delay: delay)
        }
    }

    private func proxyDelayLookupKey(nodeName: String, nodeID: String? = nil) -> String {
        nodeID?.trimmedNonEmpty ?? self.proxyNodeIDs[nodeName] ?? nodeName
    }

    private func resolvedDelayValue(
        currentGroup: String,
        proxyName: String,
        fallbackGroupName: String?,
        visitedGroups: Set<String>) -> Int?
    {
        let nodeDelayKey = self.proxyDelayLookupKey(nodeName: proxyName)
        if let liveValue = groupLatencies[currentGroup]?[nodeDelayKey] {
            return liveValue
        }

        if let referencedGroup = self.proxyGroup(named: proxyName),
           !visitedGroups.contains(referencedGroup.name)
        {
            let nextVisitedGroups = visitedGroups.union([referencedGroup.name])
            if let nestedNode = referencedGroup.now?.trimmedNonEmpty,
               let resolvedNestedDelay = self.resolvedDelayValue(
                   currentGroup: referencedGroup.name,
                   proxyName: nestedNode,
                   fallbackGroupName: referencedGroup.name,
                   visitedGroups: nextVisitedGroups)
            {
                return resolvedNestedDelay
            }

            if let referencedGroupDelay = self.groupDelayValue(for: referencedGroup.name) {
                return referencedGroupDelay
            }
        }

        if let liveValue = latestDelay(for: proxyName, nodeID: self.proxyNodeIDs[proxyName]) {
            return liveValue
        }

        if let fallbackGroupName {
            return self.groupDelayValue(for: fallbackGroupName)
        }

        return nil
    }

    private func groupDelayValue(for groupName: String) -> Int? {
        let key = self.proxyDelayLookupKey(nodeName: groupName)
        return self.liveProxyLatestDelay[key]
            ?? self.proxyHistoryLatestDelay[key]
            ?? self.liveProxyLatestDelay[groupName]
            ?? self.proxyHistoryLatestDelay[groupName]
    }

    private func proxyGroup(named name: String) -> ProxyGroup? {
        self.presentedProxyGroup(named: name)
            ?? self.proxyGroups.last(where: { $0.name == name })
    }

    private func refreshResolvedGroupLatencies(startingFrom rootGroups: [ProxyGroup]) async {
        self.rebuildProxyGroupIndex()

        let measurementPlan = self.resolveProxyLatencyMeasurementPlanUseCase.execute(
            rootGroups: rootGroups,
            proxyGroupsByName: self.proxyGroupsByName(),
            proxyNodeIDs: self.proxyNodeIDs,
            defaultTestURL: self.defaultHealthcheckURL,
            defaultTimeout: self.defaultHealthcheckTimeoutMilliseconds)
        let nodeGroups = self.proxyGroups(named: measurementPlan.nodeGroupNames)
        let wholeGroupTypes = self.proxyGroups(named: measurementPlan.wholeGroupNames)

        var remainingGroupJobs = measurementPlan.groupPendingCounts

        for group in nodeGroups {
            self.beginPresentedGroupLatencyLoading(group.name)
            self.ensurePresentedGroupLatencyBucket(group.name)
            for delayKey in measurementPlan.groupPendingDelayKeys[group.name] ?? [] {
                self.beginPresentedGroupLatencyPending(groupName: group.name, delayKey: delayKey)
            }
        }

        for group in nodeGroups where (remainingGroupJobs[group.name] ?? 0) == 0 {
            self.endPresentedGroupLatencyLoading(group.name)
        }

        var wholeGroupDirectNodes: [String: [String]] = [:]
        for group in wholeGroupTypes {
            let directNodes = measurementPlan.groupDirectNodes[group.name]
                ?? self.directLatencyTestNodes(in: group)
            wholeGroupDirectNodes[group.name] = directNodes
            self.beginPresentedGroupLatencyLoading(group.name)
            self.ensurePresentedGroupLatencyBucket(group.name)
            for delayKey in directNodes.map({ self.proxyDelayLookupKey(nodeName: $0) }) {
                self.beginPresentedGroupLatencyPending(groupName: group.name, delayKey: delayKey)
            }
        }

        async let nodeMeasurements: Void = self.executeLatencyMeasurementPlan(measurementPlan) { jobKey, delay in
            self.applyMeasuredDelay(
                delay,
                for: jobKey,
                in: measurementPlan,
                remainingGroupJobs: &remainingGroupJobs)
        }

        async let wholeGroupMeasurements: Void = self.executeWholeGroupLatencyMeasurements(
            wholeGroupTypes,
            directNodes: wholeGroupDirectNodes)

        _ = await (nodeMeasurements, wholeGroupMeasurements)
    }

    private func executeLatencyMeasurementPlan(
        _ plan: ProxyLatencyMeasurementPlan,
        onResult: @escaping @MainActor (ProxyLatencyMeasurementJobKey, Int) -> Void) async
    {
        guard !plan.orderedJobs.isEmpty else { return }

        do {
            let repository = try self.proxyRepository(using: self.clientOrThrow())
            await withTaskGroup(of: (ProxyLatencyMeasurementJobKey, Int).self) { taskGroup in
                let concurrencyLimit = max(1, min(self.maxConcurrentLatencyMeasurements, plan.orderedJobs.count))
                var nextJobIndex = 0

                func enqueueNextJob() {
                    guard nextJobIndex < plan.orderedJobs.count else { return }
                    let job = plan.orderedJobs[nextJobIndex]
                    nextJobIndex += 1
                    taskGroup.addTask {
                        do {
                            let result = try await repository.measureNodeLatency(
                                name: job.nodeName,
                                url: job.key.testURL,
                                timeout: job.key.timeout)
                            return (job.key, max(result.delay, 0))
                        } catch {
                            return (job.key, 0)
                        }
                    }
                }

                for _ in 0..<concurrencyLimit {
                    enqueueNextJob()
                }

                while let (jobKey, delay) = await taskGroup.next() {
                    onResult(jobKey, delay)
                    enqueueNextJob()
                }
            }
        } catch {
            for job in plan.orderedJobs {
                onResult(job.key, 0)
            }
        }
    }

    private func executeWholeGroupLatencyMeasurements(
        _ groups: [ProxyGroup],
        directNodes: [String: [String]]) async
    {
        guard !groups.isEmpty else { return }

        await withTaskGroup(of: Void.self) { taskGroup in
            let concurrencyLimit = max(1, min(self.maxConcurrentLatencyMeasurements, groups.count))
            var nextGroupIndex = 0

            func enqueueNextGroup() {
                guard nextGroupIndex < groups.count else { return }
                let group = groups[nextGroupIndex]
                let cachedDirectNodes = directNodes[group.name]
                nextGroupIndex += 1
                taskGroup.addTask { [group, cachedDirectNodes] in
                    await self.measureAndFinalizeWholeGroupLatency(
                        group,
                        cachedDirectNodes: cachedDirectNodes)
                }
            }

            for _ in 0..<concurrencyLimit {
                enqueueNextGroup()
            }

            while await taskGroup.next() != nil {
                enqueueNextGroup()
            }
        }
    }

    private func measureAndFinalizeWholeGroupLatency(
        _ group: ProxyGroup,
        cachedDirectNodes: [String]?) async
    {
        let nodes = cachedDirectNodes ?? self.directLatencyTestNodes(in: group)
        let testURL = normalizedHealthcheckURL(group.testUrl) ?? defaultHealthcheckURL
        let timeout = normalizedHealthcheckTimeout(group.timeout) ?? defaultHealthcheckTimeoutMilliseconds

        do {
            let response = try await self.measureGroupLatencyUseCase().execute(
                group: group.name,
                url: testURL,
                timeout: timeout)
            let delays = self.normalizedMeasuredDelays(response.values)
            self.replacePresentedGroupLatencies(delays, for: group.name)
            self.recordMeasuredProxyDelays(delays)
        } catch {
            let delays = nodes.reduce(into: [:]) { partialResult, nodeName in
                partialResult[self.proxyDelayLookupKey(nodeName: nodeName)] = 0
            }
            self.replacePresentedGroupLatencies(delays, for: group.name)
            self.recordMeasuredProxyDelays(delays)
        }

        await self.refreshProxyGroups()

        for delayKey in nodes.map({ self.proxyDelayLookupKey(nodeName: $0) }) {
            self.endPresentedGroupLatencyPending(groupName: group.name, delayKey: delayKey)
        }
        self.endPresentedGroupLatencyLoading(group.name)
    }

    private func applyMeasuredDelay(
        _ delay: Int,
        for jobKey: ProxyLatencyMeasurementJobKey,
        in plan: ProxyLatencyMeasurementPlan,
        remainingGroupJobs: inout [String: Int])
    {
        self.recordMeasuredProxyDelays([jobKey.proxyKey: delay])

        for target in plan.jobTargets[jobKey] ?? [] {
            self.setPresentedGroupLatency(
                groupName: target.groupName,
                delayKey: target.delayKey,
                delay: delay)
            self.endPresentedGroupLatencyPending(groupName: target.groupName, delayKey: target.delayKey)

            let nextCount = max(0, (remainingGroupJobs[target.groupName] ?? 0) - 1)
            remainingGroupJobs[target.groupName] = nextCount
            if nextCount == 0 {
                self.endPresentedGroupLatencyLoading(target.groupName)
            }
        }
    }

    private func normalizedMeasuredDelays(_ delays: [String: Int]) -> [String: Int] {
        delays.reduce(into: [:]) { partialResult, entry in
            let key = self.proxyDelayLookupKey(nodeName: entry.key)
            partialResult[key] = max(entry.value, 0)
        }
    }

    private func resolvedLatencyTesting(
        currentGroup: String,
        proxyName: String,
        visitedGroups: Set<String>) -> Bool
    {
        if self.nodeLatencyLoading.contains(proxyName) { return true }
        let delayKey = self.proxyDelayLookupKey(nodeName: proxyName)
        if self.groupLatencyPendingDelayKeys[currentGroup]?.contains(delayKey) == true {
            return true
        }

        guard let referencedGroup = self.proxyGroup(named: proxyName),
              !visitedGroups.contains(referencedGroup.name)
        else {
            return false
        }

        if self.usesWholeGroupLatencyPresentation(referencedGroup) {
            return self.isWholeGroupLatencyMeasurementInProgress(referencedGroup)
        }

        guard let nestedNode = referencedGroup.now?.trimmedNonEmpty else {
            return !(self.groupLatencyPendingDelayKeys[referencedGroup.name]?.isEmpty ?? true)
        }

        return self.resolvedLatencyTesting(
            currentGroup: referencedGroup.name,
            proxyName: nestedNode,
            visitedGroups: visitedGroups.union([referencedGroup.name]))
    }

    private func usesWholeGroupLatencyPresentation(_ group: ProxyGroup) -> Bool {
        let normalizedType = group.type?
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        return switch normalizedType {
        case "urltest", "fallback", "loadbalance", "relay":
            true
        default:
            false
        }
    }

    private func isWholeGroupLatencyMeasurementInProgress(_ group: ProxyGroup) -> Bool {
        self.groupLatencyLoading.contains(group.name)
    }

    private func directLatencyTestNodes(in group: ProxyGroup) -> [String] {
        var seenDelayKeys: Set<String> = []

        return group.all.compactMap { candidate in
            guard self.proxyGroup(named: candidate) == nil else { return nil }

            let delayKey = self.proxyDelayLookupKey(nodeName: candidate)
            guard seenDelayKeys.insert(delayKey).inserted else { return nil }
            return candidate
        }
    }

    private func beginNodeLatencyLoading(_ nodeName: String) {
        self.beginPresentedNodeLatencyLoading(nodeName)
    }

    private func endNodeLatencyLoading(_ nodeName: String) {
        self.endPresentedNodeLatencyLoading(nodeName)
    }

    func controllerHost() -> String {
        guard let host = controllerHost(from: controller), !host.isEmpty else {
            return "127.0.0.1"
        }
        return host
    }

    private func managedEndpointProxyCommandHost() -> String {
        self.resolveManagedProxyCommandHostUseCase.execute(
            isRemoteTarget: self.isRemoteTarget,
            controllerHost: self.controllerHost(),
            localExternalControllerHost: self.controllerHost(from: self.localExternalControllerDisplay),
            allowLan: self.settingsAllowLan,
            currentDeviceIPv4: DeviceIPv4AddressResolver.currentAddress())
    }

    func buildSystemProxyDisplayString(host: String, ports: SystemProxyPorts) -> String? {
        guard let port = ports.primaryPort, port > 0 else { return nil }
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.contains(":"), !trimmedHost.hasPrefix("[") {
            return "[\(trimmedHost)]:\(port)"
        }
        return "\(trimmedHost):\(port)"
    }

    func makeControllerUIURL(_ controller: String, secret: String? = nil) -> String {
        let base = "\(normalizedControllerAddress(controller))/ui"
        guard let url = URL(string: normalizedControllerAddress(controller)),
              var components = URLComponents(string: base) else {
            return base
        }

        var queryItems: [URLQueryItem] = []
        if let host = url.host {
            queryItems.append(URLQueryItem(name: "host", value: host))
            queryItems.append(URLQueryItem(name: "hostname", value: host))
        }
        if let port = url.port {
            queryItems.append(URLQueryItem(name: "port", value: "\(port)"))
        } else if let scheme = url.scheme {
            queryItems.append(URLQueryItem(name: "port", value: scheme == "https" ? "443" : "80"))
        }

        if let secret, !secret.isEmpty {
            queryItems.append(URLQueryItem(name: "secret", value: secret))
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
            return components.string ?? base
        }
        return base
    }

    private func proxyGroupsByName() -> [String: ProxyGroup] {
        Dictionary(uniqueKeysWithValues: self.proxyGroups.map { ($0.name, $0) })
    }

    private func proxyGroups(named names: [String]) -> [ProxyGroup] {
        guard !names.isEmpty else { return [] }
        let groupsByName = self.proxyGroupsByName()
        return names.compactMap { groupsByName[$0] }
    }

    private func applyOptimisticSystemProxyToggleStateIfNeeded(
        enabled: Bool,
        plan: SystemProxyTogglePlan)
    {
        guard plan.shouldOptimisticallyUpdateEnabledState else { return }

        isSystemProxyEnabled = enabled
        if plan.shouldPersistEditableSettingsSnapshot {
            persistEditableSettingsSnapshot()
        }
    }

    private func resolveSystemProxyToggleTarget(
        enabled: Bool,
        plan: SystemProxyTogglePlan) throws -> SystemProxyToggleTarget
    {
        guard enabled else {
            return SystemProxyToggleTarget(host: self.controllerHost(), ports: .disabled)
        }

        switch plan.executionMode {
        case .optimisticLocalOnly:
            return SystemProxyToggleTarget(host: self.controllerHost(), ports: self.currentSystemProxyPortsFromState())
        case .runtimeSynchronized:
            let target = try self.resolveSystemProxyTargetFromState()
            return SystemProxyToggleTarget(host: target.host, ports: target.ports)
        }
    }

    private func executeSystemProxyToggle(
        target: SystemProxyToggleTarget,
        enabled: Bool,
        plan: SystemProxyTogglePlan) async throws
    {
        try await applySystemProxy(enabled: enabled, host: target.host, ports: target.ports)

        if plan.shouldPatchRuntimeMode {
            try await self.patchRuntimeConfigUseCase().execute(body: ["mode": .string(currentMode.rawValue)])
        }

        if plan.shouldCloseConnections {
            await self.closeAllConnections()
        }
    }

    private func completeSystemProxyToggleSuccess(
        enabled: Bool,
        target: SystemProxyToggleTarget,
        plan: SystemProxyTogglePlan) async
    {
        isSystemProxyEnabled = enabled
        systemProxyActiveDisplay = enabled
            ? self.buildSystemProxyDisplayString(host: target.host, ports: target.ports)
            : nil

        if plan.success.shouldClearFailureHint {
            self.clearSystemProxyOpenFailureHint()
        }

        if plan.success.shouldClearHelperFailureState {
            self.systemProxyHelperFailureReason = nil
            self.systemProxyHelperFailureMessage = nil
        }

        await self.performSystemProxyHelperRefresh(plan.success.helperRefresh)

        if plan.success.shouldResetObservedState {
            self.resetSystemProxyObservedState()
        }

        self.appendSystemProxyToggleLogIfNeeded(enabled: enabled, shouldAppend: plan.success.shouldAppendToggleLog)
    }

    private func handleSystemProxyToggleFailure(
        _ error: Error,
        plan: SystemProxyTogglePlan) async
    {
        appendLog(level: "error", message: tr("log.system_proxy.toggle_failed", systemProxyErrorMessage(error)))

        if plan.failure.shouldUpdateFailureHint {
            self.updateSystemProxyOpenFailureHint(for: error)
        }

        if plan.failure.shouldRefreshHelperStatus {
            await self.refreshSystemProxyHelperStatus()
        }

        if plan.failure.shouldRefreshSystemProxyStatus {
            await refreshSystemProxyStatus()
        } else if plan.failure.shouldResetObservedState {
            self.resetSystemProxyObservedState()
        }
    }

    private func performSystemProxyHelperRefresh(_ refresh: SystemProxyToggleHelperRefresh) async {
        switch refresh {
        case .none:
            return
        case .status:
            await self.refreshSystemProxyHelperStatus()
        case .runtimeSnapshot:
            await self.refreshSystemProxyHelperRuntimeSnapshot()
        }
    }

    private func appendSystemProxyToggleLogIfNeeded(enabled: Bool, shouldAppend: Bool) {
        guard shouldAppend else { return }
        let state = enabled ? tr("log.system_proxy.enabled") : tr("log.system_proxy.disabled")
        appendLog(level: "info", message: tr("log.system_proxy.toggled", state))
    }
}
