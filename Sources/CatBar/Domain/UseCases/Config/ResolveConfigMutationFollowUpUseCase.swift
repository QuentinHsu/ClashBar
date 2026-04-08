import Foundation

struct ConfigMutationFollowUpPlan: Equatable {
    let shouldRefreshConfigState: Bool
    let shouldReloadCurrentConfig: Bool
}

struct ResolveConfigMutationFollowUpUseCase {
    func execute(
        updatedFileNames: Set<String>,
        selectedConfigName: String,
        isRuntimeRunning: Bool,
        hasRemoteSourceChanges: Bool) -> ConfigMutationFollowUpPlan
    {
        let shouldRefreshConfigState = hasRemoteSourceChanges || !updatedFileNames.isEmpty
        return ConfigMutationFollowUpPlan(
            shouldRefreshConfigState: shouldRefreshConfigState,
            shouldReloadCurrentConfig:
                shouldRefreshConfigState
                && isRuntimeRunning
                && updatedFileNames.contains(selectedConfigName))
    }
}
