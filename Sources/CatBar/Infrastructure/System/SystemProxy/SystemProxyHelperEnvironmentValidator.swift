import Foundation
import ProxyHelperShared
import Security

struct SystemProxyHelperEnvironmentValidator {
    func validateEnvironment() throws {
        guard self.isHelperBundledInMainApp() else {
            throw SystemProxyServiceError.helperNotBundled
        }
        guard self.isRunningFromApplicationsDirectory() else {
            throw SystemProxyServiceError.helperRequiresInstallToApplications
        }
        try self.validateSigningRequirements()
    }

    func isHelperBundledInMainApp() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        let fileManager = FileManager.default

        let plistURL = bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons", isDirectory: true)
            .appendingPathComponent(ProxyHelperConstants.daemonPlistName, isDirectory: false)
        let helperURL = bundleURL
            .appendingPathComponent(ProxyHelperConstants.helperBundleProgram, isDirectory: false)

        return fileManager.fileExists(atPath: plistURL.path) && fileManager.fileExists(atPath: helperURL.path)
    }

    func isRunningFromApplicationsDirectory() -> Bool {
        let bundlePath = Bundle.main.bundleURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        return bundlePath.hasPrefix("/Applications/") && bundlePath.hasSuffix(".app")
    }

    func validateSigningRequirements() throws {
        let appURL = Bundle.main.bundleURL
        let helperURL = appURL.appendingPathComponent(ProxyHelperConstants.helperBundleProgram, isDirectory: false)

        let appTeam = self.signingTeamIdentifier(at: appURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let helperTeam = self.signingTeamIdentifier(at: helperURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let appHasTeam = !appTeam.isEmpty
        let helperHasTeam = !helperTeam.isEmpty

        if !appHasTeam, !helperHasTeam {
            return
        }

        guard appHasTeam == helperHasTeam else {
            throw SystemProxyServiceError.helperInvalidSignature(
                "App/helper signing mode mismatch (one has TeamIdentifier, the other does not).")
        }

        guard appTeam == helperTeam else {
            throw SystemProxyServiceError.helperInvalidSignature(
                "App and helper TeamIdentifier mismatch (\(appTeam) != \(helperTeam)).")
        }
    }

    private func signingTeamIdentifier(at url: URL) -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode
        else { return nil }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info) == errSecSuccess,
            let dict = info as? [String: Any]
        else { return nil }

        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
