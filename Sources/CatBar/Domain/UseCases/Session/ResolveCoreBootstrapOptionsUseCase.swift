import Foundation

enum CoreBootstrapKind: Equatable {
    case start
    case restart(trigger: ProviderRefreshTrigger)
}

struct CoreBootstrapOptionsPlan: Equatable {
    let overlaySyncingKey: String
    let providerTrigger: ProviderRefreshTrigger
    let refreshProxyGroupsAfterBootstrap: Bool
    let refreshSystemProxyBeforeOverlay: Bool
    let refreshSystemProxyAfterBootstrap: Bool
    let autoTestGroupLatencies: Bool
}

struct ResolveCoreBootstrapOptionsUseCase {
    func execute(_ kind: CoreBootstrapKind) -> CoreBootstrapOptionsPlan {
        switch kind {
        case .start:
            return CoreBootstrapOptionsPlan(
                overlaySyncingKey: "start-overlay",
                providerTrigger: .start,
                refreshProxyGroupsAfterBootstrap: false,
                refreshSystemProxyBeforeOverlay: true,
                refreshSystemProxyAfterBootstrap: false,
                autoTestGroupLatencies: true)
        case let .restart(trigger):
            return CoreBootstrapOptionsPlan(
                overlaySyncingKey: "restart-overlay",
                providerTrigger: trigger,
                refreshProxyGroupsAfterBootstrap: true,
                refreshSystemProxyBeforeOverlay: false,
                refreshSystemProxyAfterBootstrap: true,
                autoTestGroupLatencies: false)
        }
    }
}
