import Foundation
import XCTest
@testable import CatBar

final class PresentLogsUseCaseTests: XCTestCase {
    private let subject = PresentLogsUseCase()

    func testExecuteReturnsFirst120LogsWhenNoFiltersAreApplied() {
        let logs = (0..<125).map { index in
            AppErrorLogEntry(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID(),
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                source: index.isMultiple(of: 2) ? .catbar : .mihomo,
                level: index.isMultiple(of: 3) ? "warning" : "info",
                message: "message-\(index)")
        }

        let result = self.subject.execute(self.makeInput(logs: logs))

        XCTAssertEqual(result.count, 120)
        XCTAssertEqual(result.first?.message, "message-0")
        XCTAssertEqual(result.last?.message, "message-119")
    }

    func testExecuteAppliesSourceLevelAndSearchFiltersTogether() {
        let logs = [
            AppErrorLogEntry(source: .catbar, level: "info", message: "startup ok"),
            AppErrorLogEntry(source: .mihomo, level: "warning", message: "rule hit example.com"),
            AppErrorLogEntry(source: .mihomo, level: "error", message: "rule hit blocked.com"),
        ]

        let result = self.subject.execute(self.makeInput(
            logs: logs,
            selectedSources: [.mihomo],
            selectedLevels: [.warning],
            searchText: "example"))

        XCTAssertEqual(result.map(\.message), ["rule hit example.com"])
    }

    func testExecuteDoesNotSearchBeyondRetainedLogLimit() {
        let logs = (0..<121).map { index in
            AppErrorLogEntry(
                source: .catbar,
                level: "info",
                message: index == 120 ? "match-me" : "message-\(index)")
        }

        let result = self.subject.execute(self.makeInput(logs: logs, searchText: "match"))

        XCTAssertTrue(result.isEmpty)
    }

    private func makeInput(
        logs: [AppErrorLogEntry],
        selectedSources: Set<AppLogSource> = [],
        selectedLevels: Set<LogLevelFilter> = [],
        searchText: String = "") -> PresentLogsUseCase.Input
    {
        PresentLogsUseCase.Input(
            logs: logs,
            selectedSources: selectedSources,
            selectedLevels: selectedLevels,
            searchText: searchText,
            searchTextContent: \.message,
            normalizedLevel: { $0.trimmed.lowercased() },
            levelFilter: {
                switch $0 {
                case "warning":
                    .warning
                case "error":
                    .error
                default:
                    .info
                }
            })
    }
}
