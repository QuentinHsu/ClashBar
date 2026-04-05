import XCTest
@testable import CatBar

final class ConnectionRulePresentationResolverTests: XCTestCase {
    private let resolver = ConnectionRulePresentationResolver()

    func testParseRuleReadsParenthesizedPayload() {
        let parsed = self.resolver.parseRule("DOMAIN-SUFFIX(google.com)")

        XCTAssertEqual(
            parsed,
            ParsedConnectionRule(type: "DOMAIN-SUFFIX", payload: "google.com"))
    }

    func testParseRuleReadsCommaSeparatedPayload() {
        let parsed = self.resolver.parseRule("IP-CIDR,1.1.1.1/32")

        XCTAssertEqual(
            parsed,
            ParsedConnectionRule(type: "IP-CIDR", payload: "1.1.1.1/32"))
    }

    func testRuleTypeTextHidesMatchAndFinalMarkers() {
        XCTAssertEqual(self.resolver.ruleTypeText(raw: "MATCH", fallback: nil), "--")
        XCTAssertEqual(self.resolver.ruleTypeText(raw: nil, fallback: "FINAL"), "--")
    }

    func testChainsPartsDropsEmptyValuesAndReversesOrder() {
        XCTAssertEqual(
            self.resolver.chainsParts(["Proxy", "  ", "Group"]),
            ["Group", "Proxy"])
    }

    func testSearchTextIncludesCoreSearchFields() {
        let connection = ConnectionSummary(
            id: "abc",
            upload: 1,
            download: 2,
            start: "2026-01-01T12:00:00Z",
            rule: "DOMAIN-SUFFIX(example.com)",
            rulePayload: "payload",
            chains: ["Proxy", "Group"],
            metadata: ConnectionMetadata(
                network: "tcp",
                sourceIP: "10.0.0.1",
                destinationIP: "1.1.1.1",
                host: "example.com"))

        let text = self.resolver.searchText(for: connection)

        XCTAssertTrue(text.contains("example.com"))
        XCTAssertTrue(text.contains("1.1.1.1"))
        XCTAssertTrue(text.contains("10.0.0.1"))
        XCTAssertTrue(text.contains("tcp"))
        XCTAssertTrue(text.contains("abc"))
        XCTAssertTrue(text.contains("Group > Proxy"))
    }
}
