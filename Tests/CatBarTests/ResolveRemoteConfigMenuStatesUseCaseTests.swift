import XCTest
@testable import CatBar

final class ResolveRemoteConfigMenuStatesUseCaseTests: XCTestCase {
    private let useCase = ResolveRemoteConfigMenuStatesUseCase()

    func testExecuteReturnsEmptyStatesWhenNoRemoteSourcesRemain() {
        let states = self.useCase.execute(
            remoteConfigSources: [:],
            currentStates: ["remote.yaml": .idle],
            updatedAtProvider: { _ in nil })

        XCTAssertEqual(states, [:])
    }

    func testExecuteBuildsStatesForEachRemoteSource() {
        let updatedAt = Date(timeIntervalSince1970: 100)

        let states = self.useCase.execute(
            remoteConfigSources: [
                "a.yaml": "https://example.com/a",
                "b.yaml": "https://example.com/b",
            ],
            currentStates: [:],
            updatedAtProvider: { fileName in
                fileName == "a.yaml" ? updatedAt : nil
            })

        XCTAssertEqual(states["a.yaml"], RemoteConfigMenuState(updatedAt: updatedAt, phase: .idle))
        XCTAssertEqual(states["b.yaml"], .idle)
    }

    func testExecutePreservesRefreshingStateWhileRefreshIsInFlight() {
        let updatedAt = Date(timeIntervalSince1970: 100)
        let current = RemoteConfigMenuState(updatedAt: nil, phase: .refreshing)

        let states = self.useCase.execute(
            remoteConfigSources: ["remote.yaml": "https://example.com/sub.yaml"],
            currentStates: ["remote.yaml": current],
            updatedAtProvider: { _ in updatedAt })

        XCTAssertEqual(
            states["remote.yaml"],
            RemoteConfigMenuState(updatedAt: updatedAt, phase: .refreshing))
    }

    func testExecuteDropsStatesForRemovedRemoteSources() {
        let retainedUpdatedAt = Date(timeIntervalSince1970: 200)

        let states = self.useCase.execute(
            remoteConfigSources: ["kept.yaml": "https://example.com/kept.yaml"],
            currentStates: [
                "kept.yaml": .idle,
                "removed.yaml": RemoteConfigMenuState(updatedAt: Date(timeIntervalSince1970: 100), phase: .failed),
            ],
            updatedAtProvider: { _ in retainedUpdatedAt })

        XCTAssertEqual(states.count, 1)
        XCTAssertNil(states["removed.yaml"])
        XCTAssertEqual(states["kept.yaml"], RemoteConfigMenuState(updatedAt: retainedUpdatedAt, phase: .idle))
    }
}
