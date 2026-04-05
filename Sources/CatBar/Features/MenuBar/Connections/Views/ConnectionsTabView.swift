import AppKit
import SwiftUI

extension MenuBarRootView {
    private enum ConnectionsLayout {
        static let topLineSpacing: CGFloat = MenuBarLayoutTokens.space2
        static let topMetaSpacing: CGFloat = MenuBarLayoutTokens.space1
        static let secondLineSpacing: CGFloat = MenuBarLayoutTokens.space2
        static let rowLineHeight: CGFloat = 16
        static let topRuleMinWidth: CGFloat = 26
        static let topPayloadMinWidth: CGFloat = 14
        /// Width of the content VStack inside each connection row (static — panel is fixed 360pt)
        /// = panelWidth - panelContentHPad*2 - rowHPad*2 - leadingIcon - hstackGaps - closeButton
        /// = 360 - 16 - 8 - 16 - 12 - 12 = 296
        static let rowContentWidth: CGFloat =
            MenuBarLayoutTokens.panelWidth
                - (MenuBarLayoutTokens.space8 * 2) // panelContent horizontal padding
                - (MenuBarLayoutTokens.space4 * 2)
                - MenuBarLayoutTokens.rowLeadingIcon
                - (MenuBarLayoutTokens.space6 * 2)
                - 12
    }

    private static var textWidthCache: [String: CGFloat] = [:]

    private var connectionRulePresentationResolver: ConnectionRulePresentationResolver {
        ConnectionRulePresentationResolver()
    }

    private var connectionsTopLineLayoutResolver: ConnectionsTopLineLayoutResolver {
        ConnectionsTopLineLayoutResolver(
            topLineSpacing: ConnectionsLayout.topLineSpacing,
            topMetaSpacing: ConnectionsLayout.topMetaSpacing,
            minimumHostWidthRatio: 0.5,
            minimumRuleWidth: ConnectionsLayout.topRuleMinWidth,
            minimumPayloadWidth: ConnectionsLayout.topPayloadMinWidth)
    }

    @ViewBuilder
    var connectionsTabBody: some View {
        let connections = self.connectionsViewModel.visibleConnections

        if connections.isEmpty {
            emptyCard(tr("ui.empty.connections"))
        } else {
            VStack(spacing: 0) {
                ForEach(connections, id: \.id) { conn in
                    self.connectionRow(conn)
                }
            }
        }
    }

