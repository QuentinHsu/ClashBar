import Foundation

struct CoreFeatureRecoveryAttemptContext: Equatable {
    let pendingRecovery: CoreFeatureRecoveryState?
    let isRuntimeRunning: Bool
    let autoManageCoreOnNetworkChangeEnabled: Bool
    let networkReachabilityStatus: NetworkReachabilityStatus
}

enum CoreFeatureRecoveryAttemptDecision: Equatable {
    case skip
    case clearPendingState
    case attempt(CoreFeatureRecoveryState)
}

struct ResolveCoreFeatureRecoveryAttemptUseCase {
    func execute(_ context: CoreFeatureRecoveryAttemptContext) -> CoreFeatureRecoveryAttemptDecision {
        guard let recovery = context.pendingRecovery else {
            return .skip
        }

        guard recovery.shouldRecoverAnyFeature else {
            return .clearPendingState
        }

        guard context.isRuntimeRunning else {
            return .skip
        }

        if context.autoManageCoreOnNetworkChangeEnabled, context.networkReachabilityStatus == .offline {
            return .skip
        }

        return .attempt(recovery)
    }
}
