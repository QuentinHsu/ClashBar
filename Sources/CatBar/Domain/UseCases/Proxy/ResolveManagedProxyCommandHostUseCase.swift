import Foundation

struct ResolveManagedProxyCommandHostUseCase {
    func execute(
        isRemoteTarget: Bool,
        controllerHost: String,
        localExternalControllerHost: String?,
        allowLan: Bool,
        currentDeviceIPv4: String?) -> String
    {
        guard !isRemoteTarget else {
            return controllerHost
        }

        let configuredHost = localExternalControllerHost?.trimmedNonEmpty ?? controllerHost
        guard allowLan else {
            return configuredHost
        }
        guard self.shouldUseCurrentDeviceIPv4(for: configuredHost) else {
            return configuredHost
        }

        return currentDeviceIPv4?.trimmedNonEmpty ?? controllerHost
    }

    private func shouldUseCurrentDeviceIPv4(for host: String) -> Bool {
        switch host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "localhost", "127.0.0.1", "::1", "0.0.0.0", "::", "0:0:0:0:0:0:0:0":
            true
        default:
            false
        }
    }
}
