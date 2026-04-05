import XCTest
@testable import CatBar

final class PresentConnectionsUseCaseTests: XCTestCase {
    private let subject = PresentConnectionsUseCase()
    private let timestampFormatter = ISO8601DateFormatter()

    func testExecuteTruncatesToRetainedConnectionLimit() {
        let connections = (0..<125).map { index in
            self.makeConnection(id: "conn-\(index)", network: index.isMultiple(of: 2) ? "tcp" : "udp")
        }

        let result = self.subject.execute(
            connections: connections,
            filterText: "",
            transportFilter: .all,
            sortOption: .default,
            searchText: \.id)

        XCTAssertEqual(result.count, 120)
        XCTAssertEqual(result.first?.id, "conn-0")
        XCTAssertEqual(result.last?.id, "conn-119")
    }

    func testExecuteFiltersByTransportAndSearchText() {
        let connections = [
            self.makeConnection(id: "1", network: "tcp", host: "alpha.example.com"),
            self.makeConnection(id: "2", network: "udp", host: "beta.example.com"),
            self.makeConnection(id: "3", network: "http", host: "gamma.example.com"),
        ]

        let result = self.subject.execute(
            connections: connections,
            filterText: "gamma",
            transportFilter: .other,
            sortOption: .default,
            searchText: { $0.metadata?.host ?? "" })

        XCTAssertEqual(result.map(\.id), ["3"])
    }

    func testExecuteSortsByNewestTimestampWithStableIDFallback() {
        let connections = [
            self.makeConnection(id: "b", network: "tcp", startTimestamp: 10),
            self.makeConnection(id: "a", network: "tcp", startTimestamp: 10),
            self.makeConnection(id: "c", network: "tcp", startTimestamp: 30),
            self.makeConnection(id: "d", network: "tcp", startTimestamp: nil),
        ]

        let result = self.subject.execute(
            connections: connections,
            filterText: "",
            transportFilter: .all,
            sortOption: .newest,
            searchText: \.id)

        XCTAssertEqual(result.map(\.id), ["c", "a", "b", "d"])
    }

    func testExecuteSortsByTotalTrafficDescending() {
        let connections = [
            self.makeConnection(id: "small", network: "tcp", upload: 20, download: 10, startTimestamp: 50),
            self.makeConnection(id: "large", network: "tcp", upload: 40, download: 30, startTimestamp: 10),
            self.makeConnection(id: "tie-newer", network: "tcp", upload: 15, download: 15, startTimestamp: 60),
            self.makeConnection(id: "tie-older", network: "tcp", upload: 10, download: 20, startTimestamp: 30),
        ]

        let result = self.subject.execute(
            connections: connections,
            filterText: "",
            transportFilter: .all,
            sortOption: .totalDesc,
            searchText: \.id)

        XCTAssertEqual(result.map(\.id), ["large", "tie-newer", "small", "tie-older"])
    }

    private func makeConnection(
        id: String,
        network: String,
        host: String? = nil,
        upload: Int64? = nil,
        download: Int64? = nil,
        startTimestamp: TimeInterval? = nil) -> ConnectionSummary
    {
        let start = startTimestamp.map {
            self.timestampFormatter.string(from: Date(timeIntervalSince1970: $0))
        }
        return ConnectionSummary(
            id: id,
            upload: upload,
            download: download,
            start: start,
            rule: nil,
            rulePayload: nil,
            chains: nil,
            metadata: ConnectionMetadata(
                network: network,
                sourceIP: nil,
                destinationIP: nil,
                host: host))
    }
}
