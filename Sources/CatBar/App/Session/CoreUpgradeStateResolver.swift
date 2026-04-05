import Foundation

struct CoreUpgradeStateResolver {
    let unknownMessage: String
    private let decoder = JSONDecoder()

    func resolve(response: CoreUpgradeResponse) -> CoreUpgradeState {
        if let status = response.status?.trimmedNonEmpty,
           status.caseInsensitiveCompare("ok") == .orderedSame
        {
            return .succeeded
        }

        if let message = response.message?.trimmedNonEmpty {
            return self.resolve(message: message)
        }

        return .failed(message: self.unknownMessage)
    }

    func resolve(error: Error) -> CoreUpgradeState {
        if let apiError = error as? APIError,
           case let .statusCode(_, responseBody) = apiError
        {
            if let data = responseBody.data(using: .utf8),
               let response = try? self.decoder.decode(CoreUpgradeResponse.self, from: data)
            {
                let state = self.resolve(response: response)
                if case let .failed(message) = state, message == self.unknownMessage {
                    return self.resolve(message: responseBody)
                }
                return state
            }

            return self.resolve(message: responseBody)
        }

        return self.resolve(message: error.localizedDescription)
    }

    func resolve(message: String) -> CoreUpgradeState {
        let trimmedMessage = message.trimmed
        guard !trimmedMessage.isEmpty else {
            return .failed(message: self.unknownMessage)
        }

        if self.isAlreadyLatestMessage(trimmedMessage) {
            return .alreadyLatest(version: self.latestVersion(in: trimmedMessage))
        }

        return .failed(message: trimmedMessage)
    }

    private func isAlreadyLatestMessage(_ message: String) -> Bool {
        message.range(
            of: "already using latest version",
            options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func latestVersion(in message: String) -> String? {
        let pattern = #"v?\d+(?:\.\d+)+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        guard let match = regex.matches(in: message, range: range).last,
              let swiftRange = Range(match.range, in: message)
        else {
            return nil
        }

        let raw = String(message[swiftRange])
        return AppSemanticVersion.normalizedDisplayVersion(from: raw)
    }
}
