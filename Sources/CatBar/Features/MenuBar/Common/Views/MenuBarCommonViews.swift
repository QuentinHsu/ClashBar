import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct SeparatedForEach<Element: Equatable, ID: Hashable, RowContent: View>: View {
    private struct Item: Identifiable {
        let id: ID
        let element: Element
        let isLast: Bool
    }

    private let items: [Item]
    private let separator: Color
    private let content: (Element) -> RowContent

    init<Data: RandomAccessCollection>(
        data: Data,
        id idPath: KeyPath<Element, ID>,
        separator: Color,
        @ViewBuilder content: @escaping (Element) -> RowContent) where Data.Element == Element
    {
        let array = Array(data)
        self.items = array.enumerated().map { index, el in
            Item(id: el[keyPath: idPath], element: el, isLast: index == array.count - 1)
        }
        self.separator = separator
        self.content = content
    }

    var body: some View {
        ForEach(self.items) { item in
            self.content(item.element)
            if !item.isLast {
                Rectangle()
                    .fill(self.separator)
                    .frame(height: MenuBarLayoutTokens.stroke)
            }
        }
    }
}

struct MeasurementAwareVStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(alignment: HorizontalAlignment = .center, spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVStack(alignment: self.alignment, spacing: self.spacing) { self.content }
    }
}

enum MenuBarNodeRowVariant: Equatable {
    case plain
    case selectable(selected: Bool)

    var isSelected: Bool {
        switch self {
        case .plain:
            false
        case let .selectable(selected):
            selected
        }
    }

    var showsSelectionIndicator: Bool {
        switch self {
        case .plain:
            false
        case .selectable:
            true
        }
    }
}

enum MenuBarNodeMetricActionDisplay {
    case hidden
    case alwaysVisible
    case replacesMetricOnHover
}

struct MenuBarNodeRow: View {
    let title: String
    let typeText: String?
    let metricText: String
    let metricColor: Color
    let isMetricLoading: Bool
    let variant: MenuBarNodeRowVariant
    let metricActionDisplay: MenuBarNodeMetricActionDisplay
    let metricActionLabel: String?
    let metricActionTint: Color
    let metricActionBaseTint: Color
    let onPrimaryAction: (() -> Void)?
    let onMetricAction: (() -> Void)?

    @State private var isHovered = false

    private let metricColumnWidth: CGFloat = 56
    private let trailingActionWidth: CGFloat = MenuBarLayoutTokens.rowLeadingIcon
    private let selectionIndicatorWidth: CGFloat = 11
    private let typeColumnWidth: CGFloat = 68

    init(
        title: String,
        typeText: String?,
        metricText: String,
        metricColor: Color,
        isMetricLoading: Bool,
        variant: MenuBarNodeRowVariant,
        metricActionDisplay: MenuBarNodeMetricActionDisplay,
        metricActionLabel: String?,
        metricActionTint: Color = Color(nsColor: .systemTeal).opacity(T.Opacity.solid),
        metricActionBaseTint: Color = Color(nsColor: .secondaryLabelColor),
        onPrimaryAction: (() -> Void)?,
        onMetricAction: (() -> Void)?)
    {
        self.title = title
        self.typeText = typeText
        self.metricText = metricText
        self.metricColor = metricColor
        self.isMetricLoading = isMetricLoading
        self.variant = variant
        self.metricActionDisplay = metricActionDisplay
        self.metricActionLabel = metricActionLabel
        self.metricActionTint = metricActionTint
        self.metricActionBaseTint = metricActionBaseTint
        self.onPrimaryAction = onPrimaryAction
        self.onMetricAction = onMetricAction
    }

    var body: some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            if self.variant.showsSelectionIndicator {
                Image(systemName: self.variant.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.app(size: T.FontSize.caption, weight: .semibold))
                    .foregroundStyle(
                        self.variant.isSelected
                            ? Color(nsColor: .controlAccentColor)
                            : Color(nsColor: .tertiaryLabelColor))
                    .frame(width: self.selectionIndicatorWidth, alignment: .center)
                    .padding(.trailing, MenuBarLayoutTokens.space2)
            }