    var connectionsControlCard: some View {
        VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space4) {
            if !remoteMachineStore.machines.isEmpty {
                self.connectionsSourceChips
            }

            HStack(spacing: MenuBarLayoutTokens.space6) {
                self.connectionsFilterMenu
                self.connectionsSortMenu

                Spacer(minLength: 0)

                self.fractionSummaryBadge(
                    current: self.connectionsViewModel.visibleConnections.count,
                    total: min(self.connectionsStore.connections.count, 120))

                self.compactTopIcon(
                    "xmark",
                    label: tr("ui.action.close_all"),
                    warning: true)
                {
                    await appSession.closeAllConnections()
                }
                .help(tr("ui.action.close_all"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            NonActivatingTextField(
                placeholder: tr("ui.placeholder.filter_connection"),
                text: $connectionsViewModel.filterText,
                style: .roundedBorder,
                font: NSFont.monospacedSystemFont(
                    ofSize: MenuBarLayoutTokens.FontSize.body,
                    weight: .regular))
        }
        .menuRowPadding(vertical: MenuBarLayoutTokens.space4)
    }

    private var connectionsSourceChips: some View {
        HStack(spacing: MenuBarLayoutTokens.space2) {
            self.logFilterToggleButton(
                title: tr("ui.network.source.local"),
                selected: remoteMachineStore.activeTarget.isLocal,
                action: {
                    guard !remoteMachineStore.activeTarget.isLocal else { return }
                    Task { await appSession.switchToMachineTarget(.local) }
                })

            ForEach(remoteMachineStore.machines) { machine in
                self.logFilterToggleButton(
                    title: machine.name,
                    selected: remoteMachineStore.activeTargetID == machine.id,
                    action: {
                        guard remoteMachineStore.activeTargetID != machine.id else { return }
                        Task { await appSession.switchToMachineTarget(.remote(machine)) }
                    })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var connectionsFilterMenu: some View {
        self.compactSelectionMenu(.init(
            selection: self.connectionsViewModel.transportFilter,
            options: ConnectionsTransportFilter.allCases,
            symbol: "line.3.horizontal.decrease.circle",
            helpText: tr("ui.network.filter.transport"),
            optionTitle: { self.tr($0.titleKey) },
            onSelect: { self.connectionsViewModel.transportFilter = $0 }))
    }

    var connectionsSortMenu: some View {
        self.compactSelectionMenu(.init(
            selection: self.connectionsViewModel.sortOption,
            options: ConnectionsSortOption.allCases,
            symbol: "arrow.up.arrow.down",
            helpText: tr("ui.network.sort.label"),
            optionTitle: { self.tr($0.titleKey) },
            onSelect: { self.connectionsViewModel.sortOption = $0 }))
    }

    func refreshVisibleConnections() {
        self.connectionsViewModel.updateVisibleConnections(
            from: self.connectionsStore.connections,
            searchText: { connection in
                self.connectionRulePresentationResolver.searchText(for: connection)
            })
    }

    func connectionRow(_ conn: ConnectionSummary) -> some View {
        let visual = self.connectionVisual(for: conn)
        let hovered = self.connectionsViewModel.hoveredConnectionID == conn.id
        let hostText = conn.metadata?.host.trimmedNonEmpty
            ?? conn.metadata?.destinationIP.trimmedNonEmpty
            ?? tr("ui.common.na")
        let networkType = conn.metadata?.network.trimmedNonEmpty?.uppercased() ?? "--"
        let timeText = self.connectionTimeOnly(conn.start)
        let upText = ValueFormatter.bytesCompactNoSpace(conn.upload ?? 0)
        let downText = ValueFormatter.bytesCompactNoSpace(conn.download ?? 0)
        let parsedRule = self.connectionRulePresentationResolver.parseRule(conn.rule)
        let ruleTypeText = self.connectionRulePresentationResolver.ruleTypeText(
            raw: conn.rule,
            fallback: parsedRule?.type)
        let rulePayloadText = conn.rulePayload.trimmedNonEmpty
            ?? parsedRule?.payload.trimmedNonEmpty
            ?? "--"

        return HStack(alignment: .center, spacing: MenuBarLayoutTokens.space6) {
            Image(systemName: visual.symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                .foregroundStyle(visual.color)
                .frame(
                    width: MenuBarLayoutTokens.rowLeadingIcon,
                    height: MenuBarLayoutTokens.rowLeadingIcon,
                    alignment: .center)

            VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space2) {
                self.connectionRowTopLine(host: hostText, ruleType: ruleTypeText, rulePayload: rulePayloadText)
                self.connectionRowMetrics(time: timeText, network: networkType, up: upText, down: downText)
                self.connectionsChainsLine(parts: self.connectionRulePresentationResolver.chainsParts(conn.chains))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            self.connectionRowCloseButton(id: conn.id, hovered: hovered)
        }
        .padding(.horizontal, MenuBarLayoutTokens.space4)
        .padding(.vertical, MenuBarLayoutTokens.space2)
        .background(nativeHoverRowBackground(hovered))
        .onHover { self.connectionsViewModel.hoveredConnectionID = self.nextHovered(
            current: self.connectionsViewModel.hoveredConnectionID, target: conn.id, isHovering: $0) }
        .contextMenu { self.connectionRowContextMenu(conn) }
    }

    private func connectionRowTopLine(host: String, ruleType: String, rulePayload: String) -> some View {
        // Use static rowContentWidth constant — no GeometryReader needed since panel is always 360pt
        let layout = self.connectionsTopLineLayoutResolver.resolve(
            totalWidth: ConnectionsLayout.rowContentWidth,
            desiredRuleWidth: max(
                ConnectionsLayout.topRuleMinWidth,
                self.connectionsMonospacedTextWidth(
                    ruleType,
                    size: MenuBarLayoutTokens.FontSize.caption,
                    weight: .semibold) + 4),
            desiredPayloadWidth: max(
                ConnectionsLayout.topPayloadMinWidth,
                self.connectionsMonospacedTextWidth(
                    rulePayload,
                    size: MenuBarLayoutTokens.FontSize.caption,
                    weight: .medium)))

        return HStack(spacing: ConnectionsLayout.topLineSpacing) {
            Text(host)
                .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: layout.hostWidth, alignment: .leading)

            HStack(spacing: ConnectionsLayout.topMetaSpacing) {
                self.connectionsTopBadge(text: ruleType)
                    .frame(width: layout.ruleWidth, alignment: .trailing)
                self.connectionsTopPayload(text: rulePayload)
                    .frame(width: layout.payloadWidth, alignment: .trailing)
            }
            .frame(
                width: layout.ruleWidth + ConnectionsLayout.topMetaSpacing + layout.payloadWidth,
                alignment: .trailing)
        }
        .frame(height: ConnectionsLayout.rowLineHeight)
    }

    private func connectionRowMetrics(time: String, network: String, up: String, down: String) -> some View {
        return HStack(spacing: 0) {
            // Left: time · network (plain text, no icons)
            Text(time.isEmpty ? tr("ui.common.na") : time)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                .foregroundStyle(nativeSecondaryLabel)

            Text(" · ")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                .foregroundStyle(nativeTertiaryLabel)

            Text(network.isEmpty ? tr("ui.common.na") : network)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(self.connectionNetworkColor(network))

            Spacer(minLength: MenuBarLayoutTokens.space4)

            // Right: ↑upload ↓download
            HStack(spacing: MenuBarLayoutTokens.space4) {
                HStack(spacing: 0) {
                    Image(systemName: "arrow.up")
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid))
                    Text(up)
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                        .foregroundStyle(nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid))
                }
                HStack(spacing: 0) {
                    Image(systemName: "arrow.down")
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid))
                    Text(down)
                        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                        .foregroundStyle(nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid))
                }
            }
        }
        .frame(height: ConnectionsLayout.rowLineHeight)
    }

    private func connectionNetworkColor(_ network: String) -> Color {
        switch network.uppercased() {
        case "UDP": return nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
        case "TCP": return nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid)
        default: return nativeSecondaryLabel
        }
    }

    private func connectionRowCloseButton(id: String, hovered: Bool) -> some View {
        Button {
            Task { await appSession.closeConnection(id: id) }
        } label: {
            Image(systemName: "xmark")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .frame(width: 10, height: 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(hovered ? nativeSecondaryLabel : nativeTertiaryLabel)
        .frame(width: 12, height: 12)
        .opacity(hovered ? 1 : 0)
    }

    @ViewBuilder
    private func connectionRowContextMenu(_ conn: ConnectionSummary) -> some View {
        Button(role: .destructive) {
            Task { await appSession.closeConnection(id: conn.id) }
        } label: {
            Label(tr("ui.action.close_connection"), systemImage: "xmark.circle")
        }

        if let host = appSession.resolvedConnectionHost(for: conn) {
            Button {
                appSession.copyConnectionHost(host)
            } label: {
                Label(tr("ui.action.copy_host"), systemImage: "doc.on.doc")
            }
        }

        Button {
            appSession.copyConnectionID(conn.id)
        } label: {
            Label(tr("ui.action.copy_connection_id"), systemImage: "number")
        }
    }

    func connectionsMetricColumn(
        symbol: String,
        text: String,
        symbolColor: Color = .secondary,
        textColor: Color = .secondary,
        fallback: String? = nil,
        spacing: CGFloat = MenuBarLayoutTokens.space2,
        truncation: Text.TruncationMode = .middle,
        width: CGFloat) -> some View
    {
        let renderedText = text.isEmpty ? (fallback ?? "") : text

        return HStack(spacing: spacing) {
            Image(systemName: symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(symbolColor)
                .frame(width: 10, alignment: .leading)
            Text(renderedText)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(truncation)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
    }

    func connectionsTopBadge(text: String) -> some View {
        Text(text)
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            .foregroundStyle(nativeSecondaryLabel)
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
            .padding(.horizontal, MenuBarLayoutTokens.space2)
            .padding(.vertical, MenuBarLayoutTokens.space1)
            .background(nativeBadgeCapsule())
    }

    func connectionsTopPayload(text: String) -> some View {
        Text(text)
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
            .foregroundStyle(nativeSecondaryLabel)
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    func connectionsChainsLine(parts: [String]) -> some View {
        let chainText = parts.joined(separator: " › ")
        let displayText = parts.isEmpty ? tr("ui.common.na") : chainText

        return Text(displayText)
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
            .foregroundStyle(nativeSecondaryLabel)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: ConnectionsLayout.rowLineHeight, alignment: .leading)
    }

    func connectionsMonospacedTextWidth(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let cacheKey = "\(text)\0\(size)\0\(weight.rawValue)"
        if let cached = Self.textWidthCache[cacheKey] {
            return cached
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: weight),
        ]
        let width = ceil((text as NSString).size(withAttributes: attributes).width)
        Self.textWidthCache[cacheKey] = width
        return width
    }

    func connectionTimeOnly(_ input: String?) -> String {
        let full = ValueFormatter.dateTimeFromISO(input)
        guard full != "--" else { return full }
        return full.split(separator: " ").last.map(String.init) ?? full
    }

    func connectionVisual(for conn: ConnectionSummary) -> (symbol: String, color: Color) {
        let host = conn.metadata?.host?.lowercased() ?? ""
        let network = conn.metadata?.network?.lowercased() ?? ""

        if host.contains("google") || host.contains("gstatic") {
            return ("shield.fill", nativePurple.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("icloud") || host.contains("apple") {
            return ("icloud.fill", nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("github") {
            return ("terminal.fill", nativeIndigo.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("twitter") || host.contains("x.com") {
            return ("lock.fill", nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if host.contains("amazon") {
            return ("cart.fill", nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if network.contains("udp") {
            return ("dot.radiowaves.left.and.right", nativeTeal.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        if network.contains("tcp") {
            return ("network", nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid))
        }
        return ("globe", nativeSecondaryLabel)
    }
}
