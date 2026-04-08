import XCTest
@testable import CatBar

final class ResolveProxyCommandPortsUseCaseTests: XCTestCase {
    private let useCase = ResolveProxyCommandPortsUseCase()

    func testExecutePrefersDedicatedHttpAndSocksPorts() {
        let ports = self.useCase.execute(
            systemProxyPorts: SystemProxyPorts(httpPort: 7890, httpsPort: 7890, socksPort: 7891),
            effectiveMixedPort: 9999)

        XCTAssertEqual(ports, ProxyCommandPorts(httpPort: 7890, socksPort: 7891))
    }

    func testExecuteFallsBackAcrossAvailablePorts() {
        let ports = self.useCase.execute(
            systemProxyPorts: SystemProxyPorts(httpPort: nil, httpsPort: nil, socksPort: 7891),
            effectiveMixedPort: 9999)

        XCTAssertEqual(ports, ProxyCommandPorts(httpPort: 7891, socksPort: 7891))
    }

    func testExecuteFallsBackToEffectiveMixedPortWhenNoPortsExist() {
        let ports = self.useCase.execute(
            systemProxyPorts: .disabled,
            effectiveMixedPort: 7890)

        XCTAssertEqual(ports, ProxyCommandPorts(httpPort: 7890, socksPort: 7890))
    }
}