            Text(self.title)
                .font(.app(size: T.FontSize.body, weight: self.titleWeight))
                .foregroundStyle(self.titleColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let typeText = self.normalizedTypeText {
                Text(typeText)
                    .font(.app(size: T.FontSize.caption, weight: self.typeWeight))
                    .foregroundStyle(self.typeColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, self.typeHorizontalPadding)
                    .padding(.vertical, MenuBarLayoutTokens.space1)
                    .background(self.typeBackground)
                    .frame(width: self.typeColumnWidth, alignment: .leading)
            }

            self.metricContent
                .frame(width: self.metricColumnWidth, alignment: .trailing)

            if self.showsTrailingActionColumn {
                self.metricActionButton(iconOnly: true)
                    .frame(width: self.trailingActionWidth, height: self.trailingActionWidth, alignment: .center)
            }
        }
            .frame(height: MenuBarLayoutTokens.compactRowHeight)
            .padding(.horizontal, self.horizontalPadding)
            .padding(.vertical, MenuBarLayoutTokens.space1)
            .background(
                RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                    .fill(self.rowBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                self.onPrimaryAction?()
            }
            .onHover { self.isHovered = $0 }
    }

    private var metricContent: some View {
        Group {
            if self.isMetricLoading {
                MenuBarNodeRowLoadingIndicator()
            } else if self.metricActionDisplay == .replacesMetricOnHover, self.isHovered, self.onMetricAction != nil {
                self.metricActionButton(iconOnly: false)
            } else {
                Text(self.metricText)
                    .font(.app(size: T.FontSize.caption, weight: self.metricFontWeight))
                    .foregroundStyle(self.metricColor.opacity(self.variant.isSelected ? 1 : self.metricOpacity))
                    .lineLimit(1)
                    .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
            }
        }
    }

    @ViewBuilder
    private func metricActionButton(iconOnly: Bool) -> some View {
        if let onMetricAction {
            LatencyTestIconButton(
                label: self.metricActionLabel ?? "",
                tint: self.metricActionTint,
                baseTint: self.metricActionBaseTint,
                size: iconOnly ? self.trailingActionWidth : 14,
                action: onMetricAction)
        } else if iconOnly {
            Color.clear
        } else {
            EmptyView()
        }
    }

    private var showsTrailingActionColumn: Bool {
        self.metricActionDisplay == .alwaysVisible
    }

    private var horizontalPadding: CGFloat {
        self.variant.showsSelectionIndicator ? MenuBarLayoutTokens.space4 : MenuBarLayoutTokens.space6
    }

    private var rowBackground: Color {
        if self.variant.isSelected {
            return Color(nsColor: .controlAccentColor).opacity(T.Opacity.tint)
        }
        if self.variant.showsSelectionIndicator, self.isHovered {
            return Color(nsColor: .selectedContentBackgroundColor).opacity(0.22)
        }
        return .clear
    }

    private var titleWeight: Font.Weight {
        self.variant.isSelected ? .semibold : .medium
    }

    private var titleColor: Color {
        switch self.variant {
        case .plain:
            Color(nsColor: .labelColor)
        case .selectable:
            self.variant.isSelected ? .primary : .secondary
        }
    }

    private var typeColor: Color {
        switch self.variant {
        case .plain:
            Color(nsColor: .secondaryLabelColor)
        case .selectable:
            self.variant.isSelected ? Color.primary.opacity(0.68) : Color.secondary.opacity(0.78)
        }
    }

    private var typeWeight: Font.Weight {
        switch self.variant {
        case .plain:
            .medium
        case .selectable:
            .medium
        }
    }

    private var typeHorizontalPadding: CGFloat {
        switch self.variant {
        case .plain, .selectable:
            MenuBarLayoutTokens.space4
        }
    }

    @ViewBuilder
    private var typeBackground: some View {
        switch self.variant {
        case .plain:
            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.1))
        case .selectable:
            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(self.variant.isSelected ? 0.18 : 0.1))
        }
    }

    private var metricFontWeight: Font.Weight {
        .semibold
    }

    private var metricOpacity: Double {
        self.variant.showsSelectionIndicator ? 0.94 : 1
    }

    private var normalizedTypeText: String? {
        self.typeText?.trimmedNonEmpty
    }
}

