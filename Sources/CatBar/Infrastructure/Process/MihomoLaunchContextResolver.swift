import Foundation

struct MihomoLaunchContext: Equatable {
    let binaryPath: String
    let workingDirectoryURL: URL
    let arguments: [String]
}

struct MihomoLaunchContextResolver {
    func validationContext(binaryPath: String, configPath: String) -> MihomoLaunchContext {
        let workingDirectoryURL = self.workingDirectoryURL(for: configPath)
        return MihomoLaunchContext(
            binaryPath: binaryPath,
            workingDirectoryURL: workingDirectoryURL,
            arguments: ["-d", workingDirectoryURL.path, "-f", configPath, "-t"])
    }

    func runtimeContext(binaryPath: String, configPath: String, controller: String) -> MihomoLaunchContext {
        let workingDirectoryURL = self.workingDirectoryURL(for: configPath)
        return MihomoLaunchContext(
            binaryPath: binaryPath,
            workingDirectoryURL: workingDirectoryURL,
            arguments: ["-d", workingDirectoryURL.path, "-f", configPath, "-ext-ctl", controller])
    }

    private func workingDirectoryURL(for configPath: String) -> URL {
        let configFileURL = URL(fileURLWithPath: configPath).standardizedFileURL.resolvingSymlinksInPath()
        let configDirectoryURL = configFileURL.deletingLastPathComponent()
        if configDirectoryURL.lastPathComponent == "config" {
            return configDirectoryURL.deletingLastPathComponent()
        }
        return configDirectoryURL
    }
}
