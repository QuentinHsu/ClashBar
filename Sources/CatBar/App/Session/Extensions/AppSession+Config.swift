import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
extension AppSession {
    private var resolveConfigMutationFollowUpUseCase: ResolveConfigMutationFollowUpUseCase {
        ResolveConfigMutationFollowUpUseCase()
    }

    private var resolveRemoteConfigMenuStatesUseCase: ResolveRemoteConfigMenuStatesUseCase {
        ResolveRemoteConfigMenuStatesUseCase()
    }

    private var resolveRemoteConfigImportRequestUseCase: ResolveRemoteConfigImportRequestUseCase {
        ResolveRemoteConfigImportRequestUseCase()
    }

    private var resolveConfigSelectionTransitionUseCase: ResolveConfigSelectionTransitionUseCase {
        ResolveConfigSelectionTransitionUseCase()
    }

    private var resolveRemoteConfigRefreshTargetUseCase: ResolveRemoteConfigRefreshTargetUseCase {
        ResolveRemoteConfigRefreshTargetUseCase()
    }

    private var remoteConfigMenuStateResolver: RemoteConfigMenuStateResolver {
        RemoteConfigMenuStateResolver()
    }

    private struct ConfigImportDestination {
        let fileName: String
        let targetURL: URL
        let isOverwrite: Bool
    }

    private func reloadRuntimeConfigUseCase() throws -> ReloadRuntimeConfigUseCase {
        try ReloadRuntimeConfigUseCase(repository: DefaultRuntimeConfigRepository(transport: self.clientOrThrow()))
    }

