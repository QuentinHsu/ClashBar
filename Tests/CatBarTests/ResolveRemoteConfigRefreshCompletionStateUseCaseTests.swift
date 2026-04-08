import XCTest
@testable import CatBar

final class ResolveRemoteConfigRefreshCompletionStateUseCaseTests: XCTestCase {
    private let useCase = ResolveRemoteConfigRefreshCompletionStateUseCase()

    func testExecuteReturnsIdleStateWithResolvedUpdatedAtOnSuccess() {
        let current = RemoteConfigMenuState(
            updatedAt: Date(timeIntervalSince1970: 100),
            phase: .refreshing)
        let updatedAt = Date(timeIntervalSince1970: 200)

        let state = self.useCase.execute(
            current: current,
            completion: .succeeded(
                updatedAt: updatedAt,
                fallbackUpdatedAt: Date(timeIntervalSince1970: 300)))

        XCTAssertEqual(
            state,
            RemoteConfigMenuState(updatedAt: updatedAt, phase: .idle))
    }

    func testExecuteFallsBackToCurrentDateWhenSuccessTimestampMissing() {
        let current = RemoteConfigMenuState(
            updatedAt: Date(timeIntervalSince1970: 100),
            phase: .refreshing)
        let fallbackUpdatedAt = Date(timeIntervalSince1970: 300)

        let state = self.useCase.execute(
            current: current,
            completion: .succeeded(
                updatedAt: nil,
                fallbackUpdatedAt: fallbackUpdatedAt))

        XCTAssertEqual(
            state,
            RemoteConfigMenuState(updatedAt: fallbackUpdatedAt, phase: .idle))
    }

    func testExecutePreservesPreviousUpdatedAtOnFailure() {
        let previousUpdatedAt = Date(timeIntervalSince1970: 100)
        let current = RemoteConfigMenuState(
            updatedAt: previousUpdatedAt,
            phase: .refreshing)

        let state = self.useCase.execute(current: current, completion: .failed)

        XCTAssertEqual(
            state,
            RemoteConfigMenuState(updatedAt: previousUpdatedAt, phase: .failed))
    }
}
