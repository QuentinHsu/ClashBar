import XCTest
@testable import CatBar

final class ResolveRemoteConfigImportFeedbackUseCaseTests: XCTestCase {
    private let useCase = ResolveRemoteConfigImportFeedbackUseCase()

    func testExecuteBuildsErrorFeedbackForInvalidURL() {
        let feedback = self.useCase.execute(
            outcome: .requestValidationFailed(.invalidURL(input: "bad")),
            invalidURLMessage: { "invalid url: \($0)" },
            invalidFileNameMessage: { _ in XCTFail("unexpected file-name builder"); return "" },
            successMessage: { _ in XCTFail("unexpected success builder"); return "" },
            failureMessage: { _, _ in XCTFail("unexpected failure builder"); return "" })

        XCTAssertEqual(
            feedback,
            RemoteConfigImportFeedback(
                logLevel: "error",
                message: "invalid url: bad",
                alertIsSuccess: false))
    }

    func testExecuteBuildsErrorFeedbackForInvalidFileName() {
        let feedback = self.useCase.execute(
            outcome: .requestValidationFailed(.invalidFileName(input: "bad/name")),
            invalidURLMessage: { _ in XCTFail("unexpected URL builder"); return "" },
            invalidFileNameMessage: { "invalid file: \($0)" },
            successMessage: { _ in XCTFail("unexpected success builder"); return "" },
            failureMessage: { _, _ in XCTFail("unexpected failure builder"); return "" })

        XCTAssertEqual(
            feedback,
            RemoteConfigImportFeedback(
                logLevel: "error",
                message: "invalid file: bad/name",
                alertIsSuccess: false))
    }

    func testExecuteBuildsSuccessFeedback() {
        let feedback = self.useCase.execute(
            outcome: .succeeded(fileName: "remote.yaml"),
            invalidURLMessage: { _ in XCTFail("unexpected URL builder"); return "" },
            invalidFileNameMessage: { _ in XCTFail("unexpected file-name builder"); return "" },
            successMessage: { "imported \($0)" },
            failureMessage: { _, _ in XCTFail("unexpected failure builder"); return "" })

        XCTAssertEqual(
            feedback,
            RemoteConfigImportFeedback(
                logLevel: "info",
                message: "imported remote.yaml",
                alertIsSuccess: true))
    }

    func testExecuteBuildsFailureFeedback() {
        let feedback = self.useCase.execute(
            outcome: .failed(fileName: "remote.yaml", reason: "timeout"),
            invalidURLMessage: { _ in XCTFail("unexpected URL builder"); return "" },
            invalidFileNameMessage: { _ in XCTFail("unexpected file-name builder"); return "" },
            successMessage: { _ in XCTFail("unexpected success builder"); return "" },
            failureMessage: { fileName, reason in "\(fileName): \(reason)" })

        XCTAssertEqual(
            feedback,
            RemoteConfigImportFeedback(
                logLevel: "error",
                message: "remote.yaml: timeout",
                alertIsSuccess: false))
    }
}
