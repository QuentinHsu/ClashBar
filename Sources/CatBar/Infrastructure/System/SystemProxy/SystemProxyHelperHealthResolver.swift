import Foundation
import ServiceManagement

struct SystemProxyHelperHealthResolver {
    func registrationState(from status: SMAppService.Status) -> SystemProxyHelperRegistrationState {
        switch status {
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notRegistered:
            .notRegistered
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    func failedHealthSnapshot(
        registrationState: SystemProxyHelperRegistrationState,
        backgroundActivityAllowed: Bool,
        processRunning: Bool,
        error: Error) -> SystemProxyHelperHealthSnapshot
    {
        SystemProxyHelperHealthSnapshot(
            registrationState: registrationState,
            backgroundActivityAllowed: backgroundActivityAllowed,
            processRunning: processRunning,
            failureReason: self.failureReason(for: error),
            rawMessage: self.failureMessage(for: error))
    }

    func failureReason(for error: Error) -> SystemProxyHelperFailureReason {
        guard let serviceError = error as? SystemProxyServiceError else {
            return .unknown
        }

        switch serviceError {
        case .helperNotBundled:
            return .helperNotBundled
        case .helperRequiresInstallToApplications:
            return .appNotInApplications
        case .helperNeedsApproval:
            return .backgroundActivityDisabled
        case .helperNotRegistered:
            return .helperNotRegistered
        case .helperStartTimedOut:
            return .helperStartTimedOut
        case .helperInvalidSignature:
            return .signatureMismatch
        case .helperConnectionFailed:
            return .helperConnectionFailed
        case .helperOperationFailed:
            return .helperOperationFailed
        case .invalidHost, .invalidPort:
            return .unknown
        }
    }

    func failureMessage(for error: Error) -> String {
        if let serviceError = error as? SystemProxyServiceError {
            return serviceError.localizedDescription
        }
        return error.localizedDescription
    }

    func isLikelyApprovalError(_ error: Error) -> Bool {
        let normalized = error.localizedDescription.lowercased()
        return normalized.contains("operation not permitted")
            || normalized.contains("disallowed")
            || normalized.contains("denied")
            || normalized.contains("launch constraint")
            || normalized.contains("background item")
            || normalized.contains("approval")
    }
}
