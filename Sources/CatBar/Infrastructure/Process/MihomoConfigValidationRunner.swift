import Darwin
import Foundation

private final class MihomoProcessOutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ data: Data) {
        self.lock.withLock {
            self.data = data
        }
    }

    func load() -> Data {
        self.lock.withLock {
            self.data
        }
    }
}

struct MihomoConfigValidationRunner {
    let timeout: TimeInterval
    let processWaiter: MihomoProcessWaiter
    let onLog: ((String) -> Void)?

    func validate(context: MihomoLaunchContext) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: context.binaryPath)
        process.currentDirectoryURL = context.workingDirectoryURL
        process.arguments = context.arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        let outputBox = MihomoProcessOutputBox()
        let outputDrainGroup = DispatchGroup()
        outputDrainGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            outputBox.store(outputData)
            outputDrainGroup.leave()
        }

        do {
            try process.run()
        } catch {
            throw MihomoConfigValidationError.launchFailed("Failed to run mihomo -t: \(error.localizedDescription)")
        }

        let didExit = self.processWaiter.waitForExit(process, timeout: self.timeout)
        if !didExit {
            self.onLog?("[mihomo config test] timeout after \(self.processWaiter.normalizedTimeoutSeconds(self.timeout))s")
            process.terminate()
            if !self.processWaiter.waitForExit(process, timeout: 1.0) {
                _ = Darwin.kill(process.processIdentifier, SIGKILL)
                _ = self.processWaiter.waitForExit(process, timeout: 0.5)
            }
        }

        _ = outputDrainGroup.wait(timeout: .now() + 1.0)
        let outputData = outputBox.load()
        let outputText = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard didExit else {
            throw MihomoConfigValidationError.timedOut(
                seconds: self.processWaiter.normalizedTimeoutSeconds(self.timeout),
                details: outputText)
        }

        guard process.terminationStatus == 0 else {
            throw MihomoConfigValidationError.failed(exitCode: process.terminationStatus, details: outputText)
        }

        if !outputText.isEmpty {
            self.onLog?("[mihomo config test] \(outputText)")
        }
    }
}
