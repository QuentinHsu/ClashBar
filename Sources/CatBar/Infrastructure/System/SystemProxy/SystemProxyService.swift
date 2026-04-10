import Foundation
import os
import ProxyHelperShared
import ServiceManagement

enum SystemProxyServiceError: LocalizedError, Equatable {
    case invalidHost
    case invalidPort
    case helperNotBundled
    case helperRequiresInstallToApplications
    case helperNeedsApproval
    case helperNotRegistered(String?)
    case helperStartTimedOut
    case helperInvalidSignature(String)
    case helperConnectionFailed(String)
    case helperOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "Invalid proxy host."
        case .invalidPort:
            return "Invalid proxy port."
        case .helperNotBundled:
            return "Privileged helper not found in app bundle. Please rebuild and run the packaged app."
        case .helperRequiresInstallToApplications:
            return "Privileged helper can only be installed from /Applications. " +
                "Move CatBar.app to /Applications and reopen it."
        case .helperNeedsApproval:
            return "Privileged helper requires approval in System Settings > Login Items."
        case let .helperNotRegistered(message):
            if let message, !message.isEmpty {
                return "Privileged helper is not registered: \(message)"
            }
            return "Privileged helper is not registered."
        case .helperStartTimedOut:
            return "Privileged helper did not start in time."
        case let .helperInvalidSignature(message):
            return "Privileged helper signature invalid: \(message)"
        case let .helperConnectionFailed(message):
            return "Failed to connect privileged helper: \(message)"
        case let .helperOperationFailed(message):
            return "Privileged helper operation failed: \(message)"
        }
    }
}

struct SystemProxyService {
    private let helperLaunchRetryDelayNanoseconds: UInt64 = 250_000_000
    private let helperLaunchRetryAttempts = 4
    private let configurationValidator: SystemProxyConfigurationValidator
    private let environmentValidator: SystemProxyHelperEnvironmentValidator
    private let healthResolver: SystemProxyHelperHealthResolver
    private let commandRunner: SystemProxyCommandRunner
    private let helperBridge: SystemProxyHelperBridge

    private static let systemSettingsOpenGate = SystemSettingsOpenGate()

    private final class SystemSettingsOpenGate: Sendable {
        private let state = OSAllocatedUnfairLock(initialState: Date.distantPast)

