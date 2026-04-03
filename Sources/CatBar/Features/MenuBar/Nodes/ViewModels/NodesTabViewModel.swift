import Foundation
import SwiftUI

@MainActor
final class NodesTabViewModel: ObservableObject {
    @Published var nodeTestingInProgress: Set<String> = []
    @Published var expandedProviders: Set<String> = []
    @Published var searchText: String = ""

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

    func toggleProvider(_ name: String) {
        if self.expandedProviders.contains(name) {
            self.expandedProviders.remove(name)
        } else {
            self.expandedProviders.insert(name)
        }
    }

    func buildLocalNodes(
        proxyNodeIDs: [String: String],
        proxyNodeTypes: [String: String],
        proxyProvidersDetail: [String: ProviderDetail]) -> [LocalNode]
    {
        var providerNodeNames: Set<String> = []
        for (_, detail) in proxyProvidersDetail {
            if let proxies = detail.proxies {
                for proxy in proxies {
                    providerNodeNames.insert(proxy.name)
                }
            }
        }

        let groupTypes: Set<String> = [
            "Selector", "URLTest", "Fallback", "LoadBalance", "Relay",
            "Direct", "Reject", "RejectDrop", "Pass", "Dns",
            "DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE",
        ]

        return proxyNodeTypes
            .filter { name, type in
                !providerNodeNames.contains(name) && !groupTypes.contains(type)
            }
            .map { LocalNode(id: proxyNodeIDs[$0.key], name: $0.key, type: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func filteredProviderNodes(_ nodes: [ProviderProxyNode], searchText: String) -> [ProviderProxyNode] {
        guard !searchText.isEmpty else { return nodes }
        let lowered = searchText.lowercased()
        return nodes.filter { node in
            node.name.lowercased().contains(lowered)
                || (node.type?.lowercased().contains(lowered) ?? false)
        }
    }

    func filteredLocalNodes(_ nodes: [LocalNode], searchText: String) -> [LocalNode] {
        guard !searchText.isEmpty else { return nodes }
        let lowered = searchText.lowercased()
        return nodes.filter {
            $0.name.lowercased().contains(lowered) || $0.type.lowercased().contains(lowered)
        }
    }
}
