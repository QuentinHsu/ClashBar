import XCTest
@testable import CatBar

final class SystemProxyPresentationStateTests: XCTestCase {
    func testResetObservedStateClearsHelperHealthAndDisplayWhenDisabled() {
        var state = SystemProxyPresentationState()
        state.isEnabled = false
        state.backgroundActivityAllowed = true
        state.helperProcessRunning = true
        state.helperFailureReason = .helperConnectionFailed
        state.helperFailureMessage = "failed"
        state.activeDisplay = "127.0.0.1:7890"

        state.resetObservedState()

        XCTAssertNil(state.backgroundActivityAllowed)
        XCTAssertNil(state.helperProcessRunning)
        XCTAssertNil(state.helperFailureReason)
        XCTAssertNil(state.helperFailureMessage)
        XCTAssertNil(state.activeDisplay)
    }

    func testResetObservedStateKeepsDisplayWhenEnabled() {
        var state = SystemProxyPresentationState()
        state.isEnabled = true
        state.activeDisplay = "127.0.0.1:7890"

        state.resetObservedState()

        XCTAssertEqual(state.activeDisplay, "127.0.0.1:7890")
    }

    func testApplyHelperHealthSnapshotStoresObservedFieldsAndReturnsPreviousValues() {
        var state = SystemProxyPresentationState()
        state.helperFailureReason = .helperNotRegistered
        state.helperFailureMessage = "before"

        let snapshot = SystemProxyHelperHealthSnapshot(
            registrationState: .enabled,
            backgroundActivityAllowed: false,
            processRunning: true,
            failureReason: .backgroundActivityDisabled,
            rawMessage: "after")

        let previous = state.applyHelperHealthSnapshot(snapshot)

        XCTAssertEqual(previous.previousReason, .helperNotRegistered)
        XCTAssertEqual(previous.previousMessage, "before")
        XCTAssertEqual(state.backgroundActivityAllowed, false)
        XCTAssertEqual(state.helperProcessRunning, true)
        XCTAssertEqual(state.helperFailureReason, .backgroundActivityDisabled)
        XCTAssertEqual(state.helperFailureMessage, "after")
    }
}
