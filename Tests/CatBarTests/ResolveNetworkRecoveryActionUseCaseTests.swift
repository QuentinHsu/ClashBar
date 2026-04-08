import XCTest
@testable import CatBar

final class ResolveNetworkRecoveryActionUseCaseTests: XCTestCase {
    private let useCase = ResolveNetworkRecoveryActionUseCase()

    func testExecuteStopsWhenAutoManagementIsDisabled() {
        let decision = self.useCase.execute(.init(
            autoManageCoreOnNetworkChangeEnabled: false,
            networkReachabilityStatus: .online,
            shouldResumeCoreAfterNetworkRecovery: true,
            isCoreActionProcessing: false,
            isRuntimeRunning: false,
            hasPendingFeatureRecovery: false))

        XCTAssertEqual(decision, .stop)
    }

    func testExecuteStopsWhenRecoveryShouldNotResume() {
        let decision = self.useCase.execute(.init(
            autoManageCoreOnNetworkChangeEnabled: true,
            networkReachabilityStatus: .online,
            shouldResumeCoreAfterNetworkRecovery: false,
            isCoreActionProcessing: false,
            isRuntimeRunning: false,
            hasPendingFeatureRecovery: false))

        XCTAssertEqual(decision, .stop)
    }

    func testExecuteWaitsWhileAnotherCoreActionIsInFlight() {
        let decision = self.useCase.execute(.init(
            autoManageCoreOnNetworkChangeEnabled: true,
            networkReachabilityStatus: .online,
            shouldResumeCoreAfterNetworkRecovery: true,
            isCoreActionProcessing: true,
            isRuntimeRunning: false,
            hasPendingFeatureRecovery: false))

        XCTAssertEqual(decision, .waitForCurrentCoreAction)
    }

    func testExecuteCompletesWhenCoreAlreadyRunningWithoutPendingFeatureRecovery() {
        let decision = self.useCase.execute(.init(
            autoManageCoreOnNetworkChangeEnabled: true,
            networkReachabilityStatus: .online,
            shouldResumeCoreAfterNetworkRecovery: true,
            isCoreActionProcessing: false,
            isRuntimeRunning: true,
            hasPendingFeatureRecovery: false))

        XCTAssertEqual(decision, .complete)
    }

    func testExecuteRestoresPendingFeaturesWhenCoreAlreadyRunning() {
        let decision = self.useCase.execute(.init(
            autoManageCoreOnNetworkChangeEnabled: true,
            networkReachabilityStatus: .online,
            shouldResumeCoreAfterNetworkRecovery: true,
            isCoreActionProcessing: false,
            isRuntimeRunning: true,
            hasPendingFeatureRecovery: true))

        XCTAssertEqual(decision, .restorePendingFeatures)
    }

    func testExecuteStartsCoreWhenRuntimeIsStopped() {
        let decision = self.useCase.execute(.init(
            autoManageCoreOnNetworkChangeEnabled: true,
            networkReachabilityStatus: .online,
            shouldResumeCoreAfterNetworkRecovery: true,
            isCoreActionProcessing: false,
            isRuntimeRunning: false,
            hasPendingFeatureRecovery: false))

        XCTAssertEqual(decision, .startCore)
    }
}
