import Foundation

enum RuntimeVisualStatus {
    case stopped
    case starting
    case runningHealthy
    case runningDegraded
    case failed
}

enum StartTrigger {
    case manual
    case auto
    case networkRecovery
}

enum StopTrigger {
    case manual
    case networkLoss
}

enum CoreActionState {
    case idle
    case starting
    case stopping
    case restarting
}

enum CoreUpgradeState: Equatable {
    case idle
    case running
    case succeeded
    case alreadyLatest(version: String?)
    case failed(message: String)
}

enum ConfigLogLevel: String, CaseIterable {
    case silent
    case error
    case warning
    case info
    case debug
}

enum ConfigPatchValue {
    case bool(Bool)
    case int(Int)
    case string(String)
    indirect case object([String: ConfigPatchValue])

    var jsonValue: JSONValue {
        switch self {
        case let .bool(value):
            .bool(value)
        case let .int(value):
            .int(value)
        case let .string(value):
            .string(value)
        case let .object(value):
            .object(value.mapValues(\.jsonValue))
        }
    }
}

enum StatusBarDisplayMode: String, CaseIterable, Identifiable {
    case iconOnly = "icon_only"
    case iconAndSpeed = "icon_and_speed"
    case speedOnly = "speed_only"

    var id: String {
        rawValue
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }
}

struct DataAcquisitionPolicy: Equatable {
    let enableTrafficStream: Bool
    let enableMemoryStream: Bool
    let enableConnectionsStream: Bool
    let connectionsIntervalMilliseconds: Int?
    let enableLogsStream: Bool
    let mediumFrequencyIntervalNanoseconds: UInt64
    let lowFrequencyIntervalNanoseconds: UInt64
}

enum ProviderRefreshTrigger {
    case start
    case restart
    case configSwitch
}

enum ProviderRefreshPhase {
    case idle
    case updating
    case succeeded
    case failed
    case cancelled
}

enum RemoteConfigRefreshPhase: Equatable {
    case idle
    case refreshing
    case failed
}

struct RemoteConfigMenuState: Equatable {
    let updatedAt: Date?
    let phase: RemoteConfigRefreshPhase

    static let idle = RemoteConfigMenuState(updatedAt: nil, phase: .idle)
}

struct ProviderRefreshStatus {
    let phase: ProviderRefreshPhase
    let trigger: ProviderRefreshTrigger?
    let progressDone: Int
    let progressTotal: Int
    let message: String?
    let updatedAt: Date?

    static let idle = ProviderRefreshStatus(
        phase: .idle,
        trigger: nil,
        progressDone: 0,
        progressTotal: 0,
        message: nil,
        updatedAt: nil)
}

struct ProviderPresentationState {
    var providerProxyCount: Int = 0
    var providerRuleCount: Int = 0
    var rulesCount: Int = 0
    var proxyProvidersDetail: [String: ProviderDetail] = [:] {
        didSet {
            self.sortedProxyProviderNames = self.proxyProvidersDetail.keys.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }
    }
    var sortedProxyProviderNames: [String] = []
    var providerUpdating: Set<String> = []
    var isProxyProvidersRefreshing: Bool = false
    var ruleProviders: [String: ProviderDetail] = [:]
    var ruleItems: [RuleItem] = []
    var isRuleProvidersRefreshing: Bool = false
    var providerRefreshStatus: ProviderRefreshStatus = .idle

    mutating func insertUpdatingProviderNames(_ names: [String]) -> Set<String> {
        let insertedNames = Set(names).subtracting(self.providerUpdating)
        self.providerUpdating.formUnion(insertedNames)
        return insertedNames
    }

    mutating func beginUpdatingProvider(_ name: String) -> Bool {
        self.providerUpdating.insert(name).inserted
    }

    mutating func endUpdatingProvider(_ name: String) {
        self.providerUpdating.remove(name)
    }

    mutating func retainUpdatingProviderNames(in currentNames: Set<String>) {
        self.providerUpdating = self.providerUpdating.intersection(currentNames)
    }

    mutating func clearCollections(keepingCapacity: Bool) {
        self.providerProxyCount = 0
        self.providerRuleCount = 0
        self.rulesCount = 0
        self.proxyProvidersDetail.removeAll(keepingCapacity: keepingCapacity)
        self.providerUpdating.removeAll(keepingCapacity: keepingCapacity)
        self.ruleProviders.removeAll(keepingCapacity: keepingCapacity)
        self.ruleItems.removeAll(keepingCapacity: keepingCapacity)
    }

