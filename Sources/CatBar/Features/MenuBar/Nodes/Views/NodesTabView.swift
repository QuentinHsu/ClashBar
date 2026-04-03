import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

extension MenuBarRootView {
    var nodesTabBody: some View {
        VStack(alignment: .leading, spacing: T.space6) {
            remoteNodesSection
            localNodesSection
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Remote Nodes (Proxy Providers)

    private var remoteNodesSection: some View {
        let providers = appSession.sortedProxyProviderNames

        return VStack(alignment: .leading, spacing: T.space6) {
            self.nodesSectionHeader(
                tr("ui.section.remote_nodes"),
                count: "\(providers.count)")

            if providers.isEmpty {
                emptyCard(tr("ui.empty.remote_nodes"))
            } else {
                VStack(spacing: T.space2) {
                    ForEach(providers, id: \.self) { name in
                        self.proxyProviderRow(name: name, detail: appSession.proxyProvidersDetail[name])
                    }
                }
            }
        }
    }

    // MARK: - Local Nodes

    private var localNodesSection: some View {
        let localNodes = self.computeLocalNodes()

        return VStack(alignment: .leading, spacing: T.space6) {
            self.nodesSectionHeader(
                tr("ui.section.local_nodes"),
                count: "\(localNodes.count)")

            if localNodes.isEmpty {
                emptyCard(tr("ui.empty.local_nodes"))
            } else {
                VStack(spacing: T.space2) {
                    ForEach(localNodes, id: \.name) { node in
                        self.localNodeRow(node)
                    }
                }
            }
        }
    }

    private static let builtinProxyNames: Set<String> = [
        "DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE",
    ]

    private func computeLocalNodes() -> [LocalNodeItem] {
        let providerNodeNames: Set<String> = {
            var names = Set<String>()
            for detail in appSession.proxyProvidersDetail.values {
                if let proxies = detail.proxies {
                    for proxy in proxies {
                        names.insert(proxy.name)
                    }
                }
            }
            return names
        }()

        return appSession.proxyNodeTypes
            .filter { !providerNodeNames.contains($0.key) && !Self.builtinProxyNames.contains($0.key.uppercased()) }
            .map { LocalNodeItem(name: $0.key, type: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func localNodeRow(_ node: LocalNodeItem) -> some View {
        let delayValue = appSession.proxyHistoryLatestDelay[node.name]
        let delayText: String = {
            guard let value = delayValue, value > 0 else { return "-" }
            return "\(value) ms"
        }()
        let hovered = hoveredLocalNodeName == node.name

        return HStack(alignment: .center, spacing: T.space6) {
            VStack(alignment: .leading, spacing: T.space1) {
                Text(node.name)
                    .font(.app(size: T.FontSize.body, weight: .semibold))
                    .foregroundStyle(nativePrimaryLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(node.type)
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(nativeSecondaryLabel)
                .padding(.horizontal, T.space4)
                .padding(.vertical, T.space1)
                .background(nativeBadgeCapsule())

            Text(delayText)
                .font(.app(size: T.FontSize.caption, weight: .regular))
                .foregroundStyle(latencyColor(delayValue))
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, T.space4)
        .padding(.vertical, T.space6)
        .background(nativeHoverRowBackground(hovered))
        .onHover { hoveredLocalNodeName = self.nextHovered(
            current: hoveredLocalNodeName,
            target: node.name,
            isHovering: $0) }
    }
}

struct LocalNodeItem: Equatable {
    let name: String
    let type: String
}
