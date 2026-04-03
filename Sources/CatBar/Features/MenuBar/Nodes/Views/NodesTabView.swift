import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

extension MenuBarRootView {
    var nodesTabBody: some View {
        VStack(alignment: .leading, spacing: T.space6) {
            self.nodesSearchBar
            self.remoteNodesSection
            self.nodesLocalSection()
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var nodesSearchBar: some View {
        HStack(spacing: T.space4) {
            TextField(tr("ui.nodes.search_placeholder"), text: $nodesViewModel.searchText)
                .font(.app(size: T.FontSize.body, weight: .regular))
                .textFieldStyle(.plain)
                .foregroundStyle(nativePrimaryLabel)

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

    private var remoteNodesSection: some View {
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
                        self.nodesProviderBlock(name: name, detail: appSession.proxyProvidersDetail[name])
                    }
                }
            }
        }
    }

    private func nodesProviderBlock(name: String, detail: ProviderDetail?) -> some View {
        let nodeCount = detail?.proxies?.count ?? 0
        let isUpdating = appSession.providerUpdating.contains(name)
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

        return AttachedPopoverMenu { isHovered in
            VStack(alignment: .leading, spacing: hasSubscription ? T.space4 : 0) {
                HStack(alignment: .center, spacing: T.space6) {
                    Text(name)
                        .font(.app(size: T.FontSize.body, weight: .semibold))
                        .foregroundStyle(nativePrimaryLabel)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Text("\(nodeCount)")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeSecondaryLabel)
                        .padding(.horizontal, T.space4)
                        .padding(.vertical, T.space1)
                        .background(nativeBadgeCapsule())

                    Text(updatedText)
                        .font(.app(size: T.FontSize.caption, weight: .regular))
                        .foregroundStyle(nativeTertiaryLabel)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)

                    Spacer(minLength: T.space4)

                    self.providerActionButton(.refresh, isLoading: isUpdating) {
                        await appSession.updateProxyProvider(name: name)
                    }
                    .frame(width: 18, alignment: .center)

                    Image(systemName: "chevron.right")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeTertiaryLabel)
                        .frame(width: T.space8, alignment: .trailing)
                }

                if hasSubscription {
                    VStack(alignment: .leading, spacing: T.space2) {
                        HStack(spacing: 0) {
                            Text(expireText)
                                .font(.app(size: T.FontSize.caption, weight: .regular))
                                .foregroundStyle(expireColor)

                            Spacer(minLength: T.space4)

                            if let upload, let download, let total {
                                let used = upload + download
                                let quotaText =
                                    "\(ValueFormatter.bytesCompactNoSpace(used)) / " +
                                    "\(ValueFormatter.bytesCompactNoSpace(total))"
                                Text(quotaText)
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
                }
            }
            .padding(.horizontal, T.space4)
            .padding(.vertical, T.space6)
            .background(nativeHoverRowBackground(isHovered))
        } content: { _ in
            self.popoverHeader(name: name, count: nodeCount) {
                EmptyView()
            } trailing: {
                self.providerActionButton(.refresh, isLoading: isUpdating) {
                    await appSession.updateProxyProvider(name: name)
                }
                .frame(width: 18, alignment: .center)
            }

            if hasSubscription {
                VStack(alignment: .leading, spacing: T.space2) {
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

            self.nodesProviderExpandedContent(detail: detail)
        }
        .contextMenu {
            Button(tr("ui.action.refresh")) {
                Task { await appSession.updateProxyProvider(name: name) }
            }
        }
    }

    private func nodesProviderExpandedContent(detail: ProviderDetail?) -> some View {
        let allNodes = detail?.proxies ?? []
        let filtered = nodesViewModel.filteredProviderNodes(allNodes, searchText: nodesViewModel.searchText)

        if filtered.isEmpty {
            return AnyView(
                Text(nodesViewModel.searchText.isEmpty ? tr("ui.common.na") : tr("ui.nodes.no_match"))
                    .font(.app(size: T.FontSize.caption, weight: .regular))
                    .foregroundStyle(nativeSecondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, T.space6)
                    .padding(.vertical, T.space4)
            )
        }

        return AnyView(
            VStack(spacing: 0) {
                ForEach(filtered, id: \.stableIdentity) { node in
                    self.nodesProviderNodeRow(
                        node: node,
                        testUrl: detail?.testUrl,
                        timeout: detail?.timeout)
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
            isTesting: isTesting)
        {
            await self.testNodeLatency(nodeName: node.name, testUrl: testUrl, timeout: timeout)
        }
    }

    func nodesLocalSection() -> some View {
        let allLocal = nodesViewModel.buildLocalNodes(
            proxyNodeIDs: appSession.proxyNodeIDs,
            proxyNodeTypes: appSession.proxyNodeTypes,
            proxyProvidersDetail: appSession.proxyProvidersDetail)
        let filtered = nodesViewModel.filteredLocalNodes(allLocal, searchText: nodesViewModel.searchText)

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
            isTesting: isTesting)
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
    let onTest: () async -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: T.space4) {
            Text(self.name)
                .font(.app(size: T.FontSize.body, weight: .medium))
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(T.minimumScale)

            Spacer(minLength: 0)

            if let typeText = self.typeText {
                Text(typeText)
                    .font(.app(size: T.FontSize.caption, weight: .medium))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, T.space4)
                    .padding(.vertical, T.space1)
                    .background(
                        RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.1)))
            }

            Group {
                if self.isTesting {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text(self.delayText)
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(self.delayColor)
                        .lineLimit(1)
                }
            }
            .frame(width: 50, alignment: .trailing)

            Button {
                Task { await self.onTest() }
            } label: {
                Image(systemName: "bolt.horizontal")
                    .font(.app(size: T.FontSize.caption, weight: .semibold))
                    .foregroundStyle(
                        self.isHovered
                            ? Color(nsColor: .systemTeal).opacity(T.Opacity.solid)
                            : Color(nsColor: .secondaryLabelColor))
                    .frame(width: T.rowLeadingIcon, height: T.rowLeadingIcon)
            }
            .buttonStyle(.borderless)
            .disabled(self.isTesting)
            .onHover { self.isHovered = $0 }
            .help("Test Latency")
        }
        .frame(height: T.compactRowHeight)
        .padding(.horizontal, T.space6)
        .padding(.vertical, T.space1)
    }
}
