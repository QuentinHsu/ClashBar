import SwiftUI

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

extension MenuBarRootView {
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
