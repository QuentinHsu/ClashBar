import Foundation

struct SystemProxyProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        [self.stderr, self.stdout]
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown command error."
    }
}

struct SystemProxyCommandRunner {
    func runSynchronously(executable: String, arguments: [String]) throws -> SystemProxyProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw SystemProxyServiceError.helperOperationFailed(error.localizedDescription)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return SystemProxyProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    func isProcessRunning(matching pattern: String) throws -> Bool {
        let result = try self.runSynchronously(
            executable: "/usr/bin/pgrep",
            arguments: ["-f", pattern])
        switch result.exitCode {
        case 0:
            return true
        case 1:
            return false
        default:
            throw SystemProxyServiceError.helperOperationFailed(result.combinedOutput)
        }
    }
}
