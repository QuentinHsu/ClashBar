import Foundation

struct ShouldRestartStreamUseCase {
    struct Input {
        let enabled: Bool
        let forceRestart: Bool
        let taskExists: Bool
        let lastPayloadAt: Date?
        let now: Date
        let staleAfter: TimeInterval?
    }

    func execute(_ input: Input) -> Bool {
        guard input.enabled else { return false }

        if input.forceRestart || !input.taskExists {
            return true
        }

        guard
            let staleAfter = input.staleAfter,
            staleAfter > 0,
            let lastPayloadAt = input.lastPayloadAt
        else {
            return false
        }

        return input.now.timeIntervalSince(lastPayloadAt) >= staleAfter
    }
}
