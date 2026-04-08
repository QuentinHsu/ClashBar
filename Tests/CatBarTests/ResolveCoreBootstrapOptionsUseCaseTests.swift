import XCTest
@testable import CatBar

final class ResolveCoreBootstrapOptionsUseCaseTests: XCTestCase {
    private let useCase = ResolveCoreBootstrapOptionsUseCase()

    func testExecuteReturnsStartBootstrapOptions() {
        let options = self.useCase.execute(.start)

        XCTAssertEqual(
            options,
            CoreBootstrapOptionsPlan(
                overlaySyncingKey: "start-overlay",
                providerTrigger: .start,
                refreshProxyGroupsAfterBootstrap: false,
                refreshSystemProxyBeforeOverlay: true,
                refreshSystemProxyAfterBootstrap: false,
                autoTestGroupLatencies: true))
    }

    func testExecuteReturnsRestartBootstrapOptions() {
        let options = self.useCase.execute(.restart(trigger: .configSwitch))

        XCTAssertEqual(
            options,
            CoreBootstrapOptionsPlan(
                overlaySyncingKey: "restart-overlay",
                providerTrigger: .configSwitch,
                refreshProxyGroupsAfterBootstrap: true,
                refreshSystemProxyBeforeOverlay: false,
                refreshSystemProxyAfterBootstrap: true,
                autoTestGroupLatencies: false))
    }
}