    private func canonicalConfigPath(_ url: URL?) -> String? {
        url?.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func validateConfigSelectionIfNeeded(
        previousSelectedURL: URL?,
        targetSelectedURL: URL,
        staleSelectionCanonicalPath: String?) async -> Bool
    {
        let validationFailure = await self.configValidationFailureDetails(configPath: targetSelectedURL.path)
        let currentCanonicalPath = self.canonicalConfigPath(self.configRepository.selectedConfig)
        guard currentCanonicalPath == staleSelectionCanonicalPath else { return false }

        guard let validationFailure else { return true }
        self.handleConfigValidationFailure(configPath: targetSelectedURL.path, details: validationFailure)
        if let previousSelectedURL {
            configRepository.selectConfig(previousSelectedURL)
        }
        _ = self.syncSelectedConfigSelection(configRepository.selectedConfig)
        syncConfigDisplayState()
        return false
    }

    private func prepareConfigImportDestination(
        configDirectory: URL,
        fileName: String) -> ConfigImportDestination?
    {
        let targetURL = configDirectory.appendingPathComponent(fileName, isDirectory: false)
        let isOverwrite = FileManager.default.fileExists(atPath: targetURL.path)
        guard !isOverwrite || self.confirmOverwriteConfig(named: fileName) else {
            appendLog(level: "info", message: tr("log.config.import.cancelled", fileName))
            return nil
        }

        return ConfigImportDestination(
            fileName: fileName,
            targetURL: targetURL,
            isOverwrite: isOverwrite)
    }

    private func replaceRemoteConfigFile(
        from remoteURL: URL,
        userAgent: String?,
        targetURL: URL) async throws
    {
        let data = try await downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
        try writeConfigData(data, to: targetURL)
    }

    func seedBundledConfigIfNeeded() {
        let fileManager = FileManager.default
        let targetURL = workingDirectoryManager.configDirectoryURL
            .appendingPathComponent("CatBar.yaml", isDirectory: false)

        if fileManager.fileExists(atPath: targetURL.path) {
            return
        }

        guard let bundledConfigURL = bundledDefaultConfigURL(fileManager: fileManager) else {
            return
        }

        do {
            let data = try Data(contentsOf: bundledConfigURL)
            try writeConfigData(data, to: targetURL)
        } catch {
            appendLog(
                level: "error",
                message: tr("log.config.import_local.failed", "CatBar.yaml", error.localizedDescription))
        }
    }

    private func bundledDefaultConfigURL(fileManager: FileManager = .default) -> URL? {
        FindBundledConfigTemplateUseCase().execute(
            resourceRoots: AppResourceBundleLocator.candidateResourceRoots(),
            fileManager: fileManager)
    }

    func selectConfig() async {
        let previousSelectedURL = configRepository.selectedConfig
        guard configRepository.chooseConfigDirectory() != nil else { return }

        let transition = self.resolveConfigSelectionTransitionUseCase.execute(
            previousSelectedURL: previousSelectedURL,
            nextSelectedURL: configRepository.selectedConfig,
            coreIsRunning: coreRepository.isRunning,
            validationTiming: .afterSelection)

        if let validationRequest = transition.validationRequest {
            guard await self.validateConfigSelectionIfNeeded(
                previousSelectedURL: previousSelectedURL,
                targetSelectedURL: validationRequest.targetSelectedURL,
                staleSelectionCanonicalPath: validationRequest.staleSelectionCanonicalPath)
            else {
                return
            }
        }

        let nextSelectedPath = self.syncSelectedConfigSelection(configRepository.selectedConfig)
        syncConfigDisplayState()

        appendLog(level: "info", message: tr("log.config.loaded_count", configRepository.availableConfigs.count))
        await restartCoreIfNeededForConfigSwitch(
            previousPath: transition.previousSelectedPath,
            nextPath: nextSelectedPath)
    }

    func selectConfigFile(named fileName: String) async {
        let previousSelectedURL = configRepository.selectedConfig
        guard let matched = configRepository.availableConfigs.first(where: { $0.lastPathComponent == fileName }) else {
            appendLog(level: "error", message: tr("log.config.not_found", fileName))
            return
        }

        let transition = self.resolveConfigSelectionTransitionUseCase.execute(
            previousSelectedURL: previousSelectedURL,
            nextSelectedURL: matched,
            coreIsRunning: coreRepository.isRunning,
            validationTiming: .beforeSelection)

        if let validationRequest = transition.validationRequest {
            guard await self.validateConfigSelectionIfNeeded(
                previousSelectedURL: previousSelectedURL,
                targetSelectedURL: validationRequest.targetSelectedURL,
                staleSelectionCanonicalPath: validationRequest.staleSelectionCanonicalPath)
            else {
                return
            }
        }

        configRepository.selectConfig(matched)
        let nextSelectedPath = self.syncSelectedConfigSelection(matched)
        syncConfigDisplayState()
        appendLog(level: "info", message: tr("log.config.selected", fileName))
        await restartCoreIfNeededForConfigSwitch(
            previousPath: transition.previousSelectedPath,
            nextPath: nextSelectedPath)
    }

    func importLocalConfigFile() {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }

        self.prepareModalWindowPresentation()
        let panel = NSOpenPanel()
        self.configureModalWindow(panel)
        panel.title = tr("ui.quick.import_local_config")
        panel.directoryURL = configDirectory
        var allowedTypes: [UTType] = []
        if let yamlType = UTType(filenameExtension: "yaml") {
            allowedTypes.append(yamlType)
        }
        if let ymlType = UTType(filenameExtension: "yml"), !allowedTypes.contains(ymlType) {
            allowedTypes.append(ymlType)
        }
        if !allowedTypes.isEmpty {
            panel.allowedContentTypes = allowedTypes
        }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }
        guard let fileName = normalizedConfigFileName(sourceURL.lastPathComponent) else {
            appendLog(level: "error", message: tr("log.config.import.invalid_filename", sourceURL.lastPathComponent))
            return
        }

        guard let destination = self.prepareConfigImportDestination(
            configDirectory: configDirectory,
            fileName: fileName)
        else {
            return
        }

