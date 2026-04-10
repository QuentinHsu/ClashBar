import CoreGraphics
import Foundation

enum ConnectionVisualStyle: Equatable {
    case google
    case apple
    case github
    case twitter
    case amazon
    case udp
    case tcp
    case generic

    var symbolName: String {
        switch self {
        case .google:
            "shield.fill"
        case .apple:
            "icloud.fill"
        case .github:
            "terminal.fill"
        case .twitter:
            "lock.fill"
        case .amazon:
            "cart.fill"
        case .udp:
            "dot.radiowaves.left.and.right"
        case .tcp:
            "network"
        case .generic:
            "globe"
        }
    }
}

enum ConnectionNetworkStyle: Equatable {
    case tcp
    case udp
    case other
}

struct ConnectionRowPresentation: Equatable {
    let hostText: String
    let ruleTypeText: String
    let rulePayloadText: String
    let layout: ConnectionsTopLineLayout
    let timeText: String
    let networkText: String
    let networkStyle: ConnectionNetworkStyle
    let upText: String
    let downText: String
    let chainParts: [String]
    let visualStyle: ConnectionVisualStyle
}

struct ConnectionRowPresentationResolver {
    let ruleResolver: ConnectionRulePresentationResolver
    let layoutResolver: ConnectionsTopLineLayoutResolver
    let rowContentWidth: CGFloat
    let minimumRuleWidth: CGFloat
    let minimumPayloadWidth: CGFloat
    let measureRuleWidth: (String) -> CGFloat
    let measurePayloadWidth: (String) -> CGFloat
    let fallbackHostText: String
    let formatTimeText: (String?) -> String
    let formatTrafficText: (Int64) -> String

    func resolve(_ connection: ConnectionSummary) -> ConnectionRowPresentation {
        let parsedRule = self.ruleResolver.parseRule(connection.rule)
        let ruleTypeText = self.ruleResolver.ruleTypeText(
            raw: connection.rule,
            fallback: parsedRule?.type)
        let rulePayloadText = connection.rulePayload.trimmedNonEmpty
            ?? parsedRule?.payload?.trimmedNonEmpty
            ?? "--"

        let layout = self.layoutResolver.resolve(
            totalWidth: self.rowContentWidth,
            desiredRuleWidth: max(self.minimumRuleWidth, self.measureRuleWidth(ruleTypeText) + 4),
            desiredPayloadWidth: max(self.minimumPayloadWidth, self.measurePayloadWidth(rulePayloadText)))

        let normalizedNetwork = connection.metadata?.network.trimmedOrEmpty ?? ""
        let networkText = normalizedNetwork.isEmpty ? "--" : normalizedNetwork.uppercased()

        return ConnectionRowPresentation(
            hostText: connection.metadata?.host.trimmedNonEmpty
                ?? connection.metadata?.destinationIP.trimmedNonEmpty
                ?? self.fallbackHostText,
            ruleTypeText: ruleTypeText,
            rulePayloadText: rulePayloadText,
            layout: layout,
            timeText: self.formatTimeText(connection.start),
            networkText: networkText,
            networkStyle: self.networkStyle(for: networkText),
            upText: self.formatTrafficText(connection.upload ?? 0),
            downText: self.formatTrafficText(connection.download ?? 0),
            chainParts: self.ruleResolver.chainsParts(connection.chains),
            visualStyle: self.visualStyle(host: connection.metadata?.host, network: normalizedNetwork))
    }

    private func networkStyle(for networkText: String) -> ConnectionNetworkStyle {
        switch networkText {
        case "TCP":
            .tcp
        case "UDP":
            .udp
        default:
            .other
        }
    }

    private func visualStyle(host: String?, network: String) -> ConnectionVisualStyle {
        let normalizedHost = host?.lowercased() ?? ""
        let normalizedNetwork = network.lowercased()

        if normalizedHost.contains("google") || normalizedHost.contains("gstatic") {
            return .google
        }
        if normalizedHost.contains("icloud") || normalizedHost.contains("apple") {
            return .apple
        }
        if normalizedHost.contains("github") {
            return .github
        }
        if normalizedHost.contains("twitter") || normalizedHost.contains("x.com") {
            return .twitter
        }
        if normalizedHost.contains("amazon") {
            return .amazon
        }
        if normalizedNetwork.contains("udp") {
            return .udp
        }
        if normalizedNetwork.contains("tcp") {
            return .tcp
        }
        return .generic
    }
}
