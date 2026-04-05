import XCTest
@testable import CatBar

final class LaunchAtLoginPresentationStateTests: XCTestCase {
    func testSyncEnabledUpdatesFlagOnly() {
        var state = LaunchAtLoginPresentationState()
        state.errorMessage = "keep"

        state.syncEnabled(true)

        XCTAssertTrue(state.isEnabled)
        XCTAssertEqual(state.errorMessage, "keep")
    }

    func testClearErrorRemovesOnlyMessage() {
        var state = LaunchAtLoginPresentationState()
        state.isEnabled = true
        state.errorMessage = "failed"

        state.clearError()

        XCTAssertTrue(state.isEnabled)
        XCTAssertNil(state.errorMessage)
    }

    func testApplyFailureRestoresEnabledStateAndSetsMessage() {
        var state = LaunchAtLoginPresentationState()

        state.applyFailure(enabled: false, message: "approval required")

        XCTAssertFalse(state.isEnabled)
        XCTAssertEqual(state.errorMessage, "approval required")
    }
}
