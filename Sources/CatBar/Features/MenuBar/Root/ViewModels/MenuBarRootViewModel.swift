import Foundation
import SwiftUI

@MainActor
final class MenuBarRootViewModel: ObservableObject {
    @Published var currentTab: RootTab = .proxy
    @Published private(set) var filteredProxyGroups: [ProxyGroup] = []

    func syncCurrentTab(_ tab: RootTab) {
        self.currentTab = tab
    }

    func updateFilteredProxyGroups(from groups: [ProxyGroup], hideHiddenGroups: Bool, mode: CoreMode) {
        let nextGroups = groups.filter { group in
            guard self.isVisible(group, in: mode) else { return false }
            return !hideHiddenGroups || group.hidden != true
        }
        guard nextGroups != self.filteredProxyGroups else { return }
        self.filteredProxyGroups = nextGroups
    }

    private func isVisible(_ group: ProxyGroup, in mode: CoreMode) -> Bool {
        switch mode {
        case .global:
            return group.name == "GLOBAL"
        case .direct:
            return false
        case .rule:
            return group.name != "GLOBAL"
        }
    }
}
