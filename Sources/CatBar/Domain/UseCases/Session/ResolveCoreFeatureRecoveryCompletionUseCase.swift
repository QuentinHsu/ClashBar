import Foundation

struct CoreFeatureRecoveryCompletionContext: Equatable {
    let requestedRecovery: CoreFeatureRecoveryState
    let systemProxyRestored: Bool
    let tunRestored: Bool
}

struct ResolveCoreFeatureRecoveryCompletionUseCase {
    func execute(_ context: CoreFeatureRecoveryCompletionContext) -> CoreFeatureRecoveryState? {
        CoreFeatureRecoveryState(
            systemProxyEnabled: context.requestedRecovery.systemProxyEnabled && !context.systemProxyRestored,
            tunEnabled: context.requestedRecovery.tunEnabled && !context.tunRestored)
            .pendingState
    }
}
