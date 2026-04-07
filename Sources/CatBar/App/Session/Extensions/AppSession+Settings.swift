import Foundation

@MainActor
extension AppSession {
    private var buildEditableSettingsOverlayPatchBodyUseCase: BuildEditableSettingsOverlayPatchBodyUseCase {
        BuildEditableSettingsOverlayPatchBodyUseCase()
    }

    private var buildPortPatchBodyUseCase: BuildPortPatchBodyUseCase {
        BuildPortPatchBodyUseCase()
    }

    private var resolveOverlayPortFieldsUseCase: ResolveOverlayPortFieldsUseCase {
        ResolveOverlayPortFieldsUseCase()
    }

    private func fetchRuntimeConfigUseCase() throws -> FetchRuntimeConfigUseCase {
        try self.makeFetchRuntimeConfigUseCase(using: self.clientOrThrow())
    }

    private func patchRuntimeConfigUseCase() throws -> PatchRuntimeConfigUseCase {
        try self.makePatchRuntimeConfigUseCase(using: self.settingsPatchTransport())
    }

    enum EditableCoreSetting: String, CaseIterable, Identifiable {
        case allowLan = "allow-lan"
        case ipv6
        case tcpConcurrent = "tcp-concurrent"
        case logLevel = "log-level"

        var id: String {
            self.rawValue
        }

        var configKey: String {
            self.rawValue
        }
    }

    private func boolStateKeyPath(for setting: EditableCoreSetting) -> ReferenceWritableKeyPath<AppSession, Bool>? {
        switch setting {
        case .allowLan:
            \.settingsAllowLan
        case .ipv6:
            \.settingsIPv6
        case .tcpConcurrent:
            \.settingsTCPConcurrent
        case .logLevel:
            nil
        }
    }

    private func stringStateKeyPath(for setting: EditableCoreSetting) -> ReferenceWritableKeyPath<AppSession, String>? {
        switch setting {
        case .logLevel:
            \.settingsLogLevel
        case .allowLan, .ipv6, .tcpConcurrent:
            nil
        }
    }

    func boolValue(for setting: EditableCoreSetting) -> Bool {
        guard let keyPath = self.boolStateKeyPath(for: setting) else {
            assertionFailure("Setting \(setting.configKey) does not store a Bool")
            return false
        }
        return self[keyPath: keyPath]
    }

    func stringValue(for setting: EditableCoreSetting) -> String {
        guard let keyPath = self.stringStateKeyPath(for: setting) else {
            assertionFailure("Setting \(setting.configKey) does not store a String")
            return ""
        }
        return self[keyPath: keyPath]
    }

    func applyEditableCoreSetting(_ setting: EditableCoreSetting, to value: Bool) async {
        guard let keyPath = self.boolStateKeyPath(for: setting) else {
            assertionFailure("Setting \(setting.configKey) does not accept Bool updates")
            return
        }
        await self.applyBooleanSetting(keyPath, configKey: setting.configKey, value: value)
    }

    func applyEditableCoreSetting(_ setting: EditableCoreSetting, to value: String) async {
        guard self.stringStateKeyPath(for: setting) != nil else {
            assertionFailure("Setting \(setting.configKey) does not accept String updates")
            return
        }

        let normalized = value.trimmed
        if setting == .logLevel, ConfigLogLevel(rawValue: normalized) == nil {
            settingsErrorMessage = tr("app.settings.error.invalid_log_level", value)
            settingsSavedMessage = nil
            return
        }

        await self.patchSingleConfig(setting.configKey, value: .string(normalized))
    }

    func applySettingTunMode(_ value: Bool) async {
        await toggleTunMode(value)
    }

    func applyProxyPorts(autoSaved: Bool = false) async {
        guard let body = self.validatedPortPatchBody(
            fields: self.proxyPortFields,
            errorMessageKey: "app.settings.error.port_range",
            skipEmptyValues: false)
        else { return }

        let syncingKey = autoSaved ? "ports-auto" : "ports"
        let successMessage = autoSaved ? tr("app.settings.saved.ports_auto") : tr("app.settings.saved.ports")
        await self.patchConfigBody(body, syncingKey: syncingKey, successMessage: successMessage)
    }

