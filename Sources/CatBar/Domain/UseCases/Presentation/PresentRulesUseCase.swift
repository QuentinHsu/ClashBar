import Foundation

struct PresentRulesOutput {
    let groups: [RulePolicyGroup]
    let providerLookup: [String: ProviderDetail]
}

struct PresentRulesUseCase {
    func execute(items: [RuleItem], providers: [String: ProviderDetail]) -> PresentRulesOutput {
        let truncated = items.prefix(100)

        var order: [String] = []
        var buckets: [String: [RuleItem]] = [:]

        for rule in truncated {
            let key = rule.proxy ?? ""
            if buckets[key] == nil {
                order.append(key)
            }
            buckets[key, default: []].append(rule)
        }

        let groups = order.map { key in
            RulePolicyGroup(policy: key, rules: buckets[key] ?? [])
        }

        return PresentRulesOutput(
            groups: groups,
            providerLookup: self.makeProviderLookup(from: providers))
    }

    private func makeProviderLookup(from providers: [String: ProviderDetail]) -> [String: ProviderDetail] {
        var map: [String: ProviderDetail] = [:]
        map.reserveCapacity(providers.count * 2)

        for (key, detail) in providers {
            map[key.lowercased()] = detail
            if let name = detail.name.trimmedNonEmpty {
                map[name.lowercased()] = detail
            }
        }

        return map
    }
}
