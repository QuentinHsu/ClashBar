import Foundation

private struct ProxyLatencyMeasurementJobKey: Hashable {
    let proxyKey: String
    let testURL: String
    let timeout: Int
}

private struct ProxyLatencyMeasurementTarget {
    let groupName: String
    let delayKey: String
}

private struct ProxyLatencyMeasurementPlan {
    let orderedJobs: [(key: ProxyLatencyMeasurementJobKey, nodeName: String)]
    let groupJobs: [String: [String: ProxyLatencyMeasurementJobKey]]
    let jobTargets: [ProxyLatencyMeasurementJobKey: [ProxyLatencyMeasurementTarget]]
    let groupPendingCounts: [String: Int]
    let groupPendingDelayKeys: [String: Set<String>]
    let groupDirectNodes: [String: [String]]
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

        guard self.isRemoteTarget || self.isRuntimeRunning else {
            isSystemProxyEnabled = enabled
            persistEditableSettingsSnapshot()
            let state = enabled ? tr("log.system_proxy.enabled") : tr("log.system_proxy.disabled")
            appendLog(level: "info", message: tr("log.system_proxy.toggled", state))

            do {
                if enabled {
                    let ports = self.currentSystemProxyPortsFromState()
                    let host = self.controllerHost()
                    try await applySystemProxy(enabled: true, host: host, ports: ports)
                    systemProxyActiveDisplay = self.buildSystemProxyDisplayString(host: host, ports: ports)
                    await self.refreshSystemProxyHelperStatus()
                } else {
                    try await applySystemProxy(enabled: false, host: self.controllerHost(), ports: .disabled)
                    systemProxyActiveDisplay = nil
                    self.resetSystemProxyObservedState()
                }
            } catch {
                appendLog(level: "error", message: tr("log.system_proxy.toggle_failed", systemProxyErrorMessage(error)))
                if enabled {
                    self.updateSystemProxyOpenFailureHint(for: error)
                    await self.refreshSystemProxyHelperStatus()
                }
            }
            return
        }

