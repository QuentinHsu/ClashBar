import XCTest
@testable import CatBar

final class ResolveCoreFeatureRecoveryAttemptUseCaseTests: XCTestCase {
    func testExecuteSkipsWhenNoPendingRecoveryExists() {
        let useCase = ResolveCoreFeatureRecoveryAttemptUseCase()

        let decision = useCase.execute(.init(
            pendingRecovery: nil,
            isRuntimeRunning: true,
            autoManageCoreOnNetworkChangeEnabled: false,
            networkReachabilityStatus: .online))

        XCTAssertEqual(decision, .skip)
    }

    func testExecuteClearsEmptyPendingRecoveryState() {
        let useCase = ResolveCoreFeatureRecoveryAttemptUseCase()

        let decision = useCase.execute(.init(
            pendingRecovery: CoreFeatureRecoveryState(systemProxyEnabled: false, tunEnabled: false),
            isRuntimeRunning: true,
            autoManageCoreOnNetworkChangeEnabled: false,
            networkReachabilityStatus: .online))

        XCTAssertEqual(decision, .clearPendingState)
    }

    func testExecuteSkipsWhenRuntimeIsStoppedOrOfflineManaged() {
        let useCase = ResolveCoreFeatureRecoveryAttemptUseCase()
        let recovery = CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: false)

        let stoppedDecision = useCase.execute(.init(
            pendingRecovery: recovery,
            isRuntimeRunning: false,
            autoManageCoreOnNetworkChangeEnabled: false,
            networkReachabilityStatus: .online))
        let offlineDecision = useCase.execute(.init(
            pendingRecovery: recovery,
            isRuntimeRunning: true,
            autoManageCoreOnNetworkChangeEnabled: true,
            networkReachabilityStatus: .offline))

        XCTAssertEqual(stoppedDecision, .skip)
        XCTAssertEqual(offlineDecision, .skip)
    }

    func testExecuteAttemptsRecoveryWhenRuntimeCanRestoreFeatures() {
        let useCase = ResolveCoreFeatureRecoveryAttemptUseCase()
        let recovery = CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: true)

        let decision = useCase.execute(.init(
            pendingRecovery: recovery,
            isRuntimeRunning: true,
            autoManageCoreOnNetworkChangeEnabled: true,
            networkReachabilityStatus: .online))

        XCTAssertEqual(decision, .attempt(recovery))
    }
}
