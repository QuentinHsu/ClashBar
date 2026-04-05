import Foundation

enum StartCoreFailureKind: Equatable {
    case missingConfig(message: String)
    case validationFailed(startupMessage: String)
    case executionFailed(message: String)
}

struct StartCoreFailureResolution: Equatable {
    let statusText: String?
    let apiStatus: APIHealth?
    let startupErrorMessage: String?
}

struct StartCoreFailureResolver {
    func resolve(trigger: StartTrigger, kind: StartCoreFailureKind) -> StartCoreFailureResolution {
        switch (trigger, kind) {
        case let (.auto, .missingConfig(message)):
            return StartCoreFailureResolution(
                statusText: "Stopped",
                apiStatus: .unknown,
                startupErrorMessage: message)
        case let (.auto, .validationFailed(startupMessage)):
            return StartCoreFailureResolution(
                statusText: "Stopped",
                apiStatus: .unknown,
                startupErrorMessage: startupMessage)
        case let (.auto, .executionFailed(message)):
            return StartCoreFailureResolution(
                statusText: "Stopped",
                apiStatus: .unknown,
                startupErrorMessage: message)
        case (.manual, .missingConfig):
            return StartCoreFailureResolution(
                statusText: nil,
                apiStatus: nil,
                startupErrorMessage: nil)
        case (.manual, .validationFailed):
            return StartCoreFailureResolution(
                statusText: "Failed",
                apiStatus: .failed,
                startupErrorMessage: nil)
        case (.manual, .executionFailed):
            return StartCoreFailureResolution(
                statusText: "Failed",
                apiStatus: .failed,
                startupErrorMessage: nil)
        case (.networkRecovery, _):
            return StartCoreFailureResolution(
                statusText: "Failed",
                apiStatus: .failed,
                startupErrorMessage: nil)
        }
    }
}
