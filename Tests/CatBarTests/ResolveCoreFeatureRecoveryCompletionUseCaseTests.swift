import XCTest
@testable import CatBar

final class ResolveCoreFeatureRecoveryCompletionUseCaseTests: XCTestCase {
    func testExecuteClearsPendingRecoveryWhenAllRequestedFeaturesRestore() {
        let useCase = ResolveCoreFeatureRecoveryCompletionUseCase()

        let pendingRecovery = useCase.execute(.init(
            requestedRecovery: CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: true),
            systemProxyRestored: true,
            tunRestored: true))

        XCTAssertNil(pendingRecovery)
    }

    func testExecuteKeepsOnlyFailedRequestedFeaturesPending() {
        let useCase = ResolveCoreFeatureRecoveryCompletionUseCase()

        let pendingRecovery = useCase.execute(.init(
            requestedRecovery: CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: true),
            systemProxyRestored: false,
            tunRestored: true))

        XCTAssertEqual(
            pendingRecovery,
            CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: false))
    }

    func testExecuteIgnoresUnrequestedFeaturesEvenWhenRestoreFlagsAreFalse() {
        let useCase = ResolveCoreFeatureRecoveryCompletionUseCase()

        let pendingRecovery = useCase.execute(.init(
            requestedRecovery: CoreFeatureRecoveryState(systemProxyEnabled: false, tunEnabled: true),
            systemProxyRestored: false,
            tunRestored: false))

        XCTAssertEqual(
            pendingRecovery,
            CoreFeatureRecoveryState(systemProxyEnabled: false, tunEnabled: true))
    }
}
