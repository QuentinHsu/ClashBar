import AppKit
import Foundation

@MainActor
extension AppSession {
    private var startCoreFailureResolver: StartCoreFailureResolver {
        StartCoreFailureResolver()
    }

    private var validateCoreConfigUseCase: ValidateCoreConfigUseCase {
        ValidateCoreConfigUseCase(coreRepository: self.coreRepository)
    }

    private var startCoreUseCase: StartCoreUseCase {
        StartCoreUseCase(coreRepository: self.coreRepository)
    }

    private var stopCoreUseCase: StopCoreUseCase {
        StopCoreUseCase(coreRepository: self.coreRepository)
    }

    private var restartCoreUseCase: RestartCoreUseCase {
        RestartCoreUseCase(coreRepository: self.coreRepository)
    }

    private var coreFeatureRecoveryTransitionResolver: CoreFeatureRecoveryTransitionResolver {
        CoreFeatureRecoveryTransitionResolver()
    }

    private var resolveCoreFeatureRecoveryAttemptUseCase: ResolveCoreFeatureRecoveryAttemptUseCase {
        ResolveCoreFeatureRecoveryAttemptUseCase()
    }

    private struct CoreBootstrapOptions {
        let overlaySyncingKey: String
        let providerTrigger: ProviderRefreshTrigger
        let refreshProxyGroupsAfterBootstrap: Bool
        let refreshSystemProxyBeforeOverlay: Bool
        let refreshSystemProxyAfterBootstrap: Bool
        let autoTestGroupLatencies: Bool
    }

    private struct CoreLaunchContext {
        let configPath: String
        let launchController: String
    }

    private func performExclusiveCoreAction(_ action: CoreActionState, operation: () async -> Void) async {
        guard self.beginPresentedCoreAction(action) else { return }
        defer { self.endPresentedCoreAction() }
        await operation()
    }

    private func applyStartCoreFailureResolution(_ resolution: StartCoreFailureResolution) {
        if let statusText = resolution.statusText {
            self.statusText = statusText
        }
        if let apiStatus = resolution.apiStatus {
            self.apiStatus = apiStatus
        }
        self.setPresentedStartupError(resolution.startupErrorMessage)
    }

    private func handleMissingStartCoreConfig(trigger: StartTrigger) {
        let message = tr("log.start.no_config")
        appendLog(level: "error", message: message)
        self.presentCoreFailureAlert(
            title: self.tr("app.core.alert.start_failed.title"),
            message: message,
            dedupeKey: "core-start-failed")
        self.applyStartCoreFailureResolution(
            self.startCoreFailureResolver.resolve(
                trigger: trigger,
                kind: .missingConfig(message: message)))
    }

    private func handleStartCoreValidationFailure(configPath: String, trigger: StartTrigger) {
        preserveLocalSettingsOnNextSync = false
        let startupMessage = tr("app.config.validation_failed.startup", URL(fileURLWithPath: configPath).lastPathComponent)
        self.applyStartCoreFailureResolution(
            self.startCoreFailureResolver.resolve(
                trigger: trigger,
                kind: .validationFailed(startupMessage: startupMessage)))
    }

    private func handleStartCoreExecutionFailure(_ error: Error, trigger: StartTrigger) {
        let errorMessage = self.coreErrorMessage(error)
        preserveLocalSettingsOnNextSync = false
        let message = tr("log.start.failed", errorMessage)
        appendLog(level: "error", message: message)
        self.presentCoreFailureAlert(
            title: self.tr("app.core.alert.start_failed.title"),
            message: message,
            dedupeKey: "core-start-failed")
        self.applyStartCoreFailureResolution(
            self.startCoreFailureResolver.resolve(
                trigger: trigger,
                kind: .executionFailed(message: message)))
    }

    private func handleMissingRestartCoreConfig() {
        let message = tr("log.start.no_config")
        appendLog(level: "error", message: message)
        self.presentCoreFailureAlert(
            title: self.tr("app.core.alert.restart_failed.title"),
            message: message,
            dedupeKey: "core-restart-failed")
    }

    private func handleRestartCoreExecutionFailure(_ error: Error) {
        let errorMessage = self.coreErrorMessage(error)
        preserveLocalSettingsOnNextSync = false
        let message = tr("log.restart.failed", errorMessage)
        appendLog(level: "error", message: message)
        self.presentCoreFailureAlert(
            title: self.tr("app.core.alert.restart_failed.title"),
            message: message,
            dedupeKey: "core-restart-failed")
    }

