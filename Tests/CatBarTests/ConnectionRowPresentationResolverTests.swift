import CoreGraphics
import XCTest
@testable import CatBar

final class ConnectionRowPresentationResolverTests: XCTestCase {
    private let ruleResolver = ConnectionRulePresentationResolver()
    private let layoutResolver = ConnectionsTopLineLayoutResolver(
        topLineSpacing: 2,
        topMetaSpacing: 1,
        minimumHostWidthRatio: 0.5,
        minimumRuleWidth: 26,
        minimumPayloadWidth: 14)

    func testResolveBuildsPresentationWithRuleFallbacksAndTrafficText() {
        let subject = self.makeSubject()
        let connection = ConnectionSummary(
            id: "conn-1",
            upload: 1024,
            download: 2048,
            start: "2026-04-10T12:00:00Z",
            rule: "DOMAIN-SUFFIX(example.com)",
            rulePayload: nil,
            chains: ["Proxy-B", "Proxy-A"],
            metadata: .init(network: "tcp", sourceIP: nil, destinationIP: "1.1.1.1", host: "example.com"))

        let result = subject.resolve(connection)

        XCTAssertEqual(result.hostText, "example.com")
        XCTAssertEqual(result.ruleTypeText, "DOMAIN-SUFFIX")
        XCTAssertEqual(result.rulePayloadText, "example.com")
        XCTAssertEqual(result.networkText, "TCP")
        XCTAssertEqual(result.networkStyle, .tcp)
        XCTAssertEqual(result.visualStyle, .tcp)
        XCTAssertEqual(result.timeText, "12:00:00")
        XCTAssertEqual(result.upText, ValueFormatter.bytesCompactNoSpace(1024))
        XCTAssertEqual(result.downText, ValueFormatter.bytesCompactNoSpace(2048))
        XCTAssertEqual(result.chainParts, ["Proxy-A", "Proxy-B"])
    }

    func testResolveFallsBackToDestinationIPAndGenericVisual() {
        let subject = self.makeSubject()
        let connection = ConnectionSummary(
            id: "conn-2",
            upload: nil,
            download: nil,
            start: nil,
            rule: "MATCH",
            rulePayload: nil,
            chains: nil,
            metadata: .init(network: "quic", sourceIP: nil, destinationIP: "8.8.8.8", host: nil))

        let result = subject.resolve(connection)

        XCTAssertEqual(result.hostText, "8.8.8.8")
        XCTAssertEqual(result.ruleTypeText, "--")
        XCTAssertEqual(result.rulePayloadText, "--")
        XCTAssertEqual(result.networkText, "QUIC")
        XCTAssertEqual(result.networkStyle, .other)
        XCTAssertEqual(result.visualStyle, .generic)
    }

    private func makeSubject() -> ConnectionRowPresentationResolver {
        ConnectionRowPresentationResolver(
            ruleResolver: self.ruleResolver,
            layoutResolver: self.layoutResolver,
            rowContentWidth: 296,
            minimumRuleWidth: 26,
            minimumPayloadWidth: 14,
            measureRuleWidth: { CGFloat($0.count * 7) },
            measurePayloadWidth: { CGFloat($0.count * 6) },
            fallbackHostText: "N/A",
            formatTimeText: { _ in "12:00:00" },
            formatTrafficText: { ValueFormatter.bytesCompactNoSpace($0) })
    }
}
