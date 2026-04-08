import Foundation

struct AppLaunchAutoStartContext: Equatable {
    let startBackgroundRefresh: Bool
    let autoStartCoreEnabled: Bool
    let shouldDeferForMissingManagedCore: Bool
}

enum AppLaunchAutoStartDecision: Equatable {
    case skip
    case schedule
}

struct ResolveAppLaunchAutoStartUseCase {
    func execute(_ context: AppLaunchAutoStartContext) -> AppLaunchAutoStartDecision {
        guard context.startBackgroundRefresh,
              context.autoStartCoreEnabled,
              !context.shouldDeferForMissingManagedCore
        else {
            return .skip
        }

        return .schedule
    }
}
