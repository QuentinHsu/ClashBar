import Foundation

@MainActor
extension AppSession {
    private var coreUpgradeStateResolver: CoreUpgradeStateResolver {
        CoreUpgradeStateResolver(unknownMessage: tr("ui.common.unknown"))
    }

    private func maintenanceRepository() throws -> MaintenanceRepository {
        try DefaultMaintenanceRepository(transport: self.clientOrThrow())
    }

    private func upgradeCoreUseCase() throws -> UpgradeCoreUseCase {
        try UpgradeCoreUseCase(repository: self.maintenanceRepository())
    }

    private func flushFakeIPCacheUseCase() throws -> FlushFakeIPCacheUseCase {
        try FlushFakeIPCacheUseCase(repository: self.maintenanceRepository())
    }

    private func flushDNSCacheUseCase() throws -> FlushDNSCacheUseCase {
        try FlushDNSCacheUseCase(repository: self.maintenanceRepository())
    }

    private func fetchVersionUseCase() throws -> FetchVersionUseCase {
        try FetchVersionUseCase(repository: self.maintenanceRepository())
    }

    func upgradeCore() async {
        guard self.beginPresentedCoreUpgrade() else { return }

        self.coreUpgradeFeedbackClearTask?.cancel()
        self.coreUpgradeFeedbackClearTask = nil

        do {
            let response = try await self.upgradeCoreUseCase().execute()
            self.applyCoreUpgradeState(self.coreUpgradeState(from: response))
        } catch {
            self.applyCoreUpgradeState(self.coreUpgradeState(from: error))
        }
    }

    func flushFakeIPCache() async {
        await runNoResponseAction(tr("log.action_name.flush_fakeip_cache")) {
            try await self.flushFakeIPCacheUseCase().execute()
        }
    }

    func flushDNSCache() async {
        await runNoResponseAction(tr("log.action_name.flush_dns_cache")) {
            try await self.flushDNSCacheUseCase().execute()
        }
    }

    func refreshActiveTab() async {
        await refreshForActivatedTab(activeMenuTab)
    }

    var isCoreUpgradeInFlight: Bool {
        self.isPresentedCoreUpgradeInFlight
    }

    private func applyCoreUpgradeState(_ state: CoreUpgradeState) {
        self.applyPresentedCoreUpgradeState(state)

        switch state {
        case .idle, .running:
            return
        case .succeeded:
            self.appendLog(level: "info", message: tr("log.core_upgrade.updated"))
            Task { [weak self] in
                await self?.refreshCoreVersionAfterUpgradeIfPossible()
            }
        case let .alreadyLatest(version):
            if let version, !version.isEmpty {
                self.version = AppSemanticVersion.normalizedDisplayVersion(from: version)
                self.appendLog(level: "info", message: tr("log.core_upgrade.latest_version", self.version))
            } else {
                self.appendLog(level: "info", message: tr("log.core_upgrade.latest"))
            }
        case let .failed(message):
            self.appendLog(level: "error", message: tr("log.core_upgrade.failed", message))
        }

        self.scheduleCoreUpgradeFeedbackAutoClear()
    }

    private func scheduleCoreUpgradeFeedbackAutoClear() {
        self.coreUpgradeFeedbackClearTask?.cancel()
        self.coreUpgradeFeedbackClearTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 4_000_000_000)
            } catch {
                return
            }

            guard let self else { return }
            guard !self.isCoreUpgradeInFlight else { return }
            self.applyPresentedCoreUpgradeState(.idle)
        }
    }

    private func refreshCoreVersionAfterUpgradeIfPossible() async {
        do {
            try await Task.sleep(nanoseconds: 750_000_000)
        } catch {
            return
        }

        guard !Task.isCancelled else { return }

        do {
            let versionInfo = try await self.fetchVersionUseCase().execute()
            guard !Task.isCancelled else { return }
            self.version = versionInfo.version
        } catch {
            // Best effort only. The core may be restarting briefly after an upgrade request.
        }
    }

    private func coreUpgradeState(from response: CoreUpgradeResponse) -> CoreUpgradeState {
        self.coreUpgradeStateResolver.resolve(response: response)
    }

    private func coreUpgradeState(from error: Error) -> CoreUpgradeState {
        self.coreUpgradeStateResolver.resolve(error: error)
    }

    private func coreUpgradeState(fromMessage message: String) -> CoreUpgradeState {
        self.coreUpgradeStateResolver.resolve(message: message)
    }
}
