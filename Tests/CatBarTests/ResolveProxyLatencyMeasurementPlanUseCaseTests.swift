import XCTest
@testable import CatBar

final class ResolveProxyLatencyMeasurementPlanUseCaseTests: XCTestCase {
    private let useCase = ResolveProxyLatencyMeasurementPlanUseCase()

    func testExecuteExpandsReferencedGroupsAndPrioritizesCurrentNestedNode() {
        let root = ProxyGroup(
            name: "GLOBAL",
            type: "select",
            now: "Auto",
            all: ["Auto", "HK"])
        let nested = ProxyGroup(
            name: "Auto",
            type: "select",
            now: "JP",
            all: ["JP", "US"])
        let proxyGroupsByName = [
            root.name: root,
            nested.name: nested,
        ]

        let plan = self.useCase.execute(
            rootGroups: [root],
            proxyGroupsByName: proxyGroupsByName,
            proxyNodeIDs: ["JP": "node-jp", "US": "node-us", "HK": "node-hk"],
            defaultTestURL: "https://example.com",
            defaultTimeout: 5000)

        XCTAssertEqual(plan.nodeGroupNames, ["GLOBAL", "Auto"])
        XCTAssertEqual(plan.wholeGroupNames, [])
        XCTAssertEqual(plan.groupDirectNodes["GLOBAL"], ["HK"])
        XCTAssertEqual(plan.groupDirectNodes["Auto"], ["JP", "US"])
        XCTAssertEqual(plan.groupPendingCounts["GLOBAL"], 1)
        XCTAssertEqual(plan.groupPendingCounts["Auto"], 2)
        XCTAssertEqual(plan.orderedJobs.first?.key.proxyKey, "node-jp")
    }

    func testExecuteSeparatesWholeGroupMeasurements() {
        let group = ProxyGroup(
            name: "Auto",
            type: "url-test",
            now: "JP",
            all: ["JP", "US"])

        let plan = self.useCase.execute(
            rootGroups: [group],
            proxyGroupsByName: [group.name: group],
            proxyNodeIDs: ["JP": "node-jp", "US": "node-us"],
            defaultTestURL: "https://example.com",
            defaultTimeout: 5000)

        XCTAssertEqual(plan.nodeGroupNames, [])
        XCTAssertEqual(plan.wholeGroupNames, ["Auto"])
        XCTAssertEqual(plan.groupDirectNodes["Auto"], ["JP", "US"])
        XCTAssertTrue(plan.orderedJobs.isEmpty)
    }

    func testExecuteDeduplicatesNodesByResolvedDelayKey() {
        let group = ProxyGroup(
            name: "GLOBAL",
            type: "select",
            now: "Node A",
            all: ["Node A", "Node Alias"])

        let plan = self.useCase.execute(
            rootGroups: [group],
            proxyGroupsByName: [group.name: group],
            proxyNodeIDs: ["Node A": "same-id", "Node Alias": "same-id"],
            defaultTestURL: "https://example.com",
            defaultTimeout: 5000)

        XCTAssertEqual(plan.groupDirectNodes["GLOBAL"], ["Node A"])
        XCTAssertEqual(plan.groupPendingCounts["GLOBAL"], 1)
        XCTAssertEqual(plan.groupPendingDelayKeys["GLOBAL"], ["same-id"])
        XCTAssertEqual(plan.orderedJobs.map(\.nodeName), ["Node A"])
    }
}
