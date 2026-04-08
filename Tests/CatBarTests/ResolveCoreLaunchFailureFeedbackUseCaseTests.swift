import XCTest
@testable import CatBar

final class ResolveCoreLaunchFailureFeedbackUseCaseTests: XCTestCase {
    private let useCase = ResolveCoreLaunchFailureFeedbackUseCase()

    func testExecuteBuildsStartMissingConfigFeedback() {
        let feedback = self.useCase.execute(
            action: .start(trigger: .auto),
            kind: .missingConfig(message: "no config"),
            startAlertTitle: "Start Failed",
            restartAlertTitle: "Restart Failed")

        XCTAssertEqual(
            feedback,
            CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: false,
                logLevel: "error",
                logMessage: "no config",
                alertTitle: "Start Failed",
                alertMessage: "no config",
                alertDedupeKey: "core-start-failed",
                startFailureResolution: StartCoreFailureResolver().resolve(
                    trigger: .auto,
                    kind: .missingConfig(message: "no config"))))
    }

    func testExecuteBuildsStartValidationFeedbackWithoutDuplicateLogOrAlert() {
        let feedback = self.useCase.execute(
            action: .start(trigger: .manual),
            kind: .validationFailed(startupMessage: "bad config"),
            startAlertTitle: "Start Failed",
            restartAlertTitle: "Restart Failed")

        XCTAssertEqual(
            feedback,
            CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: true,
                logLevel: nil,
                logMessage: nil,
                alertTitle: nil,
                alertMessage: nil,
                alertDedupeKey: nil,
                startFailureResolution: StartCoreFailureResolver().resolve(
                    trigger: .manual,
                    kind: .validationFailed(startupMessage: "bad config"))))
    }

    func testExecuteBuildsStartExecutionFeedback() {
        let feedback = self.useCase.execute(
            action: .start(trigger: .networkRecovery),
            kind: .executionFailed(message: "start failed"),
            startAlertTitle: "Start Failed",
            restartAlertTitle: "Restart Failed")

        XCTAssertEqual(
            feedback,
            CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: true,
                logLevel: "error",
                logMessage: "start failed",
                alertTitle: "Start Failed",
                alertMessage: "start failed",
                alertDedupeKey: "core-start-failed",
                startFailureResolution: StartCoreFailureResolver().resolve(
                    trigger: .networkRecovery,
                    kind: .executionFailed(message: "start failed"))))
    }

    func testExecuteBuildsRestartMissingConfigFeedback() {
        let feedback = self.useCase.execute(
            action: .restart,
            kind: .missingConfig(message: "no config"),
            startAlertTitle: "Start Failed",
            restartAlertTitle: "Restart Failed")

        XCTAssertEqual(
            feedback,
            CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: false,
                logLevel: "error",
                logMessage: "no config",
                alertTitle: "Restart Failed",
                alertMessage: "no config",
                alertDedupeKey: "core-restart-failed",
                startFailureResolution: nil))
    }

    func testExecuteBuildsRestartExecutionFeedback() {
        let feedback = self.useCase.execute(
            action: .restart,
            kind: .executionFailed(message: "restart failed"),
            startAlertTitle: "Start Failed",
            restartAlertTitle: "Restart Failed")

        XCTAssertEqual(
            feedback,
            CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: true,
                logLevel: "error",
                logMessage: "restart failed",
                alertTitle: "Restart Failed",
                alertMessage: "restart failed",
                alertDedupeKey: "core-restart-failed",
                startFailureResolution: nil))
    }
}
