import Foundation

struct ProxyCommandPorts: Equatable {
    let httpPort: Int
    let socksPort: Int
}

struct ResolveProxyCommandPortsUseCase {
    func execute(systemProxyPorts: SystemProxyPorts, effectiveMixedPort: Int) -> ProxyCommandPorts {
        let httpPort = systemProxyPorts.httpPort ?? systemProxyPorts.socksPort ?? effectiveMixedPort
        let socksPort = systemProxyPorts.socksPort ?? systemProxyPorts.httpPort ?? httpPort
        return ProxyCommandPorts(httpPort: httpPort, socksPort: socksPort)
    }
}
