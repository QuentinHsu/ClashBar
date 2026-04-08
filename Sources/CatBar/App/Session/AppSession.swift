import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppSession: ObservableObject {
    private var resolveAppLaunchAutoStartUseCase: ResolveAppLaunchAutoStartUseCase {
        ResolveAppLaunchAutoStartUseCase()
    }

    @Published private var coreRuntimePresentationState = CoreRuntimePresentationState()
    var localExternalControllerDisplay: String = "127.0.0.1:9090"

    @Published private var runtimeMetricsPresentationState = RuntimeMetricsPresentationState()

    var connectionsCount: Int {
        self.connectionsStore.connectionsCount
    }

    var connections: [ConnectionSummary] {
        self.connectionsStore.connections
    }

    let connectionsStore = ConnectionsStore()
    var appUpdater: (any AppUpdating)?

    @Published private var configPresentationState = ConfigPresentationState()
    @Published private var proxyGroupPresentationState = ProxyGroupPresentationState()
    @Published private var proxyLatencyPresentationState = ProxyLatencyPresentationState()
    @Published private var providerPresentationState = ProviderPresentationState()
    @Published private var systemProxyPresentationState = SystemProxyPresentationState()

    @Published private var logPresentationState = LogPresentationState()
    @Published private var coreControlPresentationState = CoreControlPresentationState()
    @Published private var interfacePresentationState = InterfacePresentationState()
    @Published private var launchAtLoginPresentationState = LaunchAtLoginPresentationState()
    @Published private var appReleasePresentationState = AppReleasePresentationState()
    private var lifecycleCoordinationState = LifecycleCoordinationState()
    @Published private(set) var menuBarDisplaySnapshot = MenuBarDisplay(
        mode: .iconOnly,
        symbolName: "bolt.slash.circle",
        speedLines: nil,
        isRunning: false)

    @Published private var settingsPresentationState = SettingsPresentationState()
    var isCoreSettingSyncing: Bool {
        self.settingsPresentationState.isCoreSettingSyncing
    }

    private let menuBarDisplayResolver = MenuBarDisplayResolver()

    var runtimeVisualStatus: RuntimeVisualStatus {
        self.menuBarDisplayResolver.resolveRuntimeVisualStatus(
            statusText: self.statusText,
            apiStatus: self.apiStatus,
            coreIsRunning: self.coreRepository.isRunning)
    }

    var runtimeStatusText: String {
        switch self.runtimeVisualStatus {
        case .starting: tr("app.runtime.starting")
        case .runningHealthy, .runningDegraded: tr("app.runtime.running")
        case .failed: tr("app.runtime.failed")
        case .stopped: tr("app.runtime.stopped")
        }
    }

    var isExternalControllerWildcardIPv4: Bool {
        guard let host = self.controllerHost(from: self.externalControllerDisplay) else {
            return false
        }
        return host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "0.0.0.0"
    }

    // DRY: unify "running" checks across AppSession and extensions.
    var isRuntimeRunning: Bool {
        self.menuBarDisplayResolver.resolveIsRuntimeRunning(
            statusText: self.statusText,
            coreIsRunning: self.coreRepository.isRunning)
    }

    var menuBarSymbolName: String {
        self.menuBarDisplayResolver.resolveSymbolName(for: self.runtimeVisualStatus)
    }

    var statusBarDisplayMode: StatusBarDisplayMode {
        get { StatusBarDisplayMode(rawValue: self.statusBarDisplayModeRaw) ?? .iconOnly }
        set {
            guard self.statusBarDisplayModeRaw != newValue.rawValue else { return }
            self.statusBarDisplayModeRaw = newValue.rawValue
            self.refreshMenuBarDisplaySnapshotIfNeeded()
            self.updateDataAcquisitionPolicy()
            if newValue != .iconOnly {
                self.flushPendingTrafficSnapshotIfNeeded(immediately: true)
            }
        }
    }

    var menuBarSpeedLines: MenuBarSpeedLines {
        self.menuBarDisplayResolver.resolveSpeedLines(traffic: self.traffic, isRuntimeRunning: self.isRuntimeRunning)
    }

    private var computedMenuBarDisplay: MenuBarDisplay {
        self.menuBarDisplayResolver.resolveDisplay(
            mode: self.statusBarDisplayMode,
            runtimeVisualStatus: self.runtimeVisualStatus,
            isRuntimeRunning: self.isRuntimeRunning,
            traffic: self.traffic)
    }



    func refreshMenuBarDisplaySnapshotIfNeeded() {
        let next = self.computedMenuBarDisplay
        guard next != self.menuBarDisplaySnapshot else { return }
        self.menuBarDisplaySnapshot = next
    }

    func syncConfigPresentationState(path: String, availableFileNames: [String]) {
        self.configPresentationState.syncConfigDirectory(
            path: path,
            availableFileNames: availableFileNames)
    }

    func clearPresentedLogs(keepingCapacity: Bool) {
        self.logPresentationState.clear(keepingCapacity: keepingCapacity)
    }

    func clearPresentedTrafficHistory(historyMaxPoints: Int) {
        self.runtimeMetricsPresentationState.clearTrafficHistory(historyMaxPoints: historyMaxPoints)
    }

    func appendPresentedTrafficHistory(up: Int64, down: Int64, historyMaxPoints: Int) {
        self.runtimeMetricsPresentationState.appendTrafficHistory(
            up: up,
            down: down,
            historyMaxPoints: historyMaxPoints)
    }

    func updatePresentedTrafficTotals(from snapshot: TrafficSnapshot, now: Date) {
        self.runtimeMetricsPresentationState.updateTrafficTotals(from: snapshot, now: now)
    }

    func applyPresentedRuntimeConfigSnapshot(
        _ config: ConfigSnapshot,
        normalizeMode: (String?) -> CoreMode?)
    {
        self.coreRuntimePresentationState.applyRuntimeConfigSnapshot(
            config,
            normalizeMode: normalizeMode)
    }

    func trimPresentedLogs(to maxEntries: Int) {
        self.logPresentationState.trim(to: maxEntries)
    }

    func prependPresentedLogs(_ entries: [AppErrorLogEntry], limit: Int) {
        self.logPresentationState.prepend(entries, limit: limit)
    }

    func rebuildPresentedProxyGroupIndex() {
        self.proxyGroupPresentationState.rebuildGroupIndex()
    }

    func clearPresentedProxyGroupIndex(keepingCapacity: Bool = false) {
        self.proxyGroupPresentationState.clearResolvedGroupIndex(keepingCapacity: keepingCapacity)
    }

    func clearPresentedProxyGroups(keepingCapacity: Bool = false) {
        self.proxyGroupPresentationState.clear(keepingCapacity: keepingCapacity)
    }

    func presentedProxyGroup(named name: String) -> ProxyGroup? {
        self.proxyGroupPresentationState.proxyGroupIndex[name]
    }

    func clearPresentedProxyLatencyState() {
        self.proxyLatencyPresentationState.clearMeasuredDelays()
    }

    func ensurePresentedGroupLatencyBucket(_ groupName: String) {
        self.proxyLatencyPresentationState.ensureGroupLatencyBucket(groupName)
    }

    func setPresentedGroupLatency(groupName: String, delayKey: String, delay: Int) {
        self.proxyLatencyPresentationState.setGroupLatency(groupName: groupName, delayKey: delayKey, delay: delay)
    }

    func replacePresentedGroupLatencies(_ delays: [String: Int], for groupName: String) {
        self.proxyLatencyPresentationState.replaceGroupLatencies(delays, for: groupName)
    }

    func recordPresentedLiveProxyDelay(key: String, delay: Int) {
        self.proxyLatencyPresentationState.recordMeasuredProxyDelay(key: key, delay: delay)
    }

    func beginPresentedGroupLatencyLoading(_ groupName: String) {
        self.proxyLatencyPresentationState.beginGroupLatencyLoading(groupName)
    }

    func endPresentedGroupLatencyLoading(_ groupName: String) {
        self.proxyLatencyPresentationState.endGroupLatencyLoading(groupName)
    }

    func beginPresentedGroupLatencyPending(groupName: String, delayKey: String) {
        self.proxyLatencyPresentationState.beginGroupLatencyPending(groupName: groupName, delayKey: delayKey)
    }

    func endPresentedGroupLatencyPending(groupName: String, delayKey: String) {
        self.proxyLatencyPresentationState.endGroupLatencyPending(groupName: groupName, delayKey: delayKey)
    }

    func beginPresentedNodeLatencyLoading(_ nodeName: String) {
        self.proxyLatencyPresentationState.beginNodeLatencyLoading(nodeName)
    }

    func endPresentedNodeLatencyLoading(_ nodeName: String) {
        self.proxyLatencyPresentationState.endNodeLatencyLoading(nodeName)
    }

    func currentPresentedEditableSettingsSnapshot() -> EditableSettingsSnapshot {
        self.settingsPresentationState.currentEditableSettingsSnapshot()
    }

    func applyPresentedEditableSettingsSnapshot(_ snapshot: EditableSettingsSnapshot) {
        self.settingsPresentationState.applyEditableSettingsSnapshot(snapshot)
    }

    func syncPresentedEditableSettings(from previous: EditableSettingsSnapshot, to incoming: EditableSettingsSnapshot) {
        self.settingsPresentationState.syncEditableFields(from: previous, to: incoming)
    }

    func insertPresentedUpdatingProviderNames(_ names: [String]) -> Set<String> {
        self.providerPresentationState.insertUpdatingProviderNames(names)
    }

    func beginPresentedUpdatingProvider(_ name: String) -> Bool {
        self.providerPresentationState.beginUpdatingProvider(name)
    }

    func endPresentedUpdatingProvider(_ name: String) {
        self.providerPresentationState.endUpdatingProvider(name)
    }

    func retainPresentedUpdatingProviderNames(in currentNames: Set<String>) {
        self.providerPresentationState.retainUpdatingProviderNames(in: currentNames)
    }

    func clearPresentedProviderCollections(keepingCapacity: Bool) {
        self.providerPresentationState.clearCollections(keepingCapacity: keepingCapacity)
    }

    func updatePresentedProviderRefreshStatus(
        phase: ProviderRefreshPhase,
        trigger: ProviderRefreshTrigger?,
        progressDone: Int,
        progressTotal: Int,
        message: String?,
        updatedAt: Date = Date())
    {
        self.providerPresentationState.updateRefreshStatus(
            phase: phase,
            trigger: trigger,
            progressDone: progressDone,
            progressTotal: progressTotal,
            message: message,
            updatedAt: updatedAt)
    }

    func beginPresentedLatestAppReleaseCheck() -> Bool {
        self.appReleasePresentationState.beginCheckingLatestRelease()
    }

    func endPresentedLatestAppReleaseCheck() {
        self.appReleasePresentationState.endCheckingLatestRelease()
    }

    func updatePresentedLatestAppReleaseIfChanged(_ release: AppReleaseInfo) -> Bool {
        self.appReleasePresentationState.updateLatestReleaseIfChanged(release)
    }

    func presentedAvailableAppUpdate(currentVersion: String) -> AppReleaseInfo? {
        self.appReleasePresentationState.availableUpdate(currentVersion: currentVersion)
    }

    func syncPresentedLaunchAtLoginEnabled(_ enabled: Bool) {
        self.launchAtLoginPresentationState.syncEnabled(enabled)
    }

    func clearPresentedLaunchAtLoginError() {
        self.launchAtLoginPresentationState.clearError()
    }

    func applyPresentedLaunchAtLoginFailure(enabled: Bool, message: String) {
        self.launchAtLoginPresentationState.applyFailure(enabled: enabled, message: message)
    }

    func beginPresentedCoreAction(_ action: CoreActionState) -> Bool {
        self.coreControlPresentationState.beginAction(action)
    }

    func endPresentedCoreAction() {
        self.coreControlPresentationState.endAction()
    }

    func setPresentedStartupError(_ message: String?) {
        self.coreControlPresentationState.setStartupError(message)
    }

    func beginPresentedCoreUpgrade() -> Bool {
        self.coreControlPresentationState.beginUpgrade()
    }

    func applyPresentedCoreUpgradeState(_ state: CoreUpgradeState) {
        self.coreControlPresentationState.applyUpgradeState(state)
    }

    func beginLifecycleAutoStartAttempt() -> Bool {
        self.lifecycleCoordinationState.beginAutoStartAttempt()
    }

    func markLifecycleSystemProxyConsistencyCheckedOnLaunch() {
        self.lifecycleCoordinationState.markSystemProxyConsistencyCheckedOnLaunch()
    }

    func setPresentedPanelVisibility(_ presented: Bool) -> Bool {
        self.interfacePresentationState.setPanelPresented(presented)
    }

    func setPresentedActiveMenuTab(_ tab: RootTab) -> Bool {
        self.interfacePresentationState.setActiveMenuTab(tab)
    }

    func beginPresentedQuittingApp() -> Bool {
        self.interfacePresentationState.beginQuitting()
    }

    func clearPresentedSystemProxyOpenFailureHint() {
        self.systemProxyPresentationState.clearOpenFailureHint()
    }

    func updatePresentedSystemProxyOpenFailureHint(_ hint: String?) {
        self.systemProxyPresentationState.updateOpenFailureHint(hint)
    }

    func resetPresentedSystemProxyObservedState() {
        self.systemProxyPresentationState.resetObservedState()
    }

    func applyPresentedSystemProxyHelperHealthSnapshot(
        _ snapshot: SystemProxyHelperHealthSnapshot)
        -> (previousReason: SystemProxyHelperFailureReason?, previousMessage: String?)
    {
        self.systemProxyPresentationState.applyHelperHealthSnapshot(snapshot)
    }

    var isRemoteTarget: Bool {
        !self.remoteMachineStore.activeTarget.isLocal
    }

    var statusText: String {
        get { self.coreRuntimePresentationState.statusText }
        set {
            self.coreRuntimePresentationState.statusText = newValue
            self.refreshMenuBarDisplaySnapshotIfNeeded()
        }
    }

    var version: String {
        get { self.coreRuntimePresentationState.version }
        set { self.coreRuntimePresentationState.version = newValue }
    }

    var controller: String {
        get { self.coreRuntimePresentationState.controller }
        set { self.coreRuntimePresentationState.controller = newValue }
    }

    var externalControllerDisplay: String {
        get { self.coreRuntimePresentationState.externalControllerDisplay }
        set { self.coreRuntimePresentationState.externalControllerDisplay = newValue }
    }

    var controllerUIURL: String {
        get { self.coreRuntimePresentationState.controllerUIURL }
        set { self.coreRuntimePresentationState.controllerUIURL = newValue }
    }

    var controllerSecret: String? {
        get { self.coreRuntimePresentationState.controllerSecret }
        set { self.coreRuntimePresentationState.controllerSecret = newValue }
    }

    var currentMode: CoreMode {
        get { self.coreRuntimePresentationState.currentMode }
        set { self.coreRuntimePresentationState.currentMode = newValue }
    }

    var logLevel: String {
        get { self.coreRuntimePresentationState.logLevel }
        set { self.coreRuntimePresentationState.logLevel = newValue }
    }

    var port: Int? {
        get { self.coreRuntimePresentationState.port }
        set { self.coreRuntimePresentationState.port = newValue }
    }

    var socksPort: Int? {
        get { self.coreRuntimePresentationState.socksPort }
        set { self.coreRuntimePresentationState.socksPort = newValue }
    }

    var redirPort: Int? {
        get { self.coreRuntimePresentationState.redirPort }
        set { self.coreRuntimePresentationState.redirPort = newValue }
    }

    var tproxyPort: Int? {
        get { self.coreRuntimePresentationState.tproxyPort }
        set { self.coreRuntimePresentationState.tproxyPort = newValue }
    }

    var mixedPort: Int {
        get { self.coreRuntimePresentationState.mixedPort }
        set { self.coreRuntimePresentationState.mixedPort = newValue }
    }

    var isProxySyncing: Bool {
        get { self.coreRuntimePresentationState.isProxySyncing }
        set { self.coreRuntimePresentationState.isProxySyncing = newValue }
    }

    var isTunSyncing: Bool {
        get { self.coreRuntimePresentationState.isTunSyncing }
        set { self.coreRuntimePresentationState.isTunSyncing = newValue }
    }

    var apiStatus: APIHealth {
        get { self.coreRuntimePresentationState.apiStatus }
        set {
            self.coreRuntimePresentationState.apiStatus = newValue
            self.refreshMenuBarDisplaySnapshotIfNeeded()
        }
    }

    var traffic: TrafficSnapshot {
        get { self.runtimeMetricsPresentationState.traffic }
        set {
            self.runtimeMetricsPresentationState.traffic = newValue
            self.refreshMenuBarDisplaySnapshotIfNeeded()
        }
    }

    var memory: MemorySnapshot {
        get { self.runtimeMetricsPresentationState.memory }
        set { self.runtimeMetricsPresentationState.memory = newValue }
    }

    var displayUpTotal: Int64 {
        get { self.runtimeMetricsPresentationState.displayUpTotal }
        set { self.runtimeMetricsPresentationState.displayUpTotal = newValue }
    }

    var displayDownTotal: Int64 {
        get { self.runtimeMetricsPresentationState.displayDownTotal }
        set { self.runtimeMetricsPresentationState.displayDownTotal = newValue }
    }

    var trafficHistoryUp: [Int64] {
        get { self.runtimeMetricsPresentationState.trafficHistoryUp }
        set { self.runtimeMetricsPresentationState.trafficHistoryUp = newValue }
    }

    var trafficHistoryDown: [Int64] {
        get { self.runtimeMetricsPresentationState.trafficHistoryDown }
        set { self.runtimeMetricsPresentationState.trafficHistoryDown = newValue }
    }

    var lastTrafficSampleAt: Date? {
        get { self.runtimeMetricsPresentationState.lastTrafficSampleAt }
        set { self.runtimeMetricsPresentationState.lastTrafficSampleAt = newValue }
    }

    var isModeSwitchEnabled: Bool {
        (self.isRemoteTarget || self.coreRepository.isRunning) && self.apiStatus == .healthy
    }

    var mihomoBinaryPath: String {
        get { self.configPresentationState.mihomoBinaryPath }
        set { self.configPresentationState.mihomoBinaryPath = newValue }
    }

    var selectedConfigName: String {
        get { self.configPresentationState.selectedConfigName }
        set { self.configPresentationState.selectedConfigName = newValue }
    }

    var configDirectoryPath: String {
        get { self.configPresentationState.configDirectoryPath }
        set { self.configPresentationState.configDirectoryPath = newValue }
    }

    var availableConfigFileNames: [String] {
        get { self.configPresentationState.availableConfigFileNames }
        set { self.configPresentationState.availableConfigFileNames = newValue }
    }

    var remoteConfigMenuStates: [String: RemoteConfigMenuState] {
        get { self.configPresentationState.remoteConfigMenuStates }
        set { self.configPresentationState.remoteConfigMenuStates = newValue }
    }

    var proxyGroups: [ProxyGroup] {
        get { self.proxyGroupPresentationState.proxyGroups }
        set { self.proxyGroupPresentationState.proxyGroups = newValue }
    }

    var proxyHistoryLatestDelay: [String: Int] {
        get { self.proxyGroupPresentationState.proxyHistoryLatestDelay }
        set { self.proxyGroupPresentationState.proxyHistoryLatestDelay = newValue }
    }

    var proxyNodeTypes: [String: String] {
        get { self.proxyGroupPresentationState.proxyNodeTypes }
        set { self.proxyGroupPresentationState.proxyNodeTypes = newValue }
    }

    var proxyNodeIDs: [String: String] {
        get { self.proxyGroupPresentationState.proxyNodeIDs }
        set { self.proxyGroupPresentationState.proxyNodeIDs = newValue }
    }

    var groupLatencyLoading: Set<String> {
        get { self.proxyLatencyPresentationState.groupLatencyLoading }
        set { self.proxyLatencyPresentationState.groupLatencyLoading = newValue }
    }

    var nodeLatencyLoading: Set<String> {
        get { self.proxyLatencyPresentationState.nodeLatencyLoading }
        set { self.proxyLatencyPresentationState.nodeLatencyLoading = newValue }
    }

    var groupLatencyPendingDelayKeys: [String: Set<String>] {
        get { self.proxyLatencyPresentationState.groupLatencyPendingDelayKeys }
        set { self.proxyLatencyPresentationState.groupLatencyPendingDelayKeys = newValue }
    }

    var groupLatencies: [String: [String: Int]] {
        get { self.proxyLatencyPresentationState.groupLatencies }
        set { self.proxyLatencyPresentationState.groupLatencies = newValue }
    }

    var liveProxyLatestDelay: [String: Int] {
        get { self.proxyLatencyPresentationState.liveProxyLatestDelay }
        set { self.proxyLatencyPresentationState.liveProxyLatestDelay = newValue }
    }

    var errorLogs: [AppErrorLogEntry] {
        get { self.logPresentationState.errorLogs }
        set { self.logPresentationState.errorLogs = newValue }
    }

    var providerProxyCount: Int {
        get { self.providerPresentationState.providerProxyCount }
        set { self.providerPresentationState.providerProxyCount = newValue }
    }

    var providerRuleCount: Int {
        get { self.providerPresentationState.providerRuleCount }
        set { self.providerPresentationState.providerRuleCount = newValue }
    }

    var rulesCount: Int {
        get { self.providerPresentationState.rulesCount }
        set { self.providerPresentationState.rulesCount = newValue }
    }

    var providerRefreshStatus: ProviderRefreshStatus {
        get { self.providerPresentationState.providerRefreshStatus }
        set { self.providerPresentationState.providerRefreshStatus = newValue }
    }

    var proxyProvidersDetail: [String: ProviderDetail] {
        get { self.providerPresentationState.proxyProvidersDetail }
        set { self.providerPresentationState.proxyProvidersDetail = newValue }
    }

    var sortedProxyProviderNames: [String] {
        self.providerPresentationState.sortedProxyProviderNames
    }

    var providerUpdating: Set<String> {
        get { self.providerPresentationState.providerUpdating }
        set { self.providerPresentationState.providerUpdating = newValue }
    }

    var isProxyProvidersRefreshing: Bool {
        get { self.providerPresentationState.isProxyProvidersRefreshing }
        set { self.providerPresentationState.isProxyProvidersRefreshing = newValue }
    }

    var ruleProviders: [String: ProviderDetail] {
        get { self.providerPresentationState.ruleProviders }
        set { self.providerPresentationState.ruleProviders = newValue }
    }

    var ruleItems: [RuleItem] {
        get { self.providerPresentationState.ruleItems }
        set { self.providerPresentationState.ruleItems = newValue }
    }

    var isRuleProvidersRefreshing: Bool {
        get { self.providerPresentationState.isRuleProvidersRefreshing }
        set { self.providerPresentationState.isRuleProvidersRefreshing = newValue }
    }

    var isSystemProxyEnabled: Bool {
        get { self.systemProxyPresentationState.isEnabled }
        set { self.systemProxyPresentationState.isEnabled = newValue }
    }

    var systemProxyEnableIntentInFlight: Bool {
        get { self.systemProxyPresentationState.enableIntentInFlight }
        set { self.systemProxyPresentationState.enableIntentInFlight = newValue }
    }

    var systemProxyHelperFailureReason: SystemProxyHelperFailureReason? {
        get { self.systemProxyPresentationState.helperFailureReason }
        set { self.systemProxyPresentationState.helperFailureReason = newValue }
    }

    var systemProxyHelperFailureMessage: String? {
        get { self.systemProxyPresentationState.helperFailureMessage }
        set { self.systemProxyPresentationState.helperFailureMessage = newValue }
    }

    var systemProxyBackgroundActivityAllowed: Bool? {
        get { self.systemProxyPresentationState.backgroundActivityAllowed }
        set { self.systemProxyPresentationState.backgroundActivityAllowed = newValue }
    }

    var systemProxyHelperProcessRunning: Bool? {
        get { self.systemProxyPresentationState.helperProcessRunning }
        set { self.systemProxyPresentationState.helperProcessRunning = newValue }
    }

    var systemProxyActiveDisplay: String? {
        get { self.systemProxyPresentationState.activeDisplay }
        set { self.systemProxyPresentationState.activeDisplay = newValue }
    }

    var systemProxyOpenFailureHint: String? {
        get { self.systemProxyPresentationState.openFailureHint }
        set { self.systemProxyPresentationState.openFailureHint = newValue }
    }

    var isTunEnabled: Bool {
        get { self.settingsPresentationState.tunEnabled }
        set { self.settingsPresentationState.tunEnabled = newValue }
    }

    var settingsAllowLan: Bool {
        get { self.settingsPresentationState.allowLan }
        set { self.settingsPresentationState.allowLan = newValue }
    }

    var settingsIPv6: Bool {
        get { self.settingsPresentationState.ipv6 }
        set { self.settingsPresentationState.ipv6 = newValue }
    }

    var settingsTCPConcurrent: Bool {
        get { self.settingsPresentationState.tcpConcurrent }
        set { self.settingsPresentationState.tcpConcurrent = newValue }
    }

    var settingsLogLevel: String {
        get { self.settingsPresentationState.logLevel }
        set { self.settingsPresentationState.logLevel = newValue }
    }

    var settingsPort: String {
        get { self.settingsPresentationState.port }
        set { self.settingsPresentationState.port = newValue }
    }

    var settingsSocksPort: String {
        get { self.settingsPresentationState.socksPort }
        set { self.settingsPresentationState.socksPort = newValue }
    }

    var settingsMixedPort: String {
        get { self.settingsPresentationState.mixedPort }
        set { self.settingsPresentationState.mixedPort = newValue }
    }

    var settingsRedirPort: String {
        get { self.settingsPresentationState.redirPort }
        set { self.settingsPresentationState.redirPort = newValue }
    }

    var settingsTProxyPort: String {
        get { self.settingsPresentationState.tproxyPort }
        set { self.settingsPresentationState.tproxyPort = newValue }
    }

    var settingsSyncingKey: String? {
        get { self.settingsPresentationState.syncingKey }
        set { self.settingsPresentationState.syncingKey = newValue }
    }

    var settingsErrorMessage: String? {
        get { self.settingsPresentationState.errorMessage }
        set { self.settingsPresentationState.errorMessage = newValue }
    }

    var settingsSavedMessage: String? {
        get { self.settingsPresentationState.savedMessage }
        set { self.settingsPresentationState.savedMessage = newValue }
    }

    var latestAppReleaseInfo: AppReleaseInfo? {
        get { self.appReleasePresentationState.latestReleaseInfo }
        set { self.appReleasePresentationState.latestReleaseInfo = newValue }
    }

    var launchAtLoginEnabled: Bool {
        get { self.launchAtLoginPresentationState.isEnabled }
        set { self.launchAtLoginPresentationState.isEnabled = newValue }
    }

    var launchAtLoginErrorMessage: String? {
        get { self.launchAtLoginPresentationState.errorMessage }
        set { self.launchAtLoginPresentationState.errorMessage = newValue }
    }

    var startupErrorMessage: String? {
        get { self.coreControlPresentationState.startupErrorMessage }
        set { self.coreControlPresentationState.startupErrorMessage = newValue }
    }

    var coreActionState: CoreActionState {
        get { self.coreControlPresentationState.actionState }
        set { self.coreControlPresentationState.actionState = newValue }
    }

    var coreUpgradeState: CoreUpgradeState {
        get { self.coreControlPresentationState.upgradeState }
        set { self.coreControlPresentationState.upgradeState = newValue }
    }

    var uiLanguage: AppLanguage {
        get { self.interfacePresentationState.uiLanguage }
        set { self.interfacePresentationState.uiLanguage = newValue }
    }

    var appearanceMode: AppAppearanceMode {
        get { self.interfacePresentationState.appearanceMode }
        set { self.interfacePresentationState.appearanceMode = newValue }
    }

    var isPanelPresented: Bool {
        get { self.interfacePresentationState.isPanelPresented }
        set { self.interfacePresentationState.isPanelPresented = newValue }
    }

    var isQuittingApp: Bool {
        get { self.interfacePresentationState.isQuittingApp }
        set { self.interfacePresentationState.isQuittingApp = newValue }
    }

    var activeMenuTab: RootTab {
        get { self.interfacePresentationState.activeMenuTab }
        set { self.interfacePresentationState.activeMenuTab = newValue }
    }

    var isLatestAppReleaseCheckInFlight: Bool {
        get { self.appReleasePresentationState.isCheckingLatestRelease }
        set { self.appReleasePresentationState.isCheckingLatestRelease = newValue }
    }

    var didAttemptAutoStart: Bool {
        get { self.lifecycleCoordinationState.didAttemptAutoStart }
        set { self.lifecycleCoordinationState.didAttemptAutoStart = newValue }
    }

    var didCheckSystemProxyConsistencyOnLaunch: Bool {
        get { self.lifecycleCoordinationState.didCheckSystemProxyConsistencyOnLaunch }
        set { self.lifecycleCoordinationState.didCheckSystemProxyConsistencyOnLaunch = newValue }
    }

    var lastSyncedEditableSettings: EditableSettingsSnapshot? {
        get { self.settingsPresentationState.lastSyncedEditableSettings }
        set { self.settingsPresentationState.lastSyncedEditableSettings = newValue }
    }

    var preserveLocalSettingsOnNextSync: Bool {
        get { self.settingsPresentationState.preserveLocalSettingsOnNextSync }
        set { self.settingsPresentationState.preserveLocalSettingsOnNextSync = newValue }
    }

    var pendingConfigSwitchOverlaySettings: EditableSettingsSnapshot? {
        get { self.settingsPresentationState.pendingConfigSwitchOverlaySettings }
        set { self.settingsPresentationState.pendingConfigSwitchOverlaySettings = newValue }
    }

    var pendingAppLaunchOverlaySettings: EditableSettingsSnapshot? {
        get { self.settingsPresentationState.pendingAppLaunchOverlaySettings }
        set { self.settingsPresentationState.pendingAppLaunchOverlaySettings = newValue }
    }

    var suppressSettingsPersistence: Bool {
        get { self.settingsPresentationState.suppressPersistence }
        set { self.settingsPresentationState.suppressPersistence = newValue }
    }

    var isTunToggleEnabled: Bool {
        (self.isRemoteTarget || self.isRuntimeRunning) && !self.isCoreActionProcessing && !self.isTunSyncing
    }

    var isCoreUpgradeAvailable: Bool {
        if self.isRemoteTarget {
            return self.apiStatus == .healthy || self.apiStatus == .degraded
        }
        return self.isRuntimeRunning
    }

    var autoStartCoreEnabled: Bool {
        get { self.autoStartCore }
        set { self.autoStartCore = newValue }
    }

    var autoManageCoreOnNetworkChangeEnabled: Bool {
        get { self.autoCoreControlOnNetworkChange }
        set {
            guard self.autoCoreControlOnNetworkChange != newValue else { return }
            self.autoCoreControlOnNetworkChange = newValue
            self.updateNetworkReachabilityMonitoringState()
        }
    }

    var isCoreActionProcessing: Bool {
        self.coreControlPresentationState.isActionProcessing
    }

    var isPresentedCoreUpgradeInFlight: Bool {
        self.coreControlPresentationState.isUpgradeInFlight
    }

    var primaryCoreActionLabel: String {
        if self.isCoreActionProcessing { return tr("app.primary.processing") }
        return self.isRuntimeRunning ? tr("app.primary.restart") : tr("app.primary.start")
    }

    var primaryCoreActionIconName: String {
        if self.isCoreActionProcessing { return "hourglass" }
        return self.isRuntimeRunning ? "arrow.clockwise" : "play.fill"
    }

    var isPrimaryCoreActionEnabled: Bool {
        !self.isCoreActionProcessing
    }

    let processManager: any MihomoControlling
    let coreRepository: any CoreRepository
    let configRepository: any ConfigRepository
    let systemProxyRepository: any SystemProxyRepository
    let tunPermissionRepository: any TunPermissionRepository
    let launchAtLoginRepository: any LaunchAtLoginRepository
    let workingDirectoryManager: WorkingDirectoryManager
    let networkReachabilityMonitor: NetworkReachabilityMonitor
    let clipboardRepository: any ClipboardRepository
    let remoteMachineStore: RemoteMachineStore
    var apiClient: MihomoAPIClient?
    var modeSwitchTransportOverride: MihomoAPITransporting?
    var settingsPatchTransportOverride: MihomoAPITransporting?

    var mediumFrequencyTask: Task<Void, Never>?
    var lowFrequencyTask: Task<Void, Never>?
    var streamReceiveTasks: [StreamKind: Task<Void, Never>] = [:]
    var streamWebSocketTasks: [StreamKind: URLSessionWebSocketTask] = [:]
    var streamReconnectAttempts: [String: Int] = [:]
    var streamLastDisconnectLogAt: [String: Date] = [:]
    var streamLastDisconnectLogMessage: [String: String] = [:]
    var proxyPortsAutoSaveTask: Task<Void, Never>?
    var settingsFeedbackClearTask: Task<Void, Never>?
    var providerRefreshTask: Task<Void, Never>?
    var networkAutoStopTask: Task<Void, Never>?
    var networkAutoStartTask: Task<Void, Never>?
    var deferredEditableSettingsOverlayTask: Task<Void, Never>?
    var coreUpgradeFeedbackClearTask: Task<Void, Never>?
    var configDirectoryMonitorTask: Task<Void, Never>?
    var trafficDecodeTask: Task<Void, Never>?
    var mihomoLogFlushTask: Task<Void, Never>?
    var providerRefreshGeneration: Int = 0
    var lastTrafficDecodeAt: Date = .distantPast
    var pendingTrafficPayload: Data?
    var pendingMihomoLogs: [AppErrorLogEntry] = []
    var modeSwitchInFlight = false
    var activatedTabRefreshGeneration: Int = 0
    var configFileSignatureSnapshot: [String: String] = [:]
    var pendingConfigChangeRestart = false
    let defaults = UserDefaults.standard
    @AppStorage("catbar.auto.start.core") private var autoStartCore: Bool = false
    @AppStorage("catbar.auto.core.network.recovery") private var autoCoreControlOnNetworkChange: Bool = true
    @AppStorage("catbar.statusbar.display.mode") private var statusBarDisplayModeRaw: String = StatusBarDisplayMode
        .iconOnly.rawValue
    @AppStorage("catbar.proxy.node.hide_unavailable") var hideUnavailableProxyNodes: Bool = false
    let selectedConfigKey = "catbar.config.selected.filename"
    let legacySelectedConfigKey = "catbar.config.selected"
    let remoteConfigSourcesKey = "catbar.config.remote.sources.v1"
    let lastSuccessfulConfigPathKey = "catbar.last.success.config.path"
    let editableSettingsSnapshotKey = "catbar.settings.editable.snapshot.v1"
    let systemProxyEnabledOnQuitKey = "catbar.system_proxy.enabled_on_quit"
    let uiLanguageKey = "catbar.ui.language"
    let appearanceModeKey = "catbar.ui.appearance.mode"
    let maxLogEntries = 200
    let hiddenPanelMaxInMemoryLogEntries = 20
    let maxBufferedMihomoLogEntries = 40
    let historyMaxPoints = 60
    let mihomoLogFlushIntervalNanoseconds: UInt64 = 150_000_000
    let foregroundMediumFrequencyIntervalNanoseconds: UInt64 = 4_000_000_000
    let backgroundMediumFrequencyIntervalNanoseconds: UInt64 = 12_000_000_000
    let foregroundLowFrequencyPrimaryTabsIntervalNanoseconds: UInt64 = 20_000_000_000
    let foregroundLowFrequencyOtherTabsIntervalNanoseconds: UInt64 = 45_000_000_000
    let backgroundLowFrequencyIntervalNanoseconds: UInt64 = 120_000_000_000
    let trafficPublishIntervalNanoseconds: UInt64 = 500_000_000
    let streamDisconnectLogThrottleInterval: TimeInterval = 2
    let streamReconnectBaseDelayNanoseconds: UInt64 = 1_000_000_000
    let streamReconnectMaxDelayNanoseconds: UInt64 = 8_000_000_000
    // DRY: shared defaults for latency/provider healthcheck endpoints.
    let defaultHealthcheckURL = "https://www.gstatic.com/generate_204"
    let defaultHealthcheckTimeoutMilliseconds = 5000
    let maxConcurrentLatencyMeasurements = 8
    var mediumFrequencyIntervalNanoseconds: UInt64 = 4_000_000_000
    var lowFrequencyIntervalNanoseconds: UInt64 = 20_000_000_000
    var currentConnectionsStreamIntervalMilliseconds: Int?
    var currentLogsStreamLevel: String?
    var catbarLogFileURL: URL?
    var mihomoLogFileURL: URL?
    var catbarLogStore: AppLogStore?
    var mihomoLogStore: AppLogStore?
    var lastCoreFailureAlertKey: String?
    var lastCoreFailureAlertAt: Date?
    let coreFailureAlertThrottleInterval: TimeInterval = 20
    var networkReachabilityStatus: NetworkReachabilityStatus {
        get { self.lifecycleCoordinationState.networkReachabilityStatus }
        set { self.lifecycleCoordinationState.networkReachabilityStatus = newValue }
    }
    var shouldResumeCoreAfterNetworkRecovery: Bool {
        get { self.lifecycleCoordinationState.shouldResumeCoreAfterNetworkRecovery }
        set { self.lifecycleCoordinationState.shouldResumeCoreAfterNetworkRecovery = newValue }
    }
    var isNetworkReachabilityMonitoring: Bool {
        get { self.lifecycleCoordinationState.isNetworkReachabilityMonitoring }
        set { self.lifecycleCoordinationState.isNetworkReachabilityMonitoring = newValue }
    }
    var pendingCoreFeatureRecoveryState: CoreFeatureRecoveryState? {
        get { self.lifecycleCoordinationState.pendingCoreFeatureRecoveryState }
        set { self.lifecycleCoordinationState.pendingCoreFeatureRecoveryState = newValue }
    }
    var deferredEditableSettingsOverlay: DeferredEditableSettingsOverlayRequest?
    var remoteConfigSources: [String: String] = [:]
    var externalControllerWarningKeys: Set<String> = []
    let streamJSONDecoder = JSONDecoder()
    let initialNoCoreSetupGuideShownKey = "catbar.core.install.guide.shown.v1"
    let bundlesMihomoCore: Bool
    var didPresentInitialNoCoreSetupGuide = false

    init(
        processManager: (any MihomoControlling)? = nil,
        configManager: ConfigDirectoryManager? = nil,
        workingDirectoryManager: WorkingDirectoryManager = WorkingDirectoryManager(),
        systemProxyService: SystemProxyService = SystemProxyService(),
        tunPermissionService: TunPermissionService = TunPermissionService(),
        configImportService: ConfigImportService = ConfigImportService(),
        appLaunchService: AppLaunchService = AppLaunchService(),
        networkReachabilityMonitor: NetworkReachabilityMonitor = NetworkReachabilityMonitor(),
        clipboardRepository: any ClipboardRepository = PasteboardClipboardRepository(),
        remoteMachineStore: RemoteMachineStore = RemoteMachineStore(),
        catbarLogStore: AppLogStore? = nil,
        mihomoLogStore: AppLogStore? = nil,
        startBackgroundRefresh: Bool = true)
    {
        self.processManager = processManager ?? MihomoProcessManager(workingDirectoryManager: workingDirectoryManager)
        self.coreRepository = DefaultCoreRepository(processManager: self.processManager)
        self.workingDirectoryManager = workingDirectoryManager
        self.systemProxyRepository = DefaultSystemProxyRepository(service: systemProxyService)
        self.tunPermissionRepository = DefaultTunPermissionRepository(service: tunPermissionService)
        self.launchAtLoginRepository = DefaultLaunchAtLoginRepository(service: appLaunchService)
        self.networkReachabilityMonitor = networkReachabilityMonitor
        self.clipboardRepository = clipboardRepository
        self.remoteMachineStore = remoteMachineStore
        self.catbarLogStore = catbarLogStore
        self.mihomoLogStore = mihomoLogStore
        let resolvedConfigManager = configManager ?? ConfigDirectoryManager(
            workingDirectoryManager: workingDirectoryManager)
        self.configRepository = DefaultConfigRepository(
            configManager: resolvedConfigManager,
            configImportService: configImportService)
        self.bundlesMihomoCore = Self.resolveBundledMihomoCoreFlag()
        self.uiLanguage = loadPersistedUILanguage()
        self.appearanceMode = loadPersistedAppearanceMode()
        applyAppAppearance()
        refreshLaunchAtLoginStatus()

        self.mihomoBinaryPath = self.coreRepository.detectedBinaryPath ?? "-"
        if let managedProcess = self.processManager as? MihomoProcessManager {
            managedProcess.onLog = { [weak self] line in
                Task { @MainActor in
                    guard self?.isRemoteTarget != true else { return }
                    self?.appendMihomoLog(level: "info", message: line)
                }
            }
            managedProcess.onTermination = { [weak self] code in
                Task { @MainActor in
                    guard self?.isRemoteTarget != true else { return }
                    let message = self?.tr("log.process.terminated", code) ?? ""
                    self?.statusText = "Failed"
                    self?.apiStatus = .failed
                    self?.resetTrafficPresentation()
                    self?.appendLog(level: "error", message: message)
                    self?.cancelPolling()
                    if self?.coreActionState == .idle, let self, !message.isEmpty {
                        self.presentCoreFailureAlert(
                            title: self.tr("app.core.alert.process_terminated.title"),
                            message: message,
                            dedupeKey: "core-process-terminated",
                            style: .critical)
                    }
                }
            }
        }
        do {
            try self.workingDirectoryManager.bootstrapDirectories()
            catbarLogFileURL = self.workingDirectoryManager.logsDirectoryURL.appendingPathComponent(
                "catbar.log",
                isDirectory: false)
            mihomoLogFileURL = self.workingDirectoryManager.logsDirectoryURL.appendingPathComponent(
                "mihomo.log",
                isDirectory: false)

            if let catbarLogFileURL, self.catbarLogStore == nil {
                self.catbarLogStore = AppLogStore(logFileURL: catbarLogFileURL)
            }
            if let mihomoLogFileURL, self.mihomoLogStore == nil {
                self.mihomoLogStore = AppLogStore(logFileURL: mihomoLogFileURL)
            }
            ensureLogFileExists()
            seedBundledConfigIfNeeded()
        } catch {
            appendLog(level: "error", message: tr("log.working_dir_init_failed", error.localizedDescription))
        }
        restoreSavedConfigDirectory()
        restoreLastSuccessfulConfigIfAvailable()
        self.remoteConfigSources = loadPersistedRemoteConfigSources()
        pruneRemoteConfigSourcesIfNeeded()
        // Restore persisted remote target if available; otherwise stay local.
        if case let .remote(machine) = self.remoteMachineStore.activeTarget {
            self.controller = machine.controllerAddress
            self.controllerSecret = machine.secret
            self.externalControllerDisplay = machine.displayAddress
            self.controllerUIURL = makeControllerUIURL(machine.controllerAddress, secret: machine.secret)
        } else {
            self.controllerUIURL = makeControllerUIURL(self.controller, secret: self.controllerSecret)
        }
        if let persisted = loadPersistedEditableSettingsSnapshot() {
            applyEditableSettingsSnapshotToUI(persisted)
            self.preserveLocalSettingsOnNextSync = true
            self.pendingAppLaunchOverlaySettings = persisted
        }

        if startBackgroundRefresh {
            Task {
                // If a remote target was restored, verify connectivity first.
                // Fall back to local silently if the remote is unreachable.
                if case let .remote(machine) = self.remoteMachineStore.activeTarget {
                    let status = await self.remoteMachineStore.refreshConnectivity(for: machine)
                    if !status.isConnected {
                        self.remoteMachineStore.selectTarget(.local)
                        if let configPath = await self.resolveSelectedConfigPath() {
                            self.applyExternalControllerFromSelectedConfigFile(configPath: configPath)
                        } else {
                            let fallback = "127.0.0.1:9090"
                            self.controller = fallback
                            self.controllerSecret = nil
                            self.externalControllerDisplay = fallback
                            self.localExternalControllerDisplay = fallback
                            self.controllerUIURL = self.makeControllerUIURL(fallback, secret: nil)
                            self.ensureAPIClient()
                        }
                        self.appendLog(level: "warning", message: self.tr(
                            "log.remote.restore_failed", machine.name))
                    } else {
                        self.ensureAPIClient()
                        self.statusText = "Running"
                        self.preserveLocalSettingsOnNextSync = false
                        self.pendingAppLaunchOverlaySettings = nil
                        self.lastSyncedEditableSettings = nil
                        _ = try? await self.fetchRuntimeConfigSnapshot()
                    }
                }
                await refreshFromAPI(includeSlowCalls: true)
                await applyPendingAppLaunchSettingsOverlayIfNeeded()
                self.seedCoreFeatureRecoveryFromPersistedQuitState()
                if self.hasSystemProxyOpenIntent {
                    await self.systemProxyRepository.warmUpHelperIfPossible()
                    await self.refreshSystemProxyHelperStatus()
                    await refreshSystemProxyStatus()
                    await ensureSystemProxyConsistencyOnFirstLaunchIfNeeded()
                } else {
                    self.resetSystemProxyObservedState()
                    self.didCheckSystemProxyConsistencyOnLaunch = true
                }
            }

            self.startConfigDirectoryMonitoringIfNeeded()
        }
        if self.resolveAppLaunchAutoStartUseCase.execute(.init(
            startBackgroundRefresh: startBackgroundRefresh,
            autoStartCoreEnabled: self.autoStartCore,
            shouldDeferForMissingManagedCore: self.shouldDeferAutoStartForMissingManagedCore())) == .schedule
        {
            Task { [weak self] in
                await self?.attemptAutoStartIfNeeded()
            }
        }

        self.updateNetworkReachabilityMonitoringState()
        self.refreshMenuBarDisplaySnapshotIfNeeded()
    }

    deinit {
        networkAutoStopTask?.cancel()
        networkAutoStartTask?.cancel()
        deferredEditableSettingsOverlayTask?.cancel()
        configDirectoryMonitorTask?.cancel()
        trafficDecodeTask?.cancel()
        mihomoLogFlushTask?.cancel()
        mediumFrequencyTask?.cancel()
        lowFrequencyTask?.cancel()
        for task in streamReceiveTasks.values {
            task.cancel()
        }
        for webSocketTask in streamWebSocketTasks.values {
            webSocketTask.cancel(with: .goingAway, reason: nil)
        }
        providerRefreshTask?.cancel()
    }

    private static func resolveBundledMihomoCoreFlag() -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "CatBarBundlesMihomoCore") else {
            return true
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            return NSString(string: string).boolValue
        }
        return true
    }
}