    mutating func updateRefreshStatus(
        phase: ProviderRefreshPhase,
        trigger: ProviderRefreshTrigger?,
        progressDone: Int,
        progressTotal: Int,
        message: String?,
        updatedAt: Date)
    {
        self.providerRefreshStatus = ProviderRefreshStatus(
            phase: phase,
            trigger: trigger,
            progressDone: progressDone,
            progressTotal: progressTotal,
            message: message,
            updatedAt: updatedAt)
    }
}

struct ConfigPresentationState {
    var mihomoBinaryPath: String = "-"
    var selectedConfigName: String = "-"
    var configDirectoryPath: String = "-"
    var availableConfigFileNames: [String] = []
    var remoteConfigMenuStates: [String: RemoteConfigMenuState] = [:]

    mutating func syncConfigDirectory(path: String, availableFileNames: [String]) {
        self.configDirectoryPath = path
        self.availableConfigFileNames = availableFileNames
        if self.selectedConfigName == "-", let first = availableFileNames.first {
            self.selectedConfigName = first
        }
    }
}

struct LogPresentationState {
    var errorLogs: [AppErrorLogEntry] = []

    mutating func clear(keepingCapacity: Bool) {
        self.errorLogs.removeAll(keepingCapacity: keepingCapacity)
    }

    mutating func trim(to maxEntries: Int) {
        guard self.errorLogs.count > maxEntries else { return }
        self.errorLogs.removeLast(self.errorLogs.count - maxEntries)
    }

    mutating func prepend(_ entries: [AppErrorLogEntry], limit: Int) {
        guard !entries.isEmpty else { return }
        let combined = entries.reversed() + self.errorLogs
        self.errorLogs = Array(combined.prefix(limit))
    }
}

struct ProxyGroupPresentationState {
    var proxyGroups: [ProxyGroup] = []
    var proxyGroupIndex: [String: ProxyGroup] = [:]
    var proxyHistoryLatestDelay: [String: Int] = [:]
    var proxyNodeTypes: [String: String] = [:]
    var proxyNodeIDs: [String: String] = [:]

    mutating func rebuildGroupIndex() {
        self.proxyGroupIndex = Dictionary(
            self.proxyGroups.map { ($0.name, $0) },
            uniquingKeysWith: { _, latest in latest })
    }

    mutating func clearResolvedGroupIndex(keepingCapacity: Bool) {
        self.proxyGroupIndex.removeAll(keepingCapacity: keepingCapacity)
    }

    mutating func clear(keepingCapacity: Bool) {
        self.proxyGroups.removeAll(keepingCapacity: keepingCapacity)
        self.proxyGroupIndex.removeAll(keepingCapacity: keepingCapacity)
        self.proxyHistoryLatestDelay.removeAll(keepingCapacity: keepingCapacity)
        self.proxyNodeTypes.removeAll(keepingCapacity: keepingCapacity)
        self.proxyNodeIDs.removeAll(keepingCapacity: keepingCapacity)
    }
}

struct ProxyLatencyPresentationState {
    var groupLatencyLoading: Set<String> = []
    var nodeLatencyLoading: Set<String> = []
    var groupLatencyPendingDelayKeys: [String: Set<String>] = [:]
    var groupLoadingRefCount = RefCountedPresence<String>()
    var pendingDelayKeyRefCount = NestedRefCountedPresence<String, String>()
    var nodeLoadingRefCount = RefCountedPresence<String>()
    var groupLatencies: [String: [String: Int]] = [:]
    var liveProxyLatestDelay: [String: Int] = [:]

    mutating func clearMeasuredDelays() {
        self.groupLatencies = [:]
        self.liveProxyLatestDelay = [:]
        self.groupLatencyLoading = []
        self.groupLoadingRefCount.reset()
        self.groupLatencyPendingDelayKeys = [:]
        self.pendingDelayKeyRefCount.reset()
        self.nodeLatencyLoading = []
        self.nodeLoadingRefCount.reset()
    }

    mutating func ensureGroupLatencyBucket(_ groupName: String) {
        if self.groupLatencies[groupName] == nil {
            self.groupLatencies[groupName] = [:]
        }
    }

    mutating func setGroupLatency(groupName: String, delayKey: String, delay: Int) {
        self.ensureGroupLatencyBucket(groupName)
        self.groupLatencies[groupName]?[delayKey] = delay
    }

    mutating func replaceGroupLatencies(_ delays: [String: Int], for groupName: String) {
        self.groupLatencies[groupName] = delays
    }

    mutating func recordMeasuredProxyDelay(key: String, delay: Int) {
        self.liveProxyLatestDelay[key] = max(delay, 0)
    }

