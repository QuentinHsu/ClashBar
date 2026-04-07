import XCTest
@testable import CatBar

final class ResolveEditableSettingsSyncPlanUseCaseTests: XCTestCase {
    private let useCase = ResolveEditableSettingsSyncPlanUseCase()

    func testExecuteReturnsPreserveLocalPlanWhenConfigRefreshMustKeepLocalState() {
        let previous = self.makeSnapshot(logLevel: ConfigLogLevel.warning.rawValue, mixedPort: "7893")
        let incoming = self.makeSnapshot(logLevel: ConfigLogLevel.info.rawValue, mixedPort: "7890")

        let plan = self.useCase.execute(
            intent: .configRefresh(preserveLocalState: true),
            previous: previous,
            incoming: incoming)

        XCTAssertEqual(plan, .preserveLocal(snapshot: incoming))
        XCTAssertEqual(plan.incomingSnapshot, incoming)
    }

    func testExecuteReturnsApplySnapshotPlanForInitialConfigRefresh() {
        let incoming = self.makeSnapshot(logLevel: ConfigLogLevel.debug.rawValue, mixedPort: "7890")

        let plan = self.useCase.execute(
            intent: .configRefresh(preserveLocalState: false),
            previous: nil,
            incoming: incoming)

        XCTAssertEqual(plan, .applySnapshot(snapshot: incoming))
        XCTAssertEqual(plan.incomingSnapshot, incoming)
    }

    func testExecuteReturnsSyncPresentedPlanForSubsequentConfigRefresh() {
        let previous = self.makeSnapshot(logLevel: ConfigLogLevel.warning.rawValue, mixedPort: "7893")
        let incoming = self.makeSnapshot(logLevel: ConfigLogLevel.info.rawValue, mixedPort: "7890")

        let plan = self.useCase.execute(
            intent: .configRefresh(preserveLocalState: false),
            previous: previous,
            incoming: incoming)

        XCTAssertEqual(plan, .syncPresented(previous: previous, incoming: incoming))
        XCTAssertEqual(plan.incomingSnapshot, incoming)
    }

    func testExecuteReturnsApplySnapshotPlanForRuntimeReconciliation() {
        let previous = self.makeSnapshot(logLevel: ConfigLogLevel.warning.rawValue, mixedPort: "7893")
        let incoming = self.makeSnapshot(logLevel: ConfigLogLevel.info.rawValue, mixedPort: "7890")

        let plan = self.useCase.execute(
            intent: .runtimeReconciliation,
            previous: previous,
            incoming: incoming)

        XCTAssertEqual(plan, .applySnapshot(snapshot: incoming))
        XCTAssertEqual(plan.incomingSnapshot, incoming)
    }

    private func makeSnapshot(logLevel: String, mixedPort: String) -> EditableSettingsSnapshot {
        EditableSettingsSnapshot(
            allowLan: true,
            ipv6: false,
            tcpConcurrent: true,
            tunEnabled: false,
            logLevel: logLevel,
            port: "",
            socksPort: "",
            mixedPort: mixedPort,
            redirPort: "",
            tproxyPort: "")
    }
}
