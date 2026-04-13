import Foundation

enum TunModeToggleExecution: Equatable {
    case persistOnly
    case patchRuntimeOnly
    case patchRuntimeAndRestart
}

struct ResolveTunModeToggleExecutionUseCase {
    func execute(isRemoteTarget: Bool, isRuntimeRunning: Bool) -> TunModeToggleExecution {
        guard isRuntimeRunning else {
            return .persistOnly
        }

        if isRemoteTarget {
            return .patchRuntimeOnly
        }

        return .patchRuntimeAndRestart
    }
}
