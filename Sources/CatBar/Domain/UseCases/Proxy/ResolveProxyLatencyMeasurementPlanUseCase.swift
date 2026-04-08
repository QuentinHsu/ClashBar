import Foundation

struct ProxyLatencyMeasurementJobKey: Hashable {
    let proxyKey: String
    let testURL: String
    let timeout: Int
}

struct ProxyLatencyMeasurementTarget: Equatable {
    let groupName: String
    let delayKey: String
}

struct ProxyLatencyMeasurementJob: Equatable {
    let key: ProxyLatencyMeasurementJobKey
    let nodeName: String
}

struct ProxyLatencyMeasurementPlan: Equatable {
    let nodeGroupNames: [String]
    let wholeGroupNames: [String]
    let orderedJobs: [ProxyLatencyMeasurementJob]
    let jobTargets: [ProxyLatencyMeasurementJobKey: [ProxyLatencyMeasurementTarget]]
    let groupPendingCounts: [String: Int]
    let groupPendingDelayKeys: [String: Set<String>]
    let groupDirectNodes: [String: [String]]
}

struct ResolveProxyLatencyMeasurementPlanUseCase {
    func execute(
        rootGroups: [ProxyGroup],
        proxyGroupsByName: [String: ProxyGroup],
        proxyNodeIDs: [String: String],
        defaultTestURL: String,
        defaultTimeout: Int) -> ProxyLatencyMeasurementPlan
    {
        let expandedGroups = self.expandedReferencedGroups(
            startingFrom: rootGroups,
            proxyGroupsByName: proxyGroupsByName)
        let wholeGroups = expandedGroups.filter(self.usesWholeGroupLatencyPresentation)
        let nodeGroups = expandedGroups.filter { !self.usesWholeGroupLatencyPresentation($0) }

        var orderedJobs: [ProxyLatencyMeasurementJob] = []
        var seenJobs: Set<ProxyLatencyMeasurementJobKey> = []
        var groupJobs: [String: [String: ProxyLatencyMeasurementJobKey]] = [:]
        var jobTargets: [ProxyLatencyMeasurementJobKey: [ProxyLatencyMeasurementTarget]] = [:]
        var groupPendingCounts: [String: Int] = [:]
        var groupPendingDelayKeys: [String: Set<String>] = [:]
        var groupDirectNodes: [String: [String]] = [:]

        for group in expandedGroups {
            groupDirectNodes[group.name] = self.directLatencyTestNodes(
                in: group,
                proxyGroupsByName: proxyGroupsByName,
                proxyNodeIDs: proxyNodeIDs)
        }

        for group in nodeGroups {
            let directNodes = groupDirectNodes[group.name] ?? []
            guard !directNodes.isEmpty else {
                groupJobs[group.name] = [:]
                groupPendingCounts[group.name] = 0
                continue
            }

            let testURL = HealthcheckNormalization.normalizedURL(group.testUrl) ?? defaultTestURL
            let timeout = HealthcheckNormalization.normalizedTimeout(group.timeout) ?? defaultTimeout
            var resolvedGroupJobs: Set<ProxyLatencyMeasurementJobKey> = []
            var pendingDelayKeys: Set<String> = []
            var resolvedGroupJobLookup: [String: ProxyLatencyMeasurementJobKey] = [:]

            for nodeName in directNodes {
                let delayKey = self.proxyDelayLookupKey(nodeName: nodeName, proxyNodeIDs: proxyNodeIDs)
                let jobKey = ProxyLatencyMeasurementJobKey(
                    proxyKey: delayKey,
                    testURL: testURL,
                    timeout: timeout)
                if seenJobs.insert(jobKey).inserted {
                    orderedJobs.append(ProxyLatencyMeasurementJob(key: jobKey, nodeName: nodeName))
                }
                jobTargets[jobKey, default: []].append(
                    ProxyLatencyMeasurementTarget(groupName: group.name, delayKey: delayKey))
                resolvedGroupJobs.insert(jobKey)
                pendingDelayKeys.insert(delayKey)
                resolvedGroupJobLookup[delayKey] = jobKey
            }

            groupJobs[group.name] = resolvedGroupJobLookup
            groupPendingCounts[group.name] = resolvedGroupJobs.count
            groupPendingDelayKeys[group.name] = pendingDelayKeys
        }

        orderedJobs = self.prioritizedJobs(
            orderedJobs,
            rootGroups: rootGroups,
            proxyGroupsByName: proxyGroupsByName,
            proxyNodeIDs: proxyNodeIDs,
            groupJobs: groupJobs)

        return ProxyLatencyMeasurementPlan(
            nodeGroupNames: nodeGroups.map(\.name),
            wholeGroupNames: wholeGroups.map(\.name),
            orderedJobs: orderedJobs,
            jobTargets: jobTargets,
            groupPendingCounts: groupPendingCounts,
            groupPendingDelayKeys: groupPendingDelayKeys,
            groupDirectNodes: groupDirectNodes)
    }

