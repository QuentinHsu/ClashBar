import XCTest
@testable import CatBar

final class ResolveSystemProxyPortSyncPlanUseCaseTests: XCTestCase {
    private let useCase = ResolveSystemProxyPortSyncPlanUseCase()

    func testExecuteSkipsConnectionCloseWhenPreviousPortsAreUnavailable() {
        let currentPorts = SystemProxyPorts(httpPort: 7890, httpsPort: 7890, socksPort: 7890)

        let plan = self.useCase.execute(previousPorts: nil, currentPorts: currentPorts)

        XCTAssertFalse(plan.shouldCloseConnections)
    }

    func testExecuteSkipsConnectionCloseWhenPortsDidNotChange() {
        let currentPorts = SystemProxyPorts(httpPort: 7890, httpsPort: 7890, socksPort: 7890)

        let plan = self.useCase.execute(previousPorts: currentPorts, currentPorts: currentPorts)

        XCTAssertFalse(plan.shouldCloseConnections)
    }

    func testExecuteRequestsConnectionCloseWhenPortsChanged() {
        let previousPorts = SystemProxyPorts(httpPort: 7890, httpsPort: 7890, socksPort: 7890)
        let currentPorts = SystemProxyPorts(httpPort: 7891, httpsPort: 7891, socksPort: 7891)

        let plan = self.useCase.execute(previousPorts: previousPorts, currentPorts: currentPorts)

        XCTAssertTrue(plan.shouldCloseConnections)
    }
}
