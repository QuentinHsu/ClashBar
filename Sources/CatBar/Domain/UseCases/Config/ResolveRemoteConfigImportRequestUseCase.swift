import Foundation

struct RemoteConfigImportRequest: Equatable {
    let remoteURL: URL
    let fileName: String
}

enum ResolveRemoteConfigImportRequestError: Error, Equatable {
    case invalidURL(input: String)
    case invalidFileName(input: String)
}

struct ResolveRemoteConfigImportRequestUseCase {
    func execute(
        urlString: String,
        fileNameInput: String,
        isSupportedRemoteConfigURL: (URL) -> Bool,
        inferredRemoteConfigFileName: (URL) -> String,
        normalizedConfigFileName: (String, String?) -> String?) -> Result<RemoteConfigImportRequest, ResolveRemoteConfigImportRequestError>
    {
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let remoteURL = URL(string: trimmedURLString),
              isSupportedRemoteConfigURL(remoteURL)
        else {
            return .failure(.invalidURL(input: trimmedURLString))
        }

        let fallbackFileName = inferredRemoteConfigFileName(remoteURL)
        guard let fileName = normalizedConfigFileName(fileNameInput, fallbackFileName) else {
            return .failure(.invalidFileName(input: fileNameInput))
        }

        return .success(RemoteConfigImportRequest(remoteURL: remoteURL, fileName: fileName))
    }
}
