import Foundation
import XCTest
@testable import CatBar

final class LogPresentationStateTests: XCTestCase {
    func testPrependAddsNewestEntriesAtFrontAndEnforcesLimit() {
        var state = LogPresentationState(errorLogs: [
            self.makeLog(message: "older-1"),
            self.makeLog(message: "older-2"),
        ])

        state.prepend([
            self.makeLog(message: "new-1"),
            self.makeLog(message: "new-2"),
        ], limit: 3)

        XCTAssertEqual(state.errorLogs.map(\.message), ["new-2", "new-1", "older-1"])
    }

    func testTrimRemovesOldestEntriesPastLimit() {
        var state = LogPresentationState(errorLogs: [
            self.makeLog(message: "latest"),
            self.makeLog(message: "middle"),
            self.makeLog(message: "oldest"),
        ])

        state.trim(to: 2)

        XCTAssertEqual(state.errorLogs.map(\.message), ["latest", "middle"])
    }

    func testClearRespectsKeepingCapacityFlagAndEmptiesLogs() {
        var state = LogPresentationState(errorLogs: [
            self.makeLog(message: "one"),
            self.makeLog(message: "two"),
        ])

        state.clear(keepingCapacity: true)

        XCTAssertTrue(state.errorLogs.isEmpty)
    }

    private func makeLog(message: String) -> AppErrorLogEntry {
        AppErrorLogEntry(
            timestamp: Date(timeIntervalSince1970: 0),
            source: .catbar,
            level: "info",
            message: message)
    }
}
