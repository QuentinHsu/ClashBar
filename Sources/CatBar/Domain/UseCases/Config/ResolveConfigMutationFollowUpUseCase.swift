import Foundation

struct ConfigMutationFollowUpPlan: Equatable {
    let shouldReloadCurrentConfig: Bool
}

struct ResolveConfigMutationFollowUpUseCase {
    func execute(
        updatedFileNames: Set<String>,
        selectedConfigName: String,
        isRuntimeRunning: Bool) -> ConfigMutationFollowUpPlan
    {
        ConfigMutationFollowUpPlan(
            shouldReloadCurrentConfig:
                !updatedFileNames.isEmpty
                && isRuntimeRunning
                && updatedFileNames.contains(selectedConfigName))
    }
}
