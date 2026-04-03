import Foundation

struct ProxyGroupsPresentation {
    let groups: [ProxyGroup]
    let history: [String: Int]
    let nodeTypes: [String: String]
    let nodeIDs: [String: String]
}

struct BuildProxyGroupsPresentationUseCase {
    func execute(
        response: ProxyGroupsResponse,
        proxyProviders: [String: ProviderDetail],
        fallbackProxyProviders: [String: ProviderDetail]) -> ProxyGroupsPresentation
    {
        let providerLookup = proxyProviders.isEmpty ? fallbackProxyProviders : proxyProviders
        let proxiesWithHealthcheckConfig = response.proxies.values.map { proxy in
            let provider = providerLookup[proxy.name]
            let resolvedTestURL = HealthcheckNormalization.normalizedURL(proxy.testUrl)
                ?? HealthcheckNormalization.normalizedURL(provider?.testUrl)
            let resolvedTimeout = HealthcheckNormalization.normalizedTimeout(proxy.timeout)
                ?? HealthcheckNormalization.normalizedTimeout(provider?.timeout)

            return ProxyGroup(
                id: proxy.id,
                name: proxy.name,
                type: proxy.type,
                now: proxy.now,
                all: proxy.all,
                providerName: proxy.providerName,
                alive: proxy.alive,
                testUrl: resolvedTestURL,
                timeout: resolvedTimeout,
                icon: proxy.icon,
                hidden: proxy.hidden,
                latestDelay: proxy.latestDelay)
        }

        let sortIndex = (response.proxies["GLOBAL"]?.all ?? []) + ["GLOBAL"]
        var sortIndexMap: [String: Int] = [:]
        for (index, name) in sortIndex.enumerated() where sortIndexMap[name] == nil {
            sortIndexMap[name] = index
        }

        let groups = proxiesWithHealthcheckConfig
            .enumerated()
            .filter { !$0.element.all.isEmpty }
            .sorted { lhs, rhs in
                let lhsOrder = sortIndexMap[lhs.element.name] ?? .max
                let rhsOrder = sortIndexMap[rhs.element.name] ?? .max

                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }

                return lhs.element.name.localizedCaseInsensitiveCompare(rhs.element.name) == .orderedAscending
            }
            .map(\.element)

        var history: [String: Int] = [:]
        var nodeTypes: [String: String] = [:]
        var nodeIDs: [String: String] = [:]
        for proxy in response.proxies.values {
            let trimmedID = proxy.id?.trimmedNonEmpty
            if let trimmedID {
                nodeIDs[proxy.name] = trimmedID
            }
            if proxy.all.isEmpty, let type = proxy.type.trimmedNonEmpty {
                nodeTypes[proxy.name] = type
            }
            if let latest = proxy.latestDelay {
                history[trimmedID ?? proxy.name] = latest
            }
        }

        return ProxyGroupsPresentation(groups: groups, history: history, nodeTypes: nodeTypes, nodeIDs: nodeIDs)
    }
}