        func openIfNeeded(minimumInterval: TimeInterval) {
            let shouldOpen = self.state.withLock { lastOpened in
                let now = Date()
                guard now.timeIntervalSince(lastOpened) >= minimumInterval else {
                    return false
                }
                lastOpened = now
                return true
            }

            if shouldOpen {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    init(
        configurationValidator: SystemProxyConfigurationValidator = SystemProxyConfigurationValidator(),
        environmentValidator: SystemProxyHelperEnvironmentValidator = SystemProxyHelperEnvironmentValidator(),
        healthResolver: SystemProxyHelperHealthResolver = SystemProxyHelperHealthResolver(),
        commandRunner: SystemProxyCommandRunner = SystemProxyCommandRunner(),
        helperBridge: SystemProxyHelperBridge = SystemProxyHelperBridge(
            machServiceName: ProxyHelperConstants.machServiceName,
            responseTimeoutNanoseconds: 4_000_000_000))
    {
        self.configurationValidator = configurationValidator
        self.environmentValidator = environmentValidator
        self.healthResolver = healthResolver
        self.commandRunner = commandRunner
        self.helperBridge = helperBridge
    }

    private enum HelperRegistrationResult {
        case ready
        case needsApproval
        case failed(String?)
    }

    func warmUpHelperIfPossible() async {
        guard self.environmentValidator.isHelperBundledInMainApp() else { return }
        guard self.environmentValidator.isRunningFromApplicationsDirectory() else { return }
        do {
            try self.environmentValidator.validateSigningRequirements()
        } catch {
            return
        }

        switch self.attemptHelperRegistration() {
        case .ready:
            _ = try? await self.waitForHelperResponsiveness()
        case .needsApproval, .failed:
            return
        }
    }

    func applySystemProxy(enabled: Bool, host: String, ports: SystemProxyPorts) async throws {
        let resolvedHost = try self.configurationValidator.validateHost(host)
        try await self.ensureHelperReadyForUse()

        if enabled {
            let resolvedPorts = try self.configurationValidator.validateAndResolvePorts(ports, requiresEnabledPort: true)
            try await self.invokeHelperMutation { helper, completion in
                helper.setSystemProxy(
                    host: resolvedHost,
                    httpPort: resolvedPorts.httpPort,
                    httpsPort: resolvedPorts.httpsPort,
                    socksPort: resolvedPorts.socksPort,
                    completion: completion)
            }
        } else {
            try await self.invokeHelperMutation { helper, completion in
                helper.clearSystemProxy(completion: completion)
            }
        }
    }

    func isSystemProxyEnabled() async throws -> Bool {
        try await self.ensureHelperReadyForUse()
        return try await self.invokeHelperBooleanQuery { helper, completion in
            helper.getSystemProxyState(completion: completion)
        }
    }

    func readSystemProxyActiveDisplay() async throws -> String? {
        try await self.ensureHelperReadyForUse()
        guard let target = try await self.invokeHelperActiveTargetQuery() else {
            return nil
        }
        return self.configurationValidator.formatProxyDisplay(host: target.host, port: target.port)
    }

    func readHelperHealthSnapshot() async -> SystemProxyHelperHealthSnapshot {
        let registrationState = self.healthResolver.registrationState(from: self.helperService().status)
        let backgroundActivityAllowed = registrationState != .requiresApproval

        do {
            let processRunning = try self.isHelperProcessRunning()
            try self.environmentValidator.validateEnvironment()

            switch registrationState {
            case .enabled:
                return SystemProxyHelperHealthSnapshot(
                    registrationState: registrationState,
                    backgroundActivityAllowed: backgroundActivityAllowed,
                    processRunning: processRunning,
                    failureReason: nil,
                    rawMessage: nil)
            case .requiresApproval:
                let error = SystemProxyServiceError.helperNeedsApproval
                return self.healthResolver.failedHealthSnapshot(
                    registrationState: registrationState,
                    backgroundActivityAllowed: backgroundActivityAllowed,
                    processRunning: processRunning,
                    error: error)
            case .notRegistered, .unavailable:
                let error = SystemProxyServiceError.helperNotRegistered(nil)
                return self.healthResolver.failedHealthSnapshot(
                    registrationState: registrationState,
                    backgroundActivityAllowed: backgroundActivityAllowed,
                    processRunning: processRunning,
                    error: error)
            }
        } catch {
            return self.healthResolver.failedHealthSnapshot(
                registrationState: registrationState,
                backgroundActivityAllowed: backgroundActivityAllowed,
                processRunning: false,
                error: error)
        }
    }

    func isSystemProxyConfigured(host: String, ports: SystemProxyPorts) async throws -> Bool {
        let resolvedHost = try self.configurationValidator.validateHost(host)
        let resolvedPorts = try self.configurationValidator.validateAndResolvePorts(ports, requiresEnabledPort: true)
        try await self.ensureHelperReadyForUse()
        return try await self.invokeHelperBooleanQuery { helper, completion in
            helper.isSystemProxyConfigured(
                host: resolvedHost,
                httpPort: resolvedPorts.httpPort,
                httpsPort: resolvedPorts.httpsPort,
                socksPort: resolvedPorts.socksPort,
                completion: completion)
        }
    }

    private func ensureHelperReadyForUse() async throws {
        try self.environmentValidator.validateEnvironment()
        try self.ensureHelperRegistered()
        try await self.ensureHelperProcessResponsive()
    }

    private func ensureHelperRegistered() throws {
        if self.helperService().status == .enabled {
            return
        }

        switch self.attemptHelperRegistration() {
        case .ready:
            return
        case .needsApproval:
            self.openSystemSettingsLoginItemsIfNeeded()
            throw SystemProxyServiceError.helperNeedsApproval
        case let .failed(message):
            let status = self.helperService().status
            throw SystemProxyServiceError.helperNotRegistered(message ?? "status=\(status.rawValue)")
        }
    }

    private func ensureHelperProcessResponsive() async throws {
        if try await self.waitForHelperResponsiveness() {
            return
        }

        try await self.reregisterHelper()

        if try await self.waitForHelperResponsiveness() {
            return
        }

        throw SystemProxyServiceError.helperStartTimedOut
    }

    private func attemptHelperRegistration() -> HelperRegistrationResult {
        let daemonService = self.helperService()
        if daemonService.status == .enabled {
            return .ready
        }

        do {
            try daemonService.register()
        } catch {
            if daemonService.status == .enabled {
                return .ready
            }
            if daemonService.status == .requiresApproval || self.healthResolver.isLikelyApprovalError(error) {
                return .needsApproval
            }
            return .failed(error.localizedDescription)
        }

        switch daemonService.status {
        case .enabled:
            return .ready
        case .requiresApproval:
            return .needsApproval
        case .notRegistered, .notFound:
            return .failed("status=\(daemonService.status.rawValue)")
        @unknown default:
            return .failed("status=\(daemonService.status.rawValue)")
        }
    }

    private func reregisterHelper() async throws {
        let daemonService = self.helperService()
        try? await daemonService.unregister()
        try self.ensureHelperRegistered()
    }

    private func waitForHelperResponsiveness() async throws -> Bool {
        for attempt in 0..<self.helperLaunchRetryAttempts {
            do {
                try await self.invokeHelperPing()
                return true
            } catch {
                if attempt < self.helperLaunchRetryAttempts - 1 {
                    try await Task.sleep(nanoseconds: self.helperLaunchRetryDelayNanoseconds)
                }
            }
        }
        return false
    }

    private func invokeHelperPing() async throws {
        try await self.invokeHelper { _ in
            try await self.helperBridge.invokePing()
        }
    }

    private func helperService() -> SMAppService {
        SMAppService.daemon(plistName: ProxyHelperConstants.daemonPlistName)
    }

    private func openSystemSettingsLoginItemsIfNeeded() {
        Self.systemSettingsOpenGate.openIfNeeded(minimumInterval: 60)
    }

    private func isHelperProcessRunning() throws -> Bool {
        try self.commandRunner.isProcessRunning(
            matching: ".*/\(ProxyHelperConstants.machServiceName)$")
    }

    private func invokeHelperMutation(
        _ invoke: @escaping (ProxyHelperProtocol, @escaping (Bool, String?) -> Void) -> Void) async throws
    {
        _ = try await self.invokeHelper { bridge in
            try await bridge.invokeMutation(invoke)
        } as Void
    }

    private func invokeHelperBooleanQuery(
        _ invoke: @escaping (ProxyHelperProtocol, @escaping (Bool, Bool, String?) -> Void) -> Void) async throws
        -> Bool
    {
        try await self.invokeHelper { bridge in
            try await bridge.invokeBooleanQuery(invoke)
        }
    }

    private func invokeHelperActiveTargetQuery() async throws -> (host: String, port: Int)? {
        try await self.invokeHelper { bridge in
            try await bridge.invokeActiveTargetQuery()
        }
    }

    private func invokeHelper<Value: Sendable>(
        _ invoke: @escaping (SystemProxyHelperBridge) async throws -> Value) async throws
        -> Value
    {
        do {
            return try await invoke(self.helperBridge)
        } catch {
            guard self.helperBridge.isConnectionFailure(error) else {
                throw error
            }
            try self.ensureHelperRegistered()
            try await self.ensureHelperProcessResponsive()
            return try await invoke(self.helperBridge)
        }
    }

    func clearSystemProxyBlocking(timeout: TimeInterval = 2.0) {
        self.helperBridge.clearSystemProxyBlocking(timeout: timeout)
    }
}
