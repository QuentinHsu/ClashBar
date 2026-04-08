import XCTest
@testable import CatBar

final class ResolveSystemProxyTogglePlanUseCaseTests: XCTestCase {
    private let useCase = ResolveSystemProxyTogglePlanUseCase()

    func testExecuteReturnsOptimisticLocalPlanForStoppedLocalCore() {
        let plan = self.useCase.execute(
            enabled: true,
            isRemoteTarget: false,
            isRuntimeRunning: false,
            wasSystemProxyEnabled: false)

        XCTAssertEqual(plan.executionMode, .optimisticLocalOnly)
        XCTAssertTrue(plan.shouldOptimisticallyUpdateEnabledState)
        XCTAssertTrue(plan.shouldPersistEditableSettingsSnapshot)
        XCTAssertTrue(plan.shouldAppendToggleLogBeforeExecution)
        XCTAssertFalse(plan.shouldPatchRuntimeMode)
        XCTAssertFalse(plan.shouldCloseConnections)
        XCTAssertEqual(plan.success.helperRefresh, .status)
        XCTAssertFalse(plan.success.shouldResetObservedState)
        XCTAssertTrue(plan.failure.shouldUpdateFailureHint)
        XCTAssertTrue(plan.failure.shouldRefreshHelperStatus)
        XCTAssertFalse(plan.failure.shouldRefreshSystemProxyStatus)
    }

    func testExecuteReturnsRuntimeSynchronizedPlanForRunningCoreEnable() {
        let plan = self.useCase.execute(
            enabled: true,
            isRemoteTarget: false,
            isRuntimeRunning: true,
            wasSystemProxyEnabled: false)

        XCTAssertEqual(plan.executionMode, .runtimeSynchronized)
        XCTAssertFalse(plan.shouldOptimisticallyUpdateEnabledState)
        XCTAssertFalse(plan.shouldPersistEditableSettingsSnapshot)
        XCTAssertFalse(plan.shouldAppendToggleLogBeforeExecution)
        XCTAssertTrue(plan.shouldPatchRuntimeMode)
        XCTAssertTrue(plan.shouldCloseConnections)
        XCTAssertEqual(plan.success.helperRefresh, .runtimeSnapshot)
        XCTAssertTrue(plan.success.shouldClearFailureHint)
        XCTAssertTrue(plan.success.shouldClearHelperFailureState)
        XCTAssertTrue(plan.success.shouldAppendToggleLog)
        XCTAssertTrue(plan.failure.shouldUpdateFailureHint)
        XCTAssertTrue(plan.failure.shouldRefreshHelperStatus)
        XCTAssertTrue(plan.failure.shouldRefreshSystemProxyStatus)
        XCTAssertFalse(plan.failure.shouldResetObservedState)
    }

    func testExecuteDisablingWithoutCurrentProxyResetsObservedStateOnRuntimeFailure() {
        let plan = self.useCase.execute(
            enabled: false,
            isRemoteTarget: true,
            isRuntimeRunning: false,
            wasSystemProxyEnabled: false)

        XCTAssertEqual(plan.executionMode, .runtimeSynchronized)
        XCTAssertEqual(plan.success.helperRefresh, .none)
        XCTAssertTrue(plan.success.shouldResetObservedState)
        XCTAssertFalse(plan.failure.shouldUpdateFailureHint)
        XCTAssertTrue(plan.failure.shouldRefreshHelperStatus)
        XCTAssertFalse(plan.failure.shouldRefreshSystemProxyStatus)
        XCTAssertTrue(plan.failure.shouldResetObservedState)
    }
}
