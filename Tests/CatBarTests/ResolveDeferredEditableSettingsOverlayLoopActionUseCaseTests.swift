import XCTest
@testable import CatBar

final class ResolveDeferredEditableSettingsOverlayLoopActionUseCaseTests: XCTestCase {
    private let useCase = ResolveDeferredEditableSettingsOverlayLoopActionUseCase()

    func testExecuteStopsWhenTaskWasCancelled() {
        let action = self.useCase.execute(
            request: self.makeRequest(),
            isRuntimeRunning: true,
            isTaskCancelled: true)

        XCTAssertEqual(action, .stop)
    }

    func testExecuteStopsWhenRuntimeIsNotRunning() {
        let action = self.useCase.execute(
            request: self.makeRequest(),
            isRuntimeRunning: false,
            isTaskCancelled: false)

        XCTAssertEqual(action, .stop)
    }

    func testExecuteFinishesWhenRequestIsMissing() {
        let action = self.useCase.execute(
            request: nil,
            isRuntimeRunning: true,
            isTaskCancelled: false)

        XCTAssertEqual(action, .finish)
    }

    func testExecuteEvaluatesRequestWhenLoopCanProceed() {
        let request = self.makeRequest()

        let action = self.useCase.execute(
            request: request,
            isRuntimeRunning: true,
            isTaskCancelled: false)

        XCTAssertEqual(action, .evaluateRequest(request))
    }

    private func makeRequest() -> DeferredEditableSettingsOverlayRequest {
        DeferredEditableSettingsOverlayRequest(
            snapshot: EditableSettingsSnapshot(
                allowLan: true,
                ipv6: false,
                tcpConcurrent: true,
                tunEnabled: false,
                logLevel: ConfigLogLevel.info.rawValue,
                port: "7890",
                socksPort: "7891",
                mixedPort: "7892",
                redirPort: "",
                tproxyPort: ""),
            syncingKey: "test-overlay",
            syncSystemProxyPort: true)
    }
}
