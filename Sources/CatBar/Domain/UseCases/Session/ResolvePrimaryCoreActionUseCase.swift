import Foundation

enum PrimaryCoreActionDecision: Equatable {
    case skip
    case startManual
    case restart
}

struct ResolvePrimaryCoreActionUseCase {
    func execute(
        isCoreActionProcessing: Bool,
        isRuntimeRunning: Bool) -> PrimaryCoreActionDecision
    {
        guard !isCoreActionProcessing else { return .skip }
        return isRuntimeRunning ? .restart : .startManual
    }
}