        do {
            let data = try Data(contentsOf: sourceURL)
            try writeConfigData(data, to: destination.targetURL)

            self.updateRemoteConfigSource(for: destination.fileName, urlString: nil)
            appendLog(level: "info", message: tr("log.config.import_local.success", destination.fileName))

            if destination.isOverwrite {
                Task {
                    await self.applyConfigMutationFollowUp(updatedFileNames: [destination.fileName])
                }
            }
        } catch {
            appendLog(
                level: "error",
                message: tr("log.config.import_local.failed", destination.fileName, error.localizedDescription))
        }
    }

    func importRemoteConfigFile() async {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }
        guard let input = promptRemoteConfigImportInput() else { return }

        let requestResult = self.resolveRemoteConfigImportRequestUseCase.execute(
            urlString: input.urlString,
            fileNameInput: input.fileName,
            isSupportedRemoteConfigURL: self.isSupportedRemoteConfigURL,
            inferredRemoteConfigFileName: self.inferredRemoteConfigFileName,
            normalizedConfigFileName: self.normalizedConfigFileName)
        guard case let .success(request) = requestResult else {
            self.handleRemoteConfigImportRequestFailure(requestResult)
            return
        }

        guard let destination = self.prepareConfigImportDestination(
            configDirectory: configDirectory,
            fileName: request.fileName)
        else {
            return
        }

        do {
            let userAgent = await remoteSubscriptionUserAgent()
            try await self.replaceRemoteConfigFile(
                from: request.remoteURL,
                userAgent: userAgent,
                targetURL: destination.targetURL)

            self.updateRemoteConfigSource(for: destination.fileName, urlString: request.remoteURL.absoluteString)
            let message = tr("log.config.import_remote.success", destination.fileName)
            appendLog(level: "info", message: message)

            if destination.isOverwrite {
                await self.applyConfigMutationFollowUp(updatedFileNames: [destination.fileName])
            }

            self.presentRemoteConfigImportResultAlert(success: true, message: message)
        } catch {
            let message = tr("log.config.import_remote.failed", destination.fileName, error.localizedDescription)
            appendLog(level: "error", message: message)
            self.presentRemoteConfigImportResultAlert(success: false, message: message)
        }
    }

    func updateAllRemoteConfigFiles() async {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }
        pruneRemoteConfigSourcesIfNeeded()

        let sources = remoteConfigSources
        guard !sources.isEmpty else {
            appendLog(level: "info", message: tr("log.config.remote.no_sources"))
            return
        }

        let userAgent = await remoteSubscriptionUserAgent()
        var updatedFileNames: Set<String> = []
        var failedCount = 0

        for fileName in sources.keys.sorted() {
            guard let target = self.resolveRemoteConfigRefreshTargetOrLogFailure(
                fileName: fileName,
                configDirectory: configDirectory)
            else {
                failedCount += 1
                continue
            }

            do {
                try await self.refreshRemoteConfigTarget(target, userAgent: userAgent)
                updatedFileNames.insert(target.fileName)
            } catch {
                failedCount += 1
                self.logRemoteConfigUpdateFailure(fileName: fileName, error: error)
            }
        }

        await self.applyConfigMutationFollowUp(updatedFileNames: updatedFileNames)
        appendLog(level: "info", message: tr("log.config.remote.update_summary", updatedFileNames.count, failedCount))
    }

    func showSelectedConfigInFinder() {
        guard let configDirectory = ensureConfigDirectoryAvailable() else { return }
        if let selected = configRepository.selectedConfig, FileManager.default.fileExists(atPath: selected.path) {
            NSWorkspace.shared.activateFileViewerSelecting([selected])
            return
        }

        if !NSWorkspace.shared.open(configDirectory) {
            appendLog(level: "error", message: tr("log.config.show_in_finder.failed", configDirectory.path))
        }
    }

    func showCoreDirectoryInFinder() {
        do {
            try workingDirectoryManager.bootstrapDirectories()
            let coreDirectory = try workingDirectoryManager.normalizeAndValidateWithinRoot(
                workingDirectoryManager.coreDirectoryURL,
                mustBeDirectory: true)
            if !NSWorkspace.shared.open(coreDirectory) {
                appendLog(level: "error", message: tr("log.core.show_in_finder.failed", coreDirectory.path))
            }
        } catch {
            appendLog(
                level: "error",
                message: tr("log.core.show_in_finder.failed", workingDirectoryManager.coreDirectoryURL.path))
        }
    }

    func reloadConfigFileList() {
        guard self.ensureConfigDirectoryAvailable() != nil else { return }
        self.refreshConfigStateAfterMutation()
        appendLog(level: "info", message: tr("log.config.loaded_count", configRepository.availableConfigs.count))
    }

    func refreshRemoteConfigMenuStates() {
        self.remoteConfigMenuStates = self.resolveRemoteConfigMenuStatesUseCase.execute(
            remoteConfigSources: self.remoteConfigSources,
            currentStates: self.remoteConfigMenuStates,
            updatedAtProvider: self.remoteConfigUpdatedAt)
    }

    func remoteConfigMenuState(for fileName: String) -> RemoteConfigMenuState {
        self.remoteConfigMenuStates[fileName] ?? .idle
    }

    func refreshRemoteConfigFile(named fileName: String) async {
        guard self.remoteConfigMenuState(for: fileName).phase != .refreshing else { return }
        guard let configDirectory = self.ensureConfigDirectoryAvailable() else { return }

        self.pruneRemoteConfigSourcesIfNeeded()
        self.setRemoteConfigMenuState(for: fileName, phase: .refreshing)

        guard let target = self.resolveRemoteConfigRefreshTargetOrLogFailure(
            fileName: fileName,
            configDirectory: configDirectory)
        else {
            self.setRemoteConfigMenuState(for: fileName, phase: .failed)
            return
        }

        do {
            let userAgent = await self.remoteSubscriptionUserAgent()
            try await self.refreshRemoteConfigTarget(target, userAgent: userAgent)

            await self.applyConfigMutationFollowUp(updatedFileNames: [fileName])

            self.setRemoteConfigMenuState(
                for: fileName,
                phase: .idle,
                updatedAt: self.remoteConfigUpdatedAt(for: fileName) ?? Date())
        } catch {
            self.logRemoteConfigUpdateFailure(fileName: fileName, error: error)
            self.setRemoteConfigMenuState(for: fileName, phase: .failed)
        }
    }

    func reloadConfig() async {
        let actionName = tr("log.action_name.reload_config")
        let expectedTunEnabled = isTunEnabled

        do {
            try await self.executeConfigReload(expectedTunEnabled: expectedTunEnabled)
            appendLog(level: "info", message: tr("log.action.success", actionName))
        } catch {
            appendLog(level: "error", message: tr("log.action.failed", actionName, error.localizedDescription))
        }
    }

    func ensureConfigDirectoryAvailable() -> URL? {
        if let configDirectory = configRepository.configDirectory {
            return configDirectory
        }

        do {
            try workingDirectoryManager.bootstrapDirectories()
            configRepository.setConfigDirectory(workingDirectoryManager.configDirectoryURL)
            self.refreshConfigStateAfterMutation()
            return configRepository.configDirectory
        } catch {
            appendLog(level: "error", message: tr("log.working_dir_init_failed", error.localizedDescription))
            return nil
        }
    }

    private func refreshConfigStateAfterMutation() {
        _ = configRepository.reloadConfigs()
        if self.syncSelectedConfigSelection(configRepository.selectedConfig) == nil {
            selectedConfigName = "-"
            defaults.removeObject(forKey: selectedConfigKey)
        }
        syncConfigDisplayState()
        self.refreshRemoteConfigMenuStates()
    }

    @discardableResult
    func syncSelectedConfigSelection(_ selected: URL?) -> String? {
        guard let selected else {
            return nil
        }
        // DRY: keep selected config state/defaults updates in one place.
        selectedConfigName = selected.lastPathComponent
        defaults.set(selected.lastPathComponent, forKey: selectedConfigKey)
        return selected.path
    }

    private func writeConfigData(_ data: Data, to targetURL: URL) throws {
        try configRepository.writeConfigData(data, to: targetURL)
    }

    private func confirmOverwriteConfig(named fileName: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = tr("app.config.import.overwrite.title", fileName)
        alert.informativeText = tr("app.config.import.overwrite.message")
        alert.addButton(withTitle: tr("ui.action.overwrite"))
        alert.addButton(withTitle: tr("ui.action.cancel"))
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentRemoteConfigImportResultAlert(success: Bool, message: String) {
        let alert = NSAlert()
        alert.alertStyle = success ? .informational : .warning
        alert.messageText = success
            ? tr("app.config.remote_import.alert.success.title")
            : tr("app.config.remote_import.alert.failure.title")
        alert.informativeText = message
        alert.addButton(withTitle: tr("ui.action.ok"))
        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        alert.runModal()
    }

    private func handleRemoteConfigImportRequestFailure(
        _ result: Result<RemoteConfigImportRequest, ResolveRemoteConfigImportRequestError>)
    {
        guard case let .failure(error) = result else { return }

        let message: String
        switch error {
        case let .invalidURL(input):
            message = tr("log.config.remote.invalid_url", input)
        case let .invalidFileName(input):
            message = tr("log.config.import.invalid_filename", input)
        }

        appendLog(level: "error", message: message)
        self.presentRemoteConfigImportResultAlert(success: false, message: message)
    }

    private struct RemoteConfigImportInput {
        let urlString: String
        let fileName: String
    }

    private func promptRemoteConfigImportInput() -> RemoteConfigImportInput? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = tr("ui.quick.import_remote_config")
        alert.informativeText = tr("app.config.remote_import.prompt")
        alert.addButton(withTitle: tr("ui.action.import"))
        alert.addButton(withTitle: tr("ui.action.cancel"))

        // Use fixed frames in accessory view to avoid NSAlert auto-layout overlap in compact windows.
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 96))

        let urlLabel = NSTextField(labelWithString: tr("ui.quick.remote.url_label"))
        urlLabel.font = .systemFont(ofSize: 12, weight: .medium)
        urlLabel.frame = NSRect(x: 0, y: 76, width: 340, height: 16)

        let urlField = NSTextField(frame: NSRect(x: 0, y: 50, width: 340, height: 24))
        urlField.placeholderString = tr("ui.quick.remote.url_placeholder")

        let fileLabel = NSTextField(labelWithString: tr("ui.quick.remote.filename_label"))
        fileLabel.font = .systemFont(ofSize: 12, weight: .medium)
        fileLabel.frame = NSRect(x: 0, y: 30, width: 340, height: 16)

        let fileField = NSTextField(frame: NSRect(x: 0, y: 4, width: 340, height: 24))
        fileField.placeholderString = tr("ui.quick.remote.filename_placeholder")

        container.addSubview(urlLabel)
        container.addSubview(urlField)
        container.addSubview(fileLabel)
        container.addSubview(fileField)
        alert.accessoryView = container

        self.prepareModalWindowPresentation()
        self.configureModalWindow(alert.window)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return RemoteConfigImportInput(
            urlString: urlField.stringValue,
            fileName: fileField.stringValue)
    }

    func prepareModalWindowPresentation() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func configureModalWindow(_ window: NSWindow) {
        window.level = .statusBar
        window.collectionBehavior.insert(.moveToActiveSpace)
    }

    func normalizedConfigFileName(_ fileName: String, fallback: String? = nil) -> String? {
        configRepository.normalizedConfigFileName(fileName, fallback: fallback)
    }

    private func inferredRemoteConfigFileName(from remoteURL: URL) -> String {
        configRepository.inferredRemoteConfigFileName(from: remoteURL)
    }

    func isSupportedRemoteConfigURL(_ url: URL) -> Bool {
        configRepository.isSupportedRemoteConfigURL(url)
    }

    private func downloadRemoteConfigData(from remoteURL: URL, userAgent: String? = nil) async throws -> Data {
        try await configRepository.downloadRemoteConfigData(from: remoteURL, userAgent: userAgent)
    }

    private func remoteSubscriptionUserAgent() async -> String {
        let version = await resolvedMihomoVersionForSubscriptionUserAgent()
        return "clash.meta/\(version)"
    }

    private func resolvedMihomoVersionForSubscriptionUserAgent() async -> String {
        if let current = normalizedMihomoVersionForUserAgent(self.version) {
            return current
        }

        guard let client = try? clientOrThrow() else {
            return "unknown"
        }

        guard let fetched = try? await self.makeFetchVersionUseCase(using: client).execute() else {
            return "unknown"
        }

        let normalized = self.normalizedMihomoVersionForUserAgent(fetched.version) ?? "unknown"
        if normalized != "unknown" {
            self.version = normalized
        }
        return normalized
    }

    private func normalizedMihomoVersionForUserAgent(_ rawVersion: String) -> String? {
        let trimmed = rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "-" else { return nil }
        return trimmed
    }

    private func restoreTunAfterConfigReloadIfNeeded(expectedEnabled: Bool) async throws {
        guard isRuntimeRunning else { return }
        try await self.patchTunConfig(enable: expectedEnabled)
        try await self.verifyTunRuntimeState(expectedEnabled: expectedEnabled)
        if isTunEnabled != expectedEnabled {
            isTunEnabled = expectedEnabled
            persistEditableSettingsSnapshot()
        }
    }

    private func executeConfigReload(expectedTunEnabled: Bool) async throws {
        ensureAPIClient()
        try await self.reloadRuntimeConfigUseCase().execute(force: false)
        try await self.restoreTunAfterConfigReloadIfNeeded(expectedEnabled: expectedTunEnabled)
    }

    private func applyConfigMutationFollowUp(updatedFileNames: Set<String>) async {
        let followUpPlan = self.resolveConfigMutationFollowUpUseCase.execute(
            updatedFileNames: updatedFileNames,
            selectedConfigName: selectedConfigName,
            isRuntimeRunning: isRuntimeRunning)
        self.refreshConfigStateAfterMutation()
        if followUpPlan.shouldReloadCurrentConfig {
            await self.reloadConfig()
        }
    }

    private func updateRemoteConfigSource(for fileName: String, urlString: String?) {
        if let urlString {
            remoteConfigSources[fileName] = urlString
        } else {
            remoteConfigSources.removeValue(forKey: fileName)
        }
        persistRemoteConfigSources()
        self.refreshConfigStateAfterMutation()
    }

    private func remoteConfigUpdatedAt(for fileName: String) -> Date? {
        guard let configURL = self.configRepository.availableConfigs.first(where: { $0.lastPathComponent == fileName })
        else {
            return nil
        }
        return try? configURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func invalidRemoteConfigUpdateMessage(for fileName: String) -> String {
        let source = self.remoteConfigSources[fileName] ?? fileName
        return self.remoteConfigUpdateFailureMessage(
            fileName: fileName,
            reason: tr("log.config.remote.invalid_url", source))
    }

    private func remoteConfigUpdateFailureMessage(fileName: String, reason: String) -> String {
        tr("log.config.remote.update_item_failed", fileName, reason)
    }

    private func logRemoteConfigUpdateFailure(fileName: String, error: Error) {
        appendLog(
            level: "error",
            message: self.remoteConfigUpdateFailureMessage(
                fileName: fileName,
                reason: error.localizedDescription))
    }

    private func setRemoteConfigMenuState(
        for fileName: String,
        phase: RemoteConfigRefreshPhase,
        updatedAt: Date? = nil)
    {
        let resolvedUpdatedAt = updatedAt ?? self.remoteConfigMenuStates[fileName]?.updatedAt
        self.remoteConfigMenuStates[fileName] = RemoteConfigMenuState(
            updatedAt: resolvedUpdatedAt,
            phase: phase)
    }

    private func resolveRemoteConfigRefreshTargetOrLogFailure(
        fileName: String,
        configDirectory: URL) -> RemoteConfigRefreshTarget?
    {
        guard let target = self.resolveRemoteConfigRefreshTarget(
            fileName: fileName,
            configDirectory: configDirectory)
        else {
            appendLog(level: "error", message: self.invalidRemoteConfigUpdateMessage(for: fileName))
            return nil
        }

        return target
    }

    private func refreshRemoteConfigTarget(
        _ target: RemoteConfigRefreshTarget,
        userAgent: String?) async throws
    {
        try await self.replaceRemoteConfigFile(
            from: target.remoteURL,
            userAgent: userAgent,
            targetURL: target.targetURL)
    }

    private func resolveRemoteConfigRefreshTarget(fileName: String, configDirectory: URL) -> RemoteConfigRefreshTarget? {
        switch self.resolveRemoteConfigRefreshTargetUseCase.execute(
            fileName: fileName,
            remoteConfigSources: self.remoteConfigSources,
            configDirectory: configDirectory,
            isSupportedRemoteConfigURL: self.isSupportedRemoteConfigURL)
        {
        case let .success(target):
            target
        case .failure:
            nil
        }
    }
}
