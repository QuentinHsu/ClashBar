import Foundation
import SwiftUI

@MainActor
final class MenuBarRootViewModel: ObservableObject {
    @Published var currentTab: RootTab = .proxy
    @Published private(set) var filteredProxyGroups: [ProxyGroup] = []

    private let presentFilteredProxyGroupsUseCase: PresentFilteredProxyGroupsUseCase

    init(presentFilteredProxyGroupsUseCase: PresentFilteredProxyGroupsUseCase = PresentFilteredProxyGroupsUseCase()) {
        self.presentFilteredProxyGroupsUseCase = presentFilteredProxyGroupsUseCase
    }

    func syncCurrentTab(_ tab: RootTab) {
        self.currentTab = tab
    }

    func updateFilteredProxyGroups(from groups: [ProxyGroup], hideHiddenGroups: Bool, mode: CoreMode) {
        let nextGroups = self.presentFilteredProxyGroupsUseCase.execute(
            groups: groups,
            hideHiddenGroups: hideHiddenGroups,
            mode: mode)
        guard nextGroups != self.filteredProxyGroups else { return }
        self.filteredProxyGroups = nextGroups
    }
}
