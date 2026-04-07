import XCTest
@testable import CatBar

final class ResolveConfigMutationFollowUpUseCaseTests: XCTestCase {
    private let useCase = ResolveConfigMutationFollowUpUseCase()

    func testExecuteSkipsReloadWhenNoFilesChanged() {
        let plan = self.useCase.execute(
            updatedFileNames: [],
            selectedConfigName: "active.yaml",
            isRuntimeRunning: true)

        XCTAssertFalse(plan.shouldReloadCurrentConfig)
    }

    func testExecuteSkipsReloadWhenRuntimeIsStopped() {
        let plan = self.useCase.execute(
            updatedFileNames: ["active.yaml"],
            selectedConfigName: "active.yaml",
            isRuntimeRunning: false)

        XCTAssertFalse(plan.shouldReloadCurrentConfig)
    }

    func testExecuteSkipsReloadWhenCurrentSelectionWasNotUpdated() {
        let plan = self.useCase.execute(
            updatedFileNames: ["other.yaml"],
            selectedConfigName: "active.yaml",
            isRuntimeRunning: true)

        XCTAssertFalse(plan.shouldReloadCurrentConfig)
    }

    func testExecuteRequestsReloadWhenRunningSelectionWasUpdated() {
        let plan = self.useCase.execute(
            updatedFileNames: ["active.yaml", "other.yaml"],
            selectedConfigName: "active.yaml",
            isRuntimeRunning: true)

        XCTAssertTrue(plan.shouldReloadCurrentConfig)
    }
}
