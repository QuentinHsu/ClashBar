import Foundation

enum DeferredEditableSettingsOverlayLoopAction: Equatable {
    case stop
    case finish
    case evaluateRequest(DeferredEditableSettingsOverlayRequest)
}

struct ResolveDeferredEditableSettingsOverlayLoopActionUseCase {
    func execute(
        request: DeferredEditableSettingsOverlayRequest?,
        isRuntimeRunning: Bool,
        isTaskCancelled: Bool) -> DeferredEditableSettingsOverlayLoopAction
    {
        guard !isTaskCancelled, isRuntimeRunning else {
            return .stop
        }

        guard let request else {
            return .finish
        }

        return .evaluateRequest(request)
    }
}
