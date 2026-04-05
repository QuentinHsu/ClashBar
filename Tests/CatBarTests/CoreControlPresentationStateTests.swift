import XCTest
@testable import CatBar

final class CoreControlPresentationStateTests: XCTestCase {
    func testBeginAndEndActionGuardsConcurrentTransitions() {
        var state = CoreControlPresentationState()

        XCTAssertTrue(state.beginAction(.starting))
        XCTAssertFalse(state.beginAction(.restarting))
        XCTAssertTrue(state.isActionProcessing)

        state.endAction()

        XCTAssertEqual(state.actionState, .idle)
        XCTAssertFalse(state.isActionProcessing)
    }

    func testSetStartupErrorStoresAndClearsMessage() {
        var state = CoreControlPresentationState()

        state.setStartupError("failed")
        XCTAssertEqual(state.startupErrorMessage, "failed")

        state.setStartupError(nil)
        XCTAssertNil(state.startupErrorMessage)
    }

    func testBeginUpgradeAndApplyUpgradeStateTrackInFlightState() {
        var state = CoreControlPresentationState()

        XCTAssertTrue(state.beginUpgrade())
        XCTAssertFalse(state.beginUpgrade())
        XCTAssertTrue(state.isUpgradeInFlight)

        state.applyUpgradeState(.failed(message: "oops"))

        XCTAssertFalse(state.isUpgradeInFlight)
        XCTAssertEqual(state.upgradeState, .failed(message: "oops"))
    }
}