private struct MenuBarNodeRowLoadingIndicator: View {
    var body: some View {
        ProgressView()
            .controlSize(.mini)
            .frame(width: 30, height: 14, alignment: .center)
    }
}

struct LatencyTestIconButton: View {
    let label: String
    let tint: Color
    let baseTint: Color
    let isLoading: Bool
    let size: CGFloat
    let fontSize: CGFloat
    let action: () -> Void

    @State private var isHovered = false

    init(
        label: String,
        tint: Color,
        baseTint: Color,
        isLoading: Bool = false,
        size: CGFloat = MenuBarLayoutTokens.rowLeadingIcon,
        fontSize: CGFloat = T.FontSize.caption,
        action: @escaping () -> Void)
    {
        self.label = label
        self.tint = tint
        self.baseTint = baseTint
        self.isLoading = isLoading
        self.size = size
        self.fontSize = fontSize
        self.action = action
    }

    var body: some View {
        Button(action: self.action) {
            ZStack {
                Image(systemName: "bolt.horizontal")
                    .font(.app(size: self.fontSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(self.isHovered ? self.tint : self.baseTint)
                    .opacity(self.isLoading ? 0 : 1)

                ProgressView()
                    .controlSize(.mini)
                    .opacity(self.isLoading ? 1 : 0)
            }
            .frame(width: self.size, height: self.size, alignment: .center)
        }
        .buttonStyle(.borderless)
        .disabled(self.isLoading)
        .onHover { self.isHovered = $0 }
        .help(self.label)
    }
}

extension MenuBarRootView {
    var isDarkAppearance: Bool {
        self.colorScheme == .dark
    }

    var nativeAccent: Color {
        Color(nsColor: .controlAccentColor)
    }

    var nativeInfo: Color {
        Color(nsColor: .systemBlue)
    }

    var nativePositive: Color {
        Color(nsColor: .systemGreen)
    }

    var nativeWarning: Color {
        Color(nsColor: .systemOrange)
    }

    var nativeCritical: Color {
        Color(nsColor: .systemRed)
    }

    var nativeTeal: Color {
        Color(nsColor: .systemTeal)
    }

    var nativeIndigo: Color {
        Color(nsColor: .systemIndigo)
    }

    var nativePurple: Color {
        Color(nsColor: .systemPurple)
    }

    var nativePrimaryLabel: Color {
        Color(nsColor: .labelColor)
    }

    var nativeSecondaryLabel: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.labelSecondary : T.Theme.Light.labelSecondary)
    }

