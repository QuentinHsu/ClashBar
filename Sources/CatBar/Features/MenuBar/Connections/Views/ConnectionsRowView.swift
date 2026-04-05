import SwiftUI

extension MenuBarRootView {
    struct ConnectionRowDisplayModel {
        let id: String
        let symbolName: String
        let symbolColor: Color
        let hostText: String
        let ruleTypeText: String
        let rulePayloadText: String
        let hostWidth: CGFloat
        let ruleWidth: CGFloat
        let payloadWidth: CGFloat
        let timeText: String
        let networkText: String
        let networkColor: Color
        let upText: String
        let downText: String
        let chainParts: [String]
        let hovered: Bool
    }

    struct ConnectionRowView: View {
        let model: ConnectionRowDisplayModel
        let primaryLabel: Color
        let secondaryLabel: Color
        let tertiaryLabel: Color
        let infoColor: Color
        let positiveColor: Color
        let hoverFill: Color
        let onClose: () -> Void

        var body: some View {
            HStack(alignment: .center, spacing: MenuBarLayoutTokens.space6) {
                Image(systemName: model.symbolName)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                    .foregroundStyle(model.symbolColor)
                    .frame(
                        width: MenuBarLayoutTokens.rowLeadingIcon,
                        height: MenuBarLayoutTokens.rowLeadingIcon,
                        alignment: .center)

                VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space2) {
                    self.topLine
                    self.metricsLine
                    self.chainsLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                self.closeButton
            }
            .padding(.horizontal, MenuBarLayoutTokens.space4)
            .padding(.vertical, MenuBarLayoutTokens.space2)
            .background(
                RoundedRectangle(
                    cornerRadius: MenuBarLayoutTokens.cornerRadius,
                    style: .continuous)
                .fill(model.hovered ? hoverFill : .clear))
        }

        private var topLine: some View {
            HStack(spacing: MenuBarLayoutTokens.space2) {
                Text(model.hostText)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                    .foregroundStyle(primaryLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: model.hostWidth, alignment: .leading)

                HStack(spacing: MenuBarLayoutTokens.space1) {
                    self.topBadge(text: model.ruleTypeText)
                        .frame(width: model.ruleWidth, alignment: .trailing)
                    self.topPayload(text: model.rulePayloadText)
                        .frame(width: model.payloadWidth, alignment: .trailing)
                }
                .frame(
                    width: model.ruleWidth + MenuBarLayoutTokens.space1 + model.payloadWidth,
                    alignment: .trailing)
            }
            .frame(height: 16)
        }

        private var metricsLine: some View {
            HStack(spacing: 0) {
                Text(model.timeText.isEmpty ? "--" : model.timeText)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                    .foregroundStyle(secondaryLabel)

                Text(" · ")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                    .foregroundStyle(tertiaryLabel)

                Text(model.networkText.isEmpty ? "--" : model.networkText)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                    .foregroundStyle(model.networkColor)

                Spacer(minLength: MenuBarLayoutTokens.space4)

                HStack(spacing: MenuBarLayoutTokens.space4) {
                    HStack(spacing: 0) {
                        Image(systemName: "arrow.up")
                            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                            .foregroundStyle(infoColor)
                        Text(model.upText)
                            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                            .foregroundStyle(infoColor)
                    }
                    HStack(spacing: 0) {
                        Image(systemName: "arrow.down")
                            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                            .foregroundStyle(positiveColor)
                        Text(model.downText)
                            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                            .foregroundStyle(positiveColor)
                    }
                }
            }
            .frame(height: 16)
        }

        private var chainsLine: some View {
            let chainText = model.chainParts.joined(separator: " › ")
            let displayText = model.chainParts.isEmpty ? "--" : chainText

            return Text(displayText)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .regular))
                .foregroundStyle(secondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 16, alignment: .leading)
        }

        private var closeButton: some View {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.hovered ? secondaryLabel : tertiaryLabel)
            .frame(width: 12, height: 12)
            .opacity(model.hovered ? 1 : 0)
        }

        private func topBadge(text: String) -> some View {
            Text(text)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .foregroundStyle(secondaryLabel)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
                .padding(.horizontal, MenuBarLayoutTokens.space2)
                .padding(.vertical, MenuBarLayoutTokens.space1)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(MenuBarLayoutTokens.Opacity.tint)))
        }

        private func topPayload(text: String) -> some View {
            Text(text)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(secondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
