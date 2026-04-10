import Foundation
import SwiftUI

@MainActor
final class NodesTabViewModel: ObservableObject {
    @Published var nodeTestingInProgress: Set<String> = []
    @Published var providerTestingInProgress: Set<String> = []
    @Published var searchText: String = ""

    private static let reservedLocalNodeMarkers: Set<String> = [
        "SELECTOR", "URLTEST", "FALLBACK", "LOADBALANCE", "RELAY",
        "DIRECT", "REJECT", "REJECTDROP", "PASS", "DNS", "COMPATIBLE",
    ]

    struct LocalNode: Equatable, Hashable {
        let id: String?
        let name: String
        let type: String

        var stableIdentity: String {
            if let id = self.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
                return id
            }
            return self.name
        }
    }

    struct SearchMatcher {
        let keyword: String

        func matches(name: String, type: String?) -> Bool {
            if name.range(of: self.keyword, options: [.caseInsensitive]) != nil {
                return true
            }
            guard let type else { return false }
            return type.range(of: self.keyword, options: [.caseInsensitive]) != nil
        }
    }

    func buildLocalNodes(
        proxyNodeIDs: [String: String],
        proxyNodeTypes: [String: String],
        proxyProvidersDetail: [String: ProviderDetail]) -> [LocalNode]
    {
        self.buildPresentedLocalNodes(
            proxyNodeIDs: proxyNodeIDs,
            proxyNodeTypes: proxyNodeTypes,
            proxyProvidersDetail: proxyProvidersDetail,
            matcher: nil)
    }

    func buildPresentedLocalNodes(
        proxyNodeIDs: [String: String],
        proxyNodeTypes: [String: String],
        proxyProvidersDetail: [String: ProviderDetail],
        matcher: SearchMatcher?) -> [LocalNode]
    {
        var providerNodeNames: Set<String> = []
        var providerNodeIDs: Set<String> = []
        for (_, detail) in proxyProvidersDetail {
            if let proxies = detail.proxies {
                for proxy in proxies {
                    providerNodeNames.insert(proxy.name)
                    if let id = proxy.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
                        providerNodeIDs.insert(id)
                    }
                }
            }
        }

        var localNodes: [LocalNode] = []
        localNodes.reserveCapacity(proxyNodeTypes.count)

        for (name, type) in proxyNodeTypes {
            let nodeID = proxyNodeIDs[name]
            guard self.isLocalNodeCandidate(
                name: name,
                type: type,
                id: nodeID,
                providerNodeNames: providerNodeNames,
                providerNodeIDs: providerNodeIDs)
            else {
                continue
            }

            let node = LocalNode(id: nodeID, name: name, type: type)
            if let matcher, !self.matchesSearch(matcher, name: node.name, type: node.type) {
                continue
            }
            localNodes.append(node)
        }

        localNodes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return localNodes
    }

    private func isLocalNodeCandidate(
        name: String,
        type: String,
        id: String?,
        providerNodeNames: Set<String>,
        providerNodeIDs: Set<String>) -> Bool
    {
        if providerNodeNames.contains(name) {
            return false
        }

        if let id = id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty, providerNodeIDs.contains(id) {
            return false
        }

        if Self.isReservedLocalNodeMarker(name) || Self.isReservedLocalNodeMarker(type) {
            return false
        }

        return true
    }

    private static func isReservedLocalNodeMarker(_ value: String?) -> Bool {
        guard let marker = normalizedLocalNodeMarker(value) else { return false }
        return reservedLocalNodeMarkers.contains(marker)
    }

    private static func normalizedLocalNodeMarker(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedScalars = trimmed.unicodeScalars.filter(CharacterSet.alphanumerics.contains)
        let normalized = String(String.UnicodeScalarView(normalizedScalars)).uppercased()
        return normalized.isEmpty ? nil : normalized
    }

    func searchMatcher(for searchText: String) -> SearchMatcher? {
        let keyword = searchText.trimmed
        guard !keyword.isEmpty else { return nil }
        return SearchMatcher(keyword: keyword)
    }

    func filteredProviderNodes(_ nodes: [ProviderProxyNode], searchText: String) -> [ProviderProxyNode] {
        self.filteredProviderNodes(nodes, matcher: self.searchMatcher(for: searchText))
    }

    func filteredProviderNodes(_ nodes: [ProviderProxyNode], matcher: SearchMatcher?) -> [ProviderProxyNode] {
        guard let matcher else { return nodes }

        var filtered: [ProviderProxyNode] = []
        filtered.reserveCapacity(nodes.count)
        for node in nodes {
            if self.matchesSearch(matcher, name: node.name, type: node.type) {
                filtered.append(node)
            }
        }
        return filtered
    }

    func filteredLocalNodes(_ nodes: [LocalNode], searchText: String) -> [LocalNode] {
        self.filteredLocalNodes(nodes, matcher: self.searchMatcher(for: searchText))
    }

    func filteredLocalNodes(_ nodes: [LocalNode], matcher: SearchMatcher?) -> [LocalNode] {
        guard let matcher else { return nodes }

        var filtered: [LocalNode] = []
        filtered.reserveCapacity(nodes.count)
        for node in nodes {
            if self.matchesSearch(matcher, name: node.name, type: node.type) {
                filtered.append(node)
            }
        }
        return filtered
    }

    private func matchesSearch(_ matcher: SearchMatcher, name: String, type: String?) -> Bool {
        matcher.matches(name: name, type: type)
    }
}
