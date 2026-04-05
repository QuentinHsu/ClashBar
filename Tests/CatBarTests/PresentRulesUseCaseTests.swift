import Foundation
import XCTest
@testable import CatBar

final class PresentRulesUseCaseTests: XCTestCase {
    private let subject = PresentRulesUseCase()

    func testExecuteTruncatesRulesAndGroupsByFirstSeenPolicyOrder() throws {
        let items = [
            try self.makeRule(type: "DOMAIN", payload: "a.com", proxy: "Policy-B"),
            try self.makeRule(type: "DOMAIN", payload: "b.com", proxy: "Policy-A"),
            try self.makeRule(type: "DOMAIN", payload: "c.com", proxy: "Policy-B"),
        ] + (0..<110).map { index in
            try! self.makeRule(type: "MATCH", payload: "\(index)", proxy: "Tail")
        }

        let output = self.subject.execute(items: items, providers: [:])

        XCTAssertEqual(output.groups.map(\.policy), ["Policy-B", "Policy-A", "Tail"])
        XCTAssertEqual(output.groups[0].rules.count, 2)
        XCTAssertEqual(output.groups[1].rules.count, 1)
        XCTAssertEqual(output.groups[2].rules.count, 97)
    }

    func testExecuteBuildsCaseInsensitiveProviderLookupFromKeyAndDisplayName() {
        let providers = [
            "provider-one": ProviderDetail(
                name: "Provider One",
                vehicleType: nil,
                testUrl: nil,
                timeout: nil,
                updatedAt: nil,
                ruleCount: nil,
                subscriptionInfo: nil,
                proxies: nil),
        ]

        let output = self.subject.execute(items: [], providers: providers)

        XCTAssertEqual(output.providerLookup["provider-one"]?.name, "Provider One")
        XCTAssertEqual(output.providerLookup["provider one"]?.name, "Provider One")
    }

    private func makeRule(type: String, payload: String, proxy: String) throws -> RuleItem {
        let data = """
        {
          "type": "\(type)",
          "payload": "\(payload)",
          "proxy": "\(proxy)"
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(RuleItem.self, from: data)
    }
}
