import Foundation

struct RemoteConfigRefreshTarget: Equatable {
    let fileName: String
    let remoteURL: URL
    let targetURL: URL
}

enum ResolveRemoteConfigRefreshTargetError: Error, Equatable {
    case invalidURL(source: String)
}

struct ResolveRemoteConfigRefreshTargetUseCase {
    func execute(
        fileName: String,
        remoteConfigSources: [String: String],
        configDirectory: URL,
        isSupportedRemoteConfigURL: (URL) -> Bool) -> Result<RemoteConfigRefreshTarget, ResolveRemoteConfigRefreshTargetError>
    {
        let source = remoteConfigSources[fileName] ?? fileName
        guard let urlString = remoteConfigSources[fileName],
              let remoteURL = URL(string: urlString),
              isSupportedRemoteConfigURL(remoteURL)
        else {
            return .failure(.invalidURL(source: source))
        }

        return .success(
            RemoteConfigRefreshTarget(
                fileName: fileName,
                remoteURL: remoteURL,
                targetURL: configDirectory.appendingPathComponent(fileName, isDirectory: false)))
    }
}
