import XCTest
@testable import CatBar

final class CoreFeatureRecoveryTransitionResolverTests: XCTestCase {
    private let resolver = CoreFeatureRecoveryTransitionResolver()

    func testRunningRuntimeCapturesCurrentFeaturesForRecovery() {
        let plan = self.resolver.resolve(
            runtimeRunningBeforeTransition: true,
            systemProxyEnabled: true,
            tunEnabled: true,
            fallbackRecovery: CoreFeatureRecoveryState(systemProxyEnabled: false, tunEnabled: false),
            pendingRecovery: nil)

        XCTAssertEqual(
            plan,
            CoreFeatureRecoveryTransitionPlan(
                pendingRecovery: CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: true),
                shouldDisableTunBeforeTransition: true,
                shouldDisableSystemProxyBeforeTransition: true))
    }

    func testFallbackRecoveryIsUsedWhenRuntimeStateCannotCaptureFeatures() {
        let plan = self.resolver.resolve(
            runtimeRunningBeforeTransition: false,
            systemProxyEnabled: false,
            tunEnabled: false,
            fallbackRecovery: CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: false),
            pendingRecovery: CoreFeatureRecoveryState(systemProxyEnabled: false, tunEnabled: true))

        XCTAssertEqual(
            plan,
            CoreFeatureRecoveryTransitionPlan(
                pendingRecovery: CoreFeatureRecoveryState(systemProxyEnabled: true, tunEnabled: true),
                shouldDisableTunBeforeTransition: false,
                shouldDisableSystemProxyBeforeTransition: false))
    }

    func testNoRecoveryNeededClearsPendingState() {
        let plan = self.resolver.resolve(
            runtimeRunningBeforeTransition: false,
            systemProxyEnabled: false,
            tunEnabled: false,
            fallbackRecovery: CoreFeatureRecoveryState(systemProxyEnabled: false, tunEnabled: false),
            pendingRecovery: nil)

        XCTAssertEqual(
            plan,
            CoreFeatureRecoveryTransitionPlan(
                pendingRecovery: nil,
                shouldDisableTunBeforeTransition: false,
                shouldDisableSystemProxyBeforeTransition: false))
    }
}
