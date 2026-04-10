import XCTest
@testable import CatBar

final class MihomoLaunchContextResolverTests: XCTestCase {
    private let resolver = MihomoLaunchContextResolver()

    func testValidationContextUsesParentOfConfigDirectoryAsWorkingDirectory() {
        let context = self.resolver.validationContext(
            binaryPath: "/tmp/mihomo",
            configPath: "/Users/test/Library/Application Support/catbar/config/default.yaml")

        XCTAssertEqual(context.binaryPath, "/tmp/mihomo")
        XCTAssertEqual(
            context.workingDirectoryURL.path,
            "/Users/test/Library/Application Support/catbar")
        XCTAssertEqual(
            context.arguments,
            ["-d", "/Users/test/Library/Application Support/catbar", "-f", "/Users/test/Library/Application Support/catbar/config/default.yaml", "-t"])
    }

    func testRuntimeContextUsesConfigDirectoryWhenPathIsOutsideConfigFolder() {
        let context = self.resolver.runtimeContext(
            binaryPath: "/tmp/mihomo",
            configPath: "/tmp/custom/profile.yaml",
            controller: "127.0.0.1:9090")

        XCTAssertEqual(context.workingDirectoryURL.path, "/tmp/custom")
        XCTAssertEqual(
            context.arguments,
            ["-d", "/tmp/custom", "-f", "/tmp/custom/profile.yaml", "-ext-ctl", "127.0.0.1:9090"])
    }
}
