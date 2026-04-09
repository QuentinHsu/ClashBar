import Foundation

struct PresentRulesOutput {
    let groups: [RulePolicyGroup]
    let providerLookup: [String: ProviderDetail]
}

struct PresentRulesUseCase {
    func execute(items: [RuleItem], providers: [String: ProviderDetail]) -> PresentRulesOutput {
        let truncated = items.prefix(RulesSummary.retainedRuleLimit)

        var groupIndexes: [String: Int] = [:]
        groupIndexes.reserveCapacity(truncated.count)

        var orderedPolicies: [String] = []
        orderedPolicies.reserveCapacity(truncated.count)
        var groupedRules: [[RuleItem]] = []
        groupedRules.reserveCapacity(truncated.count)

        for rule in truncated {
            let key = rule.proxy ?? ""
            if let index = groupIndexes[key] {
                groupedRules[index].append(rule)
            } else {
                groupIndexes[key] = orderedPolicies.count
                orderedPolicies.append(key)
                groupedRules.append([rule])
            }
        }

        var groups: [RulePolicyGroup] = []
        groups.reserveCapacity(orderedPolicies.count)

        for index in orderedPolicies.indices {
            groups.append(RulePolicyGroup(policy: orderedPolicies[index], rules: groupedRules[index]))
        }

        return PresentRulesOutput(
            groups: groups,
            providerLookup: self.makeProviderLookup(from: providers))
    }

    private func makeProviderLookup(from providers: [String: ProviderDetail]) -> [String: ProviderDetail] {
        guard !providers.isEmpty else { return [:] }

        var map: [String: ProviderDetail] = [:]
        map.reserveCapacity(providers.count * 2)

        for (key, detail) in providers {
            map[key.lowercased()] = detail
            if let normalizedName = detail.name.trimmedNonEmpty?.lowercased() {
                map[normalizedName] = detail
            }
        }

        return map
    }
}
