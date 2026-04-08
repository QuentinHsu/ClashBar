import XCTest
@testable import CatBar

final class ResolveAppLaunchAutoStartUseCaseTests: XCTestCase {
    private let useCase = ResolveAppLaunchAutoStartUseCase()

    func testExecuteSchedulesWhenBackgroundRefreshAndAutoStartAreEnabled() {
        let decision = self.useCase.execute(.init(
            startBackgroundRefresh: true,
            autoStartCoreEnabled: true,
            shouldDeferForMissingManagedCore: false))

        XCTAssertEqual(decision, .schedule)
    }

    func testExecuteSkipsWhenBackgroundRefreshIsDisabled() {
        let decision = self.useCase.execute(.init(
            startBackgroundRefresh: false,
            autoStartCoreEnabled: true,
            shouldDeferForMissingManagedCore: false))

        XCTAssertEqual(decision, .skip)
    }

    func testExecuteSkipsWhenAutoStartIsDisabled() {
        let decision = self.useCase.execute(.init(
            startBackgroundRefresh: true,
            autoStartCoreEnabled: false,
            shouldDeferForMissingManagedCore: false))

        XCTAssertEqual(decision, .skip)
    }

    func testExecuteSkipsWhenManagedCoreIsMissing() {
        let decision = self.useCase.execute(.init(
            startBackgroundRefresh: true,
            autoStartCoreEnabled: true,
            shouldDeferForMissingManagedCore: true))

        XCTAssertEqual(decision, .skip)
    }
}