    var nativeTertiaryLabel: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.labelTertiary : T.Theme.Light.labelTertiary)
    }

    var nativeSeparator: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.separator : T.Theme.Light.separator)
    }

    var nativeControlFill: Color {
        Color(nsColor: self.isDarkAppearance ? .controlBackgroundColor : .windowBackgroundColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.controlFill : T.Theme.Light.controlFill)
    }

    var nativeControlBorder: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.controlBorder : T.Theme.Light.controlBorder)
    }

    var nativeHoverFill: Color {
        Color(nsColor: .selectedContentBackgroundColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.hoverFill : T.Theme.Light.hoverFill)
    }

    var nativeBadgeFill: Color {
        Color(nsColor: .quaternaryLabelColor).opacity(MenuBarLayoutTokens.Opacity.tint)
    }

    func nativeHoverRowBackground(
        _ hovered: Bool,
        cornerRadius: CGFloat = MenuBarLayoutTokens.cornerRadius) -> some View
    {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(hovered ? self.nativeHoverFill : .clear)
    }

    func nativeBadgeCapsule() -> some View {
        Capsule(style: .continuous)
            .fill(self.nativeBadgeFill)
    }

    func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .regular))
            .foregroundStyle(self.nativeSecondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .menuRowPadding()
    }

    var footerBar: some View {
        let mihomoRepositoryURL = URL(string: "https://github.com/MetaCubeX/mihomo")
        let mihomoSymbol = "cpu"

        return VStack(spacing: 0) {
            HStack(spacing: MenuBarLayoutTokens.space6) {
                HStack(spacing: MenuBarLayoutTokens.space6) {
                    self.footerInfo(
                        tr("ui.footer.core_mihomo", appSession.version),
                        url: mihomoRepositoryURL,
                        iconSystemName: mihomoSymbol)

                    self.footerCoreUpgradeControl
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                self.footerVersionInfo
                    .fixedSize(horizontal: true, vertical: false)
            }
            .menuRowPadding(vertical: MenuBarLayoutTokens.space2)
            .background(self.footerSurfaceBackground)
            .padding(.bottom, MenuBarLayoutTokens.space8)
        }
    }

    var footerSurfaceBackground: some View {
        RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
            .fill(self.nativeControlFill.opacity(self.isDarkAppearance ? 0.54 : 0.38))
            .overlay {
                RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                    .stroke(
                        self.nativeControlBorder.opacity(self.isDarkAppearance ? 0.40 : 0.12),
                        lineWidth: MenuBarLayoutTokens.stroke)
            }
    }

    @ViewBuilder
    func footerInfo(_ text: String, url: URL?, iconSystemName: String? = nil) -> some View {
        if let url {
            Link(destination: url) {
                self.footerInfoLabel(text, iconSystemName: iconSystemName)
            }
            .buttonStyle(.plain)
        } else {
            self.footerInfoLabel(text, iconSystemName: iconSystemName)
        }
    }

    func footerInfoLabel(_ text: String, iconSystemName: String?) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            if let iconSystemName {
                Image(systemName: iconSystemName)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                    .foregroundStyle(self.nativeSecondaryLabel)
            }

            Text(text)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(self.nativeSecondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
                .allowsTightening(true)
        }
        .help(text)
    }

    var footerCoreUpgradeControl: some View {
        self.compactAsyncIconButton(
            symbol: self.footerCoreUpgradeButtonSymbolName ?? "arrow.down.circle",
            label: self.footerCoreUpgradeButtonTitle,
            tint: self.footerCoreUpgradeButtonTint,
            baseTint: self.nativeSecondaryLabel,
            isLoading: self.appSession.isCoreUpgradeInFlight,
            size: 18,
            fontSize: MenuBarLayoutTokens.FontSize.caption,
            hierarchicalSymbol: true)
        {
            await self.appSession.upgradeCore()
        }
        .disabled(!self.isFooterCoreUpgradeEnabled)
        .help(self.footerCoreUpgradeButtonHelp)
    }

    var isFooterCoreUpgradeEnabled: Bool {
        self.appSession.isCoreUpgradeAvailable && !self.appSession.isCoreUpgradeInFlight
    }

    var footerCoreUpgradeButtonTitle: String {
        switch self.appSession.coreUpgradeState {
        case .idle:
            tr("ui.action.upgrade_core")
        case .running:
            tr("ui.footer.core_upgrade.running")
        case .succeeded:
            tr("ui.footer.core_upgrade.success")
        case .alreadyLatest:
            tr("ui.footer.core_upgrade.latest")
        case .failed:
            tr("ui.footer.core_upgrade.failed")
        }
    }

    var footerCoreUpgradeButtonSymbolName: String? {
        switch self.appSession.coreUpgradeState {
        case .idle:
            "arrow.down.circle"
        case .running:
            nil
        case .succeeded:
            "checkmark.circle.fill"
        case .alreadyLatest:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    var footerCoreUpgradeButtonTint: Color {
        switch self.appSession.coreUpgradeState {
        case .idle, .running:
            self.nativeAccent.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .succeeded, .alreadyLatest:
            self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .failed:
            self.nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid)
        }
    }

    var footerCoreUpgradeBackground: Color {
        switch self.appSession.coreUpgradeState {
        case .idle:
            self.nativeBadgeFill
        case .running:
            self.nativeAccent.opacity(MenuBarLayoutTokens.Opacity.tint)
        case .succeeded, .alreadyLatest:
            self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.tint)
        case .failed:
            self.nativeCritical.opacity(MenuBarLayoutTokens.Opacity.tint)
        }
    }

    var footerCoreUpgradeButtonHelp: String {
        if !self.appSession.isCoreUpgradeAvailable {
            return tr("ui.footer.core_upgrade.help.disabled")
        }

        switch self.appSession.coreUpgradeState {
        case .idle:
            return tr("ui.footer.core_upgrade.help")
        case .running:
            return tr("ui.footer.core_upgrade.help.running")
        case .succeeded:
            return tr("ui.footer.core_upgrade.help.success")
        case let .alreadyLatest(version):
            if let version, !version.isEmpty {
                return tr("ui.footer.core_upgrade.help.latest_version", version)
            }
            return tr("ui.footer.core_upgrade.help.latest")
        case let .failed(message):
            return tr("ui.footer.core_upgrade.help.failed", message)
        }
    }

    @ViewBuilder
    var footerVersionInfo: some View {
        if self.appSession.supportsInAppUpdates {
            Button {
                Task {
                    await self.appSession.checkForAppUpdates()
                }
            } label: {
                self.footerVersionBadge(
                    text: tr("ui.footer.version", self.appSession.currentAppVersionText),
                    symbol: "arrow.clockwise",
                    tint: self.nativeSecondaryLabel,
                    emphasized: false)
            }
            .buttonStyle(.plain)
            .help(tr("ui.footer.version_check_help"))
            .accessibilityLabel(tr(
                "ui.footer.version_check_accessibility",
                self.appSession.currentAppVersionText))
        } else if let update = self.appSession.availableAppUpdate {
            Link(destination: update.releaseURL) {
                self.footerVersionBadge(
                    text: tr("ui.footer.version", update.displayVersion),
                    symbol: "arrow.down.circle.fill",
                    tint: self.nativeAccent.opacity(MenuBarLayoutTokens.Opacity.solid),
                    emphasized: true)
            }
            .buttonStyle(.plain)
            .help(tr("ui.footer.version_update_help", update.displayVersion))
            .accessibilityLabel(tr(
                "ui.footer.version_update_accessibility",
                self.appSession.currentAppVersionText,
                update.displayVersion))
        } else if self.appSession.isLatestAppReleaseCheckInFlight {
            self.footerVersionBadge(
                text: tr("ui.footer.version", self.appSession.currentAppVersionText),
                symbol: "arrow.triangle.2.circlepath",
                tint: self.nativeSecondaryLabel,
                emphasized: false)
            .help(tr("ui.footer.version_check_running"))
        } else {
            Button {
                Task {
                    await self.appSession.checkForAppUpdates()
                }
            } label: {
                self.footerVersionBadge(
                    text: tr("ui.footer.version", self.appSession.currentAppVersionText),
                    symbol: "arrow.clockwise",
                    tint: self.nativeSecondaryLabel,
                    emphasized: false)
            }
            .buttonStyle(.plain)
            .help(tr("ui.footer.version_check_help"))
            .accessibilityLabel(tr(
                "ui.footer.version_check_accessibility",
                self.appSession.currentAppVersionText))
        }
    }

    func footerVersionBadge(text: String, symbol: String?, tint: Color, emphasized: Bool) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            }

            Text(text)
                .font(.app(
                    size: MenuBarLayoutTokens.FontSize.caption,
                    weight: emphasized ? .bold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, MenuBarLayoutTokens.space6)
        .padding(.vertical, MenuBarLayoutTokens.space2)
    }

    var statusColor: Color {
        switch appSession.runtimeVisualStatus {
        case .runningHealthy: self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .runningDegraded: self.nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .starting: self.nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .failed: self.nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .stopped: self.nativeSecondaryLabel
        }
    }

    var runtimeBadgeText: String {
        switch appSession.runtimeVisualStatus {
        case .runningHealthy, .runningDegraded:
            tr("ui.header.status.running")
        case .starting:
            tr("ui.header.status.starting")
        case .failed:
            tr("ui.header.status.failed")
        case .stopped:
            tr("ui.header.status.stopped")
        }
    }

    var appVersionText: String {
        self.appSession.currentAppVersionText
    }

    func orderedUniqueNames(_ names: [String]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        ordered.reserveCapacity(names.count)

        for name in names where !name.isEmpty {
            if seen.insert(name).inserted {
                ordered.append(name)
            }
        }

        return ordered
    }

    func compareLatency(lhs: Int?, rhs: Int?, ascending: Bool) -> ComparisonResult {
        let leftAvailable = self.isProxyNodeAvailable(lhs)
        let rightAvailable = self.isProxyNodeAvailable(rhs)

        if leftAvailable != rightAvailable {
            return leftAvailable ? .orderedAscending : .orderedDescending
        }

        guard leftAvailable, rightAvailable, let lhs, let rhs, lhs != rhs else {
            return .orderedSame
        }

        if ascending {
            return lhs < rhs ? .orderedAscending : .orderedDescending
        }
        return lhs > rhs ? .orderedAscending : .orderedDescending
    }

    func isProxyNodeAvailable(_ latency: Int?) -> Bool {
        guard let latency else { return false }
        return latency > 0
    }

    func latencyColor(_ value: Int?) -> Color {
        guard let value else {
            return self.nativeTertiaryLabel
        }
        if value == 0 { return self.nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid) }
        if value <= 400 { return self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid) }
        return self.nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
    }

    func sortedGroupNodes(_ group: ProxyGroup) -> [String] {
        self.sortedNodes(
            names: group.all,
            latencyForNode: { self.appSession.delayValue(group: group.name, node: $0) })
    }

    func defaultGroupNodes(_ group: ProxyGroup) -> [String] {
        let unique = self.orderedUniqueNames(group.all)
        guard self.appSession.hideUnavailableProxyNodes else { return unique }
        return unique.filter {
            self.isProxyNodeAvailable(self.appSession.delayValue(group: group.name, node: $0))
        }
    }

    private func sortedNodes(names: [String], latencyForNode: (String) -> Int?) -> [String] {
        let unique = self.orderedUniqueNames(names)
        let sorted = unique.sorted { lhs, rhs in
            let cmp = self.compareLatency(lhs: latencyForNode(lhs), rhs: latencyForNode(rhs), ascending: true)
            if cmp != .orderedSame { return cmp == .orderedAscending }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        guard self.appSession.hideUnavailableProxyNodes else { return sorted }
        return sorted.filter { self.isProxyNodeAvailable(latencyForNode($0)) }
    }

    func compactAsyncIconButton(
        symbol: String,
        label: String,
        tint: Color,
        baseTint: Color? = nil,
        role: ButtonRole? = nil,
        isLoading: Bool = false,
        size: CGFloat = 20,
        fontSize: CGFloat = MenuBarLayoutTokens.FontSize.body,
        hierarchicalSymbol: Bool = false,
        action: @escaping () async -> Void) -> some View
    {
        CompactAsyncIconButton(
            symbol: symbol,
            tint: tint,
            baseTint: baseTint ?? self.nativeSecondaryLabel,
            role: role,
            isLoading: isLoading,
            size: size,
            fontSize: fontSize,
            hierarchicalSymbol: hierarchicalSymbol,
            action: action)
            .accessibilityLabel(label)
    }
}

struct CompactAsyncIconButton: View {
    let symbol: String
    let tint: Color
    let baseTint: Color
    let role: ButtonRole?
    let isLoading: Bool
    let size: CGFloat
    let fontSize: CGFloat
    let hierarchicalSymbol: Bool
    let action: () async -> Void

    @State private var hovered = false

    var body: some View {
        Button(role: self.role) {
            Task { await self.action() }
        } label: {
            ZStack {
                Image(systemName: self.symbol)
                    .font(.app(size: self.fontSize, weight: .semibold))
                    .foregroundStyle(self.hovered ? self.tint : self.baseTint)
                    .symbolRenderingMode(self.hierarchicalSymbol ? .hierarchical : .monochrome)
                    .opacity(self.isLoading ? 0 : 1)

                ProgressView()
                    .controlSize(.mini)
                    .opacity(self.isLoading ? 1 : 0)
            }
            .frame(width: self.size, height: self.size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(self.isLoading)
        .onHover { self.hovered = $0 }
    }
}
