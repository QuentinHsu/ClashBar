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

    private var connectionRowPresentationResolver: ConnectionRowPresentationResolver {
        ConnectionRowPresentationResolver(
            ruleResolver: self.connectionRulePresentationResolver,
            layoutResolver: self.connectionsTopLineLayoutResolver,
            rowContentWidth: ConnectionsLayout.rowContentWidth,
            minimumRuleWidth: ConnectionsLayout.topRuleMinWidth,
            minimumPayloadWidth: ConnectionsLayout.topPayloadMinWidth,
            measureRuleWidth: {
                self.connectionsMonospacedTextWidth(
                    $0,
                    size: MenuBarLayoutTokens.FontSize.caption,
                    weight: .semibold)
            },
            measurePayloadWidth: {
                self.connectionsMonospacedTextWidth(
                    $0,
                    size: MenuBarLayoutTokens.FontSize.caption,
                    weight: .medium)
            },
            fallbackHostText: tr("ui.common.na"),
            formatTimeText: { self.connectionTimeOnly($0) },
            formatTrafficText: { ValueFormatter.bytesCompactNoSpace($0) })
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
            self.filterChipButton(
                title: tr("ui.network.source.local"),
                selected: remoteMachineStore.activeTarget.isLocal,
                action: {
                    guard !remoteMachineStore.activeTarget.isLocal else { return }
                    Task { await appSession.switchToMachineTarget(.local) }
                })

            ForEach(remoteMachineStore.machines) { machine in
                self.filterChipButton(
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
        let presentation = self.connectionRowPresentationResolver.resolve(conn)
        let model = self.connectionRowDisplayModel(conn, presentation: presentation)
        let resolvedHost = appSession.resolvedConnectionHost(for: conn)

        return ConnectionInteractiveRowView(
            model: model,
            actionLabels: .init(
                closeConnection: tr("ui.action.close_connection"),
                copyHost: tr("ui.action.copy_host"),
                copyConnectionID: tr("ui.action.copy_connection_id")),
            primaryLabel: self.nativePrimaryLabel,
            secondaryLabel: self.nativeSecondaryLabel,
            tertiaryLabel: self.nativeTertiaryLabel,
            infoColor: self.nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid),
            positiveColor: self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid),
            hoverFill: self.nativeHoverFill,
            onHoverChanged: { isHovering in
                self.connectionsViewModel.hoveredConnectionID = self.nextHovered(
                    current: self.connectionsViewModel.hoveredConnectionID,
                    target: conn.id,
                    isHovering: isHovering)
            },
            onClose: { Task { await appSession.closeConnection(id: conn.id) } },
            onCopyHost: resolvedHost.map { host in
                { appSession.copyConnectionHost(host) }
            },
            onCopyConnectionID: { appSession.copyConnectionID(conn.id) })
    }

    private func connectionRowDisplayModel(
        _ conn: ConnectionSummary,
        presentation: ConnectionRowPresentation) -> ConnectionRowDisplayModel
    {
        return ConnectionRowDisplayModel(
            id: conn.id,
            symbolName: presentation.visualStyle.symbolName,
            symbolColor: self.connectionVisualColor(presentation.visualStyle),
            hostText: presentation.hostText,
            ruleTypeText: presentation.ruleTypeText,
            rulePayloadText: presentation.rulePayloadText,
            hostWidth: presentation.layout.hostWidth,
            ruleWidth: presentation.layout.ruleWidth,
            payloadWidth: presentation.layout.payloadWidth,
            timeText: presentation.timeText,
            networkText: presentation.networkText,
            networkColor: self.connectionNetworkColor(presentation.networkStyle),
            upText: presentation.upText,
            downText: presentation.downText,
            chainParts: presentation.chainParts,
            hovered: self.connectionsViewModel.hoveredConnectionID == conn.id)
    }

    private func connectionNetworkColor(_ style: ConnectionNetworkStyle) -> Color {
        switch style {
        case .udp:
            nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .tcp:
            nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .other:
            nativeSecondaryLabel
        }
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

    private func connectionVisualColor(_ style: ConnectionVisualStyle) -> Color {
        switch style {
        case .google:
            nativePurple.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .apple:
            nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .github:
            nativeIndigo.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .twitter:
            nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .amazon:
            nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .udp:
            nativeTeal.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .tcp:
            nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .generic:
            nativeSecondaryLabel
        }
    }
}
