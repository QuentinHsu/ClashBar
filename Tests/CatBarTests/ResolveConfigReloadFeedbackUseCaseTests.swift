import XCTest
@testable import CatBar

final class ResolveConfigReloadFeedbackUseCaseTests: XCTestCase {
    private let useCase = ResolveConfigReloadFeedbackUseCase()

    func testExecuteBuildsInfoFeedbackForSuccess() {
        let feedback = self.useCase.execute(
            outcome: .succeeded(actionName: "Reload Config"),
            successMessage: { "\($0): success" },
            failureMessage: { _, _ in XCTFail("failure builder should not be used"); return "" })

        XCTAssertEqual(
            feedback,
            ConfigReloadFeedback(
                logLevel: "info",
                message: "Reload Config: success"))
    }

    func testExecuteBuildsErrorFeedbackForFailure() {
        let feedback = self.useCase.execute(
            outcome: .failed(actionName: "Reload Config", reason: "boom"),
            successMessage: { _ in XCTFail("success builder should not be used"); return "" },
            failureMessage: { actionName, reason in "\(actionName): \(reason)" })

        XCTAssertEqual(
            feedback,
            ConfigReloadFeedback(
                logLevel: "error",
                message: "Reload Config: boom"))
    }
}
