import XCTest
@testable import CatBar

final class ProviderPresentationStateTests: XCTestCase {
    func testProxyProvidersDetailKeepsSortedProviderNamesInCaseInsensitiveOrder() {
        var state = ProviderPresentationState()

        state.proxyProvidersDetail = [
            "zeta": ProviderDetail(
                name: "zeta",
                vehicleType: nil,
                testUrl: nil,
                timeout: nil,
                updatedAt: nil,
                ruleCount: nil,
                subscriptionInfo: nil,
                proxies: nil),
            "Alpha": ProviderDetail(
                name: "Alpha",
                vehicleType: nil,
                testUrl: nil,
                timeout: nil,
                updatedAt: nil,
                ruleCount: nil,
                subscriptionInfo: nil,
                proxies: nil),
            "beta": ProviderDetail(
                name: "beta",
                vehicleType: nil,
                testUrl: nil,
                timeout: nil,
                updatedAt: nil,
                ruleCount: nil,
                subscriptionInfo: nil,
                proxies: nil),
        ]

        XCTAssertEqual(state.sortedProxyProviderNames, ["Alpha", "beta", "zeta"])
    }
}
