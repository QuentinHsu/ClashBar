import XCTest
@testable import CatBar

final class ResolvePrimaryCoreActionUseCaseTests: XCTestCase {
    private let useCase = ResolvePrimaryCoreActionUseCase()

    func testExecuteSkipsWhenCoreActionIsAlreadyProcessing() {
        let decision = self.useCase.execute(
            isCoreActionProcessing: true,
            isRuntimeRunning: false)

        XCTAssertEqual(decision, .skip)
    }

    func testExecuteRequestsRestartWhenRuntimeIsRunning() {
        let decision = self.useCase.execute(
            isCoreActionProcessing: false,
            isRuntimeRunning: true)

        XCTAssertEqual(decision, .restart)
    }

    func testExecuteRequestsManualStartWhenRuntimeIsStopped() {
        let decision = self.useCase.execute(
            isCoreActionProcessing: false,
            isRuntimeRunning: false)

        XCTAssertEqual(decision, .startManual)
    }
}
