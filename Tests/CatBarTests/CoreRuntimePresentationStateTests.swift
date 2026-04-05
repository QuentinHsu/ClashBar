import XCTest
@testable import CatBar

final class CoreRuntimePresentationStateTests: XCTestCase {
    func testApplyRuntimeConfigSnapshotUpdatesModePortsAndLogLevel() {
        var state = CoreRuntimePresentationState()
        state.currentMode = .rule
        state.logLevel = ConfigLogLevel.info.rawValue

        state.applyRuntimeConfigSnapshot(
            ConfigSnapshot(
                allowLan: nil,
                mode: "global",
                logLevel: ConfigLogLevel.debug.rawValue,
                ipv6: nil,
                tcpConcurrent: nil,
                port: 7891,
                socksPort: 7892,
                redirPort: 7893,
                tproxyPort: 7894,
                mixedPort: 7895,
                tun: nil,
                externalController: nil),
            normalizeMode: { rawValue in
                guard let rawValue else { return nil }
                return CoreMode(rawValue: rawValue)
            })

        XCTAssertEqual(state.currentMode, .global)
        XCTAssertEqual(state.logLevel, ConfigLogLevel.debug.rawValue)
        XCTAssertEqual(state.port, 7891)
        XCTAssertEqual(state.socksPort, 7892)
        XCTAssertEqual(state.redirPort, 7893)
        XCTAssertEqual(state.tproxyPort, 7894)
        XCTAssertEqual(state.mixedPort, 7895)
    }

    func testApplyRuntimeConfigSnapshotPreservesModeAndLogLevelWhenUnavailable() {
        var state = CoreRuntimePresentationState()
        state.currentMode = .direct
        state.logLevel = ConfigLogLevel.warning.rawValue
        state.mixedPort = 7890

        state.applyRuntimeConfigSnapshot(
            ConfigSnapshot(
                allowLan: nil,
                mode: "unsupported",
                logLevel: nil,
                ipv6: nil,
                tcpConcurrent: nil,
                port: 9000,
                socksPort: nil,
                redirPort: nil,
                tproxyPort: nil,
                mixedPort: nil,
                tun: nil,
                externalController: nil),
            normalizeMode: { rawValue in
                guard let rawValue else { return nil }
                return CoreMode(rawValue: rawValue)
            })

        XCTAssertEqual(state.currentMode, .direct)
        XCTAssertEqual(state.logLevel, ConfigLogLevel.warning.rawValue)
        XCTAssertEqual(state.port, 9000)
        XCTAssertNil(state.socksPort)
        XCTAssertNil(state.redirPort)
        XCTAssertNil(state.tproxyPort)
        XCTAssertEqual(state.mixedPort, 0)
    }
}
