import CoreGraphics
import XCTest
@testable import CatBar

final class ConnectionsTopLineLayoutResolverTests: XCTestCase {
    private let resolver = ConnectionsTopLineLayoutResolver(
        topLineSpacing: 2,
        topMetaSpacing: 1,
        minimumHostWidthRatio: 0.5,
        minimumRuleWidth: 26,
        minimumPayloadWidth: 14)

    func testResolveReturnsZeroWidthsWhenTotalWidthIsZero() {
        XCTAssertEqual(
            self.resolver.resolve(totalWidth: 0, desiredRuleWidth: 40, desiredPayloadWidth: 80),
            ConnectionsTopLineLayout(hostWidth: 0, ruleWidth: 0, payloadWidth: 0))
    }

    func testResolvePreservesDesiredWidthsWhenSpaceIsAvailable() {
        XCTAssertEqual(
            self.resolver.resolve(totalWidth: 296, desiredRuleWidth: 40, desiredPayloadWidth: 80),
            ConnectionsTopLineLayout(hostWidth: 173, ruleWidth: 40, payloadWidth: 80))
    }

    func testResolveShrinksPayloadBeforeRuleWhenOverflowOccurs() {
        XCTAssertEqual(
            self.resolver.resolve(totalWidth: 120, desiredRuleWidth: 40, desiredPayloadWidth: 80),
            ConnectionsTopLineLayout(hostWidth: 60, ruleWidth: 40, payloadWidth: 17))
    }

    func testResolveShrinksRuleAfterPayloadHitsMinimum() {
        XCTAssertEqual(
            self.resolver.resolve(totalWidth: 100, desiredRuleWidth: 50, desiredPayloadWidth: 40),
            ConnectionsTopLineLayout(hostWidth: 50, ruleWidth: 33, payloadWidth: 14))
    }
}
