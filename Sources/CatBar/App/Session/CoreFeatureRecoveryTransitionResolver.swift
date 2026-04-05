import Foundation

struct CoreFeatureRecoveryTransitionPlan: Equatable {
    let pendingRecovery: CoreFeatureRecoveryState?
    let shouldDisableTunBeforeTransition: Bool
    let shouldDisableSystemProxyBeforeTransition: Bool
}

struct CoreFeatureRecoveryTransitionResolver {
    func resolve(
        runtimeRunningBeforeTransition: Bool,
        systemProxyEnabled: Bool,
        tunEnabled: Bool,
        fallbackRecovery: CoreFeatureRecoveryState,
        pendingRecovery: CoreFeatureRecoveryState?) -> CoreFeatureRecoveryTransitionPlan
    {
        let capturedRecovery = CoreFeatureRecoveryState(
            systemProxyEnabled: runtimeRunningBeforeTransition && systemProxyEnabled,
            tunEnabled: runtimeRunningBeforeTransition && tunEnabled)
        let baseRecovery = capturedRecovery.shouldRecoverAnyFeature ? capturedRecovery : fallbackRecovery
        let recovery = baseRecovery.merged(with: pendingRecovery)

        return CoreFeatureRecoveryTransitionPlan(
            pendingRecovery: recovery.pendingState,
            shouldDisableTunBeforeTransition: runtimeRunningBeforeTransition && recovery.tunEnabled,
            shouldDisableSystemProxyBeforeTransition: systemProxyEnabled)
    }
}
