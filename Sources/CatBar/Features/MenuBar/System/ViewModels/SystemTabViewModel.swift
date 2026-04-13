import Foundation

enum SystemFeedbackKind {
    case error
    case warning
    case success
    case info
}

struct SystemFeedbackState: Equatable {
    let message: String
    let kind: SystemFeedbackKind
    let symbol: String
}

struct NetworkHealthSummaryState: Equatable {
    let message: String
    let kind: SystemFeedbackKind
    let symbol: String
}

struct NetworkHealthRowState: Equatable, Identifiable {
    let id: String
    let title: String
    let statusText: String
    let detail: String?
    let symbol: String
    let kind: SystemFeedbackKind
}

@MainActor
enum SystemTabViewModel {
    static func maintenanceActionEnabled(session: AppSession) -> Bool {
        session.isRemoteTarget || session.coreRepository.isRunning || session.statusText.lowercased() == "running"
    }

    static func feedbackState(session: AppSession) -> SystemFeedbackState? {
        if let error = session.settingsErrorMessage.trimmedNonEmpty {
            return SystemFeedbackState(
                message: error,
                kind: .error,
                symbol: "exclamationmark.triangle.fill")
        }

        if let proxyHint = session.systemProxyOpenFailureHint?.trimmedNonEmpty {
            return SystemFeedbackState(
                message: "\(session.tr("app.system_proxy.alert.title")): \(proxyHint)",
                kind: .error,
                symbol: "exclamationmark.triangle.fill")
        }

        if let launchError = session.launchAtLoginErrorMessage.trimmedNonEmpty {
            return SystemFeedbackState(
                message: launchError,
                kind: .warning,
                symbol: "exclamationmark.circle.fill")
        }

        if let saved = session.settingsSavedMessage.trimmedNonEmpty {
            return SystemFeedbackState(
                message: saved,
                kind: .success,
                symbol: "checkmark.circle.fill")
        }

        return nil
    }

    static func networkHealthSummary(session: AppSession) -> NetworkHealthSummaryState {
        if !session.isRuntimeRunning {
            return NetworkHealthSummaryState(
                message: session.tr("ui.network_health.status.degraded"),
                kind: .info,
                symbol: "bolt.slash")
        }

        if session.apiStatus == .failed {
            return NetworkHealthSummaryState(
                message: session.tr("ui.network_health.status.degraded"),
                kind: .error,
                symbol: "xmark.octagon.fill")
        }

        let featureStates = [session.runtimeNetworkHealth.systemProxy.status, session.runtimeNetworkHealth.tun.status]
        if featureStates.contains(.mismatch) || featureStates.contains(.unavailable) || session.apiStatus == .degraded {
            return NetworkHealthSummaryState(
                message: session.tr("ui.network_health.status.degraded"),
                kind: .warning,
                symbol: "exclamationmark.triangle.fill")
        }

        if featureStates.contains(.healthy) {
            return NetworkHealthSummaryState(
                message: session.tr("ui.network_health.status.healthy"),
                kind: .success,
                symbol: "checkmark.shield.fill")
        }

        return NetworkHealthSummaryState(
            message: session.tr("ui.network_health.status.degraded"),
            kind: .info,
            symbol: "circle.dashed")
    }

    static func networkHealthRows(session: AppSession) -> [NetworkHealthRowState] {
        [
            NetworkHealthRowState(
                id: "core",
                title: session.tr("ui.network_health.row.core"),
                statusText: self.coreStatusText(session: session),
                detail: nil,
                symbol: "bolt.horizontal.circle",
                kind: self.coreStatusKind(session: session)),
            NetworkHealthRowState(
                id: "system_proxy",
                title: session.tr("ui.network_health.row.system_proxy"),
                statusText: self.featureStatusText(session: session, status: session.runtimeNetworkHealth.systemProxy.status),
                detail: nil,
                symbol: "network",
                kind: self.featureStatusKind(status: session.runtimeNetworkHealth.systemProxy.status)),
            NetworkHealthRowState(
                id: "tun",
                title: session.tr("ui.network_health.row.tun"),
                statusText: self.featureStatusText(session: session, status: session.runtimeNetworkHealth.tun.status),
                detail: nil,
                symbol: "shield.lefthalf.filled",
                kind: self.featureStatusKind(status: session.runtimeNetworkHealth.tun.status)),
        ]
    }

    private static func coreStatusText(session: AppSession) -> String {
        if !session.isRuntimeRunning {
            return session.tr("ui.network_health.status.stopped")
        }

        switch session.apiStatus {
        case .healthy:
            return session.tr("ui.network_health.status.healthy")
        case .degraded:
            return session.tr("ui.network_health.status.degraded")
        case .failed:
            return session.tr("ui.network_health.status.failed")
        case .unknown:
            return session.tr("ui.network_health.status.unavailable")
        }
    }

    private static func coreStatusKind(session: AppSession) -> SystemFeedbackKind {
        guard session.isRuntimeRunning else { return .info }
        switch session.apiStatus {
        case .healthy:
            return .success
        case .degraded:
            return .warning
        case .failed:
            return .error
        case .unknown:
            return .info
        }
    }

    private static func featureStatusText(session: AppSession, status: RuntimeNetworkFeatureHealthStatus) -> String {
        switch status {
        case .disabled:
            session.tr("ui.network_health.status.disabled")
        case .healthy:
            session.tr("ui.network_health.status.healthy")
        case .mismatch:
            session.tr("ui.network_health.status.degraded")
        case .unavailable:
            session.tr("ui.network_health.status.unavailable")
        }
    }

    private static func featureStatusKind(status: RuntimeNetworkFeatureHealthStatus) -> SystemFeedbackKind {
        switch status {
        case .disabled:
            .info
        case .healthy:
            .success
        case .mismatch:
            .warning
        case .unavailable:
            .info
        }
    }
}
