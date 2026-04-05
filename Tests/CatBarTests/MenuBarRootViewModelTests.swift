import XCTest
@testable import CatBar

@MainActor
final class MenuBarRootViewModelTests: XCTestCase {
    func testSyncCurrentTabUpdatesCurrentTab() {
        let subject = MenuBarRootViewModel()

        subject.syncCurrentTab(.logs)

        XCTAssertEqual(subject.currentTab, .logs)
    }

    func testUpdateFilteredProxyGroupsFiltersByModeAndHiddenState() {
        let subject = MenuBarRootViewModel()
        let groups = [
            ProxyGroup(name: "GLOBAL", all: [], hidden: false),
            ProxyGroup(name: "Manual", all: [], hidden: false),
            ProxyGroup(name: "Hidden", all: [], hidden: true),
        ]

        subject.updateFilteredProxyGroups(from: groups, hideHiddenGroups: true, mode: .rule)
        XCTAssertEqual(subject.filteredProxyGroups.map(\.name), ["Manual"])

        subject.updateFilteredProxyGroups(from: groups, hideHiddenGroups: false, mode: .global)
        XCTAssertEqual(subject.filteredProxyGroups.map(\.name), ["GLOBAL"])

        subject.updateFilteredProxyGroups(from: groups, hideHiddenGroups: false, mode: .direct)
        XCTAssertTrue(subject.filteredProxyGroups.isEmpty)
    }
}
