import XCTest
@testable import CatBar

@MainActor
final class NodesTabViewModelTests: XCTestCase {
    func testBuildLocalNodesExcludesProviderNodesReservedMarkersAndSortsOutput() {
        let subject = NodesTabViewModel()
        let providers = [
            "Provider": ProviderDetail(
                name: "Provider",
                vehicleType: nil,
                testUrl: nil,
                timeout: nil,
                updatedAt: nil,
                ruleCount: nil,
                subscriptionInfo: nil,
                proxies: [
                    ProviderProxyNode(id: "shared-id", name: "Provider Node", type: "vmess"),
                ]),
        ]

        let result = subject.buildLocalNodes(
            proxyNodeIDs: [
                "Provider Node": "other-id",
                "Duplicate By ID": "shared-id",
                "URL-Test": "url-id",
                "Zulu": "z-id",
                "Alpha": "a-id",
            ],
            proxyNodeTypes: [
                "Provider Node": "vmess",
                "Duplicate By ID": "trojan",
                "URL-Test": "ss",
                "Zulu": "vmess",
                "Alpha": "ss",
            ],
            proxyProvidersDetail: providers)

        XCTAssertEqual(result.map(\.name), ["Alpha", "Zulu"])
        XCTAssertEqual(result.map(\.stableIdentity), ["a-id", "z-id"])
    }

    func testFilteredProviderNodesMatchesNameAndTypeCaseInsensitively() {
        let subject = NodesTabViewModel()
        let nodes = [
            ProviderProxyNode(name: "Tokyo Relay", type: "vmess"),
            ProviderProxyNode(name: "Osaka", type: "trojan"),
        ]

        XCTAssertEqual(subject.filteredProviderNodes(nodes, searchText: "TOKYO").map(\.name), ["Tokyo Relay"])
        XCTAssertEqual(subject.filteredProviderNodes(nodes, searchText: "tro").map(\.name), ["Osaka"])
    }

    func testFilteredLocalNodesMatchesNameAndTypeCaseInsensitively() {
        let subject = NodesTabViewModel()
        let nodes = [
            NodesTabViewModel.LocalNode(id: nil, name: "HK Relay", type: "vmess"),
            NodesTabViewModel.LocalNode(id: nil, name: "JP Direct", type: "ss"),
        ]

        XCTAssertEqual(subject.filteredLocalNodes(nodes, searchText: "relay").map(\.name), ["HK Relay"])
        XCTAssertEqual(subject.filteredLocalNodes(nodes, searchText: "VME").map(\.name), ["HK Relay"])
    }
}
