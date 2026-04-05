import XCTest
@testable import CatBar

final class ConfigPresentationStateTests: XCTestCase {
    func testSyncConfigDirectoryUsesFirstAvailableFileWhenNothingSelected() {
        var state = ConfigPresentationState()

        state.syncConfigDirectory(
            path: "/tmp/configs",
            availableFileNames: ["alpha.yaml", "beta.yaml"])

        XCTAssertEqual(state.configDirectoryPath, "/tmp/configs")
        XCTAssertEqual(state.availableConfigFileNames, ["alpha.yaml", "beta.yaml"])
        XCTAssertEqual(state.selectedConfigName, "alpha.yaml")
    }

    func testSyncConfigDirectoryKeepsExistingSelection() {
        var state = ConfigPresentationState()
        state.selectedConfigName = "custom.yaml"

        state.syncConfigDirectory(
            path: "/tmp/configs",
            availableFileNames: ["alpha.yaml", "beta.yaml"])

        XCTAssertEqual(state.selectedConfigName, "custom.yaml")
    }
}
