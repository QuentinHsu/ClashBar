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
        let modeFiltered: [ProxyGroup]
        switch mode {
        case .global:
            modeFiltered = groups.filter { $0.name == "GLOBAL" }
        case .direct:
            modeFiltered = []
        case .rule:
            modeFiltered = groups
        }
        let nextGroups = hideHiddenGroups ? modeFiltered.filter { $0.hidden != true } : modeFiltered
        guard nextGroups != self.filteredProxyGroups else { return }
        self.filteredProxyGroups = nextGroups
    }
}
