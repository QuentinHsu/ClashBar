import XCTest
@testable import CatBar

final class PresentFilteredProxyGroupsUseCaseTests: XCTestCase {
    private let subject = PresentFilteredProxyGroupsUseCase()

    func testExecuteReturnsEmptyForDirectModeWithoutScanningFurther() {
        let groups = [
            ProxyGroup(name: "GLOBAL", all: [], hidden: false),
            ProxyGroup(name: "Manual", all: [], hidden: false),
        ]

        let result = self.subject.execute(groups: groups, hideHiddenGroups: false, mode: .direct)

        XCTAssertTrue(result.isEmpty)
    }

    func testExecuteReturnsOnlyGlobalGroupsInGlobalMode() {
        let groups = [
            ProxyGroup(name: "Manual", all: [], hidden: false),
            ProxyGroup(name: "GLOBAL", all: [], hidden: false),
            ProxyGroup(name: "GLOBAL", all: [], hidden: false),
        ]

        let result = self.subject.execute(groups: groups, hideHiddenGroups: false, mode: .global)

        XCTAssertEqual(result.map(\.name), ["GLOBAL", "GLOBAL"])
    }

    func testExecuteHidesHiddenGroupsAfterModeVisibilityCheck() {
        let groups = [
            ProxyGroup(name: "GLOBAL", all: [], hidden: true),
            ProxyGroup(name: "Manual", all: [], hidden: false),
            ProxyGroup(name: "Hidden", all: [], hidden: true),
        ]

        let result = self.subject.execute(groups: groups, hideHiddenGroups: true, mode: .rule)

        XCTAssertEqual(result.map(\.name), ["Manual"])
    }

    func testExecuteKeepsNonHiddenRuleGroupsInOriginalOrder() {
        let groups = [
            ProxyGroup(name: "B", all: [], hidden: false),
            ProxyGroup(name: "GLOBAL", all: [], hidden: false),
            ProxyGroup(name: "A", all: [], hidden: nil),
        ]

        let result = self.subject.execute(groups: groups, hideHiddenGroups: false, mode: .rule)

        XCTAssertEqual(result.map(\.name), ["B", "A"])
    }
}