    private func prepareCoreLaunchContext(
        onMissingConfig: () -> Void,
        onValidationFailure: (String) -> Void) async -> CoreLaunchContext?
    {
        guard let configPath = await resolveSelectedConfigPath() else {
            onMissingConfig()
            return nil
        }

        guard await self.validateConfigBeforeCoreLaunch(configPath: configPath) else {
            onValidationFailure(configPath)
            return nil
        }

        return CoreLaunchContext(
            configPath: configPath,
            launchController: applyExternalControllerFromSelectedConfigFile(configPath: configPath))
    }

    func startCore(trigger: StartTrigger = .manual) async {
        guard !self.isRemoteTarget else { return }
        await self.performExclusiveCoreAction(.starting) {
            if trigger == .manual {
                shouldResumeCoreAfterNetworkRecovery = false
            }
            var settingsOverlay = currentEditableSettingsSnapshot()
            settingsOverlay = self.overlayApplyingPendingCoreFeatureRecovery(settingsOverlay)
            preserveLocalSettingsOnNextSync = true
            do {
                settingsOverlay = try await prepareTunOverlayForCoreStartup(settingsOverlay)

                guard let launchContext = await self.prepareCoreLaunchContext(
                    onMissingConfig: { self.handleMissingStartCoreConfig(trigger: trigger) },
                    onValidationFailure: { configPath in
                        self.handleStartCoreValidationFailure(configPath: configPath, trigger: trigger)
                    })
                else {
                    return
                }

                statusText = "Starting"
                _ = try await self.startCoreUseCase.execute(
                    configPath: launchContext.configPath,
                    controller: launchContext.launchController)

                await self.completeCoreBootstrap(
                    configPath: launchContext.configPath,
                    settingsOverlay: settingsOverlay,
                    options: CoreBootstrapOptions(
                        overlaySyncingKey: "start-overlay",
                        providerTrigger: .start,
                        refreshProxyGroupsAfterBootstrap: false,
                        refreshSystemProxyBeforeOverlay: true,
                        refreshSystemProxyAfterBootstrap: false,
                        autoTestGroupLatencies: true))
            } catch {
                self.handleStartCoreExecutionFailure(error, trigger: trigger)
            }
        }
    }

    func stopCore(trigger: StopTrigger = .manual) async {
        guard !self.isRemoteTarget else { return }
        await self.performExclusiveCoreAction(.stopping) {
            if trigger == .manual {
                shouldResumeCoreAfterNetworkRecovery = false
            }
            let recoverySnapshotBeforeStop = self.currentCoreFeatureRecoverySnapshot()
            await self.prepareCoreFeatureRecoveryBeforeCoreTransition(
                fallbackRecovery: recoverySnapshotBeforeStop)
            self.cancelDeferredEditableSettingsOverlaySync()
            cancelProviderRefresh(reason: "stop requested")
            await self.stopCoreUseCase.execute()
            cancelPolling()
            statusText = "Stopped"
            apiStatus = .unknown
            resetTrafficPresentation()
        }
    }

    func restartCore(trigger: ProviderRefreshTrigger = .restart) async {
        guard !self.isRemoteTarget else { return }
        await self.performExclusiveCoreAction(.restarting) {
            preserveLocalSettingsOnNextSync = true
            cancelProviderRefresh(reason: "restart requested")
            do {
                guard let launchContext = await self.prepareCoreLaunchContext(
                    onMissingConfig: { self.handleMissingRestartCoreConfig() },
                    onValidationFailure: { _ in preserveLocalSettingsOnNextSync = false })
                else {
                    return
                }

                let recoverySnapshotBeforeRestart = self.currentCoreFeatureRecoverySnapshot()
                await self.prepareCoreFeatureRecoveryBeforeCoreTransition(
                    fallbackRecovery: recoverySnapshotBeforeRestart)
                let settingsOverlay = self.overlayApplyingPendingCoreFeatureRecovery(currentEditableSettingsSnapshot())
                _ = try await self.restartCoreUseCase.execute(
                    configPath: launchContext.configPath,
                    controller: launchContext.launchController)
                await self.completeCoreBootstrap(
                    configPath: launchContext.configPath,
                    settingsOverlay: settingsOverlay,
                    options: CoreBootstrapOptions(
                        overlaySyncingKey: "restart-overlay",
                        providerTrigger: trigger,
                        refreshProxyGroupsAfterBootstrap: true,
                        refreshSystemProxyBeforeOverlay: false,
                        refreshSystemProxyAfterBootstrap: true,
                        autoTestGroupLatencies: false))
            } catch {
                self.handleRestartCoreExecutionFailure(error)
            }
        }
    }

