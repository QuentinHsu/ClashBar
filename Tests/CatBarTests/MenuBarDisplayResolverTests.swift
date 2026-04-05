import XCTest
@testable import CatBar

final class MenuBarDisplayResolverTests: XCTestCase {
    private let resolver = MenuBarDisplayResolver()

    func testResolveRuntimeVisualStatusPrefersExplicitStartingAndFailedStates() {
        XCTAssertEqual(
            self.resolver.resolveRuntimeVisualStatus(
                statusText: "Starting",
                apiStatus: .healthy,
                coreIsRunning: true),
            .starting)
        XCTAssertEqual(
            self.resolver.resolveRuntimeVisualStatus(
                statusText: "Failed",
                apiStatus: .healthy,
                coreIsRunning: true),
            .failed)
    }

    func testResolveRuntimeVisualStatusUsesApiHealthWhenRuntimeIsRunning() {
        XCTAssertEqual(
            self.resolver.resolveRuntimeVisualStatus(
                statusText: "Running",
                apiStatus: .healthy,
                coreIsRunning: false),
            .runningHealthy)
        XCTAssertEqual(
            self.resolver.resolveRuntimeVisualStatus(
                statusText: "Stopped",
                apiStatus: .degraded,
                coreIsRunning: true),
            .runningDegraded)
        XCTAssertEqual(
            self.resolver.resolveRuntimeVisualStatus(
                statusText: "Running",
                apiStatus: .failed,
                coreIsRunning: true),
            .failed)
    }

    func testResolveSpeedLinesReturnsZeroWhenNotRunning() {
        let lines = self.resolver.resolveSpeedLines(
            traffic: TrafficSnapshot(up: 2048, down: 1024),
            isRuntimeRunning: false)

        XCTAssertEqual(lines, .zero)
    }

    func testResolveDisplayBuildsIconAndSpeedSnapshot() {
        let display = self.resolver.resolveDisplay(
            mode: .iconAndSpeed,
            runtimeVisualStatus: .runningHealthy,
            isRuntimeRunning: true,
            traffic: TrafficSnapshot(up: 2048, down: 1024))

        XCTAssertEqual(display.mode, .iconAndSpeed)
        XCTAssertEqual(display.symbolName, "bolt.horizontal.circle.fill")
        XCTAssertEqual(display.speedLines, MenuBarSpeedLines(up: "2KB/s↑", down: "1KB/s↓"))
        XCTAssertTrue(display.isRunning)
    }

    func testResolveDisplayBuildsSpeedOnlySnapshotWithoutSymbol() {
        let display = self.resolver.resolveDisplay(
            mode: .speedOnly,
            runtimeVisualStatus: .runningDegraded,
            isRuntimeRunning: true,
            traffic: TrafficSnapshot(up: 0, down: 0))

        XCTAssertEqual(display.mode, .speedOnly)
        XCTAssertNil(display.symbolName)
        XCTAssertEqual(display.speedLines, MenuBarSpeedLines(up: "0KB/s↑", down: "0KB/s↓"))
    }
}
