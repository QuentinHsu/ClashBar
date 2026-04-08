import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct MenuBarFilterChipPalette {
    let selectedFill: Color
    let selectedBorder: Color
    let selectedText: Color
    let normalText: Color
    let hoverFill: Color
}

struct MenuBarFilterChipButton: View {
    let title: String
    let selected: Bool
    let palette: MenuBarFilterChipPalette
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: self.action) {
            Text(self.title)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, T.space6)
                .padding(.vertical, T.space2)
                .foregroundStyle(self.selected ? self.palette.selectedText : self.palette.normalText)
                .background {
                    Capsule(style: .continuous)
                        .fill(self.selected ? self.palette.selectedFill : (self.isHovered ? self.palette.hoverFill : .clear))
                        .overlay {
                            if self.selected {
                                Capsule(style: .continuous)
                                    .stroke(self.palette.selectedBorder, lineWidth: T.stroke)
                            }
                        }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: self.isHovered)
        .animation(.snappy(duration: 0.16), value: self.selected)
    }
}

struct MenuBarFractionSummaryBadge: View {
    let current: Int
    let total: Int
    let primaryLabel: Color
    let secondaryLabel: Color
    let tertiaryLabel: Color
    let badgeFill: Color

    var body: some View {
        HStack(spacing: MenuBarLayoutTokens.space1) {
            Text("\(self.current)")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .bold))
                .foregroundStyle(self.primaryLabel)
            Text("/")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(self.tertiaryLabel)
            Text("\(self.total)")
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(self.secondaryLabel)
        }
        .padding(.horizontal, MenuBarLayoutTokens.space6)
        .padding(.vertical, MenuBarLayoutTokens.space2)
        .background(
            Capsule(style: .continuous)
                .fill(self.badgeFill))
    }
}

struct CompactSelectionMenuConfiguration<Option: Hashable & Identifiable> {
    let selection: Option
    let options: [Option]
    let symbol: String
    let helpText: String
    let optionTitle: (Option) -> String
    let onSelect: (Option) -> Void
}

struct CompactSelectionMenuButton<Option: Hashable & Identifiable>: View {
    let configuration: CompactSelectionMenuConfiguration<Option>

    var body: some View {
        Menu {
            ForEach(self.configuration.options) { option in
                Button {
                    self.configuration.onSelect(option)
                } label: {
                    if self.configuration.selection == option {
                        Label(self.configuration.optionTitle(option), systemImage: "checkmark")
                    } else {
                        Text(self.configuration.optionTitle(option))
                    }
                }
            }
        } label: {
            Label(
                self.configuration.optionTitle(self.configuration.selection),
                systemImage: self.configuration.symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .lineLimit(1)
        }
        .appBorderedButtonStyle()
        .controlSize(.small)
        .help(self.configuration.helpText)
    }
}

struct CompactTopIconButton: View {
    let symbol: String
    let label: String
    let tint: Color
    let baseTint: Color
    let role: ButtonRole?
    let isLoading: Bool
    let size: CGFloat
    let fontSize: CGFloat
    let hierarchicalSymbol: Bool
    let action: () async -> Void

    var body: some View {
        CompactAsyncIconButton(
            symbol: self.symbol,
            tint: self.tint,
            baseTint: self.baseTint,
            role: self.role,
            isLoading: self.isLoading,
            size: self.size,
            fontSize: self.fontSize,
            hierarchicalSymbol: self.hierarchicalSymbol,
            action: self.action)
            .accessibilityLabel(self.label)
    }
}

extension MenuBarRootView {
    var filterChipPalette: MenuBarFilterChipPalette {
        .init(
            selectedFill: self.nativeAccent.opacity(self.isDarkAppearance ? 0.10 : 0.045),
            selectedBorder: self.nativeAccent.opacity(self.isDarkAppearance ? 0.14 : 0.08),
            selectedText: self.nativePrimaryLabel.opacity(self.isDarkAppearance ? 0.96 : 0.88),
            normalText: self.nativeSecondaryLabel,
            hoverFill: self.nativeHoverFill.opacity(self.isDarkAppearance ? 0.06 : 0.035))
    }

    func filterChipButton(
        title: String,
        selected: Bool,
        action: @escaping () -> Void) -> some View
    {
        MenuBarFilterChipButton(
            title: title,
            selected: selected,
            palette: self.filterChipPalette,
            action: action)
    }

    func fractionSummaryBadge(current: Int, total: Int) -> some View {
        MenuBarFractionSummaryBadge(
            current: current,
            total: total,
            primaryLabel: self.nativePrimaryLabel,
            secondaryLabel: self.nativeSecondaryLabel,
            tertiaryLabel: self.nativeTertiaryLabel,
            badgeFill: self.nativeBadgeFill)
    }

    func compactSelectionMenu(
        _ configuration: CompactSelectionMenuConfiguration<some Hashable & Identifiable>) -> some View
    {
        CompactSelectionMenuButton(configuration: configuration)
    }

    func compactTopIcon(
        _ symbol: String,
        label: String,
        role: ButtonRole? = nil,
        warning: Bool = false,
        toneOverride: Color? = nil,
        isLoading: Bool = false,
        action: @escaping () async -> Void) -> some View
    {
        let tone: Color = if let toneOverride {
            toneOverride
        } else if warning {
            self.nativeCritical
        } else {
            self.nativeSecondaryLabel
        }

        return CompactTopIconButton(
            symbol: symbol,
            label: label,
            tint: tone.opacity(MenuBarLayoutTokens.Opacity.solid),
            baseTint: self.nativeSecondaryLabel,
            role: role,
            isLoading: isLoading,
            size: 20,
            fontSize: MenuBarLayoutTokens.FontSize.body,
            hierarchicalSymbol: false,
            action: action)
    }
}
