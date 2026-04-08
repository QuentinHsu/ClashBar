import Foundation

enum EditableSettingsSyncUIAction: Equatable {
    case none
    case applySnapshot(EditableSettingsSnapshot)
    case syncPresented(previous: EditableSettingsSnapshot, incoming: EditableSettingsSnapshot)
}

struct EditableSettingsSyncExecution: Equatable {
    let shouldResetPreserveLocalState: Bool
    let uiAction: EditableSettingsSyncUIAction
    let syncedSnapshot: EditableSettingsSnapshot
}

struct ResolveEditableSettingsSyncExecutionUseCase {
    func execute(plan: EditableSettingsSyncPlan) -> EditableSettingsSyncExecution {
        switch plan {
        case let .preserveLocal(snapshot):
            EditableSettingsSyncExecution(
                shouldResetPreserveLocalState: true,
                uiAction: .none,
                syncedSnapshot: snapshot)

        case let .applySnapshot(snapshot):
            EditableSettingsSyncExecution(
                shouldResetPreserveLocalState: false,
                uiAction: .applySnapshot(snapshot),
                syncedSnapshot: snapshot)

        case let .syncPresented(previous, incoming):
            EditableSettingsSyncExecution(
                shouldResetPreserveLocalState: false,
                uiAction: .syncPresented(previous: previous, incoming: incoming),
                syncedSnapshot: incoming)
        }
    }
}
