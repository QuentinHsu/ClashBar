import Foundation

enum LogMessageProtocolStyle: Equatable {
    case accent
    case warning
    case positive
}

struct ParsedLogEntryPresentation: Equatable {
    let protocolTag: String?
    let protocolStyle: LogMessageProtocolStyle
    let mainText: String
    let detailText: String?
}

struct LogEntryPresentationResolver {
    let fallbackText: String

    func normalizedLevel(_ raw: String) -> String {
        let lower = raw.trimmed.lowercased()
        if lower.contains("error") || lower.contains("err") {
            return "ERROR"
        }
        if lower.contains("warn") {
            return "WARNING"
        }
        return "INFO"
    }

    func parseMessage(_ raw: String) -> ParsedLogEntryPresentation {
        var message = raw.trimmed
        if message.isEmpty {
            return ParsedLogEntryPresentation(
                protocolTag: nil,
                protocolStyle: .accent,
                mainText: self.fallbackText,
                detailText: nil)
        }

        if let extracted = self.firstRegexCapture(in: message, regex: CachedLogRegex.msgField), !extracted.isEmpty {
            message = extracted
        }

        var detailText: String?
        if let trailingBracket = self.firstRegexCapture(in: message, regex: CachedLogRegex.trailingBracket) {
            detailText = trailingBracket
            message = message.replacingOccurrences(of: trailingBracket, with: "").trimmed
        }

        var protocolTag: String?
        var protocolStyle = LogMessageProtocolStyle.accent
        if let tag = self.firstRegexCapture(in: message, regex: CachedLogRegex.protocolTag) {
            protocolTag = tag
            message = message.replacingOccurrences(of: tag, with: "").trimmed

            let upper = tag.uppercased()
            if upper.contains("UDP") { protocolStyle = .warning }
            if upper.contains("DNS") { protocolStyle = .positive }
            if upper.contains("HTTP") { protocolStyle = .accent }
        }

        if message.isEmpty {
            message = raw.trimmed
        }

        return ParsedLogEntryPresentation(
            protocolTag: protocolTag,
            protocolStyle: protocolStyle,
            mainText: message.isEmpty ? self.fallbackText : message,
            detailText: detailText)
    }

    func searchText(for log: AppErrorLogEntry, sourceText: String, timeText: String) -> String {
        "\(sourceText) \(self.normalizedLevel(log.level)) \(timeText) \(log.message)"
    }

    func firstRegexCapture(in text: String, regex: NSRegularExpression?) -> String? {
        guard let regex else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        let captureRange = match.range(at: 1)
        guard captureRange.location != NSNotFound else { return nil }
        return nsText.substring(with: captureRange)
    }
}

private enum CachedLogRegex {
    static let msgField = try? NSRegularExpression(pattern: #"msg="([^"]+)""#, options: [])
    static let trailingBracket = try? NSRegularExpression(pattern: #"(?:\s|^)(\[[^\[\]]+\])\s*$"#, options: [])
    static let protocolTag = try? NSRegularExpression(pattern: #"(\[(?:TCP|UDP|DNS|HTTP|HTTPS)\])"#, options: [])
}