    func performPrimaryCoreAction() async {
        guard !isCoreActionProcessing else { return }
        if isRuntimeRunning {
            await self.restartCore()
        } else {
            await self.startCore(trigger: .manual)
        }
    }

    func setUILanguage(_ language: AppLanguage) {
        guard uiLanguage != language else { return }
        uiLanguage = language
        defaults.set(language.rawValue, forKey: uiLanguageKey)
    }

    func setAppearanceMode(_ mode: AppAppearanceMode) {
        guard appearanceMode != mode else { return }
        appearanceMode = mode
        defaults.set(mode.rawValue, forKey: appearanceModeKey)
        self.applyAppAppearance()
    }

    /// Perform all cleanup asynchronously while the loading indicator is visible,
    /// then terminate the app.  This avoids `terminate(nil)`'s nested run loop
    /// (which prevents SwiftUI rendering) by doing all heavy work **before**
    /// calling terminate.
    func quitApp() async {
        guard self.beginPresentedQuittingApp() else { return }

        // Yield so SwiftUI commits the loading-indicator frame before we begin
        // any blocking-capable work.  100 ms ≈ 6 display-refresh cycles at 60 Hz.
        try? await Task.sleep(nanoseconds: 100_000_000)

        await self.performTerminationCleanup()

        // Cleanup is complete — terminate instantly.
        // applicationShouldTerminate will see isQuittingApp == true and return
        // .terminateNow, so terminate() won't block.
        NSApplication.shared.terminate(nil)
    }

    /// Async cleanup shared by ``quitApp()`` and the Cmd-Q / system-quit path
    /// in `applicationShouldTerminate(.terminateLater)`.
    func performTerminationCleanup() async {
        self.prepareForTermination()

        if self.isSystemProxyEnabled {
            try? await self.applySystemProxy(
                enabled: false,
                host: self.controllerHost(),
                ports: .disabled)
        }

        if coreRepository.isRunning {
            await self.stopCoreUseCase.execute()
        }

        self.isPanelPresented = false
    }

    private func prepareForTermination() {
        defaults.set(isSystemProxyEnabled, forKey: systemProxyEnabledOnQuitKey)
        shouldResumeCoreAfterNetworkRecovery = false
        stopNetworkReachabilityMonitoring(resetState: true)
        stopConfigDirectoryMonitoring()
        self.cancelDeferredEditableSettingsOverlaySync()
        cancelProviderRefresh(reason: "quit requested")
        cancelPolling()
    }

