import Foundation

enum SystemProxyToggleExecutionMode: Equatable {
    case optimisticLocalOnly
    case runtimeSynchronized
}

enum SystemProxyToggleHelperRefresh: Equatable {
    case none
    case status
    case runtimeSnapshot
}

struct SystemProxyToggleSuccessPlan: Equatable {
    let helperRefresh: SystemProxyToggleHelperRefresh
    let shouldResetObservedState: Bool
    let shouldClearFailureHint: Bool
    let shouldClearHelperFailureState: Bool
    let shouldAppendToggleLog: Bool
}

struct SystemProxyToggleFailurePlan: Equatable {
    let shouldUpdateFailureHint: Bool
    let shouldRefreshHelperStatus: Bool
    let shouldRefreshSystemProxyStatus: Bool
    let shouldResetObservedState: Bool
}

struct SystemProxyTogglePlan: Equatable {
    let executionMode: SystemProxyToggleExecutionMode
    let shouldOptimisticallyUpdateEnabledState: Bool
    let shouldPersistEditableSettingsSnapshot: Bool
    let shouldAppendToggleLogBeforeExecution: Bool
    let shouldPatchRuntimeMode: Bool
    let shouldCloseConnections: Bool
    let success: SystemProxyToggleSuccessPlan
    let failure: SystemProxyToggleFailurePlan
}

struct ResolveSystemProxyTogglePlanUseCase {
    func execute(
        enabled: Bool,
        isRemoteTarget: Bool,
        isRuntimeRunning: Bool,
        wasSystemProxyEnabled: Bool) -> SystemProxyTogglePlan
    {
        guard !isRemoteTarget, !isRuntimeRunning else {
            return SystemProxyTogglePlan(
                executionMode: .runtimeSynchronized,
                shouldOptimisticallyUpdateEnabledState: false,
                shouldPersistEditableSettingsSnapshot: false,
                shouldAppendToggleLogBeforeExecution: false,
                shouldPatchRuntimeMode: true,
                shouldCloseConnections: true,
                success: SystemProxyToggleSuccessPlan(
                    helperRefresh: enabled ? .runtimeSnapshot : .none,
                    shouldResetObservedState: !enabled,
                    shouldClearFailureHint: true,
                    shouldClearHelperFailureState: true,
                    shouldAppendToggleLog: true),
                failure: SystemProxyToggleFailurePlan(
                    shouldUpdateFailureHint: enabled,
                    shouldRefreshHelperStatus: true,
                    shouldRefreshSystemProxyStatus: enabled || wasSystemProxyEnabled,
                    shouldResetObservedState: !(enabled || wasSystemProxyEnabled)))
        }

        return SystemProxyTogglePlan(
            executionMode: .optimisticLocalOnly,
            shouldOptimisticallyUpdateEnabledState: true,
            shouldPersistEditableSettingsSnapshot: true,
            shouldAppendToggleLogBeforeExecution: true,
            shouldPatchRuntimeMode: false,
            shouldCloseConnections: false,
            success: SystemProxyToggleSuccessPlan(
                helperRefresh: enabled ? .status : .none,
                shouldResetObservedState: !enabled,
                shouldClearFailureHint: false,
                shouldClearHelperFailureState: false,
                shouldAppendToggleLog: false),
            failure: SystemProxyToggleFailurePlan(
                shouldUpdateFailureHint: enabled,
                shouldRefreshHelperStatus: enabled,
                shouldRefreshSystemProxyStatus: false,
                shouldResetObservedState: false))
    }
}