    func scheduleProxyPortsAutoSaveIfNeeded() {
        guard !suppressSettingsPersistence else { return }
        guard settingsSyncingKey == nil else { return }

        proxyPortsAutoSaveTask?.cancel()
        proxyPortsAutoSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 750_000_000)
            } catch {
                return
            }

            guard let self else { return }
            if Task.isCancelled { return }
            // Clear the tracking reference before saving so patchConfigBody()
            // will not cancel the currently running autosave task itself.
            self.proxyPortsAutoSaveTask = nil
            await self.applyProxyPorts(autoSaved: true)
        }
    }

    func cancelProxyPortsAutoSave() {
        proxyPortsAutoSaveTask?.cancel()
        proxyPortsAutoSaveTask = nil
    }

    func syncEditableSettings(from config: ConfigSnapshot) {
        let incoming = EditableSettingsSnapshot(config: config)

        if preserveLocalSettingsOnNextSync {
            preserveLocalSettingsOnNextSync = false
            lastSyncedEditableSettings = incoming
            persistEditableSettingsSnapshot()
            return
        }

        guard let previous = lastSyncedEditableSettings else {
            self.applyPresentedEditableSettingsSnapshot(incoming)
            lastSyncedEditableSettings = incoming
            persistEditableSettingsSnapshot()
            return
        }

        suppressSettingsPersistence = true
        self.syncPresentedEditableSettings(from: previous, to: incoming)
        suppressSettingsPersistence = false

        lastSyncedEditableSettings = incoming
        persistEditableSettingsSnapshot()
    }

    func currentEditableSettingsSnapshot() -> EditableSettingsSnapshot {
        self.currentPresentedEditableSettingsSnapshot()
    }

    func applyPendingConfigSwitchSettingsOverlayIfNeeded() async {
        guard let overlay = pendingConfigSwitchOverlaySettings else { return }
        pendingConfigSwitchOverlaySettings = nil
        _ = await self.applyEditableSettingsOverlay(
            overlay,
            syncingKey: "config-switch-overlay",
            successMessage: tr("app.settings.overlay_success"))
    }

    func applyPendingAppLaunchSettingsOverlayIfNeeded(syncSystemProxyPort: Bool = true) async {
        guard let overlay = pendingAppLaunchOverlaySettings else { return }
        pendingAppLaunchOverlaySettings = nil

        let request = DeferredEditableSettingsOverlayRequest(
            snapshot: overlay,
            syncingKey: "app-launch-overlay",
            syncSystemProxyPort: syncSystemProxyPort)

        if await self.isCoreAPIReachableForOverlaySync() {
            _ = await self.applyEditableSettingsOverlay(
                request.snapshot,
                syncingKey: request.syncingKey,
                successMessage: "",
                syncSystemProxyPort: request.syncSystemProxyPort)
        } else {
            self.deferEditableSettingsOverlay(request)
        }
    }

    func syncEditableSettingsOverlayForCoreBootstrap(
        _ overlay: EditableSettingsSnapshot,
        syncingKey: String) async
    {
        await self.beginDeferredEditableSettingsOverlayBootstrapSync(
            DeferredEditableSettingsOverlayRequest(
                snapshot: overlay,
                syncingKey: syncingKey,
                syncSystemProxyPort: true))
    }

    private func beginDeferredEditableSettingsOverlayBootstrapSync(
        _ request: DeferredEditableSettingsOverlayRequest) async
    {
        self.deferredEditableSettingsOverlay = request
        if await self.applyDeferredEditableSettingsOverlayIfPossible() {
            self.clearDeferredEditableSettingsOverlayTask()
            return
        }

        self.scheduleDeferredEditableSettingsOverlaySync()
    }

    func cancelDeferredEditableSettingsOverlaySync() {
        self.clearDeferredEditableSettingsOverlayTask()
        self.deferredEditableSettingsOverlay = nil
    }

    @discardableResult
    func applyEditableSettingsOverlay(
        _ overlay: EditableSettingsSnapshot,
        syncingKey: String,
        successMessage: String,
        syncSystemProxyPort: Bool = true) async -> Bool
    {
        let fallback = self.lastSyncedEditableSettings
        let hasConfiguredTunStack = overlay.tunEnabled ? await self.selectedConfigDeclaresTunStack() : true

        let body: [String: ConfigPatchValue]
        do {
            body = try self.buildEditableSettingsOverlayPatchBodyUseCase.execute(
                overlay: overlay,
                fallback: fallback,
                hasConfiguredTunStack: hasConfiguredTunStack)
        } catch let BuildEditableSettingsOverlayPatchBodyError.invalidLogLevel(resolvedLogLevel) {
            settingsErrorMessage = tr("app.settings.error.overlay_invalid_log_level", resolvedLogLevel)
            settingsSavedMessage = nil
            return false
        } catch let BuildEditableSettingsOverlayPatchBodyError.invalidPort(key) {
            settingsErrorMessage = tr("app.settings.error.overlay_port_range", key)
            settingsSavedMessage = nil
            return false
        } catch {
            settingsErrorMessage = tr("app.settings.error.overlay_port_range", "unknown")
            settingsSavedMessage = nil
            return false
        }

        return await self.patchConfigBody(
            body,
            syncingKey: syncingKey,
            successMessage: successMessage,
            syncSystemProxyPort: syncSystemProxyPort)
    }

    func effectiveMixedPort() -> Int {
        ResolveEffectiveMixedPortUseCase().execute(
            runtimeMixedPort: mixedPort,
            settingsMixedPort: settingsMixedPort)
    }

    func applyEditableSettingsSnapshotToUI(_ snapshot: EditableSettingsSnapshot) {
        suppressSettingsPersistence = true
        self.applyPresentedEditableSettingsSnapshot(snapshot)
        suppressSettingsPersistence = false
    }

    func applySettingBool(key: String, value: Bool) async {
        await self.patchSingleConfig(key, value: .bool(value))
    }

    func patchSingleConfig(_ key: String, value: ConfigPatchValue) async {
        _ = await self.patchConfigBody(
            [key: value],
            syncingKey: key,
            successMessage: tr("app.settings.saved.single_key", key))
    }

    @discardableResult
    func patchConfigBody(
        _ body: [String: ConfigPatchValue],
        syncingKey: String,
        successMessage: String,
        syncSystemProxyPort: Bool = true) async -> Bool
    {
        self.prepareSettingsPatchRequest(syncingKey: syncingKey)
        defer { settingsSyncingKey = nil }

        let shouldSyncSystemProxyPort = self.shouldSyncSystemProxyPort(
            for: body,
            requested: syncSystemProxyPort)
        let previousSystemProxyPorts =
            await previousSystemProxyPortsForSyncIfNeeded(shouldSync: shouldSyncSystemProxyPort)
        let patchKeysDescription = self.patchKeysDescription(for: body)

        do {
            try await self.executeRuntimeConfigPatch(body, patchKeysDescription: patchKeysDescription)
            await self.handleSettingsPatchSuccess(
                successMessage: successMessage,
                shouldSync: shouldSyncSystemProxyPort,
                previousPorts: previousSystemProxyPorts)
            return true
        } catch {
            return await self.handleSettingsPatchFailure(
                error,
                patchKeysDescription: patchKeysDescription,
                syncingKey: syncingKey)
        }
    }

    private func isOverlaySyncingKey(_ syncingKey: String) -> Bool {
        syncingKey.hasSuffix("-overlay")
    }

    private func prepareSettingsPatchRequest(syncingKey: String) {
        self.cancelProxyPortsAutoSave()
        settingsFeedbackClearTask?.cancel()
        settingsFeedbackClearTask = nil
        settingsSyncingKey = syncingKey
        settingsErrorMessage = nil
        settingsSavedMessage = nil
    }

    private func shouldSyncSystemProxyPort(
        for body: [String: ConfigPatchValue],
        requested: Bool) -> Bool
    {
        requested
            && !self.isRemoteTarget
            && body.keys.contains { key in
                key == "mixed-port" || key == "port" || key == "socks-port"
            }
    }

    private func patchKeysDescription(for body: [String: ConfigPatchValue]) -> String {
        body.keys.sorted().joined(separator: ", ")
    }

    private func executeRuntimeConfigPatch(
        _ body: [String: ConfigPatchValue],
        patchKeysDescription: String) async throws
    {
        ensureAPIClient()
        appendLog(level: "info", message: "PATCH /configs [\(patchKeysDescription)]")
        try await self.patchRuntimeConfigUseCase().execute(body: body.mapValues(\.jsonValue))
        appendLog(level: "info", message: "PATCH /configs succeeded [\(patchKeysDescription)]")
    }

    private func handleSettingsPatchSuccess(
        successMessage: String,
        shouldSync: Bool,
        previousPorts: SystemProxyPorts?) async
    {
        await refreshFromAPI(includeSlowCalls: false)
        await self.reconcileEditableSettingsWithRuntimeConfig()
        settingsSavedMessage = successMessage
        self.scheduleSettingsFeedbackAutoClearIfNeeded(message: successMessage)
        await self.syncSystemProxyPortIfNeeded(
            shouldSync: shouldSync,
            previousPorts: previousPorts)
    }

    private func handleSettingsPatchFailure(
        _ error: Error,
        patchKeysDescription: String,
        syncingKey: String) async -> Bool
    {
        appendLog(
            level: "error",
            message: "PATCH /configs failed [\(patchKeysDescription)]: \(error.localizedDescription)")
        let message = tr("app.settings.error.save_failed", syncingKey, error.localizedDescription)
        if self.isOverlaySyncingKey(syncingKey) {
            appendLog(level: "error", message: message)
        } else {
            settingsErrorMessage = message
        }
        settingsSavedMessage = nil
        await refreshFromAPI(includeSlowCalls: false)
        await self.reconcileEditableSettingsWithRuntimeConfig()
        return false
    }

    private func scheduleDeferredEditableSettingsOverlaySync() {
        self.clearDeferredEditableSettingsOverlayTask()
        self.deferredEditableSettingsOverlayTask = Task { [weak self] in
            guard let self else { return }

            for _ in 0..<120 {
                if Task.isCancelled { return }
                guard self.isRuntimeRunning else { return }
                if await self.applyDeferredEditableSettingsOverlayIfPossible() {
                    self.clearDeferredEditableSettingsOverlayTask()
                    return
                }

                do {
                    try await Task.sleep(nanoseconds: 250_000_000)
                } catch {
                    return
                }
            }

            self.clearDeferredEditableSettingsOverlayTask()
        }
    }

    private func applyDeferredEditableSettingsOverlayIfPossible() async -> Bool {
        guard let deferred = self.deferredEditableSettingsOverlay else { return true }
        guard await self.isCoreAPIReachableForOverlaySync() else { return false }

        let applied = await self.applyEditableSettingsOverlay(
            deferred.snapshot,
            syncingKey: deferred.syncingKey,
            successMessage: "",
            syncSystemProxyPort: deferred.syncSystemProxyPort)
        if applied {
            self.deferredEditableSettingsOverlay = nil
        }
        return applied
    }

    private func deferEditableSettingsOverlay(_ request: DeferredEditableSettingsOverlayRequest) {
        self.deferredEditableSettingsOverlay = request
        self.scheduleDeferredEditableSettingsOverlaySync()
    }

    private func clearDeferredEditableSettingsOverlayTask() {
        self.deferredEditableSettingsOverlayTask?.cancel()
        self.deferredEditableSettingsOverlayTask = nil
    }

    private func isCoreAPIReachableForOverlaySync() async -> Bool {
        do {
            let client = try self.clientOrThrow()
            let _: VersionInfo = try await self.makeFetchVersionUseCase(using: client).execute()
            return true
        } catch {
            return false
        }
    }

    func scheduleSettingsFeedbackAutoClearIfNeeded(message: String) {
        guard message.trimmedNonEmpty != nil else { return }

        settingsFeedbackClearTask?.cancel()
        settingsFeedbackClearTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }

            guard let self else { return }
            if self.settingsSavedMessage == message {
                self.settingsSavedMessage = nil
            }
        }
    }

    func clientOrThrow() throws -> MihomoAPIClient {
        if apiClient == nil {
            ensureAPIClient()
        }
        if let apiClient {
            return apiClient
        }
        throw APIError.invalidURL
    }

    func modeSwitchTransport() throws -> MihomoAPITransporting {
        try self.resolvedTransport(override: modeSwitchTransportOverride)
    }

    func settingsPatchTransport() throws -> MihomoAPITransporting {
        try self.resolvedTransport(override: settingsPatchTransportOverride)
    }

    private func previousSystemProxyPortsForSyncIfNeeded(shouldSync: Bool) async -> SystemProxyPorts? {
        guard shouldSync, isSystemProxyEnabled else { return nil }
        do {
            let config = try await self.fetchRuntimeConfigUseCase().execute()
            return systemProxyPorts(from: config)
        } catch {
            return currentSystemProxyPortsFromState()
        }
    }

    private func syncSystemProxyPortIfNeeded(shouldSync: Bool, previousPorts: SystemProxyPorts?) async {
        guard shouldSync, isSystemProxyEnabled else { return }

        do {
            let target = try self.resolveSystemProxyTargetFromState()
            try await applySystemProxy(enabled: true, host: target.host, ports: target.ports)
            systemProxyActiveDisplay = buildSystemProxyDisplayString(host: target.host, ports: target.ports)
            appendLog(level: "info", message: tr("log.system_proxy.port_synced", target.ports.primaryPort ?? 0))

            if let previousPorts, previousPorts != target.ports {
                await closeAllConnections()
            }
        } catch {
            appendLog(level: "error", message: tr("log.system_proxy.port_sync_failed", systemProxyErrorMessage(error)))
            await self.refreshSystemProxyHelperStatus()
        }
    }

    private func applyBooleanSetting(
        _ keyPath: ReferenceWritableKeyPath<AppSession, Bool>,
        configKey: String,
        value: Bool) async
    {
        await self.applySettingBool(key: configKey, value: value)
    }

    private func reconcileEditableSettingsWithRuntimeConfig() async {
        do {
            let config = try await self.fetchRuntimeConfigSnapshot()
            let incoming = EditableSettingsSnapshot(config: config)
            self.applyEditableSettingsSnapshotToUI(incoming)
            self.lastSyncedEditableSettings = incoming
            self.persistEditableSettingsSnapshot()
        } catch {
            appendLog(level: "error", message: "Settings reconciliation failed: \(error.localizedDescription)")
        }
    }

    private var proxyPortFields: [SettingsPortField] {
        [
            SettingsPortField(key: "port", value: settingsPort),
            SettingsPortField(key: "socks-port", value: settingsSocksPort),
            SettingsPortField(key: "mixed-port", value: settingsMixedPort),
            SettingsPortField(key: "redir-port", value: settingsRedirPort),
            SettingsPortField(key: "tproxy-port", value: settingsTProxyPort),
        ]
    }

    private func validatedPortPatchBody(
        fields: [SettingsPortField],
        errorMessageKey: String,
        skipEmptyValues: Bool) -> [String: ConfigPatchValue]?
    {
        do {
            return try self.buildPortPatchBodyUseCase.execute(fields: fields, skipEmptyValues: skipEmptyValues)
        } catch let BuildPortPatchBodyError.invalidPort(key) {
            settingsErrorMessage = tr(errorMessageKey, key)
            settingsSavedMessage = nil
            return nil
        } catch {
            settingsErrorMessage = tr(errorMessageKey, "unknown")
            settingsSavedMessage = nil
            return nil
        }
    }

    private func resolvedTransport(override: MihomoAPITransporting?) throws -> MihomoAPITransporting {
        if let override {
            return override
        }
        return try self.clientOrThrow()
    }
}