        do {
            if enabled {
                let target = try resolveSystemProxyTargetFromState()
                try await applySystemProxy(enabled: true, host: target.host, ports: target.ports)
                systemProxyActiveDisplay = self.buildSystemProxyDisplayString(host: target.host, ports: target.ports)
            } else {
                try await applySystemProxy(enabled: false, host: self.controllerHost(), ports: .disabled)
                systemProxyActiveDisplay = nil
            }

            try await self.patchRuntimeConfigUseCase().execute(body: ["mode": .string(currentMode.rawValue)])
            await self.closeAllConnections()

            isSystemProxyEnabled = enabled
            self.clearSystemProxyOpenFailureHint()
            self.systemProxyHelperFailureReason = nil
            self.systemProxyHelperFailureMessage = nil
            if enabled {
                await self.refreshSystemProxyHelperRuntimeSnapshot()
            } else {
                self.resetSystemProxyObservedState()
            }
            let state = enabled ? tr("log.system_proxy.enabled") : tr("log.system_proxy.disabled")
            appendLog(level: "info", message: tr("log.system_proxy.toggled", state))
        } catch {
            appendLog(level: "error", message: tr("log.system_proxy.toggle_failed", systemProxyErrorMessage(error)))
            if enabled {
                self.updateSystemProxyOpenFailureHint(for: error)
            }
            await self.refreshSystemProxyHelperStatus()
            if enabled || self.isSystemProxyEnabled {
                await refreshSystemProxyStatus()
            } else {
                self.resetSystemProxyObservedState()
            }
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
        let ports = currentSystemProxyPortsFromState()
        let httpPort = ports.httpPort ?? ports.socksPort ?? effectiveMixedPort()
        let socksPort = ports.socksPort ?? ports.httpPort ?? httpPort
        let script = BuildTerminalProxyCommandUseCase().execute(host: host, httpPort: httpPort, socksPort: socksPort)
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

        let expandedGroups = self.expandedReferencedGroups(startingFrom: rootGroups)
        let wholeGroupTypes = expandedGroups.filter { self.usesWholeGroupLatencyPresentation($0) }
        let nodeGroups = expandedGroups.filter { !self.usesWholeGroupLatencyPresentation($0) }
        let measurementPlan = self.makeNodeLatencyMeasurementPlan(
            groupsToRefresh: nodeGroups,
            rootGroups: rootGroups)

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

    private func expandedReferencedGroups(startingFrom rootGroups: [ProxyGroup]) -> [ProxyGroup] {
        var visited: Set<String> = []
        var orderedGroups: [ProxyGroup] = []

        func visit(_ group: ProxyGroup) {
            guard visited.insert(group.name).inserted else { return }
            orderedGroups.append(group)

            for candidate in group.all {
                guard let referencedGroup = self.proxyGroup(named: candidate) else { continue }
                visit(referencedGroup)
            }
        }

        for group in rootGroups {
            visit(group)
        }

        return orderedGroups
    }

    private func makeNodeLatencyMeasurementPlan(
        groupsToRefresh: [ProxyGroup],
        rootGroups: [ProxyGroup]) -> ProxyLatencyMeasurementPlan
    {
        var orderedJobs: [(key: ProxyLatencyMeasurementJobKey, nodeName: String)] = []
        var seenJobs: Set<ProxyLatencyMeasurementJobKey> = []
        var groupJobs: [String: [String: ProxyLatencyMeasurementJobKey]] = [:]
        var jobTargets: [ProxyLatencyMeasurementJobKey: [ProxyLatencyMeasurementTarget]] = [:]
        var groupPendingCounts: [String: Int] = [:]
        var groupPendingDelayKeys: [String: Set<String>] = [:]
        var groupDirectNodes: [String: [String]] = [:]

        for group in groupsToRefresh {
            let directNodes = self.directLatencyTestNodes(in: group)
            groupDirectNodes[group.name] = directNodes
            guard !directNodes.isEmpty else {
                groupJobs[group.name] = [:]
                groupPendingCounts[group.name] = 0
                continue
            }

            let testURL = normalizedHealthcheckURL(group.testUrl) ?? defaultHealthcheckURL
            let timeout = normalizedHealthcheckTimeout(group.timeout) ?? defaultHealthcheckTimeoutMilliseconds
            var resolvedGroupJobs: Set<ProxyLatencyMeasurementJobKey> = []
            var pendingDelayKeys: Set<String> = []
            var resolvedGroupJobLookup: [String: ProxyLatencyMeasurementJobKey] = [:]

            for nodeName in directNodes {
                let delayKey = self.proxyDelayLookupKey(nodeName: nodeName)
                let jobKey = ProxyLatencyMeasurementJobKey(
                    proxyKey: delayKey,
                    testURL: testURL,
                    timeout: timeout)
                if seenJobs.insert(jobKey).inserted {
                    orderedJobs.append((key: jobKey, nodeName: nodeName))
                }
                jobTargets[jobKey, default: []].append(
                    ProxyLatencyMeasurementTarget(
                        groupName: group.name,
                        delayKey: delayKey))
                resolvedGroupJobs.insert(jobKey)
                pendingDelayKeys.insert(delayKey)
                resolvedGroupJobLookup[delayKey] = jobKey
            }

            groupJobs[group.name] = resolvedGroupJobLookup
            groupPendingCounts[group.name] = resolvedGroupJobs.count
            groupPendingDelayKeys[group.name] = pendingDelayKeys
        }

        orderedJobs = self.prioritizedLatencyMeasurementJobs(
            orderedJobs,
            rootGroups: rootGroups,
            groupJobs: groupJobs)

        return ProxyLatencyMeasurementPlan(
            orderedJobs: orderedJobs,
            groupJobs: groupJobs,
            jobTargets: jobTargets,
            groupPendingCounts: groupPendingCounts,
            groupPendingDelayKeys: groupPendingDelayKeys,
            groupDirectNodes: groupDirectNodes)
    }

    private func prioritizedLatencyMeasurementJobs(
        _ orderedJobs: [(key: ProxyLatencyMeasurementJobKey, nodeName: String)],
        rootGroups: [ProxyGroup],
        groupJobs: [String: [String: ProxyLatencyMeasurementJobKey]]) -> [(key: ProxyLatencyMeasurementJobKey, nodeName: String)]
    {
        guard !orderedJobs.isEmpty else { return orderedJobs }

        var priorityKeys: [ProxyLatencyMeasurementJobKey] = []
        var seenPriorityKeys: Set<ProxyLatencyMeasurementJobKey> = []

        for group in rootGroups {
            guard let currentNode = group.now?.trimmedNonEmpty else { continue }
            if let jobKey = self.currentLatencyMeasurementJobKey(
                currentGroup: group.name,
                proxyName: currentNode,
                groupJobs: groupJobs,
                visitedGroups: [group.name]),
               seenPriorityKeys.insert(jobKey).inserted
            {
                priorityKeys.append(jobKey)
            }
        }

        guard !priorityKeys.isEmpty else { return orderedJobs }

        let jobLookup = Dictionary(uniqueKeysWithValues: orderedJobs.map { ($0.key, $0) })
        let prioritizedJobs = priorityKeys.compactMap { jobLookup[$0] }
        let remainingJobs = orderedJobs.filter { !seenPriorityKeys.contains($0.key) }
        return prioritizedJobs + remainingJobs
    }

    private func currentLatencyMeasurementJobKey(
        currentGroup: String,
        proxyName: String,
        groupJobs: [String: [String: ProxyLatencyMeasurementJobKey]],
        visitedGroups: Set<String>) -> ProxyLatencyMeasurementJobKey?
    {
        let delayKey = self.proxyDelayLookupKey(nodeName: proxyName)
        if let directJobKey = groupJobs[currentGroup]?[delayKey] {
            return directJobKey
        }

        guard let referencedGroup = self.proxyGroup(named: proxyName),
              !visitedGroups.contains(referencedGroup.name),
              let nestedNode = referencedGroup.now?.trimmedNonEmpty
        else {
            return nil
        }

        return self.currentLatencyMeasurementJobKey(
            currentGroup: referencedGroup.name,
            proxyName: nestedNode,
            groupJobs: groupJobs,
            visitedGroups: visitedGroups.union([referencedGroup.name]))
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

    private func beginGroupLatencyLoading(_ groupName: String) {
        self.beginPresentedGroupLatencyLoading(groupName)
    }

    private func endGroupLatencyLoading(_ groupName: String) {
        self.endPresentedGroupLatencyLoading(groupName)
    }

    private func beginGroupLatencyPending(groupName: String, delayKey: String) {
        self.beginPresentedGroupLatencyPending(groupName: groupName, delayKey: delayKey)
    }

    private func endGroupLatencyPending(groupName: String, delayKey: String) {
        self.endPresentedGroupLatencyPending(groupName: groupName, delayKey: delayKey)
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
        guard !self.isRemoteTarget else {
            return self.controllerHost()
        }

        let configuredHost = self.controllerHost(from: self.localExternalControllerDisplay) ?? self.controllerHost()
        guard self.settingsAllowLan else {
            return configuredHost
        }
        guard self.shouldUseCurrentDeviceIPv4ForProxyCommand(host: configuredHost) else {
            return configuredHost
        }

        return DeviceIPv4AddressResolver.currentAddress() ?? self.controllerHost()
    }

    private func shouldUseCurrentDeviceIPv4ForProxyCommand(host: String) -> Bool {
        switch host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "localhost", "127.0.0.1", "::1", "0.0.0.0", "::", "0:0:0:0:0:0:0:0":
            true
        default:
            false
        }
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
}
