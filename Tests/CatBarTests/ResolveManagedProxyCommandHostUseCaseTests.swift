import XCTest
@testable import CatBar

final class ResolveManagedProxyCommandHostUseCaseTests: XCTestCase {
    private let useCase = ResolveManagedProxyCommandHostUseCase()

    func testExecuteUsesControllerHostWhenRemoteTarget() {
        let host = self.useCase.execute(
            isRemoteTarget: true,
            controllerHost: "10.0.0.2",
            localExternalControllerHost: "127.0.0.1",
            allowLan: true,
            currentDeviceIPv4: "192.168.1.10")

        XCTAssertEqual(host, "10.0.0.2")
    }

    func testExecuteKeepsConfiguredHostWhenAllowLanDisabled() {
        let host = self.useCase.execute(
            isRemoteTarget: false,
            controllerHost: "127.0.0.1",
            localExternalControllerHost: "192.168.50.1",
            allowLan: false,
            currentDeviceIPv4: "192.168.1.10")

        XCTAssertEqual(host, "192.168.50.1")
    }

    func testExecuteUsesDeviceIPv4WhenAllowLanEnabledAndConfiguredHostIsLoopback() {
        let host = self.useCase.execute(
            isRemoteTarget: false,
            controllerHost: "127.0.0.1",
            localExternalControllerHost: "0.0.0.0",
            allowLan: true,
            currentDeviceIPv4: "192.168.1.10")

        XCTAssertEqual(host, "192.168.1.10")
    }

    func testExecuteFallsBackToControllerHostWhenDeviceIPv4Unavailable() {
        let host = self.useCase.execute(
            isRemoteTarget: false,
            controllerHost: "127.0.0.1",
            localExternalControllerHost: "localhost",
            allowLan: true,
            currentDeviceIPv4: nil)

        XCTAssertEqual(host, "127.0.0.1")
    }
}
