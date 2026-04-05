import Foundation

struct ParsedConnectionRule: Equatable {
    let type: String
    let payload: String?
}

struct ConnectionRulePresentationResolver {
    func parseRule(_ raw: String?) -> ParsedConnectionRule? {
        guard let raw = raw?.trimmedNonEmpty else {
            return nil
        }

        if let open = raw.firstIndex(of: "("), let close = raw.lastIndex(of: ")"), open < close {
            let type = raw[..<open].trimmed
            let payload = raw[raw.index(after: open)..<close].trimmed
            if let type = type.nonEmpty {
                return ParsedConnectionRule(type: type, payload: payload.nonEmpty)
            }
        }

        let commaParts = raw.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        if commaParts.count == 2 {
            let type = commaParts[0].trimmed
            let payload = commaParts[1].trimmed
            if let type = type.nonEmpty {
                return ParsedConnectionRule(type: type, payload: payload.nonEmpty)
            }
        }

        return ParsedConnectionRule(type: raw, payload: nil)
    }

    func ruleTypeText(raw: String?, fallback: String?) -> String {
        let candidate = fallback?.trimmedNonEmpty ?? raw?.trimmedNonEmpty ?? ""
        guard !candidate.isEmpty else { return "--" }

        let normalized = candidate.uppercased()
        if normalized == "MATCH" || normalized == "FINAL" {
            return "--"
        }
        return candidate
    }

    func chainsParts(_ chains: [String]?) -> [String] {
        Array((chains ?? []).compactMap(\.trimmedNonEmpty).reversed())
    }

    func searchText(for connection: ConnectionSummary) -> String {
        let host = connection.metadata?.host ?? ""
        let destinationIP = connection.metadata?.destinationIP ?? ""
        let sourceIP = connection.metadata?.sourceIP ?? ""
        let network = connection.metadata?.network ?? ""
        let id = connection.id
        let rule = connection.rule ?? ""
        let rulePayload = connection.rulePayload ?? ""
        let chains = self.chainsParts(connection.chains).joined(separator: " > ")
        let start = connection.start ?? ""
        return "\(host) \(destinationIP) \(sourceIP) \(network) \(id) \(rule) \(rulePayload) \(chains) \(start)"
    }
}
