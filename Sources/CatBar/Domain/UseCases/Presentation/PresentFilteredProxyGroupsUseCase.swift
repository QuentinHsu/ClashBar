import Foundation

struct PresentFilteredProxyGroupsUseCase {
    func execute(
        groups: [ProxyGroup],
        hideHiddenGroups: Bool,
        mode: CoreMode) -> [ProxyGroup]
    {
        guard mode != .direct, !groups.isEmpty else { return [] }

        var presented: [ProxyGroup] = []
        presented.reserveCapacity(self.estimatedCapacity(for: groups.count, mode: mode))

        for group in groups {
            if hideHiddenGroups, group.hidden == true {
                continue
            }
            if !self.isVisible(group, in: mode) {
                continue
            }
            presented.append(group)
        }

        return presented
    }

    private func isVisible(_ group: ProxyGroup, in mode: CoreMode) -> Bool {
        switch mode {
        case .global:
            group.name == "GLOBAL"
        case .direct:
            false
        case .rule:
            group.name != "GLOBAL"
        }
    }

    private func estimatedCapacity(for groupCount: Int, mode: CoreMode) -> Int {
        switch mode {
        case .global:
            min(groupCount, 1)
        case .direct:
            0
        case .rule:
            groupCount
        }
    }
}
