import XCTest
@testable import CatBar

final class ResolveConfigMutationFollowUpUseCaseTests: XCTestCase {
    private let useCase = ResolveConfigMutationFollowUpUseCase()

    func testExecuteSkipsReloadWhenNoFilesChanged() {
        let plan = self.useCase.execute(
            updatedFileNames: [],
            selectedConfigName: "active.yaml",
            isRuntimeRunning: true,
            hasRemoteSourceChanges: false)

        XCTAssertFalse(plan.shouldRefreshConfigState)
        XCTAssertFalse(plan.shouldReloadCurrentConfig)
    }

    func testExecuteSkipsReloadWhenRuntimeIsStopped() {
        let plan = self.useCase.execute(
            updatedFileNames: ["active.yaml"],
            selectedConfigName: "active.yaml",
            isRuntimeRunning: false,
            hasRemoteSourceChanges: false)

        XCTAssertTrue(plan.shouldRefreshConfigState)
        XCTAssertFalse(plan.shouldReloadCurrentConfig)
    }

    func testExecuteSkipsReloadWhenCurrentSelectionWasNotUpdated() {
        let plan = self.useCase.execute(
            updatedFileNames: ["other.yaml"],
            selectedConfigName: "active.yaml",
            isRuntimeRunning: true,
            hasRemoteSourceChanges: false)

        XCTAssertTrue(plan.shouldRefreshConfigState)
        XCTAssertFalse(plan.shouldReloadCurrentConfig)
    }

    func testExecuteRequestsReloadWhenRunningSelectionWasUpdated() {
        let plan = self.useCase.execute(
            updatedFileNames: ["active.yaml", "other.yaml"],
            selectedConfigName: "active.yaml",
            isRuntimeRunning: true,
            hasRemoteSourceChanges: false)

        XCTAssertTrue(plan.shouldRefreshConfigState)
        XCTAssertTrue(plan.shouldReloadCurrentConfig)
    }

    func testExecuteRefreshesConfigStateWhenOnlyRemoteSourceChanged() {
        let plan = self.useCase.execute(
            updatedFileNames: [],
            selectedConfigName: "active.yaml",
            isRuntimeRunning: true,
            hasRemoteSourceChanges: true)

        XCTAssertTrue(plan.shouldRefreshConfigState)
        XCTAssertFalse(plan.shouldReloadCurrentConfig)
    }
}
