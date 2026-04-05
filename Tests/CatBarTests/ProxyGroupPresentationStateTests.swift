import XCTest
@testable import CatBar

final class ProxyGroupPresentationStateTests: XCTestCase {
    func testRebuildGroupIndexKeepsLatestGroupForDuplicateName() {
        var state = ProxyGroupPresentationState(
            proxyGroups: [
                ProxyGroup(name: "GLOBAL", all: ["A"], hidden: false, latestDelay: 10),
                ProxyGroup(name: "GLOBAL", all: ["B"], hidden: false, latestDelay: 20),
            ],
            proxyGroupIndex: [:],
            proxyHistoryLatestDelay: [:],
            proxyNodeTypes: [:],
            proxyNodeIDs: [:])

        state.rebuildGroupIndex()

        XCTAssertEqual(state.proxyGroupIndex["GLOBAL"]?.all, ["B"])
        XCTAssertEqual(state.proxyGroupIndex["GLOBAL"]?.latestDelay, 20)
    }

    func testClearRemovesGroupsIndexAndMetadata() {
        var state = ProxyGroupPresentationState(
            proxyGroups: [ProxyGroup(name: "GLOBAL", all: ["A"], hidden: false)],
            proxyGroupIndex: ["GLOBAL": ProxyGroup(name: "GLOBAL", all: ["A"], hidden: false)],
            proxyHistoryLatestDelay: ["GLOBAL": 20],
            proxyNodeTypes: ["A": "ss"],
            proxyNodeIDs: ["A": "id-a"])

        state.clear(keepingCapacity: false)

        XCTAssertTrue(state.proxyGroups.isEmpty)
        XCTAssertTrue(state.proxyGroupIndex.isEmpty)
        XCTAssertTrue(state.proxyHistoryLatestDelay.isEmpty)
        XCTAssertTrue(state.proxyNodeTypes.isEmpty)
        XCTAssertTrue(state.proxyNodeIDs.isEmpty)
    }
}
