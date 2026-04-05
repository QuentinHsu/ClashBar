import XCTest
@testable import CatBar

final class ProxyLatencyPresentationStateTests: XCTestCase {
    func testBeginAndEndGroupLatencyLoadingUseReferenceCounting() {
        var state = ProxyLatencyPresentationState()

        state.beginGroupLatencyLoading("GLOBAL")
        state.beginGroupLatencyLoading("GLOBAL")
        XCTAssertEqual(state.groupLatencyLoading, ["GLOBAL"])

        state.endGroupLatencyLoading("GLOBAL")
        XCTAssertEqual(state.groupLatencyLoading, ["GLOBAL"])

        state.endGroupLatencyLoading("GLOBAL")
        XCTAssertTrue(state.groupLatencyLoading.isEmpty)
    }

    func testSetGroupLatencyCreatesBucketAndStoresDelay() {
        var state = ProxyLatencyPresentationState()

        state.setGroupLatency(groupName: "GLOBAL", delayKey: "node-a", delay: 42)

        XCTAssertEqual(state.groupLatencies["GLOBAL"]?["node-a"], 42)
    }

    func testClearMeasuredDelaysResetsCollectionsAndRefCounters() {
        var state = ProxyLatencyPresentationState()
        state.beginGroupLatencyLoading("GLOBAL")
        state.beginGroupLatencyPending(groupName: "GLOBAL", delayKey: "node-a")
        state.beginNodeLatencyLoading("node-a")
        state.setGroupLatency(groupName: "GLOBAL", delayKey: "node-a", delay: 42)
        state.recordMeasuredProxyDelay(key: "node-a", delay: 42)

        state.clearMeasuredDelays()

        XCTAssertTrue(state.groupLatencyLoading.isEmpty)
        XCTAssertTrue(state.groupLatencyPendingDelayKeys.isEmpty)
        XCTAssertTrue(state.nodeLatencyLoading.isEmpty)
        XCTAssertTrue(state.groupLatencies.isEmpty)
        XCTAssertTrue(state.liveProxyLatestDelay.isEmpty)
    }
}
