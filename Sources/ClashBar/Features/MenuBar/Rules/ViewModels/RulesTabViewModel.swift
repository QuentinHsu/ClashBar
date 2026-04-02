import Foundation
import SwiftUI

@MainActor
final class RulesTabViewModel: ObservableObject {
    private let presentRulesUseCase: PresentRulesUseCase

    @Published private(set) var policyGroups: [RulePolicyGroup] = []
    @Published private(set) var providerLookup: [String: ProviderDetail] = [:]

    init(presentRulesUseCase: PresentRulesUseCase = PresentRulesUseCase()) {
        self.presentRulesUseCase = presentRulesUseCase
    }

    func updateVisibleRules(items: [RuleItem], providers: [String: ProviderDetail]) {
        let output = self.presentRulesUseCase.execute(items: items, providers: providers)
        let nextGroups = output.groups
        let nextLookup = output.providerLookup

        if nextGroups != self.policyGroups {
            self.policyGroups = nextGroups
        }

        guard nextLookup != self.providerLookup else { return }
        self.providerLookup = nextLookup
    }
}