    func applyAppAppearance() {
        let app = NSApplication.shared
        switch appearanceMode {
        case .system:
            app.appearance = nil
        case .light:
            app.appearance = NSAppearance(named: .aqua)
        case .dark:
            app.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func normalizeMode(_ raw: String?) -> CoreMode? {
        guard let raw else { return nil }
        return CoreMode(rawValue: raw.lowercased())
    }

    @discardableResult
    func validateConfigBeforeCoreLaunch(configPath: String) async -> Bool {
        guard let details = await self.configValidationFailureDetails(configPath: configPath) else {
            return true
        }

        self.handleConfigValidationFailure(configPath: configPath, details: details)
        return false
    }

    private func presentConfigValidationFailedAlert(fileName: String, details: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = tr("app.config.validation_failed.title")
        alert.informativeText = tr("app.config.validation_failed.message", fileName, details)
        alert.addButton(withTitle: tr("ui.action.ok"))
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        alert.runModal()
    }

    func configValidationFailureDetails(configPath: String) async -> String? {
        do {
            try await self.validateCoreConfigUseCase.execute(configPath: configPath)
            return nil
        } catch {
            let detailsRaw = self.coreErrorMessage(error).trimmingCharacters(in: .whitespacesAndNewlines)
            return detailsRaw.isEmpty ? tr("ui.common.unknown") : detailsRaw
        }
    }

    func handleConfigValidationFailure(configPath: String, details: String) {
        let fileName = URL(fileURLWithPath: configPath).lastPathComponent
        appendLog(level: "error", message: tr("log.config.validate_failed", fileName, details))
        self.presentConfigValidationFailedAlert(fileName: fileName, details: details)
    }

    func presentCoreFailureAlert(
        title: String,
        message: String,
        dedupeKey: String,
        style: NSAlert.Style = .warning)
    {
        let now = Date()
        if self.lastCoreFailureAlertKey == dedupeKey,
           let lastAt = self.lastCoreFailureAlertAt,
           now.timeIntervalSince(lastAt) < self.coreFailureAlertThrottleInterval
        {
            return
        }

        self.lastCoreFailureAlertKey = dedupeKey
        self.lastCoreFailureAlertAt = now

        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: tr("ui.action.ok"))
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        alert.runModal()
    }

    func restartCoreIfNeededForConfigSwitch(previousPath: String?, nextPath: String?) async {
        guard let nextPath else { return }
        guard previousPath != nextPath else { return }
        guard coreRepository.isRunning else { return }

        pendingConfigSwitchOverlaySettings = currentEditableSettingsSnapshot()
        preserveLocalSettingsOnNextSync = true
        self.clearPresentedProxyGroups()
        clearMeasuredProxyDelays()
        appendLog(level: "info", message: tr("log.config.changed_restart"))
        cancelProviderRefresh(reason: "config switch requested")
        await self.restartCore(trigger: .configSwitch)
        await applyPendingConfigSwitchSettingsOverlayIfNeeded()
    }

    func refreshProxyGroupsAfterRestart() async {
        for _ in 0..<8 {
            await refreshProxyGroups()
            if apiStatus == .healthy { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    func attemptAutoStartIfNeeded() async {
        guard self.beginLifecycleAutoStartAttempt() else { return }
        await self.startCore(trigger: .auto)
    }

    private func completeCoreBootstrap(
        configPath: String,
        settingsOverlay: EditableSettingsSnapshot,
        options: CoreBootstrapOptions) async
    {
        statusText = "Running"
        apiStatus = .healthy
        resetTrafficPresentation()
        ensureAPIClient()
        startPolling()
        await refreshFromAPI(includeSlowCalls: true)

        await self.syncEditableSettingsOverlayForCoreBootstrap(
            settingsOverlay,
            syncingKey: options.overlaySyncingKey)
        await validateTunPermissionsOnStartup()
        await ensureTunMixedStackOnStartupIfNeeded()
        await self.verifyTunAfterOverlayIfNeeded(overlay: settingsOverlay)
        enqueueProviderRefresh(trigger: options.providerTrigger)

        if options.refreshProxyGroupsAfterBootstrap {
            await self.refreshProxyGroupsAfterRestart()
        }

        // Keep startup responsive even when helper registration or system proxy reads are slow.
        scheduleSystemProxyStartupPostflight(
            refreshStatusBeforeOverlay: options.refreshSystemProxyBeforeOverlay,
            refreshStatusAfterBootstrap: options.refreshSystemProxyAfterBootstrap)

        defaults.set(configPath, forKey: lastSuccessfulConfigPathKey)
        self.setPresentedStartupError(nil)
        await self.restoreCoreFeaturesAfterStartupIfNeeded()
        enforceNetworkManagedCorePolicyIfNeeded()

        if options.autoTestGroupLatencies {
            Task { [weak self] in
                await self?.refreshAllGroupLatencies()
            }
        }
    }

    private func overlayApplyingPendingCoreFeatureRecovery(_ overlay: EditableSettingsSnapshot)
        -> EditableSettingsSnapshot
    {
        guard let recovery = self.pendingCoreFeatureRecoveryState else { return overlay }
        guard recovery.tunEnabled else { return overlay }
        return overlay.withTunEnabled(true)
    }

    private func currentCoreFeatureRecoverySnapshot() -> CoreFeatureRecoveryState {
        CoreFeatureRecoveryState(
            systemProxyEnabled: self.isSystemProxyEnabled,
            tunEnabled: self.isTunEnabled)
            .merged(with: self.pendingCoreFeatureRecoveryState)
    }

    private func prepareCoreFeatureRecoveryBeforeCoreTransition(
        fallbackRecovery: CoreFeatureRecoveryState) async
    {
        let transitionPlan = self.coreFeatureRecoveryTransitionResolver.resolve(
            runtimeRunningBeforeTransition: self.isRuntimeRunning,
            systemProxyEnabled: self.isSystemProxyEnabled,
            tunEnabled: self.isTunEnabled,
            fallbackRecovery: fallbackRecovery,
            pendingRecovery: self.pendingCoreFeatureRecoveryState)
        self.pendingCoreFeatureRecoveryState = transitionPlan.pendingRecovery

        if transitionPlan.shouldDisableTunBeforeTransition {
            self.isTunEnabled = false
            self.appendLog(level: "info", message: self.tr("log.tun.toggled", self.tr("log.tun.disabled")))
        }

        guard transitionPlan.shouldDisableSystemProxyBeforeTransition else { return }
        self.isProxySyncing = true
        defer { self.isProxySyncing = false }

        do {
            try await self.applySystemProxy(enabled: false, host: self.controllerHost(), ports: .disabled)
            self.isSystemProxyEnabled = false
            self.systemProxyActiveDisplay = nil
            self.clearSystemProxyOpenFailureHint()
            self.appendLog(
                level: "info",
                message: self.tr("log.system_proxy.toggled", self.tr("log.system_proxy.disabled")))
        } catch {
            self.appendLog(
                level: "error",
                message: self.tr("log.system_proxy.toggle_failed", self.systemProxyErrorMessage(error)))
            await self.refreshSystemProxyHelperStatus()
            await self.refreshSystemProxyStatus()
        }
    }

    func seedCoreFeatureRecoveryFromPersistedQuitState() {
        let wasSystemProxyEnabled = defaults.bool(forKey: systemProxyEnabledOnQuitKey)
        defaults.removeObject(forKey: systemProxyEnabledOnQuitKey)
        guard wasSystemProxyEnabled else { return }
        // Only seed when no in-flight recovery is already pending (e.g. from stop/restart).
        guard pendingCoreFeatureRecoveryState == nil else { return }
        pendingCoreFeatureRecoveryState = CoreFeatureRecoveryState(
            systemProxyEnabled: true,
            tunEnabled: false)
    }

    func restoreCoreFeaturesAfterStartupIfNeeded() async {
        switch self.resolveCoreFeatureRecoveryAttemptUseCase.execute(.init(
            pendingRecovery: self.pendingCoreFeatureRecoveryState,
            isRuntimeRunning: self.isRuntimeRunning,
            autoManageCoreOnNetworkChangeEnabled: self.autoManageCoreOnNetworkChangeEnabled,
            networkReachabilityStatus: self.networkReachabilityStatus))
        {
        case .skip:
            return
        case .clearPendingState:
            self.pendingCoreFeatureRecoveryState = nil
            return
        case let .attempt(recovery):
            let tunRestored = await self.restoreTunFeatureIfNeeded(requested: recovery.tunEnabled)
            let systemProxyRestored = await self.restoreSystemProxyFeatureIfNeeded(
                requested: recovery.systemProxyEnabled)

            let remaining = CoreFeatureRecoveryState(
                systemProxyEnabled: recovery.systemProxyEnabled && !systemProxyRestored,
                tunEnabled: recovery.tunEnabled && !tunRestored)
            self.pendingCoreFeatureRecoveryState = remaining.pendingState
        }
    }

    private func restoreTunFeatureIfNeeded(requested: Bool) async -> Bool {
        guard requested else { return false }

        do {
            let runtimeConfig = try await self.fetchRuntimeConfigSnapshot()
            if runtimeConfig.tunEnabled != true {
                try await self.patchTunConfig(enable: true)
                try await self.verifyTunRuntimeState(expectedEnabled: true)
            } else if !self.isTunEnabled {
                return false
            }
        } catch {
            self.appendLog(
                level: "error",
                message: self.tr("log.tun.toggle_failed", self.tunErrorMessage(error)))
            return false
        }

        self.isTunEnabled = true
        self.persistEditableSettingsSnapshot()
        self.appendLog(level: "info", message: self.tr("log.tun.toggled", self.tr("log.tun.enabled")))
        return true
    }

    private func restoreSystemProxyFeatureIfNeeded(requested: Bool) async -> Bool {
        guard requested else { return false }

        self.isProxySyncing = true
        defer { self.isProxySyncing = false }

        do {
            let target = try self.resolveSystemProxyTargetFromState()
            let isAlreadyConfigured = try await self.isSystemProxyConfigured(
                host: target.host,
                ports: target.ports)
            if !isAlreadyConfigured {
                try await self.applySystemProxy(enabled: true, host: target.host, ports: target.ports)
            }
            self.isSystemProxyEnabled = true
            self.clearSystemProxyOpenFailureHint()
            self.systemProxyActiveDisplay = self.buildSystemProxyDisplayString(
                host: target.host,
                ports: target.ports)
            self.appendLog(
                level: "info",
                message: self.tr("log.system_proxy.toggled", self.tr("log.system_proxy.enabled")))
            return true
        } catch {
            self.appendLog(
                level: "error",
                message: self.tr("log.system_proxy.toggle_failed", self.systemProxyErrorMessage(error)))
            self.updateSystemProxyOpenFailureHint(for: error)
            await self.refreshSystemProxyHelperStatus()
            await self.refreshSystemProxyStatus()
            return false
        }
    }
}
