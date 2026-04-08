import XCTest
@testable import CatBar

final class ResolveEditableSettingsSyncExecutionUseCaseTests: XCTestCase {
    private let useCase = ResolveEditableSettingsSyncExecutionUseCase()

    func testExecutePreserveLocalPlanResetsPreserveFlagWithoutUIUpdate() {
        let snapshot = self.makeSnapshot(logLevel: ConfigLogLevel.warning.rawValue, mixedPort: "7893")

        let execution = self.useCase.execute(plan: .preserveLocal(snapshot: snapshot))

        XCTAssertTrue(execution.shouldResetPreserveLocalState)
        XCTAssertEqual(execution.uiAction, .none)
        XCTAssertEqual(execution.syncedSnapshot, snapshot)
    }

    func testExecuteApplySnapshotPlanRequestsSnapshotApplication() {
        let snapshot = self.makeSnapshot(logLevel: ConfigLogLevel.info.rawValue, mixedPort: "7890")

        let execution = self.useCase.execute(plan: .applySnapshot(snapshot: snapshot))

        XCTAssertFalse(execution.shouldResetPreserveLocalState)
        XCTAssertEqual(execution.uiAction, .applySnapshot(snapshot))
        XCTAssertEqual(execution.syncedSnapshot, snapshot)
    }

    func testExecuteSyncPresentedPlanRequestsSelectiveFieldSync() {
        let previous = self.makeSnapshot(logLevel: ConfigLogLevel.warning.rawValue, mixedPort: "7893")
        let incoming = self.makeSnapshot(logLevel: ConfigLogLevel.debug.rawValue, mixedPort: "7890")

        let execution = self.useCase.execute(plan: .syncPresented(previous: previous, incoming: incoming))

        XCTAssertFalse(execution.shouldResetPreserveLocalState)
        XCTAssertEqual(execution.uiAction, .syncPresented(previous: previous, incoming: incoming))
        XCTAssertEqual(execution.syncedSnapshot, incoming)
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
