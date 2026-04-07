import XCTest
@testable import CatBar

final class ResolveRemoteConfigImportRequestUseCaseTests: XCTestCase {
    private let useCase = ResolveRemoteConfigImportRequestUseCase()

    func testExecuteBuildsRequestForSupportedURLAndNormalizedFileName() {
        let result = self.useCase.execute(
            urlString: "  https://example.com/sub.yaml  ",
            fileNameInput: "custom",
            isSupportedRemoteConfigURL: { $0.scheme == "https" },
            inferredRemoteConfigFileName: { _ in "fallback.yaml" },
            normalizedConfigFileName: { input, fallback in
                let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? fallback : "\(trimmed).yaml"
            })

        switch result {
        case let .success(request):
            XCTAssertEqual(request.remoteURL.absoluteString, "https://example.com/sub.yaml")
            XCTAssertEqual(request.fileName, "custom.yaml")
        case let .failure(error):
            XCTFail("unexpected failure: \(error)")
        }
    }

    func testExecuteUsesFallbackFileNameWhenInputIsEmpty() {
        let result = self.useCase.execute(
            urlString: "https://example.com/sub.yaml",
            fileNameInput: " ",
            isSupportedRemoteConfigURL: { $0.scheme == "https" },
            inferredRemoteConfigFileName: { _ in "fallback.yaml" },
            normalizedConfigFileName: { input, fallback in
                let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? fallback : trimmed
            })

        XCTAssertEqual(result.success?.fileName, "fallback.yaml")
    }

    func testExecuteFailsWhenURLIsUnsupported() {
        let result = self.useCase.execute(
            urlString: " ftp://example.com/sub.yaml ",
            fileNameInput: "remote",
            isSupportedRemoteConfigURL: { $0.scheme == "https" },
            inferredRemoteConfigFileName: { _ in "fallback.yaml" },
            normalizedConfigFileName: { input, _ in input })

        XCTAssertEqual(result.failure, .invalidURL(input: "ftp://example.com/sub.yaml"))
    }

    func testExecuteFailsWhenNormalizedFileNameIsUnavailable() {
        let result = self.useCase.execute(
            urlString: "https://example.com/sub.yaml",
            fileNameInput: "bad/name",
            isSupportedRemoteConfigURL: { $0.scheme == "https" },
            inferredRemoteConfigFileName: { _ in "fallback.yaml" },
            normalizedConfigFileName: { _, _ in nil })

        XCTAssertEqual(result.failure, .invalidFileName(input: "bad/name"))
    }
}

private extension Result where Success == RemoteConfigImportRequest, Failure == ResolveRemoteConfigImportRequestError {
    var success: Success? {
        switch self {
        case let .success(value):
            value
        case .failure:
            nil
        }
    }

    var failure: Failure? {
        switch self {
        case .success:
            nil
        case let .failure(error):
            error
        }
    }
}
