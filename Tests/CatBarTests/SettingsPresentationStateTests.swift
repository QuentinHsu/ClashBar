import XCTest
@testable import CatBar

final class SettingsPresentationStateTests: XCTestCase {
    func testCurrentEditableSettingsSnapshotReflectsStoredFields() {
        var state = SettingsPresentationState()
        state.allowLan = true
        state.ipv6 = true
        state.tcpConcurrent = true
        state.tunEnabled = true
        state.logLevel = ConfigLogLevel.debug.rawValue
        state.port = "7891"
        state.socksPort = "7892"
        state.mixedPort = "7893"
        state.redirPort = "7894"
        state.tproxyPort = "7895"

        XCTAssertEqual(
            state.currentEditableSettingsSnapshot(),
            EditableSettingsSnapshot(
                allowLan: true,
                ipv6: true,
                tcpConcurrent: true,
                tunEnabled: true,
                logLevel: ConfigLogLevel.debug.rawValue,
                port: "7891",
                socksPort: "7892",
                mixedPort: "7893",
                redirPort: "7894",
                tproxyPort: "7895"))
    }

    func testApplyEditableSettingsSnapshotOverwritesEditableFields() {
        var state = SettingsPresentationState()
        state.errorMessage = "keep"
        state.savedMessage = "keep"

        state.applyEditableSettingsSnapshot(
            EditableSettingsSnapshot(
                allowLan: true,
                ipv6: false,
                tcpConcurrent: true,
                tunEnabled: true,
                logLevel: ConfigLogLevel.warning.rawValue,
                port: "9000",
                socksPort: "9001",
                mixedPort: "9002",
                redirPort: "9003",
                tproxyPort: "9004"))

        XCTAssertTrue(state.allowLan)
        XCTAssertFalse(state.ipv6)
        XCTAssertTrue(state.tcpConcurrent)
        XCTAssertTrue(state.tunEnabled)
        XCTAssertEqual(state.logLevel, ConfigLogLevel.warning.rawValue)
        XCTAssertEqual(state.port, "9000")
        XCTAssertEqual(state.socksPort, "9001")
        XCTAssertEqual(state.mixedPort, "9002")
        XCTAssertEqual(state.redirPort, "9003")
        XCTAssertEqual(state.tproxyPort, "9004")
        XCTAssertEqual(state.errorMessage, "keep")
        XCTAssertEqual(state.savedMessage, "keep")
    }

    func testSyncEditableFieldsOnlyUpdatesValuesStillMatchingPreviousSnapshot() {
        var state = SettingsPresentationState()
        state.allowLan = false
        state.ipv6 = true
        state.tcpConcurrent = false
        state.tunEnabled = true
        state.logLevel = ConfigLogLevel.info.rawValue
        state.port = "7890"
        state.socksPort = "9999"
        state.mixedPort = "7890"
        state.redirPort = "0"
        state.tproxyPort = "0"

        let previous = EditableSettingsSnapshot(
            allowLan: false,
            ipv6: false,
            tcpConcurrent: false,
            tunEnabled: true,
            logLevel: ConfigLogLevel.info.rawValue,
            port: "7890",
            socksPort: "7891",
            mixedPort: "7890",
            redirPort: "0",
            tproxyPort: "0")
        let incoming = EditableSettingsSnapshot(
            allowLan: true,
            ipv6: true,
            tcpConcurrent: true,
            tunEnabled: false,
            logLevel: ConfigLogLevel.debug.rawValue,
            port: "9000",
            socksPort: "9001",
            mixedPort: "9002",
            redirPort: "9003",
            tproxyPort: "9004")

        state.syncEditableFields(from: previous, to: incoming)

        XCTAssertTrue(state.allowLan)
        XCTAssertTrue(state.ipv6)
        XCTAssertTrue(state.tcpConcurrent)
        XCTAssertFalse(state.tunEnabled)
        XCTAssertEqual(state.logLevel, ConfigLogLevel.debug.rawValue)
        XCTAssertEqual(state.port, "9000")
        XCTAssertEqual(state.socksPort, "9999")
        XCTAssertEqual(state.mixedPort, "9002")
        XCTAssertEqual(state.redirPort, "9003")
        XCTAssertEqual(state.tproxyPort, "9004")
    }
}
