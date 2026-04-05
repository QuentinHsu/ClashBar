import XCTest
@testable import CatBar

final class RemoteConfigMenuStateResolverTests: XCTestCase {
    private let resolver = RemoteConfigMenuStateResolver()

    func testResolveKeepsRefreshingPhaseWhileRefreshIsInFlight() {
        let current = RemoteConfigMenuState(
            updatedAt: Date(timeIntervalSince1970: 100),
            phase: .refreshing)

        let state = self.resolver.resolve(
            current: current,
            updatedAt: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(
            state,
            RemoteConfigMenuState(
                updatedAt: Date(timeIntervalSince1970: 200),
                phase: .refreshing))
    }

    func testResolveKeepsFailedPhaseWhenContentTimestampDidNotChange() {
        let updatedAt = Date(timeIntervalSince1970: 100)
        let current = RemoteConfigMenuState(updatedAt: updatedAt, phase: .failed)

        let state = self.resolver.resolve(current: current, updatedAt: updatedAt)

        XCTAssertEqual(state, RemoteConfigMenuState(updatedAt: updatedAt, phase: .failed))
    }

    func testResolveClearsFailedPhaseWhenContentTimestampChanges() {
        let current = RemoteConfigMenuState(
            updatedAt: Date(timeIntervalSince1970: 100),
            phase: .failed)

        let state = self.resolver.resolve(
            current: current,
            updatedAt: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(
            state,
            RemoteConfigMenuState(
                updatedAt: Date(timeIntervalSince1970: 200),
                phase: .idle))
    }

    func testResolveKeepsIdlePhaseForUnchangedIdleState() {
        let updatedAt = Date(timeIntervalSince1970: 100)
        let current = RemoteConfigMenuState(updatedAt: updatedAt, phase: .idle)

        let state = self.resolver.resolve(current: current, updatedAt: updatedAt)

        XCTAssertEqual(state, current)
    }
}
