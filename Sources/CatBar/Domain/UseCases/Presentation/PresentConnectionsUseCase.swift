import Foundation

struct PresentConnectionsUseCase {
    func execute(
        connections: [ConnectionSummary],
        filterText: String,
        transportFilter: ConnectionsTransportFilter,
        sortOption: ConnectionsSortOption,
        searchText: (ConnectionSummary) -> String) -> [ConnectionSummary]
    {
        let source = connections.prefix(ConnectionsSnapshot.retainedConnectionLimit)
        let keyword = filterText.trimmed
        let needsSearch = !keyword.isEmpty
        let needsTransportFilter = transportFilter != .all

        let filtered: [ConnectionSummary]
        if !needsSearch, !needsTransportFilter {
            filtered = Array(source)
        } else {
            var matches: [ConnectionSummary] = []
            matches.reserveCapacity(min(connections.count, ConnectionsSnapshot.retainedConnectionLimit))

            for connection in source {
                if needsTransportFilter, !transportFilter.matches(connection.metadata?.network) {
                    continue
                }
                if needsSearch, !searchText(connection).localizedStandardContains(keyword) {
                    continue
                }
                matches.append(connection)
            }

            filtered = matches
        }

        guard sortOption != .default else { return filtered }

        var sorted = filtered
        switch sortOption {
        case .default:
            return sorted
        case .newest:
            self.sortConnectionsByTimestamp(&sorted, descending: true)
        case .oldest:
            self.sortConnectionsByTimestamp(&sorted, descending: false)
        case .uploadDesc:
            self.sortConnectionsByTraffic(&sorted) { $0.upload ?? 0 }
        case .downloadDesc:
            self.sortConnectionsByTraffic(&sorted) { $0.download ?? 0 }
        case .totalDesc:
            self.sortConnectionsByTraffic(&sorted) { ($0.upload ?? 0) + ($0.download ?? 0) }
        }

        return sorted
    }

    private func sortConnectionsByTimestamp(
        _ source: inout [ConnectionSummary],
        descending: Bool)
    {
        let fallback: TimeInterval = descending ? -1 : .greatestFiniteMagnitude
        source.sort { lhs, rhs in
            let left = lhs.startTimestamp ?? fallback
            let right = rhs.startTimestamp ?? fallback
            if left != right {
                return descending ? (left > right) : (left < right)
            }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
    }

    private func sortConnectionsByTraffic(
        _ source: inout [ConnectionSummary],
        _ metric: (ConnectionSummary) -> Int64)
    {
        source.sort { lhs, rhs in
            let left = metric(lhs)
            let right = metric(rhs)
            if left != right {
                return left > right
            }
            return (lhs.startTimestamp ?? -1) > (rhs.startTimestamp ?? -1)
        }
    }
}
