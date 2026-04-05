import Foundation

struct RemoteConfigMenuStateResolver {
    func resolve(current: RemoteConfigMenuState, updatedAt: Date?) -> RemoteConfigMenuState {
        let phase: RemoteConfigRefreshPhase = switch current.phase {
        case .refreshing:
            .refreshing
        case .failed:
            current.updatedAt == updatedAt ? .failed : .idle
        case .idle:
            .idle
        }

        return RemoteConfigMenuState(updatedAt: updatedAt, phase: phase)
    }
}
