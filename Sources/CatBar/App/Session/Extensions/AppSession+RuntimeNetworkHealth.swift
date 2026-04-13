import Foundation

@MainActor
extension AppSession {
    func refreshRuntimeNetworkHealth(autoRepair: Bool = true) async {
        guard !self.isRemoteTarget else {
            self.resetPresentedRuntimeNetworkHealth()
            return
        }

        let systemProxy = await self.evaluateSystemProxyRuntimeHealth(autoRepair: autoRepair)
        let tun = await self.evaluateTunRuntimeHealth(autoRepair: autoRepair)
        let endpointHealth = await self.evaluateNetworkEndpointHealthPair()
        let nextState = RuntimeNetworkHealthPresentationState(
            systemProxy: systemProxy,
            tun: tun,
            domesticAccess: endpointHealth.domestic,
            globalAccess: endpointHealth.global)

        _ = self.applyPresentedRuntimeNetworkHealth(nextState)
    }

    private func evaluateSystemProxyRuntimeHealth(autoRepair: Bool) async -> RuntimeNetworkFeatureHealth {
        guard self.isSystemProxyEnabled else {
            return RuntimeNetworkFeatureHealth(status: .disabled)
        }

        guard self.isRuntimeRunning else {
            return RuntimeNetworkFeatureHealth(status: .unavailable)
        }

        do {
            let target = try self.resolveSystemProxyTargetFromState()
            let isConfigured = try await self.isSystemProxyConfigured(host: target.host, ports: target.ports)
            let expectedDisplay = self.buildSystemProxyDisplayString(host: target.host, ports: target.ports)

            if isConfigured {
                return RuntimeNetworkFeatureHealth(
                    status: .healthy,
                    detail: expectedDisplay,
                    observedValue: expectedDisplay)
            }

            let observedDisplay = try await self.readSystemProxyActiveDisplay()
            guard
                autoRepair,
                !self.isProxySyncing,
                self.shouldAttemptRuntimeRepair(lastAttemptAt: self.lastSystemProxyRuntimeRepairAttemptAt)
            else {
                return RuntimeNetworkFeatureHealth(
                    status: .mismatch,
                    observedValue: observedDisplay)
            }

            do {
                self.lastSystemProxyRuntimeRepairAttemptAt = Date()
                try await self.applySystemProxy(enabled: true, host: target.host, ports: target.ports)
                self.systemProxyActiveDisplay = expectedDisplay
                self.clearSystemProxyOpenFailureHint()
                self.systemProxyHelperFailureReason = nil
                self.systemProxyHelperFailureMessage = nil
                self.appendLog(
                    level: "info",
                    message: self.tr("log.system_proxy.runtime_repaired", expectedDisplay ?? target.host))
                return RuntimeNetworkFeatureHealth(
                    status: .healthy,
                    detail: expectedDisplay,
                    observedValue: expectedDisplay)
            } catch {
                self.updateSystemProxyOpenFailureHint(for: error)
                await self.refreshSystemProxyHelperStatus()
                self.appendLog(
                    level: "error",
                    message: self.tr("log.system_proxy.runtime_repair_failed", self.systemProxyErrorMessage(error)))
                return RuntimeNetworkFeatureHealth(
                    status: .mismatch,
                    detail: self.systemProxyErrorMessage(error),
                    observedValue: observedDisplay)
            }
        } catch {
            return RuntimeNetworkFeatureHealth(
                status: .unavailable,
                detail: self.systemProxyErrorMessage(error))
        }
    }

    private func evaluateTunRuntimeHealth(autoRepair: Bool) async -> RuntimeNetworkFeatureHealth {
        guard self.isTunEnabled else {
            return RuntimeNetworkFeatureHealth(status: .disabled)
        }

        guard self.isRuntimeRunning else {
            return RuntimeNetworkFeatureHealth(status: .unavailable)
        }

        do {
            let config = try await self.fetchRuntimeConfigSnapshot()
            if config.tunEnabled == true {
                return RuntimeNetworkFeatureHealth(status: .healthy)
            }

            guard
                autoRepair,
                !self.isTunSyncing,
                self.shouldAttemptRuntimeRepair(lastAttemptAt: self.lastTunRuntimeRepairAttemptAt)
            else {
                return RuntimeNetworkFeatureHealth(
                    status: .mismatch)
            }

            do {
                self.lastTunRuntimeRepairAttemptAt = Date()
                try await self.patchTunConfig(enable: true)
                try await self.verifyTunRuntimeState(expectedEnabled: true)
                self.appendLog(
                    level: "info",
                    message: self.tr("log.tun.runtime_repaired"))
                return RuntimeNetworkFeatureHealth(status: .healthy)
            } catch {
                self.appendLog(
                    level: "error",
                    message: self.tr("log.tun.runtime_repair_failed", self.tunErrorMessage(error)))
                return RuntimeNetworkFeatureHealth(
                    status: .mismatch,
                    detail: self.tunErrorMessage(error))
            }
        } catch {
            return RuntimeNetworkFeatureHealth(
                status: .unavailable,
                detail: self.tunErrorMessage(error))
        }
    }

    private func shouldAttemptRuntimeRepair(lastAttemptAt: Date?) -> Bool {
        guard let lastAttemptAt else { return true }
        return Date().timeIntervalSince(lastAttemptAt) >= self.runtimeNetworkRepairThrottleInterval
    }

    private func evaluateNetworkEndpointHealthPair() async
        -> (domestic: RuntimeNetworkFeatureHealth, global: RuntimeNetworkFeatureHealth)
    {
        guard self.isRuntimeRunning, self.networkReachabilityStatus != .offline else {
            let unavailable = RuntimeNetworkFeatureHealth(status: .unavailable)
            return (unavailable, unavailable)
        }

        if let lastProbeAt = self.lastNetworkEndpointProbePairAt,
           Date().timeIntervalSince(lastProbeAt) < self.runtimeNetworkEndpointProbeInterval
        {
            return (self.runtimeNetworkHealth.domesticAccess, self.runtimeNetworkHealth.globalAccess)
        }

        let domesticTarget = NetworkEndpointProbeTarget(name: "domestic", url: URL(string: "https://qq.com")!)
        let globalTarget = NetworkEndpointProbeTarget(name: "global", url: URL(string: "https://google.com")!)
        async let domestic = self.networkEndpointProbeService.probe(domesticTarget)
        async let global = self.networkEndpointProbeService.probe(globalTarget)
        let results = await (domestic, global)
        self.lastNetworkEndpointProbePairAt = Date()
        return results
    }
}
