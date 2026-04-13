import Foundation

struct NetworkEndpointProbeTarget: Equatable, Sendable {
    let name: String
    let url: URL
}

final class NetworkEndpointProbeService: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 4
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        self.session = URLSession(configuration: configuration)
    }

    deinit {
        self.session.invalidateAndCancel()
    }

    func probe(_ target: NetworkEndpointProbeTarget) async -> RuntimeNetworkFeatureHealth {
        var request = URLRequest(url: target.url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return RuntimeNetworkFeatureHealth(status: .unavailable)
            }

            switch httpResponse.statusCode {
            case 200..<400:
                return RuntimeNetworkFeatureHealth(status: .healthy)
            default:
                return RuntimeNetworkFeatureHealth(status: .mismatch)
            }
        } catch {
            return RuntimeNetworkFeatureHealth(status: .mismatch)
        }
    }
}