    private func expandedReferencedGroups(
        startingFrom rootGroups: [ProxyGroup],
        proxyGroupsByName: [String: ProxyGroup]) -> [ProxyGroup]
    {
        var visited: Set<String> = []
        var orderedGroups: [ProxyGroup] = []

        func visit(_ group: ProxyGroup) {
            guard visited.insert(group.name).inserted else { return }
            orderedGroups.append(group)

            for candidate in group.all {
                guard let referencedGroup = proxyGroupsByName[candidate] else { continue }
                visit(referencedGroup)
            }
        }

        for group in rootGroups {
            visit(group)
        }

        return orderedGroups
    }

    private func prioritizedJobs(
        _ orderedJobs: [ProxyLatencyMeasurementJob],
        rootGroups: [ProxyGroup],
        proxyGroupsByName: [String: ProxyGroup],
        proxyNodeIDs: [String: String],
        groupJobs: [String: [String: ProxyLatencyMeasurementJobKey]]) -> [ProxyLatencyMeasurementJob]
    {
        guard !orderedJobs.isEmpty else { return orderedJobs }

        var priorityKeys: [ProxyLatencyMeasurementJobKey] = []
        var seenPriorityKeys: Set<ProxyLatencyMeasurementJobKey> = []

        for group in rootGroups {
            guard let currentNode = group.now?.trimmedNonEmpty else { continue }
            if let jobKey = self.currentLatencyMeasurementJobKey(
                currentGroup: group.name,
                proxyName: currentNode,
                proxyGroupsByName: proxyGroupsByName,
                proxyNodeIDs: proxyNodeIDs,
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
        proxyGroupsByName: [String: ProxyGroup],
        proxyNodeIDs: [String: String],
        groupJobs: [String: [String: ProxyLatencyMeasurementJobKey]],
        visitedGroups: Set<String>) -> ProxyLatencyMeasurementJobKey?
    {
        let delayKey = self.proxyDelayLookupKey(nodeName: proxyName, proxyNodeIDs: proxyNodeIDs)
        if let directJobKey = groupJobs[currentGroup]?[delayKey] {
            return directJobKey
        }

        guard let referencedGroup = proxyGroupsByName[proxyName],
              !visitedGroups.contains(referencedGroup.name),
              let nestedNode = referencedGroup.now?.trimmedNonEmpty
        else {
            return nil
        }

        return self.currentLatencyMeasurementJobKey(
            currentGroup: referencedGroup.name,
            proxyName: nestedNode,
            proxyGroupsByName: proxyGroupsByName,
            proxyNodeIDs: proxyNodeIDs,
            groupJobs: groupJobs,
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

    private func directLatencyTestNodes(
        in group: ProxyGroup,
        proxyGroupsByName: [String: ProxyGroup],
        proxyNodeIDs: [String: String]) -> [String]
    {
        var seenDelayKeys: Set<String> = []

        return group.all.compactMap { candidate in
            guard proxyGroupsByName[candidate] == nil else { return nil }

            let delayKey = self.proxyDelayLookupKey(nodeName: candidate, proxyNodeIDs: proxyNodeIDs)
            guard seenDelayKeys.insert(delayKey).inserted else { return nil }
            return candidate
        }
    }

    private func proxyDelayLookupKey(nodeName: String, proxyNodeIDs: [String: String]) -> String {
        proxyNodeIDs[nodeName] ?? nodeName
    }
}