    mutating func beginGroupLatencyLoading(_ groupName: String) {
        self.groupLoadingRefCount.begin(groupName, into: &self.groupLatencyLoading)
    }

    mutating func endGroupLatencyLoading(_ groupName: String) {
        self.groupLoadingRefCount.end(groupName, from: &self.groupLatencyLoading)
    }

    mutating func beginGroupLatencyPending(groupName: String, delayKey: String) {
        self.pendingDelayKeyRefCount.begin(
            outer: groupName,
            inner: delayKey,
            into: &self.groupLatencyPendingDelayKeys)
    }

    mutating func endGroupLatencyPending(groupName: String, delayKey: String) {
        self.pendingDelayKeyRefCount.end(
            outer: groupName,
            inner: delayKey,
            from: &self.groupLatencyPendingDelayKeys)
    }

    mutating func beginNodeLatencyLoading(_ nodeName: String) {
        self.nodeLoadingRefCount.begin(nodeName, into: &self.nodeLatencyLoading)
    }

    mutating func endNodeLatencyLoading(_ nodeName: String) {
        self.nodeLoadingRefCount.end(nodeName, from: &self.nodeLatencyLoading)
    }
}

struct SettingsPresentationState {
    var allowLan: Bool = false
    var ipv6: Bool = false
    var tcpConcurrent: Bool = false
    var tunEnabled: Bool = false
    var logLevel: String = ConfigLogLevel.info.rawValue
    var port: String = "0"
    var socksPort: String = "0"
    var mixedPort: String = "7890"
    var redirPort: String = "0"
    var tproxyPort: String = "0"
    var syncingKey: String?
    var errorMessage: String?
    var savedMessage: String?
    var lastSyncedEditableSettings: EditableSettingsSnapshot?
    var preserveLocalSettingsOnNextSync = false
    var pendingConfigSwitchOverlaySettings: EditableSettingsSnapshot?
    var pendingAppLaunchOverlaySettings: EditableSettingsSnapshot?
    var suppressPersistence = false

    var isCoreSettingSyncing: Bool {
        self.syncingKey != nil
    }

    func currentEditableSettingsSnapshot() -> EditableSettingsSnapshot {
        EditableSettingsSnapshot(
            allowLan: self.allowLan,
            ipv6: self.ipv6,
            tcpConcurrent: self.tcpConcurrent,
            tunEnabled: self.tunEnabled,
            logLevel: self.logLevel,
            port: self.port,
            socksPort: self.socksPort,
            mixedPort: self.mixedPort,
            redirPort: self.redirPort,
            tproxyPort: self.tproxyPort)
    }

    mutating func applyEditableSettingsSnapshot(_ snapshot: EditableSettingsSnapshot) {
        self.allowLan = snapshot.allowLan
        self.ipv6 = snapshot.ipv6
        self.tcpConcurrent = snapshot.tcpConcurrent
        self.tunEnabled = snapshot.tunEnabled
        self.logLevel = snapshot.logLevel
        self.port = snapshot.port
        self.socksPort = snapshot.socksPort
        self.mixedPort = snapshot.mixedPort
        self.redirPort = snapshot.redirPort
        self.tproxyPort = snapshot.tproxyPort
    }

    mutating func syncEditableFields(from previous: EditableSettingsSnapshot, to incoming: EditableSettingsSnapshot) {
        if self.allowLan == previous.allowLan {
            self.allowLan = incoming.allowLan
        }
        if self.ipv6 == previous.ipv6 {
            self.ipv6 = incoming.ipv6
        }
        if self.tcpConcurrent == previous.tcpConcurrent {
            self.tcpConcurrent = incoming.tcpConcurrent
        }
        if self.tunEnabled == previous.tunEnabled {
            self.tunEnabled = incoming.tunEnabled
        }
        if self.logLevel == previous.logLevel {
            self.logLevel = incoming.logLevel
        }
        if self.port == previous.port {
            self.port = incoming.port
        }
        if self.socksPort == previous.socksPort {
            self.socksPort = incoming.socksPort
        }
        if self.mixedPort == previous.mixedPort {
            self.mixedPort = incoming.mixedPort
        }
        if self.redirPort == previous.redirPort {
            self.redirPort = incoming.redirPort
        }
        if self.tproxyPort == previous.tproxyPort {
            self.tproxyPort = incoming.tproxyPort
        }
    }
}

struct SystemProxyPresentationState {
    var isEnabled: Bool = false
    var enableIntentInFlight: Bool = false
    var helperFailureReason: SystemProxyHelperFailureReason?
    var helperFailureMessage: String?
    var backgroundActivityAllowed: Bool?
    var helperProcessRunning: Bool?
    var activeDisplay: String?
    var openFailureHint: String?

