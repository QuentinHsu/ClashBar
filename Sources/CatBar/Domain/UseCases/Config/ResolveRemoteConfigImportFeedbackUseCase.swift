import Foundation

enum RemoteConfigImportFeedbackOutcome: Equatable {
    case requestValidationFailed(ResolveRemoteConfigImportRequestError)
    case succeeded(fileName: String)
    case failed(fileName: String, reason: String)
}

struct RemoteConfigImportFeedback: Equatable {
    let logLevel: String
    let message: String
    let alertIsSuccess: Bool
}

struct ResolveRemoteConfigImportFeedbackUseCase {
    func execute(
        outcome: RemoteConfigImportFeedbackOutcome,
        invalidURLMessage: (String) -> String,
        invalidFileNameMessage: (String) -> String,
        successMessage: (String) -> String,
        failureMessage: (String, String) -> String) -> RemoteConfigImportFeedback
    {
        switch outcome {
        case let .requestValidationFailed(error):
            return self.feedback(
                for: error,
                invalidURLMessage: invalidURLMessage,
                invalidFileNameMessage: invalidFileNameMessage)
        case let .succeeded(fileName):
            return RemoteConfigImportFeedback(
                logLevel: "info",
                message: successMessage(fileName),
                alertIsSuccess: true)
        case let .failed(fileName, reason):
            return RemoteConfigImportFeedback(
                logLevel: "error",
                message: failureMessage(fileName, reason),
                alertIsSuccess: false)
        }
    }

    private func feedback(
        for error: ResolveRemoteConfigImportRequestError,
        invalidURLMessage: (String) -> String,
        invalidFileNameMessage: (String) -> String) -> RemoteConfigImportFeedback
    {
        let message: String
        switch error {
        case let .invalidURL(input):
            message = invalidURLMessage(input)
        case let .invalidFileName(input):
            message = invalidFileNameMessage(input)
        }

        return RemoteConfigImportFeedback(
            logLevel: "error",
            message: message,
            alertIsSuccess: false)
    }
}
