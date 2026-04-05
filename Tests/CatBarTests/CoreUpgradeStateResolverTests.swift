import XCTest
@testable import CatBar

final class CoreUpgradeStateResolverTests: XCTestCase {
    private let resolver = CoreUpgradeStateResolver(unknownMessage: "unknown")

    func testResolveResponseReturnsSucceededForOkStatus() {
        let state = self.resolver.resolve(response: CoreUpgradeResponse(status: "OK", message: nil))

        XCTAssertEqual(state, .succeeded)
    }

    func testResolveMessageReturnsAlreadyLatestAndExtractsVersion() {
        let state = self.resolver.resolve(message: "already using latest version v1.2.3")

        XCTAssertEqual(state, .alreadyLatest(version: "1.2.3"))
    }

    func testResolveResponseFallsBackToUnknownWhenMessageMissing() {
        let state = self.resolver.resolve(response: CoreUpgradeResponse(status: nil, message: nil))

        XCTAssertEqual(state, .failed(message: "unknown"))
    }

    func testResolveErrorDecodesStructuredAPIErrorBody() {
        let error = APIError.statusCode(400, #"{"status":"", "message":"already using latest version v2.0.1"}"#)

        let state = self.resolver.resolve(error: error)

        XCTAssertEqual(state, .alreadyLatest(version: "2.0.1"))
    }

    func testResolveErrorFallsBackToRawResponseBodyWhenDecodedMessageUnknown() {
        let error = APIError.statusCode(400, #"{"status":"", "message":" "}"#)

        let state = self.resolver.resolve(error: error)

        XCTAssertEqual(state, .failed(message: #"{"status":"", "message":" "}"#))
    }
}
