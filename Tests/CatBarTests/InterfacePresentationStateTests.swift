import XCTest
@testable import CatBar

final class InterfacePresentationStateTests: XCTestCase {
    func testSetPanelPresentedReturnsWhetherValueChanged() {
        var state = InterfacePresentationState()

        XCTAssertTrue(state.setPanelPresented(true))
        XCTAssertFalse(state.setPanelPresented(true))
        XCTAssertTrue(state.isPanelPresented)
    }

    func testSetActiveMenuTabReturnsChangeFlagAndStoresValue() {
        var state = InterfacePresentationState()

        XCTAssertFalse(state.setActiveMenuTab(.proxy))
        XCTAssertTrue(state.setActiveMenuTab(.logs))
        XCTAssertEqual(state.activeMenuTab, .logs)
    }

    func testBeginQuittingOnlySucceedsOnce() {
        var state = InterfacePresentationState()

        XCTAssertTrue(state.beginQuitting())
        XCTAssertFalse(state.beginQuitting())
        XCTAssertTrue(state.isQuittingApp)
    }
}
