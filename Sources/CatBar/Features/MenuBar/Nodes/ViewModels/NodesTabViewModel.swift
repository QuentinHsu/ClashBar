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

    func buildLocalNodes(
        proxyNodeIDs: [String: String],
        proxyNodeTypes: [String: String],
        proxyProvidersDetail: [String: ProviderDetail]) -> [LocalNode]
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

        return proxyNodeTypes
            .filter { name, type in
                let nodeID = proxyNodeIDs[name]
                return self.isLocalNodeCandidate(
                    name: name,
                    type: type,
                    id: nodeID,
                    providerNodeNames: providerNodeNames,
                    providerNodeIDs: providerNodeIDs)
            }
            .map { LocalNode(id: proxyNodeIDs[$0.key], name: $0.key, type: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    func filteredProviderNodes(_ nodes: [ProviderProxyNode], searchText: String) -> [ProviderProxyNode] {
        let keyword = self.normalizedSearchKeyword(searchText)
        guard let keyword else { return nodes }
        return nodes.filter { node in
            self.matchesSearchKeyword(keyword, values: [node.name, node.type ?? ""])
        }
    }

    func filteredLocalNodes(_ nodes: [LocalNode], searchText: String) -> [LocalNode] {
        let keyword = self.normalizedSearchKeyword(searchText)
        guard let keyword else { return nodes }
        return nodes.filter { node in
            self.matchesSearchKeyword(keyword, values: [node.name, node.type])
        }
    }

    private func normalizedSearchKeyword(_ searchText: String) -> String? {
        let keyword = searchText.trimmed.lowercased()
        return keyword.isEmpty ? nil : keyword
    }

    private func matchesSearchKeyword(_ keyword: String, values: [String]) -> Bool {
        values.contains { value in
            value.lowercased().contains(keyword)
        }
    }
}
