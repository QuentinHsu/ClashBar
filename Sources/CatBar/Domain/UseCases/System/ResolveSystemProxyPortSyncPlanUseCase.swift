import Foundation

struct SystemProxyPortSyncPlan: Equatable {
    let shouldCloseConnections: Bool
}

struct ResolveSystemProxyPortSyncPlanUseCase {
    func execute(
        previousPorts: SystemProxyPorts?,
        currentPorts: SystemProxyPorts) -> SystemProxyPortSyncPlan
    {
        SystemProxyPortSyncPlan(
            shouldCloseConnections: previousPorts.map { $0 != currentPorts } ?? false)
    }
}
