import XCTest
@testable import CatBar

final class BuildEditableSettingsOverlayPatchBodyUseCaseTests: XCTestCase {
    func testExecuteBuildsOverlayPatchBodyWithFallbackLogLevelAndMixedTunStack() throws {
        let useCase = BuildEditableSettingsOverlayPatchBodyUseCase()
        let overlay = EditableSettingsSnapshot(
            allowLan: true,
            ipv6: false,
            tcpConcurrent: true,
            tunEnabled: true,
            logLevel: " ",
            port: "",
            socksPort: "7891",
            mixedPort: "",
            redirPort: "",
            tproxyPort: "7895")
        let fallback = EditableSettingsSnapshot(
            allowLan: false,
            ipv6: true,
            tcpConcurrent: false,
            tunEnabled: false,
            logLevel: ConfigLogLevel.warning.rawValue,
            port: "7890",
            socksPort: "",
            mixedPort: "7893",
            redirPort: "",
            tproxyPort: "")

        let body = try useCase.execute(
            overlay: overlay,
            fallback: fallback,
            hasConfiguredTunStack: false)

        guard case let .bool(allowLan)? = body["allow-lan"] else {
            return XCTFail("missing allow-lan")
        }
        XCTAssertTrue(allowLan)

        guard case let .string(logLevel)? = body["log-level"] else {
            return XCTFail("missing log-level")
        }
        XCTAssertEqual(logLevel, ConfigLogLevel.warning.rawValue)

        guard case let .int(port)? = body["port"] else {
            return XCTFail("missing port")
        }
        XCTAssertEqual(port, 7890)

        guard case let .int(mixedPort)? = body["mixed-port"] else {
            return XCTFail("missing mixed-port")
        }
        XCTAssertEqual(mixedPort, 7893)

        guard case let .int(socksPort)? = body["socks-port"] else {
            return XCTFail("missing socks-port")
        }
        XCTAssertEqual(socksPort, 7891)

        guard case let .int(tproxyPort)? = body["tproxy-port"] else {
            return XCTFail("missing tproxy-port")
        }
        XCTAssertEqual(tproxyPort, 7895)

        guard case let .object(tunBody)? = body["tun"] else {
            return XCTFail("missing tun body")
        }
        guard case let .bool(tunEnabled)? = tunBody["enable"] else {
            return XCTFail("missing tun enable")
        }
        XCTAssertTrue(tunEnabled)
        guard case let .string(stack)? = tunBody["stack"] else {
            return XCTFail("missing tun stack")
        }
        XCTAssertEqual(stack, "mixed")

        guard case let .object(dnsBody)? = body["dns"] else {
            return XCTFail("missing dns body")
        }
        guard case let .bool(dnsEnabled)? = dnsBody["enable"] else {
            return XCTFail("missing dns enable")
        }
        XCTAssertTrue(dnsEnabled)
    }

    func testExecuteThrowsInvalidLogLevel() {
        let useCase = BuildEditableSettingsOverlayPatchBodyUseCase()
        let overlay = EditableSettingsSnapshot(
            allowLan: true,
            ipv6: false,
            tcpConcurrent: true,
            tunEnabled: false,
            logLevel: "verbose",
            port: "",
            socksPort: "",
            mixedPort: "",
            redirPort: "",
            tproxyPort: "")

        XCTAssertThrowsError(
            try useCase.execute(
                overlay: overlay,
                fallback: nil,
                hasConfiguredTunStack: true))
        { error in
            XCTAssertEqual(
                error as? BuildEditableSettingsOverlayPatchBodyError,
                .invalidLogLevel("verbose"))
        }
    }

    func testExecuteThrowsInvalidPortKey() {
        let useCase = BuildEditableSettingsOverlayPatchBodyUseCase()
        let overlay = EditableSettingsSnapshot(
            allowLan: true,
            ipv6: false,
            tcpConcurrent: true,
            tunEnabled: false,
            logLevel: ConfigLogLevel.info.rawValue,
            port: "70000",
            socksPort: "",
            mixedPort: "",
            redirPort: "",
            tproxyPort: "")

        XCTAssertThrowsError(
            try useCase.execute(
                overlay: overlay,
                fallback: nil,
                hasConfiguredTunStack: true))
        { error in
            XCTAssertEqual(
                error as? BuildEditableSettingsOverlayPatchBodyError,
                .invalidPort(key: "port"))
        }
    }
}
