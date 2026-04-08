import Foundation

enum CoreLaunchFailureAction: Equatable {
    case start(trigger: StartTrigger)
    case restart
}

enum CoreLaunchFailureFeedbackKind: Equatable {
    case missingConfig(message: String)
    case validationFailed(startupMessage: String)
    case executionFailed(message: String)
}

struct CoreLaunchFailureFeedback: Equatable {
    let shouldResetPreserveLocalSettings: Bool
    let logLevel: String?
    let logMessage: String?
    let alertTitle: String?
    let alertMessage: String?
    let alertDedupeKey: String?
    let startFailureResolution: StartCoreFailureResolution?
}

struct ResolveCoreLaunchFailureFeedbackUseCase {
    private let startCoreFailureResolver = StartCoreFailureResolver()

    func execute(
        action: CoreLaunchFailureAction,
        kind: CoreLaunchFailureFeedbackKind,
        startAlertTitle: String,
        restartAlertTitle: String) -> CoreLaunchFailureFeedback
    {
        switch (action, kind) {
        case let (.start(trigger), .missingConfig(message)):
            return CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: false,
                logLevel: "error",
                logMessage: message,
                alertTitle: startAlertTitle,
                alertMessage: message,
                alertDedupeKey: "core-start-failed",
                startFailureResolution: self.startCoreFailureResolver.resolve(
                    trigger: trigger,
                    kind: .missingConfig(message: message)))

        case let (.start(trigger), .validationFailed(startupMessage)):
            return CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: true,
                logLevel: nil,
                logMessage: nil,
                alertTitle: nil,
                alertMessage: nil,
                alertDedupeKey: nil,
                startFailureResolution: self.startCoreFailureResolver.resolve(
                    trigger: trigger,
                    kind: .validationFailed(startupMessage: startupMessage)))

        case let (.start(trigger), .executionFailed(message)):
            return CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: true,
                logLevel: "error",
                logMessage: message,
                alertTitle: startAlertTitle,
                alertMessage: message,
                alertDedupeKey: "core-start-failed",
                startFailureResolution: self.startCoreFailureResolver.resolve(
                    trigger: trigger,
                    kind: .executionFailed(message: message)))

        case let (.restart, .missingConfig(message)):
            return CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: false,
                logLevel: "error",
                logMessage: message,
                alertTitle: restartAlertTitle,
                alertMessage: message,
                alertDedupeKey: "core-restart-failed",
                startFailureResolution: nil)

        case let (.restart, .executionFailed(message)):
            return CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: true,
                logLevel: "error",
                logMessage: message,
                alertTitle: restartAlertTitle,
                alertMessage: message,
                alertDedupeKey: "core-restart-failed",
                startFailureResolution: nil)

        case (.restart, .validationFailed):
            return CoreLaunchFailureFeedback(
                shouldResetPreserveLocalSettings: true,
                logLevel: nil,
                logMessage: nil,
                alertTitle: nil,
                alertMessage: nil,
                alertDedupeKey: nil,
                startFailureResolution: nil)
        }
    }
}
