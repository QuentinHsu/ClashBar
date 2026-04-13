import XCTest
@testable import CatBar

@MainActor
final class SystemTabViewModelTests: XCTestCase {
    private final class StubProcessManager: MihomoControlling, @unchecked Sendable {
        var status: CoreLifecycleStatus = .stopped
        var isRunning: Bool { false }
        var detectedBinaryPath: String? { nil }

        func validateConfig(configPath: String) throws {}
        func validateConfigAsync(configPath: String) async throws {}
        func start(configPath: String, controller: String) throws -> CoreLifecycleStatus { .stopped }
        func startAsync(configPath: String, controller: String) async throws -> CoreLifecycleStatus { .stopped }
        func stop() {}
        func stopAsync() async {}
        func restart(configPath: String, controller: String) throws -> CoreLifecycleStatus { .stopped }
        func restartAsync(configPath: String, controller: String) async throws -> CoreLifecycleStatus { .stopped }
    }

    func testNetworkHealthSummaryReportsHealthyPathWhenCoreAndProtectionAreHealthy() {
        let session = self.makeSession()
        session.statusText = "Running"
        session.apiStatus = .healthy
        session.runtimeNetworkHealth = RuntimeNetworkHealthPresentationState(
            systemProxy: RuntimeNetworkFeatureHealth(status: .healthy, detail: "127.0.0.1:7890"),
            tun: RuntimeNetworkFeatureHealth(status: .disabled),
            domesticAccess: RuntimeNetworkFeatureHealth(status: .healthy),
            globalAccess: RuntimeNetworkFeatureHealth(status: .healthy))

        let summary = SystemTabViewModel.networkHealthSummary(session: session)

        XCTAssertEqual(summary.kind, .success)
        XCTAssertEqual(summary.symbol, "checkmark.shield.fill")
    }

    func testNetworkHealthSummaryReportsDegradedWhenFeatureHealthDrifts() {
        let session = self.makeSession()
        session.statusText = "Running"
        session.apiStatus = .healthy
        session.runtimeNetworkHealth = RuntimeNetworkHealthPresentationState(
            systemProxy: RuntimeNetworkFeatureHealth(status: .mismatch, detail: "mismatch"),
            tun: RuntimeNetworkFeatureHealth(status: .healthy, detail: "enabled"),
            domesticAccess: RuntimeNetworkFeatureHealth(status: .healthy),
            globalAccess: RuntimeNetworkFeatureHealth(status: .healthy))

        let summary = SystemTabViewModel.networkHealthSummary(session: session)

        XCTAssertEqual(summary.kind, .warning)
        XCTAssertEqual(summary.symbol, "exclamationmark.triangle.fill")
    }

    func testNetworkHealthRowsExposeDisabledStateForTun() throws {
        let session = self.makeSession()
        session.statusText = "Running"
        session.apiStatus = .healthy
        session.runtimeNetworkHealth = RuntimeNetworkHealthPresentationState(
            systemProxy: RuntimeNetworkFeatureHealth(status: .healthy, detail: "127.0.0.1:7890"),
            tun: RuntimeNetworkFeatureHealth(status: .disabled),
            domesticAccess: RuntimeNetworkFeatureHealth(status: .healthy),
            globalAccess: RuntimeNetworkFeatureHealth(status: .mismatch))

        let rows = SystemTabViewModel.networkHealthRows(session: session)
        let tunRow = try XCTUnwrap(rows.first { $0.id == "tun" })

        XCTAssertEqual(tunRow.kind, .info)
        XCTAssertEqual(tunRow.statusText, session.tr("ui.network_health.status.disabled"))
        XCTAssertNil(tunRow.detail)
    }

    func testNetworkHealthRowsIncludeDomesticAndGlobalAccess() throws {
        let session = self.makeSession()
        session.statusText = "Running"
        session.apiStatus = .healthy
        session.runtimeNetworkHealth = RuntimeNetworkHealthPresentationState(
            systemProxy: RuntimeNetworkFeatureHealth(status: .healthy),
            tun: RuntimeNetworkFeatureHealth(status: .healthy),
            domesticAccess: RuntimeNetworkFeatureHealth(status: .healthy),
            globalAccess: RuntimeNetworkFeatureHealth(status: .mismatch))

        let rows = SystemTabViewModel.networkHealthRows(session: session)
        let domesticRow = try XCTUnwrap(rows.first { $0.id == "domestic_access" })
        let globalRow = try XCTUnwrap(rows.first { $0.id == "global_access" })

        XCTAssertEqual(domesticRow.title, session.tr("ui.network_health.row.domestic_access"))
        XCTAssertEqual(domesticRow.detail, "qq.com")
        XCTAssertEqual(domesticRow.statusText, session.tr("ui.network_health.status.healthy"))
        XCTAssertEqual(globalRow.title, session.tr("ui.network_health.row.global_access"))
        XCTAssertEqual(globalRow.detail, "google.com")
        XCTAssertEqual(globalRow.statusText, session.tr("ui.network_health.status.degraded"))
    }

    private func makeSession() -> AppSession {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppSession(
            processManager: StubProcessManager(),
            workingDirectoryManager: WorkingDirectoryManager(homeDirectory: root),
            startBackgroundRefresh: false)
    }
}
