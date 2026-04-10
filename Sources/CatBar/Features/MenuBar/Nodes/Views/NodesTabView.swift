import AppKit
import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

extension MenuBarRootView {
    var nodesTabBody: some View {
        let searchMatcher = nodesViewModel.searchMatcher(for: nodesViewModel.searchText)

        return VStack(alignment: .leading, spacing: T.space6) {
            self.nodesSearchBar
            self.remoteNodesSection(searchMatcher: searchMatcher)
            self.nodesLocalSection(searchMatcher: searchMatcher)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var nodesSearchBar: some View {
        HStack(spacing: T.space4) {
            NonActivatingTextField(
                placeholder: tr("ui.nodes.search_placeholder"),
                text: $nodesViewModel.searchText,
                style: .plain,
                font: NSFont.monospacedSystemFont(ofSize: T.FontSize.body, weight: .regular))

            if !nodesViewModel.searchText.isEmpty {
                Button {
                    nodesViewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeTertiaryLabel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, T.space6)
        .padding(.vertical, T.space4)
        .background(
            RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                .fill(nativeControlFill.opacity(isDarkAppearance ? 0.54 : 0.38))
                .overlay {
                    RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                        .stroke(
                            nativeControlBorder.opacity(isDarkAppearance ? 0.40 : 0.12),
                            lineWidth: T.stroke)
                })
        .padding(.horizontal, T.space4)
    }

    private func remoteNodesSection(searchMatcher: NodesTabViewModel.SearchMatcher?) -> some View {
        let providers = appSession.sortedProxyProviderNames

        return VStack(alignment: .leading, spacing: T.space6) {
            self.nodesSectionHeader(
                tr("ui.section.remote_nodes"),
                count: "\(providers.count)")
            {
                self.nodesProvidersRefreshButton
            }

            if providers.isEmpty {
                emptyCard(tr("ui.empty.remote_nodes"))
            } else {
                VStack(alignment: .leading, spacing: T.space2) {
                    ForEach(providers, id: \.self) { name in
                        self.nodesProviderBlock(
                            name: name,
                            detail: appSession.proxyProvidersDetail[name],
                            searchMatcher: searchMatcher)
                    }
                }
            }
        }
    }

    private func nodesProviderBlock(
        name: String,
        detail: ProviderDetail?,
        searchMatcher: NodesTabViewModel.SearchMatcher?) -> some View
    {
        let nodeCount = detail?.proxies?.count ?? 0
        let isUpdating = appSession.providerUpdating.contains(name)
        let isTestingAllNodes = nodesViewModel.providerTestingInProgress.contains(name)
        let updatedText = ValueFormatter.dateTimeFromISO(detail?.updatedAt)
        let expireSeconds = detail?.subscriptionInfo?.expire
        let expireText = ValueFormatter.daysUntilExpiryShort(from: expireSeconds, language: language)
        let expireColor: Color = expireSeconds == 0 ? nativeSecondaryLabel : nativeWarning
        let upload = detail?.subscriptionInfo?.upload
        let download = detail?.subscriptionInfo?.download
        let total = detail?.subscriptionInfo?.total
        let hasSubscription = detail?.subscriptionInfo != nil
        let usedRatio: Double? = {
            guard let total, total > 0, let upload, let download else { return nil }
            let used = upload + download
            return min(max(Double(used) / Double(total), 0), 1)
        }()
        let filteredNodes = nodesViewModel.filteredProviderNodes(detail?.proxies ?? [], matcher: searchMatcher)
        let updatedTimeWidth: CGFloat = 118

        return AttachedPopoverMenu { isHovered in
            GeometryReader { geo in
                let columns = self.nodesProviderMainColumnWidths(
                    totalWidth: geo.size.width,
                    updatedTimeWidth: updatedTimeWidth)

                HStack(spacing: T.space1) {
                    HStack(alignment: .center, spacing: T.space4) {
                        Text(name)
                            .font(.app(size: T.FontSize.body, weight: .semibold))
                            .foregroundStyle(nativePrimaryLabel)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(T.minimumScale)
                            .frame(width: columns.name, alignment: .leading)

                        Text("\(nodeCount)")
                            .font(.app(size: T.FontSize.caption, weight: .semibold))
                            .foregroundStyle(nativeSecondaryLabel)
                            .padding(.horizontal, T.space4)
                            .padding(.vertical, T.space1)
                            .background(nativeBadgeCapsule())
                            .frame(width: columns.count, alignment: .leading)

                        Text(updatedText)
                            .font(.app(size: T.FontSize.caption, weight: .regular))
                            .foregroundStyle(nativeTertiaryLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(T.minimumScale)
                            .frame(width: columns.updatedAt, alignment: .trailing)

                        self.providerActionButton(.refresh, isLoading: isUpdating) {
                            await appSession.updateProxyProvider(name: name)
                        }
                        .frame(width: 18, alignment: .center)

                        Image(systemName: "chevron.right")
                            .font(.app(size: T.FontSize.caption, weight: .semibold))
                            .foregroundStyle(nativeTertiaryLabel)
                            .frame(width: T.space8, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .frame(height: T.compactRowHeight)
            .padding(.horizontal, T.space4)
            .padding(.vertical, T.space1)
            .background(nativeHoverRowBackground(isHovered))
        } content: { _ in
            self.popoverHeader(name: name, count: nodeCount) {
                EmptyView()
            } trailing: {
                self.providerActionButton(.healthcheck, isLoading: isTestingAllNodes) {
                    await self.testProviderNodesLatency(
                        providerName: name,
                        nodes: filteredNodes,
                        testUrl: detail?.testUrl,
                        timeout: detail?.timeout)
                }
                .frame(width: 18, alignment: .center)
                .disabled(filteredNodes.isEmpty)
            }

            if hasSubscription {
                VStack(alignment: .leading, spacing: T.space4) {
                    HStack(spacing: T.space4) {
                        Text(updatedText)
                            .font(.app(size: T.FontSize.caption, weight: .regular))
                            .foregroundStyle(nativeTertiaryLabel)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if let detail, let vehicleType = detail.vehicleType?.trimmedNonEmpty {
                            Text(vehicleType)
                                .font(.app(size: T.FontSize.caption, weight: .medium))
                                .foregroundStyle(nativeSecondaryLabel)
                                .padding(.horizontal, T.space4)
                                .padding(.vertical, T.space1)
                                .background(nativeBadgeCapsule())
                        }
                    }

                    HStack(spacing: T.space4) {
                        Text(expireText)
                            .font(.app(size: T.FontSize.caption, weight: .regular))
                            .foregroundStyle(expireColor)

                        Spacer(minLength: 0)

                        if let upload, let download, let total {
                            let used = upload + download
                            Text(
                                "\(ValueFormatter.bytesCompactNoSpace(used)) / " +
                                "\(ValueFormatter.bytesCompactNoSpace(total))"
                            )
                            .font(.app(size: T.FontSize.caption, weight: .regular))
                            .foregroundStyle(nativeSecondaryLabel)
                            .lineLimit(1)
                        }
                    }

                    if let usedRatio {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(nativeControlFill.opacity(T.Opacity.solid))
                                Capsule()
                                    .fill(
                                        (usedRatio >= 0.9
                                            ? nativeCritical
                                            : usedRatio >= 0.75 ? nativeWarning : nativeAccent
                                        ).opacity(T.Opacity.solid))
                                    .frame(width: geo.size.width * usedRatio)
                            }
                        }
                        .frame(height: T.space6)
                    }
                }
                .padding(.horizontal, T.space4)
                .padding(.bottom, T.space2)
            }

            self.nodesProviderExpandedContent(
                nodes: filteredNodes,
                searchText: nodesViewModel.searchText,
                testUrl: detail?.testUrl,
                timeout: detail?.timeout)
        }
        .contextMenu {
            Button(tr("ui.action.refresh")) {
                Task { await appSession.updateProxyProvider(name: name) }
            }
        }
    }

    private func nodesProviderMainColumnWidths(
        totalWidth: CGFloat,
        updatedTimeWidth: CGFloat) -> (name: CGFloat, count: CGFloat, updatedAt: CGFloat)
    {
        let actionWidth: CGFloat = 18
        let chevronWidth: CGFloat = T.space8
        let spacingCount: CGFloat = 4
        let spacing = T.space1 * spacingCount
        let countWidth: CGFloat = 42
        let available = max(
            0,
            totalWidth - countWidth - updatedTimeWidth - actionWidth - chevronWidth - spacing)
        let nameWidth = max(0, available)
        return (nameWidth, countWidth, updatedTimeWidth)
    }

    private func nodesProviderExpandedContent(
        nodes: [ProviderProxyNode],
        searchText: String,
        testUrl: String?,
        timeout: Int?) -> some View
    {
        if nodes.isEmpty {
            return AnyView(
                Text(searchText.isEmpty ? tr("ui.common.na") : tr("ui.nodes.no_match"))
                    .font(.app(size: T.FontSize.caption, weight: .regular))
                    .foregroundStyle(nativeSecondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, T.space6)
                    .padding(.vertical, T.space4)
            )
        }

        return AnyView(
            VStack(spacing: 0) {
                ForEach(nodes, id: \.stableIdentity) { node in
                    self.nodesProviderNodeRow(
                        node: node,
                        testUrl: testUrl,
                        timeout: timeout)
                }
            }
        )
    }

    private func nodesProviderNodeRow(
        node: ProviderProxyNode,
        testUrl: String?,
        timeout: Int?) -> some View
    {
        let isTesting = nodesViewModel.nodeTestingInProgress.contains(node.name)
        let delay = appSession.latestDelay(for: node.name, nodeID: node.id) ?? node.latestDelay
        let delayText = self.nodeDelayText(delay)
        let delayColor = latencyColor(delay)
        let nodeType = node.type?.trimmedNonEmpty ?? appSession.proxyNodeTypes[node.name]

        return NodesNodeRow(
            name: node.name,
            typeText: nodeType,
            delayText: delayText,
            delayColor: delayColor,
            isTesting: isTesting,
            metricActionLabel: tr("ui.action.test_latency"),
            metricActionTint: nativeTeal.opacity(T.Opacity.solid),
            metricActionBaseTint: nativeSecondaryLabel)
        {
            await self.testNodeLatency(nodeName: node.name, testUrl: testUrl, timeout: timeout)
        }
    }

    func nodesLocalSection(searchMatcher: NodesTabViewModel.SearchMatcher?) -> some View {
        let filtered = nodesViewModel.buildPresentedLocalNodes(
            proxyNodeIDs: appSession.proxyNodeIDs,
            proxyNodeTypes: appSession.proxyNodeTypes,
            proxyProvidersDetail: appSession.proxyProvidersDetail,
            matcher: searchMatcher)

        return VStack(alignment: .leading, spacing: T.space6) {
            self.nodesSectionHeader(
                tr("ui.section.local_nodes"),
                count: "\(filtered.count)")

            if filtered.isEmpty {
                emptyCard(
                    nodesViewModel.searchText.isEmpty
                        ? tr("ui.empty.local_nodes")
                        : tr("ui.nodes.no_match"))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered, id: \.stableIdentity) { node in
                        self.nodesLocalNodeRow(node)
                    }
                }
            }
        }
    }

    private func nodesLocalNodeRow(_ node: NodesTabViewModel.LocalNode) -> some View {
        let isTesting = nodesViewModel.nodeTestingInProgress.contains(node.name)
        let delay = appSession.latestDelay(for: node.name, nodeID: node.id)
        let delayText = self.nodeDelayText(delay)
        let delayColor = latencyColor(delay)

        return NodesNodeRow(
            name: node.name,
            typeText: node.type,
            delayText: delayText,
            delayColor: delayColor,
            isTesting: isTesting,
            metricActionLabel: tr("ui.action.test_latency"),
            metricActionTint: nativeTeal.opacity(T.Opacity.solid),
            metricActionBaseTint: nativeSecondaryLabel)
        {
            await self.testNodeLatency(nodeName: node.name, testUrl: nil, timeout: nil)
        }
    }

    private func testNodeLatency(nodeName: String, testUrl: String?, timeout: Int?) async {
        guard !nodesViewModel.nodeTestingInProgress.contains(nodeName) else { return }
        nodesViewModel.nodeTestingInProgress.insert(nodeName)
        defer { nodesViewModel.nodeTestingInProgress.remove(nodeName) }

        _ = await appSession.testSingleNodeLatency(
            nodeName: nodeName,
            testURL: testUrl,
            timeout: timeout)
    }

    private func testProviderNodesLatency(
        providerName: String,
        nodes: [ProviderProxyNode],
        testUrl: String?,
        timeout: Int?) async
    {
        guard !nodes.isEmpty else { return }
        guard !nodesViewModel.providerTestingInProgress.contains(providerName) else { return }

        nodesViewModel.providerTestingInProgress.insert(providerName)
        defer { nodesViewModel.providerTestingInProgress.remove(providerName) }

        for node in nodes {
            await self.testNodeLatency(nodeName: node.name, testUrl: testUrl, timeout: timeout)
        }
    }

    private var nodesProvidersRefreshButton: some View {
        self.compactTopIcon(
            "arrow.triangle.2.circlepath",
            label: tr("ui.action.refresh"),
            toneOverride: nativeInfo,
            isLoading: appSession.isProxyProvidersRefreshing)
        {
            await appSession.refreshProxyProviders()
        }
        .help(tr("ui.action.refresh"))
        .opacity(appSession.isProxyProvidersRefreshing ? 0.6 : 1)
    }

    func nodeDelayText(_ value: Int?) -> String {
        guard let value else { return tr("ui.common.unknown") }
        if value == 0 { return tr("ui.common.timeout") }
        return tr("ui.common.latency_ms", value)
    }
}

private struct NodesNodeRow: View {
    let name: String
    let typeText: String?
    let delayText: String
    let delayColor: Color
    let isTesting: Bool
    let metricActionLabel: String
    let metricActionTint: Color
    let metricActionBaseTint: Color
    let onTest: () async -> Void

    var body: some View {
        MenuBarNodeRow(
            title: self.name,
            typeText: self.typeText,
            metricText: self.delayText,
            metricColor: self.delayColor,
            isMetricLoading: self.isTesting,
            variant: .plain,
            metricActionDisplay: .alwaysVisible,
            metricActionLabel: self.metricActionLabel,
            metricActionTint: self.metricActionTint,
            metricActionBaseTint: self.metricActionBaseTint,
            onPrimaryAction: nil,
            onMetricAction: {
                Task { await self.onTest() }
            })
    }
}
