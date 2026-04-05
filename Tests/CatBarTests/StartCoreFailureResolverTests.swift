import XCTest
@testable import CatBar

final class StartCoreFailureResolverTests: XCTestCase {
    private let resolver = StartCoreFailureResolver()

    func testAutoMissingConfigStopsRuntimeAndStoresStartupError() {
        let resolution = self.resolver.resolve(
            trigger: .auto,
            kind: .missingConfig(message: "missing"))

        XCTAssertEqual(
            resolution,
            StartCoreFailureResolution(
                statusText: "Stopped",
                apiStatus: .unknown,
                startupErrorMessage: "missing"))
    }

    func testManualValidationFailureMarksRuntimeAsFailedWithoutStartupError() {
        let resolution = self.resolver.resolve(
            trigger: .manual,
            kind: .validationFailed(startupMessage: "invalid"))

        XCTAssertEqual(
            resolution,
            StartCoreFailureResolution(
                statusText: "Failed",
                apiStatus: .failed,
                startupErrorMessage: nil))
    }

    func testManualMissingConfigKeepsCurrentRuntimeStateUntouched() {
        let resolution = self.resolver.resolve(
            trigger: .manual,
            kind: .missingConfig(message: "missing"))

        XCTAssertEqual(
            resolution,
            StartCoreFailureResolution(
                statusText: nil,
                apiStatus: nil,
                startupErrorMessage: nil))
    }

    func testNetworkRecoveryExecutionFailureUsesFailedStateWithoutStartupError() {
        let resolution = self.resolver.resolve(
            trigger: .networkRecovery,
            kind: .executionFailed(message: "boom"))

        XCTAssertEqual(
            resolution,
            StartCoreFailureResolution(
                statusText: "Failed",
                apiStatus: .failed,
                startupErrorMessage: nil))
    }
}
