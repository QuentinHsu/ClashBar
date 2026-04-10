import Foundation

struct ValidatedSystemProxyPorts: Equatable, Sendable {
    let httpPort: Int
    let httpsPort: Int
    let socksPort: Int
}

struct SystemProxyConfigurationValidator {
    func validateHost(_ host: String) throws -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            throw SystemProxyServiceError.invalidHost
        }
        return trimmedHost
    }

    func validateAndResolvePorts(
        _ ports: SystemProxyPorts,
        requiresEnabledPort: Bool) throws -> ValidatedSystemProxyPorts
    {
        let resolved = ValidatedSystemProxyPorts(
            httpPort: try self.normalizePort(ports.httpPort),
            httpsPort: try self.normalizePort(ports.httpsPort),
            socksPort: try self.normalizePort(ports.socksPort))

        if requiresEnabledPort,
           resolved.httpPort == 0,
           resolved.httpsPort == 0,
           resolved.socksPort == 0
        {
            throw SystemProxyServiceError.invalidPort
        }

        return resolved
    }

    func formatProxyDisplay(host: String, port: Int) -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.contains(":"), !trimmedHost.hasPrefix("[") {
            return "[\(trimmedHost)]:\(port)"
        }
        return "\(trimmedHost):\(port)"
    }

    private func normalizePort(_ value: Int?) throws -> Int {
        guard let value else { return 0 }
        guard (1...65535).contains(value) else {
            throw SystemProxyServiceError.invalidPort
        }
        return value
    }
}