    mutating func clearOpenFailureHint() {
        self.openFailureHint = nil
    }

    mutating func updateOpenFailureHint(_ hint: String?) {
        self.openFailureHint = hint
    }

    mutating func resetObservedState() {
        self.backgroundActivityAllowed = nil
        self.helperProcessRunning = nil
        self.helperFailureReason = nil
        self.helperFailureMessage = nil
        if !self.isEnabled {
            self.activeDisplay = nil
        }
    }

    mutating func applyHelperHealthSnapshot(
        _ snapshot: SystemProxyHelperHealthSnapshot)
        -> (previousReason: SystemProxyHelperFailureReason?, previousMessage: String?)
    {
        let previous = (previousReason: self.helperFailureReason, previousMessage: self.helperFailureMessage)
        self.backgroundActivityAllowed = snapshot.backgroundActivityAllowed
        self.helperProcessRunning = snapshot.processRunning
        self.helperFailureReason = snapshot.failureReason
        self.helperFailureMessage = snapshot.rawMessage
        return previous
    }
}

struct AppReleasePresentationState {
    var latestReleaseInfo: AppReleaseInfo?
    var isCheckingLatestRelease = false

    mutating func beginCheckingLatestRelease() -> Bool {
        guard !self.isCheckingLatestRelease else { return false }
        self.isCheckingLatestRelease = true
        return true
    }

    mutating func endCheckingLatestRelease() {
        self.isCheckingLatestRelease = false
    }

    mutating func updateLatestReleaseIfChanged(_ release: AppReleaseInfo) -> Bool {
        guard self.latestReleaseInfo != release else { return false }
        self.latestReleaseInfo = release
        return true
    }

    func availableUpdate(currentVersion: String) -> AppReleaseInfo? {
        guard let latestReleaseInfo else { return nil }
        guard !latestReleaseInfo.isDraft, !latestReleaseInfo.isPrerelease else { return nil }
        guard AppSemanticVersion.isNewerRelease(tagName: latestReleaseInfo.tagName, than: currentVersion) else {
            return nil
        }
        return latestReleaseInfo
    }
}

struct LaunchAtLoginPresentationState {
    var isEnabled = false
    var errorMessage: String?

    mutating func syncEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }

    mutating func clearError() {
        self.errorMessage = nil
    }

    mutating func applyFailure(enabled: Bool, message: String) {
        self.isEnabled = enabled
        self.errorMessage = message
    }
}

struct CoreControlPresentationState {
    var startupErrorMessage: String?
    var actionState: CoreActionState = .idle
    var upgradeState: CoreUpgradeState = .idle

    var isActionProcessing: Bool {
        self.actionState != .idle
    }

    var isUpgradeInFlight: Bool {
        if case .running = self.upgradeState {
            return true
        }
        return false
    }

    mutating func beginAction(_ action: CoreActionState) -> Bool {
        guard self.actionState == .idle else { return false }
        self.actionState = action
        return true
    }

    mutating func endAction() {
        self.actionState = .idle
    }

    mutating func setStartupError(_ message: String?) {
        self.startupErrorMessage = message
    }

    mutating func beginUpgrade() -> Bool {
        guard !self.isUpgradeInFlight else { return false }
        self.upgradeState = .running
        return true
    }

    mutating func applyUpgradeState(_ state: CoreUpgradeState) {
        self.upgradeState = state
    }
}

struct InterfacePresentationState {
    var uiLanguage: AppLanguage = .zhHans
    var appearanceMode: AppAppearanceMode = .system
    var isPanelPresented = false
    var isQuittingApp = false
    var activeMenuTab: RootTab = .proxy

    mutating func setPanelPresented(_ presented: Bool) -> Bool {
        guard self.isPanelPresented != presented else { return false }
        self.isPanelPresented = presented
        return true
    }

    mutating func setActiveMenuTab(_ tab: RootTab) -> Bool {
        let changed = self.activeMenuTab != tab
        self.activeMenuTab = tab
        return changed
    }

    mutating func beginQuitting() -> Bool {
        guard !self.isQuittingApp else { return false }
        self.isQuittingApp = true
        return true
    }
}

struct MenuBarSpeedLines: Equatable {
    let up: String
    let down: String

    static let zero = MenuBarSpeedLines(up: "0KB/s↑", down: "0KB/s↓")
}

struct MenuBarDisplay: Equatable {
    let mode: StatusBarDisplayMode
    let symbolName: String?
    let speedLines: MenuBarSpeedLines?
    let isRunning: Bool
}

