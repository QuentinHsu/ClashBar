import XCTest
@testable import CatBar

final class SystemProxyConfigurationValidatorTests: XCTestCase {
    private let validator = SystemProxyConfigurationValidator()

    func testValidateHostTrimsWhitespace() throws {
        let host = try self.validator.validateHost("  127.0.0.1  ")

        XCTAssertEqual(host, "127.0.0.1")
    }

    func testValidateHostRejectsEmptyValue() {
        XCTAssertThrowsError(try self.validator.validateHost(" \n ")) { error in
            XCTAssertEqual(error as? SystemProxyServiceError, .invalidHost)
        }
    }

    func testValidateAndResolvePortsRequiresAtLeastOneEnabledPort() {
        XCTAssertThrowsError(
            try self.validator.validateAndResolvePorts(.disabled, requiresEnabledPort: true)
        ) { error in
            XCTAssertEqual(error as? SystemProxyServiceError, .invalidPort)
        }
    }

    func testValidateAndResolvePortsNormalizesNilValuesToZero() throws {
        let ports = try self.validator.validateAndResolvePorts(
            SystemProxyPorts(httpPort: 7890, httpsPort: nil, socksPort: 7891),
            requiresEnabledPort: true)

        XCTAssertEqual(ports, ValidatedSystemProxyPorts(httpPort: 7890, httpsPort: 0, socksPort: 7891))
    }

    func testFormatProxyDisplayWrapsIPv6Host() {
        let display = self.validator.formatProxyDisplay(host: "2001:db8::1", port: 7890)

        XCTAssertEqual(display, "[2001:db8::1]:7890")
    }
}
