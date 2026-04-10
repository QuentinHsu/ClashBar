import XCTest
@testable import CatBar

final class LogEntryPresentationResolverTests: XCTestCase {
    private let subject = LogEntryPresentationResolver(fallbackText: "N/A")

    func testParseMessageExtractsProtocolAndTrailingDetail() {
        let result = self.subject.parseMessage(#"msg="[UDP] dns lookup ok [detail]""#)

        XCTAssertEqual(result.protocolTag, "[UDP]")
        XCTAssertEqual(result.protocolStyle, .warning)
        XCTAssertEqual(result.mainText, "dns lookup ok")
        XCTAssertEqual(result.detailText, "[detail]")
    }

    func testParseMessageFallsBackForEmptyInput() {
        let result = self.subject.parseMessage("   ")

        XCTAssertEqual(result.mainText, "N/A")
        XCTAssertNil(result.protocolTag)
        XCTAssertNil(result.detailText)
    }

    func testNormalizedLevelMapsWarningAndErrorKeywords() {
        XCTAssertEqual(self.subject.normalizedLevel("warn"), "WARNING")
        XCTAssertEqual(self.subject.normalizedLevel("error"), "ERROR")
        XCTAssertEqual(self.subject.normalizedLevel("info"), "INFO")
    }
}
