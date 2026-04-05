import XCTest
@testable import CatBar

final class LifecycleCoordinationStateTests: XCTestCase {
    func testBeginAutoStartAttemptSucceedsOnlyOnce() {
        var state = LifecycleCoordinationState()

        XCTAssertTrue(state.beginAutoStartAttempt())
        XCTAssertTrue(state.didAttemptAutoStart)
        XCTAssertFalse(state.beginAutoStartAttempt())
    }

    func testMarkSystemProxyConsistencyCheckedOnLaunchSetsFlag() {
        var state = LifecycleCoordinationState()

        state.markSystemProxyConsistencyCheckedOnLaunch()

        XCTAssertTrue(state.didCheckSystemProxyConsistencyOnLaunch)
    }

    func testNetworkReachabilityMonitoringLifecycleTracksFlagsAndResetState() {
        var state = LifecycleCoordinationState()
        state.networkReachabilityStatus = .online
        state.shouldResumeCoreAfterNetworkRecovery = true

        XCTAssertTrue(state.beginNetworkReachabilityMonitoring())
        XCTAssertFalse(state.beginNetworkReachabilityMonitoring())
        XCTAssertEqual(state.updateNetworkReachabilityStatus(.offline), .online)
        XCTAssertEqual(state.networkReachabilityStatus, .offline)

        state.endNetworkReachabilityMonitoring(resetState: true)

        XCTAssertFalse(state.isNetworkReachabilityMonitoring)
        XCTAssertEqual(state.networkReachabilityStatus, .unknown)
        XCTAssertFalse(state.shouldResumeCoreAfterNetworkRecovery)
    }
}