struct CoreFeatureRecoveryState {
    let systemProxyEnabled: Bool
    let tunEnabled: Bool

    var shouldRecoverAnyFeature: Bool {
        self.systemProxyEnabled || self.tunEnabled
    }

    var pendingState: CoreFeatureRecoveryState? {
        self.shouldRecoverAnyFeature ? self : nil
    }

    func merged(with other: CoreFeatureRecoveryState?) -> CoreFeatureRecoveryState {
        CoreFeatureRecoveryState(
            systemProxyEnabled: self.systemProxyEnabled || (other?.systemProxyEnabled ?? false),
            tunEnabled: self.tunEnabled || (other?.tunEnabled ?? false))
    }
}

struct EditableSettingsSnapshot: Equatable, Codable {
    let allowLan: Bool
    let ipv6: Bool
    let tcpConcurrent: Bool
    let tunEnabled: Bool
    let logLevel: String
    let port: String
    let socksPort: String
    let mixedPort: String
    let redirPort: String
    let tproxyPort: String

    private enum CodingKeys: String, CodingKey {
        case allowLan
        case ipv6
        case tcpConcurrent
        case tunEnabled
        case logLevel
        case port
        case socksPort
        case mixedPort
        case redirPort
        case tproxyPort
    }

    init(config: ConfigSnapshot) {
        self.allowLan = config.allowLan ?? false
        self.ipv6 = config.ipv6 ?? false
        self.tcpConcurrent = config.tcpConcurrent ?? false
        self.tunEnabled = config.tunEnabled ?? false
        self.logLevel = ConfigLogLevel(rawValue: config.logLevel ?? "")?.rawValue ?? ConfigLogLevel.info.rawValue
        self.port = config.port.map(String.init) ?? ""
        self.socksPort = config.socksPort.map(String.init) ?? ""
        self.mixedPort = config.mixedPort.map(String.init) ?? ""
        self.redirPort = config.redirPort.map(String.init) ?? ""
        self.tproxyPort = config.tproxyPort.map(String.init) ?? ""
    }

    init(
        allowLan: Bool,
        ipv6: Bool,
        tcpConcurrent: Bool,
        tunEnabled: Bool,
        logLevel: String,
        port: String,
        socksPort: String,
        mixedPort: String,
        redirPort: String,
        tproxyPort: String)
    {
        self.allowLan = allowLan
        self.ipv6 = ipv6
        self.tcpConcurrent = tcpConcurrent
        self.tunEnabled = tunEnabled
        self.logLevel = logLevel
        self.port = port
        self.socksPort = socksPort
        self.mixedPort = mixedPort
        self.redirPort = redirPort
        self.tproxyPort = tproxyPort
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.allowLan = try container.decode(Bool.self, forKey: .allowLan)
        self.ipv6 = try container.decode(Bool.self, forKey: .ipv6)
        self.tcpConcurrent = try container.decodeIfPresent(Bool.self, forKey: .tcpConcurrent) ?? false
        self.tunEnabled = try container.decodeIfPresent(Bool.self, forKey: .tunEnabled) ?? false
        self.logLevel = try container.decode(String.self, forKey: .logLevel)
        self.port = try container.decode(String.self, forKey: .port)
        self.socksPort = try container.decode(String.self, forKey: .socksPort)
        self.mixedPort = try container.decode(String.self, forKey: .mixedPort)
        self.redirPort = try container.decode(String.self, forKey: .redirPort)
        self.tproxyPort = try container.decode(String.self, forKey: .tproxyPort)
    }
}

extension EditableSettingsSnapshot {
    func withTunEnabled(_ enabled: Bool) -> EditableSettingsSnapshot {
        EditableSettingsSnapshot(
            allowLan: self.allowLan,
            ipv6: self.ipv6,
            tcpConcurrent: self.tcpConcurrent,
            tunEnabled: enabled,
            logLevel: self.logLevel,
            port: self.port,
            socksPort: self.socksPort,
            mixedPort: self.mixedPort,
            redirPort: self.redirPort,
            tproxyPort: self.tproxyPort)
    }
}

struct SystemProxyPorts: Equatable {
    let httpPort: Int?
    let httpsPort: Int?
    let socksPort: Int?

    static let disabled = SystemProxyPorts(httpPort: nil, httpsPort: nil, socksPort: nil)

    var hasEnabledPort: Bool {
        self.httpPort != nil || self.httpsPort != nil || self.socksPort != nil
    }

    var primaryPort: Int? {
        self.httpPort ?? self.httpsPort ?? self.socksPort
    }
}
