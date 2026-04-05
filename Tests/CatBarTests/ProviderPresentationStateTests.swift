import XCTest
@testable import CatBar

final class ProviderPresentationStateTests: XCTestCase {
    func testProxyProvidersDetailKeepsSortedProviderNamesInCaseInsensitiveOrder() {
        var state = ProviderPresentationState()

        state.proxyProvidersDetail = [
            "zeta": makeProviderDetail(name: "zeta"),
            "Alpha": makeProviderDetail(name: "Alpha"),
            "beta": makeProviderDetail(name: "beta"),
        ]

        XCTAssertEqual(state.sortedProxyProviderNames, ["Alpha", "beta", "zeta"])
    }

    func testInsertAndRetainUpdatingProviderNamesTracksOnlyActiveNames() {
        var state = ProviderPresentationState()
        state.providerUpdating = ["existing"]

        let inserted = state.insertUpdatingProviderNames(["existing", "new-a", "new-b"])
        state.retainUpdatingProviderNames(in: ["existing", "new-b"])

        XCTAssertEqual(inserted, ["new-a", "new-b"])
        XCTAssertEqual(state.providerUpdating, ["existing", "new-b"])
    }

    func testBeginAndEndUpdatingProviderUsesSetInsertionSemantics() {
        var state = ProviderPresentationState()

        XCTAssertTrue(state.beginUpdatingProvider("provider-a"))
        XCTAssertFalse(state.beginUpdatingProvider("provider-a"))

        state.endUpdatingProvider("provider-a")

        XCTAssertTrue(state.providerUpdating.isEmpty)
    }

    func testUpdateRefreshStatusStoresLatestSnapshot() {
        var state = ProviderPresentationState()
        let updatedAt = Date(timeIntervalSince1970: 123)

        state.updateRefreshStatus(
            phase: .failed,
            trigger: .restart,
            progressDone: 3,
            progressTotal: 5,
            message: "partial",
            updatedAt: updatedAt)

        XCTAssertEqual(state.providerRefreshStatus.phase, .failed)
        XCTAssertEqual(state.providerRefreshStatus.trigger, .restart)
        XCTAssertEqual(state.providerRefreshStatus.progressDone, 3)
        XCTAssertEqual(state.providerRefreshStatus.progressTotal, 5)
        XCTAssertEqual(state.providerRefreshStatus.message, "partial")
        XCTAssertEqual(state.providerRefreshStatus.updatedAt, updatedAt)
    }

    func testClearCollectionsResetsCountsAndRetainedCollections() throws {
        var state = ProviderPresentationState()
        state.providerProxyCount = 1
        state.providerRuleCount = 2
        state.rulesCount = 3
        state.proxyProvidersDetail = ["proxy": makeProviderDetail(name: "proxy")]
        state.providerUpdating = ["proxy"]
        state.ruleProviders = ["rule": makeProviderDetail(name: "rule")]
        state.ruleItems = [try makeRuleItem()]

        state.clearCollections(keepingCapacity: false)

        XCTAssertEqual(state.providerProxyCount, 0)
        XCTAssertEqual(state.providerRuleCount, 0)
        XCTAssertEqual(state.rulesCount, 0)
        XCTAssertTrue(state.proxyProvidersDetail.isEmpty)
        XCTAssertTrue(state.providerUpdating.isEmpty)
        XCTAssertTrue(state.ruleProviders.isEmpty)
        XCTAssertTrue(state.ruleItems.isEmpty)
    }

    private func makeProviderDetail(name: String) -> ProviderDetail {
        ProviderDetail(
            name: name,
            vehicleType: nil,
            testUrl: nil,
            timeout: nil,
            updatedAt: nil,
            ruleCount: nil,
            subscriptionInfo: nil,
            proxies: nil)
    }

    private func makeRuleItem() throws -> RuleItem {
        let data = #"{"type":"DOMAIN","payload":"example.com","proxy":"DIRECT"}"#.data(using: .utf8)!
        return try JSONDecoder().decode(RuleItem.self, from: data)
    }
}
