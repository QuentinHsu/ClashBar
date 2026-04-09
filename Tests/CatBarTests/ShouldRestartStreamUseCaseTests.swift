import XCTest
@testable import CatBar

final class ShouldRestartStreamUseCaseTests: XCTestCase {
    func testReturnsTrueWhenNoActiveTaskExists() {
        let subject = ShouldRestartStreamUseCase()

        let result = subject.execute(.init(
            enabled: true,
            forceRestart: false,
            taskExists: false,
            lastPayloadAt: nil,
            now: Date(),
            staleAfter: 6))

        XCTAssertTrue(result)
    }

    func testReturnsFalseWhenTaskExistsAndPayloadIsFresh() {
        let subject = ShouldRestartStreamUseCase()
        let now = Date()

        let result = subject.execute(.init(
            enabled: true,
            forceRestart: false,
            taskExists: true,
            lastPayloadAt: now.addingTimeInterval(-2),
            now: now,
            staleAfter: 6))

        XCTAssertFalse(result)
    }

    func testReturnsTrueWhenTaskExistsButPayloadIsStale() {
        let subject = ShouldRestartStreamUseCase()
        let now = Date()

        let result = subject.execute(.init(
            enabled: true,
            forceRestart: false,
            taskExists: true,
            lastPayloadAt: now.addingTimeInterval(-9),
            now: now,
            staleAfter: 6))

        XCTAssertTrue(result)
    }

    func testReturnsFalseWhenStreamDoesNotHaveStalenessRequirement() {
        let subject = ShouldRestartStreamUseCase()

        let result = subject.execute(.init(
            enabled: true,
            forceRestart: false,
            taskExists: true,
            lastPayloadAt: Date.distantPast,
            now: Date(),
            staleAfter: nil))

        XCTAssertFalse(result)
    }
}
