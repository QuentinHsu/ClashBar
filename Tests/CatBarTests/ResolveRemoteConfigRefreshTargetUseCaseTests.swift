import XCTest
@testable import CatBar

final class ResolveRemoteConfigRefreshTargetUseCaseTests: XCTestCase {
    func testExecuteBuildsRefreshTargetForSupportedURL() {
        let useCase = ResolveRemoteConfigRefreshTargetUseCase()
        let configDirectory = URL(fileURLWithPath: "/tmp/configs", isDirectory: true)

        let result = useCase.execute(
            fileName: "remote.yaml",
            remoteConfigSources: ["remote.yaml": "https://example.com/sub.yaml"],
            configDirectory: configDirectory,
            isSupportedRemoteConfigURL: { $0.scheme == "https" })

        switch result {
        case let .success(target):
            XCTAssertEqual(target.fileName, "remote.yaml")
            XCTAssertEqual(target.remoteURL.absoluteString, "https://example.com/sub.yaml")
            XCTAssertEqual(target.targetURL.path, "/tmp/configs/remote.yaml")
        case let .failure(error):
            XCTFail("unexpected failure: \(error)")
        }
    }

    func testExecuteFailsWhenSourceIsMissingOrUnsupported() {
        let useCase = ResolveRemoteConfigRefreshTargetUseCase()
        let configDirectory = URL(fileURLWithPath: "/tmp/configs", isDirectory: true)

        let missingResult = useCase.execute(
            fileName: "remote.yaml",
            remoteConfigSources: [:],
            configDirectory: configDirectory,
            isSupportedRemoteConfigURL: { _ in true })
        let unsupportedResult = useCase.execute(
            fileName: "remote.yaml",
            remoteConfigSources: ["remote.yaml": "ftp://example.com/sub.yaml"],
            configDirectory: configDirectory,
            isSupportedRemoteConfigURL: { $0.scheme == "https" })

        XCTAssertEqual(
            missingResult.failure,
            .invalidURL(source: "remote.yaml"))
        XCTAssertEqual(
            unsupportedResult.failure,
            .invalidURL(source: "ftp://example.com/sub.yaml"))
    }
}

private extension Result where Failure == ResolveRemoteConfigRefreshTargetError {
    var failure: Failure? {
        switch self {
        case .success:
            nil
        case let .failure(error):
            error
        }
    }
}
