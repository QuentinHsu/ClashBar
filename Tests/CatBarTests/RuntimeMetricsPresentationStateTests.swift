import XCTest
@testable import CatBar

final class RuntimeMetricsPresentationStateTests: XCTestCase {
    func testClearTrafficHistoryResetsTotalsHistoryAndSampleTime() {
        var state = RuntimeMetricsPresentationState()
        state.displayUpTotal = 10
        state.displayDownTotal = 20
        state.trafficHistoryUp = [1, 2]
        state.trafficHistoryDown = [3, 4]
        state.lastTrafficSampleAt = Date()

        state.clearTrafficHistory(historyMaxPoints: 8)

        XCTAssertEqual(state.displayUpTotal, 0)
        XCTAssertEqual(state.displayDownTotal, 0)
        XCTAssertEqual(state.trafficHistoryUp, [])
        XCTAssertEqual(state.trafficHistoryDown, [])
        XCTAssertNil(state.lastTrafficSampleAt)
    }

    func testAppendTrafficHistoryClampsNegativeValuesAndTrimsOldestSamples() {
        var state = RuntimeMetricsPresentationState()
        state.trafficHistoryUp = [1, 2]
        state.trafficHistoryDown = [3, 4]

        state.appendTrafficHistory(up: -5, down: 6, historyMaxPoints: 2)

        XCTAssertEqual(state.trafficHistoryUp, [2, 0])
        XCTAssertEqual(state.trafficHistoryDown, [4, 6])
    }

    func testUpdateTrafficTotalsUsesSnapshotTotalsWhenPresent() {
        var state = RuntimeMetricsPresentationState()
        let now = Date(timeIntervalSince1970: 100)
        let snapshot = TrafficSnapshot(up: 1, down: 2, upTotal: 30, downTotal: 40)

        state.updateTrafficTotals(from: snapshot, now: now)

        XCTAssertEqual(state.displayUpTotal, 30)
        XCTAssertEqual(state.displayDownTotal, 40)
        XCTAssertEqual(state.lastTrafficSampleAt, now)
    }

    func testUpdateTrafficTotalsAccumulatesUsingElapsedTimeWhenTotalsAreMissing() {
        var state = RuntimeMetricsPresentationState()
        state.displayUpTotal = 10
        state.displayDownTotal = 20
        state.lastTrafficSampleAt = Date(timeIntervalSince1970: 100)

        let now = Date(timeIntervalSince1970: 102)
        let snapshot = TrafficSnapshot(up: 3, down: 4)

        state.updateTrafficTotals(from: snapshot, now: now)

        XCTAssertEqual(state.displayUpTotal, 16)
        XCTAssertEqual(state.displayDownTotal, 28)
        XCTAssertEqual(state.lastTrafficSampleAt, now)
    }
}
