import Foundation

struct NetworkRecoveryActionContext: Equatable {
    let autoManageCoreOnNetworkChangeEnabled: Bool
    let networkReachabilityStatus: NetworkReachabilityStatus
    let shouldResumeCoreAfterNetworkRecovery: Bool
    let isCoreActionProcessing: Bool
    let isRuntimeRunning: Bool
    let hasPendingFeatureRecovery: Bool
}

enum NetworkRecoveryActionDecision: Equatable {
    case stop
    case waitForCurrentCoreAction
    case complete
    case restorePendingFeatures
    case startCore
}

struct ResolveNetworkRecoveryActionUseCase {
    func execute(_ context: NetworkRecoveryActionContext) -> NetworkRecoveryActionDecision {
        guard context.autoManageCoreOnNetworkChangeEnabled,
              context.networkReachabilityStatus == .online,
              context.shouldResumeCoreAfterNetworkRecovery
        else {
            return .stop
        }

        if context.isCoreActionProcessing {
            return .waitForCurrentCoreAction
        }

        guard context.isRuntimeRunning else {
            return .startCore
        }

        return context.hasPendingFeatureRecovery ? .restorePendingFeatures : .complete
    }
}
