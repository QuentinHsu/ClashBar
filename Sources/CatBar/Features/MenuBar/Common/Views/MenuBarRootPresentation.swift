import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

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

    var statusColor: Color {
        switch appSession.runtimeVisualStatus {
        case .runningHealthy: self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .runningDegraded: self.nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .starting: self.nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .failed: self.nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .stopped: self.nativeSecondaryLabel
        }
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
}
