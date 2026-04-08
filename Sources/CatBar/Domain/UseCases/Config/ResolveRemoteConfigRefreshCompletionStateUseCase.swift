import Foundation

enum RemoteConfigRefreshCompletion {
    case succeeded(updatedAt: Date?, fallbackUpdatedAt: Date)
    case failed
}

struct ResolveRemoteConfigRefreshCompletionStateUseCase {
    func execute(
        current: RemoteConfigMenuState,
        completion: RemoteConfigRefreshCompletion) -> RemoteConfigMenuState
    {
        switch completion {
        case let .succeeded(updatedAt, fallbackUpdatedAt):
            return RemoteConfigMenuState(
                updatedAt: updatedAt ?? fallbackUpdatedAt,
                phase: .idle)
        case .failed:
            return RemoteConfigMenuState(
                updatedAt: current.updatedAt,
                phase: .failed)
        }
    }
}
