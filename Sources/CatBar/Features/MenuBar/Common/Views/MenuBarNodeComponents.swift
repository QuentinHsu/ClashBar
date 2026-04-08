import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

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
        .medium
    }

    private var typeHorizontalPadding: CGFloat {
        MenuBarLayoutTokens.space4
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
