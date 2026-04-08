import Foundation

enum ConfigReloadFeedbackOutcome: Equatable {
    case succeeded(actionName: String)
    case failed(actionName: String, reason: String)
}

struct ConfigReloadFeedback: Equatable {
    let logLevel: String
    let message: String
}

struct ResolveConfigReloadFeedbackUseCase {
    func execute(
        outcome: ConfigReloadFeedbackOutcome,
        successMessage: (String) -> String,
        failureMessage: (String, String) -> String) -> ConfigReloadFeedback
    {
        switch outcome {
        case let .succeeded(actionName):
            return ConfigReloadFeedback(
                logLevel: "info",
                message: successMessage(actionName))
        case let .failed(actionName, reason):
            return ConfigReloadFeedback(
                logLevel: "error",
                message: failureMessage(actionName, reason))
        }
    }
}
