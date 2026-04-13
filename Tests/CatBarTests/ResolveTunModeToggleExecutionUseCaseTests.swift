import XCTest
@testable import CatBar

final class ResolveTunModeToggleExecutionUseCaseTests: XCTestCase {
    private let useCase = ResolveTunModeToggleExecutionUseCase()

    func testExecuteUsesPersistOnlyWhenRuntimeIsStopped() {
        let execution = self.useCase.execute(isRemoteTarget: false, isRuntimeRunning: false)

        XCTAssertEqual(execution, .persistOnly)
    }

    func testExecuteUsesPatchRuntimeOnlyForRemoteTarget() {
        let execution = self.useCase.execute(isRemoteTarget: true, isRuntimeRunning: true)

        XCTAssertEqual(execution, .patchRuntimeOnly)
    }

    func testExecuteUsesPatchRuntimeAndRestartForLocalRunningRuntime() {
        let execution = self.useCase.execute(isRemoteTarget: false, isRuntimeRunning: true)

        XCTAssertEqual(execution, .patchRuntimeAndRestart)
    }
}
