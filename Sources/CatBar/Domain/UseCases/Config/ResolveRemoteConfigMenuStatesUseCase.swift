import Foundation

struct ResolveRemoteConfigMenuStatesUseCase {
    private let resolver = RemoteConfigMenuStateResolver()

    func execute(
        remoteConfigSources: [String: String],
        currentStates: [String: RemoteConfigMenuState],
        updatedAtProvider: (String) -> Date?) -> [String: RemoteConfigMenuState]
    {
        let remoteFileNames = Set(remoteConfigSources.keys)
        guard !remoteFileNames.isEmpty else { return [:] }

        var nextStates: [String: RemoteConfigMenuState] = [:]
        nextStates.reserveCapacity(remoteFileNames.count)

        for fileName in remoteFileNames {
            let current = currentStates[fileName] ?? .idle
            nextStates[fileName] = self.resolver.resolve(
                current: current,
                updatedAt: updatedAtProvider(fileName))
        }

        return nextStates
    }
}
