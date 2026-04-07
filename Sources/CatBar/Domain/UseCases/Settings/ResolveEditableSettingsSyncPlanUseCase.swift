import Foundation

enum EditableSettingsSyncIntent {
    case configRefresh(preserveLocalState: Bool)
    case runtimeReconciliation
}

enum EditableSettingsSyncPlan: Equatable {
    case preserveLocal(snapshot: EditableSettingsSnapshot)
    case applySnapshot(snapshot: EditableSettingsSnapshot)
    case syncPresented(previous: EditableSettingsSnapshot, incoming: EditableSettingsSnapshot)

    var incomingSnapshot: EditableSettingsSnapshot {
        switch self {
        case let .preserveLocal(snapshot),
             let .applySnapshot(snapshot):
            snapshot
        case let .syncPresented(_, incoming):
            incoming
        }
    }
}

struct ResolveEditableSettingsSyncPlanUseCase {
    func execute(
        intent: EditableSettingsSyncIntent,
        previous: EditableSettingsSnapshot?,
        incoming: EditableSettingsSnapshot) -> EditableSettingsSyncPlan
    {
        switch intent {
        case let .configRefresh(preserveLocalState):
            if preserveLocalState {
                return .preserveLocal(snapshot: incoming)
            }
            guard let previous else {
                return .applySnapshot(snapshot: incoming)
            }
            return .syncPresented(previous: previous, incoming: incoming)
        case .runtimeReconciliation:
            return .applySnapshot(snapshot: incoming)
        }
    }
}
