import XCTest
@testable import CatBar

final class CoreFeatureRecoveryStateTests: XCTestCase {
    func testPendingStateReturnsNilWhenNoRecoveryNeeded() {
        let state = CoreFeatureRecoveryState(systemProxyEnabled: false, tunEnabled: false)

        XCTAssertNil(state.pendingState)
    }

    func testPendingStateReturnsSelfWhenRecoveryIsNeeded() {
        let state = CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: false)

        XCTAssertEqual(state.pendingState?.systemProxyEnabled, true)
        XCTAssertEqual(state.pendingState?.tunEnabled, false)
    }

    func testMergedWithCombinesRecoveryFlags() {
        let state = CoreFeatureRecoveryState(systemProxyEnabled: false, tunEnabled: true)
        let other = CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: false)

        let merged = state.merged(with: other)

        XCTAssertTrue(merged.systemProxyEnabled)
        XCTAssertTrue(merged.tunEnabled)
    }
}
