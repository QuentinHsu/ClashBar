import AppKit
import Foundation

@MainActor
extension AppSession {
    private var resolveCoreBootstrapOptionsUseCase: ResolveCoreBootstrapOptionsUseCase {
        ResolveCoreBootstrapOptionsUseCase()
    }

    private var resolvePrimaryCoreActionUseCase: ResolvePrimaryCoreActionUseCase {
        ResolvePrimaryCoreActionUseCase()
    }

    private var resolveCoreLaunchFailureFeedbackUseCase: ResolveCoreLaunchFailureFeedbackUseCase {
        ResolveCoreLaunchFailureFeedbackUseCase()
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

    private var resolveCoreFeatureRecoveryCompletionUseCase: ResolveCoreFeatureRecoveryCompletionUseCase {
        ResolveCoreFeatureRecoveryCompletionUseCase()
    }

    private var resolveCoreRuntimeStopCleanupUseCase: ResolveCoreRuntimeStopCleanupUseCase {
        ResolveCoreRuntimeStopCleanupUseCase()
    }

    private struct CoreLaunchContext {
        let configPath: String
        let launchController: String
    }

    private struct CoreLaunchPlan {
        let launchContext: CoreLaunchContext
        let settingsOverlay: EditableSettingsSnapshot
    }

    private func performExclusiveCoreAction(_ action: CoreActionState, operation: () async -> Void) async {
        guard self.beginPresentedCoreAction(action) else { return }
        defer { self.endPresentedCoreAction() }
        await operation()
    }

    private func applyCoreLaunchFailureFeedback(_ feedback: CoreLaunchFailureFeedback) {
        if feedback.shouldResetPreserveLocalSettings {
            preserveLocalSettingsOnNextSync = false
        }
        if let logLevel = feedback.logLevel, let logMessage = feedback.logMessage {
            appendLog(level: logLevel, message: logMessage)
        }
        if let alertTitle = feedback.alertTitle,
           let alertMessage = feedback.alertMessage,
           let alertDedupeKey = feedback.alertDedupeKey
        {
            self.presentCoreFailureAlert(
                title: alertTitle,
                message: alertMessage,
                dedupeKey: alertDedupeKey)
        }
        self.applyStartCoreFailureResolutionIfNeeded(feedback.startFailureResolution)
    }

    private func applyStartCoreFailureResolutionIfNeeded(_ resolution: StartCoreFailureResolution?) {
        guard let resolution else { return }
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
        self.applyCoreLaunchFailureFeedback(
            self.resolveCoreLaunchFailureFeedbackUseCase.execute(
                action: .start(trigger: trigger),
                kind: .missingConfig(message: message),
                startAlertTitle: self.tr("app.core.alert.start_failed.title"),
                restartAlertTitle: self.tr("app.core.alert.restart_failed.title")))
    }

    private func handleStartCoreValidationFailure(configPath: String, trigger: StartTrigger) {
        let startupMessage = tr("app.config.validation_failed.startup", URL(fileURLWithPath: configPath).lastPathComponent)
        self.applyCoreLaunchFailureFeedback(
            self.resolveCoreLaunchFailureFeedbackUseCase.execute(
                action: .start(trigger: trigger),
                kind: .validationFailed(startupMessage: startupMessage),
                startAlertTitle: self.tr("app.core.alert.start_failed.title"),
                restartAlertTitle: self.tr("app.core.alert.restart_failed.title")))
    }

    private func handleStartCoreExecutionFailure(_ error: Error, trigger: StartTrigger) {
        let errorMessage = self.coreErrorMessage(error)
        let message = tr("log.start.failed", errorMessage)
        self.applyCoreLaunchFailureFeedback(
            self.resolveCoreLaunchFailureFeedbackUseCase.execute(
                action: .start(trigger: trigger),
                kind: .executionFailed(message: message),
                startAlertTitle: self.tr("app.core.alert.start_failed.title"),
                restartAlertTitle: self.tr("app.core.alert.restart_failed.title")))
    }

    private func handleMissingRestartCoreConfig() {
        let message = tr("log.start.no_config")
        self.applyCoreLaunchFailureFeedback(
            self.resolveCoreLaunchFailureFeedbackUseCase.execute(
                action: .restart,
                kind: .missingConfig(message: message),
                startAlertTitle: self.tr("app.core.alert.start_failed.title"),
                restartAlertTitle: self.tr("app.core.alert.restart_failed.title")))
    }

    private func handleRestartCoreExecutionFailure(_ error: Error) {
        let errorMessage = self.coreErrorMessage(error)
        let message = tr("log.restart.failed", errorMessage)
        self.applyCoreLaunchFailureFeedback(
            self.resolveCoreLaunchFailureFeedbackUseCase.execute(
                action: .restart,
                kind: .executionFailed(message: message),
                startAlertTitle: self.tr("app.core.alert.start_failed.title"),
                restartAlertTitle: self.tr("app.core.alert.restart_failed.title")))
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
            do {
                guard let plan = try await self.prepareStartCoreLaunchPlan(trigger: trigger) else {
                    return
                }

                try await self.executeStartCoreLaunchPlan(plan)
                self.recordDesiredLocalCoreRunningStateIfNeeded(for: trigger)
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
            await self.prepareForCoreRuntimeStop(preserveFeatureRecovery: true)
            self.cancelDeferredEditableSettingsOverlaySync()
            cancelProviderRefresh(reason: "stop requested")
            await self.stopCoreUseCase.execute()
            cancelPolling()
            statusText = "Stopped"
            apiStatus = .unknown
            resetTrafficPresentation()
            await self.refreshRuntimeNetworkHealth(autoRepair: false)
            self.recordDesiredLocalCoreStoppedStateIfNeeded(for: trigger)
        }
    }

    func restartCore(trigger: ProviderRefreshTrigger = .restart) async {
        guard !self.isRemoteTarget else { return }
        await self.performExclusiveCoreAction(.restarting) {
            do {
                guard let plan = await self.prepareRestartCoreLaunchPlan() else {
                    return
                }

                try await self.executeRestartCoreLaunchPlan(plan, trigger: trigger)
            } catch {
                self.handleRestartCoreExecutionFailure(error)
            }
        }
    }

    func performPrimaryCoreAction() async {
        switch self.resolvePrimaryCoreActionUseCase.execute(
            isCoreActionProcessing: self.isCoreActionProcessing,
            isRuntimeRunning: self.isRuntimeRunning)
        {
        case .skip:
            return
        case .restart:
            await self.restartCore()
        case .startManual:
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
        await self.disableSystemProxyForTerminationIfNeeded()
        await self.stopCoreForTerminationIfNeeded()
        self.finishTerminationCleanup()
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

    private func disableSystemProxyForTerminationIfNeeded() async {
        guard self.isSystemProxyEnabled else { return }
        try? await self.applySystemProxy(
            enabled: false,
            host: self.controllerHost(),
            ports: .disabled)
    }

    private func stopCoreForTerminationIfNeeded() async {
        guard coreRepository.isRunning else { return }
        await self.stopCoreUseCase.execute()
    }

    func handleUnexpectedLocalCoreTermination(exitCode: Int32) async {
        await self.prepareForCoreRuntimeStop(preserveFeatureRecovery: true)

        let message = self.tr("log.process.terminated", exitCode)
        self.statusText = "Failed"
        self.apiStatus = .failed
        self.resetTrafficPresentation()
        self.appendLog(level: "error", message: message)
        self.cancelPolling()
        await self.refreshRuntimeNetworkHealth(autoRepair: false)

        if self.coreActionState == .idle, !message.isEmpty {
            self.presentCoreFailureAlert(
                title: self.tr("app.core.alert.process_terminated.title"),
                message: message,
                dedupeKey: "core-process-terminated",
                style: .critical)
        }
    }

    private func finishTerminationCleanup() {
        self.isPanelPresented = false
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
        alert.setScrollableInformativeText(tr("app.config.validation_failed.message", fileName, details))
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
        alert.setScrollableInformativeText(message)
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

    private func recordDesiredLocalCoreRunningStateIfNeeded(for trigger: StartTrigger) {
        switch trigger {
        case .manual:
            self.shouldRestoreRunningCoreOnLaunch = true
        case .auto, .networkRecovery:
            break
        }
    }

    private func recordDesiredLocalCoreStoppedStateIfNeeded(for trigger: StopTrigger) {
        switch trigger {
        case .manual:
            self.shouldRestoreRunningCoreOnLaunch = false
        case .networkLoss:
            break
        }
    }

    private func prepareStartCoreLaunchPlan(trigger: StartTrigger) async throws -> CoreLaunchPlan? {
        preserveLocalSettingsOnNextSync = true
        var settingsOverlay = currentEditableSettingsSnapshot()
        settingsOverlay = self.overlayApplyingPendingCoreFeatureRecovery(settingsOverlay)
        settingsOverlay = try await prepareTunOverlayForCoreStartup(settingsOverlay)

        guard let launchContext = await self.prepareCoreLaunchContext(
            onMissingConfig: { self.handleMissingStartCoreConfig(trigger: trigger) },
            onValidationFailure: { configPath in
                self.handleStartCoreValidationFailure(configPath: configPath, trigger: trigger)
            })
        else {
            return nil
        }

        return CoreLaunchPlan(launchContext: launchContext, settingsOverlay: settingsOverlay)
    }

    private func executeStartCoreLaunchPlan(_ plan: CoreLaunchPlan) async throws {
        let bootstrapOptions = self.resolveCoreBootstrapOptionsUseCase.execute(.start)
        try await self.executeCoreLaunchPlan(
            plan,
            bootstrapOptions: bootstrapOptions,
            preLaunch: { self.statusText = "Starting" },
            launchOperation: {
                _ = try await self.startCoreUseCase.execute(
                    configPath: plan.launchContext.configPath,
                    controller: plan.launchContext.launchController)
            })
    }

    private func prepareRestartCoreLaunchPlan() async -> CoreLaunchPlan? {
        preserveLocalSettingsOnNextSync = true
        cancelProviderRefresh(reason: "restart requested")

        guard let launchContext = await self.prepareCoreLaunchContext(
            onMissingConfig: { self.handleMissingRestartCoreConfig() },
            onValidationFailure: { _ in preserveLocalSettingsOnNextSync = false })
        else {
            return nil
        }

        let recoverySnapshotBeforeRestart = self.currentCoreFeatureRecoverySnapshot()
        await self.prepareCoreFeatureRecoveryBeforeCoreTransition(
            fallbackRecovery: recoverySnapshotBeforeRestart)

        return CoreLaunchPlan(
            launchContext: launchContext,
            settingsOverlay: self.overlayApplyingPendingCoreFeatureRecovery(currentEditableSettingsSnapshot()))
    }

    private func executeRestartCoreLaunchPlan(
        _ plan: CoreLaunchPlan,
        trigger: ProviderRefreshTrigger) async throws
    {
        let bootstrapOptions = self.resolveCoreBootstrapOptionsUseCase.execute(.restart(trigger: trigger))
        try await self.executeCoreLaunchPlan(
            plan,
            bootstrapOptions: bootstrapOptions,
            launchOperation: {
                _ = try await self.restartCoreUseCase.execute(
                    configPath: plan.launchContext.configPath,
                    controller: plan.launchContext.launchController)
            })
    }

    private func executeCoreLaunchPlan(
        _ plan: CoreLaunchPlan,
        bootstrapOptions: CoreBootstrapOptionsPlan,
        preLaunch: () -> Void = {},
        launchOperation: () async throws -> Void) async throws
    {
        preLaunch()
        try await launchOperation()
        await self.completeCoreBootstrap(
            configPath: plan.launchContext.configPath,
            settingsOverlay: plan.settingsOverlay,
            options: bootstrapOptions)
    }

    private func completeCoreBootstrap(
        configPath: String,
        settingsOverlay: EditableSettingsSnapshot,
        options: CoreBootstrapOptionsPlan) async
    {
        self.applyCoreBootstrapRunningState()
        await self.performCoreBootstrapInitialRefresh()
        await self.performCoreBootstrapOverlayAndTunPostflight(
            settingsOverlay,
            syncingKey: options.overlaySyncingKey)
        await self.performCoreBootstrapProviderRefresh(options)
        self.scheduleSystemProxyBootstrapPostflight(options)
        await self.finalizeCoreBootstrap(configPath: configPath)
        self.scheduleBootstrapGroupLatencyRefreshIfNeeded(options)
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
        await self.disableSystemProxyBeforeCoreTransition()
    }

    private func prepareForCoreRuntimeStop(preserveFeatureRecovery: Bool) async {
        let plan = self.resolveCoreRuntimeStopCleanupUseCase.execute(.init(
            preserveFeatureRecovery: preserveFeatureRecovery,
            systemProxyEnabled: self.isSystemProxyEnabled,
            tunEnabled: self.isTunEnabled,
            pendingRecovery: self.pendingCoreFeatureRecoveryState))

        self.pendingCoreFeatureRecoveryState = plan.pendingRecovery

        if plan.shouldDeactivateTunPresentation {
            self.isTunEnabled = false
            self.appendLog(level: "info", message: self.tr("log.tun.toggled", self.tr("log.tun.disabled")))
        }

        guard plan.shouldDisableSystemProxy else { return }
        await self.disableSystemProxyBeforeCoreTransition()
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
            self.pendingCoreFeatureRecoveryState = self.resolveCoreFeatureRecoveryCompletionUseCase.execute(.init(
                requestedRecovery: recovery,
                systemProxyRestored: systemProxyRestored,
                tunRestored: tunRestored))
        }
    }

    private func restoreTunFeatureIfNeeded(requested: Bool) async -> Bool {
        guard requested else { return false }

        do {
            guard try await self.ensureTunRuntimeEnabledForRecovery() else {
                return false
            }
        } catch {
            self.handleTunFeatureRecoveryFailure(error)
            return false
        }

        self.completeTunFeatureRecovery()
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
            self.completeSystemProxyFeatureRecovery(
                host: target.host,
                ports: target.ports)
            return true
        } catch {
            await self.handleSystemProxyFeatureRecoveryFailure(error)
            return false
        }
    }

    private func ensureTunRuntimeEnabledForRecovery() async throws -> Bool {
        let runtimeConfig = try await self.fetchRuntimeConfigSnapshot()
        if runtimeConfig.tunEnabled != true {
            try await self.patchTunConfig(enable: true)
            try await self.verifyTunRuntimeState(expectedEnabled: true)
            return true
        }

        return self.isTunEnabled
    }

    private func completeTunFeatureRecovery() {
        self.isTunEnabled = true
        self.persistEditableSettingsSnapshot()
        self.appendLog(level: "info", message: self.tr("log.tun.toggled", self.tr("log.tun.enabled")))
    }

    private func handleTunFeatureRecoveryFailure(_ error: Error) {
        self.appendLog(
            level: "error",
            message: self.tr("log.tun.toggle_failed", self.tunErrorMessage(error)))
    }

    private func completeSystemProxyFeatureRecovery(host: String, ports: SystemProxyPorts) {
        self.isSystemProxyEnabled = true
        self.clearSystemProxyOpenFailureHint()
        self.systemProxyActiveDisplay = self.buildSystemProxyDisplayString(
            host: host,
            ports: ports)
        self.appendLog(
            level: "info",
            message: self.tr("log.system_proxy.toggled", self.tr("log.system_proxy.enabled")))
    }

    private func handleSystemProxyFeatureRecoveryFailure(_ error: Error) async {
        self.appendLog(
            level: "error",
            message: self.tr("log.system_proxy.toggle_failed", self.systemProxyErrorMessage(error)))
        self.updateSystemProxyOpenFailureHint(for: error)
        await self.refreshSystemProxyHelperStatus()
        await self.refreshSystemProxyStatus()
    }

    private func applyCoreBootstrapRunningState() {
        statusText = "Running"
        apiStatus = .healthy
        resetTrafficPresentation()
        ensureAPIClient()
        startPolling()
    }

    private func performCoreBootstrapInitialRefresh() async {
        await refreshFromAPI(includeSlowCalls: true)
    }

    private func performCoreBootstrapOverlayAndTunPostflight(
        _ settingsOverlay: EditableSettingsSnapshot,
        syncingKey: String) async
    {
        await self.syncEditableSettingsOverlayForCoreBootstrap(
            settingsOverlay,
            syncingKey: syncingKey)
        await validateTunPermissionsOnStartup()
        await ensureTunMixedStackOnStartupIfNeeded()
        await self.verifyTunAfterOverlayIfNeeded(overlay: settingsOverlay)
    }

    private func performCoreBootstrapProviderRefresh(_ options: CoreBootstrapOptionsPlan) async {
        enqueueProviderRefresh(trigger: options.providerTrigger)

        if options.refreshProxyGroupsAfterBootstrap {
            await self.refreshProxyGroupsAfterRestart()
        }
    }

    private func scheduleSystemProxyBootstrapPostflight(_ options: CoreBootstrapOptionsPlan) {
        // Keep startup responsive even when helper registration or system proxy reads are slow.
        scheduleSystemProxyStartupPostflight(
            refreshStatusBeforeOverlay: options.refreshSystemProxyBeforeOverlay,
            refreshStatusAfterBootstrap: options.refreshSystemProxyAfterBootstrap)
    }

    private func finalizeCoreBootstrap(configPath: String) async {
        defaults.set(configPath, forKey: lastSuccessfulConfigPathKey)
        self.setPresentedStartupError(nil)
        await self.restoreCoreFeaturesAfterStartupIfNeeded()
        enforceNetworkManagedCorePolicyIfNeeded()
    }

    private func scheduleBootstrapGroupLatencyRefreshIfNeeded(_ options: CoreBootstrapOptionsPlan) {
        guard options.autoTestGroupLatencies else { return }

        Task { [weak self] in
            await self?.refreshAllGroupLatencies()
        }
    }

    private func disableSystemProxyBeforeCoreTransition() async {
        self.isProxySyncing = true
        defer { self.isProxySyncing = false }

        do {
            try await self.applySystemProxy(enabled: false, host: self.controllerHost(), ports: .disabled)
            self.completeSystemProxyDisableBeforeCoreTransition()
        } catch {
            await self.handleSystemProxyDisableBeforeCoreTransitionFailure(error)
        }
    }

    private func completeSystemProxyDisableBeforeCoreTransition() {
        self.isSystemProxyEnabled = false
        self.systemProxyActiveDisplay = nil
        self.clearSystemProxyOpenFailureHint()
        self.appendLog(
            level: "info",
            message: self.tr("log.system_proxy.toggled", self.tr("log.system_proxy.disabled")))
    }

    private func handleSystemProxyDisableBeforeCoreTransitionFailure(_ error: Error) async {
        self.appendLog(
            level: "error",
            message: self.tr("log.system_proxy.toggle_failed", self.systemProxyErrorMessage(error)))
        await self.refreshSystemProxyHelperStatus()
        await self.refreshSystemProxyStatus()
    }
}
