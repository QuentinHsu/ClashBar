import Darwin
import Foundation

enum MihomoBinaryResolutionError: LocalizedError {
    case binaryNotFound(expectedDirectory: String)

    var errorDescription: String? {
        switch self {
        case let .binaryNotFound(expectedDirectory):
            "mihomo binary not found. Expected an executable named 'mihomo' in \(expectedDirectory)."
        }
    }
}

enum MihomoConfigValidationError: LocalizedError {
    case launchFailed(String)
    case timedOut(seconds: Int, details: String)
    case failed(exitCode: Int32, details: String)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(message):
            return message
        case let .timedOut(seconds, details):
            let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedDetails.isEmpty {
                return "mihomo -t timed out after \(seconds) seconds."
            }
            return "mihomo -t timed out after \(seconds) seconds.\n\(normalizedDetails)"
        case let .failed(exitCode, details):
            let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedDetails.isEmpty {
                return "mihomo -t exited with code \(exitCode)."
            }
            return normalizedDetails
        }
    }
}

/// Process callbacks run on system-managed threads. Shared mutable state is guarded by `lock`.
final class MihomoProcessManager: MihomoControlling, @unchecked Sendable {
    private(set) var status: CoreLifecycleStatus = .stopped
    private var process: Process?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var intentionalStop = false
    private let lock = NSLock()
    private let stateActor = ProcessStateActor()
    private let fileManager: FileManager
    private let workingDirectoryManager: WorkingDirectoryManager
    private let lifecycleQueue: DispatchQueue
    private let validationQueue: DispatchQueue
    private let configValidationTimeout: TimeInterval
    private let launchContextResolver: MihomoLaunchContextResolver
    private let processWaiter: MihomoProcessWaiter

    var onLog: ((String) -> Void)?
    var onTermination: ((Int32) -> Void)?

    var detectedBinaryPath: String? {
        try? self.resolveMihomoBinary()
    }

    var isRunning: Bool {
        self.lock.withLock {
            self.process?.isRunning == true
        }
    }

    init(
        workingDirectoryManager: WorkingDirectoryManager = WorkingDirectoryManager(),
        fileManager: FileManager = .default,
        configValidationTimeout: TimeInterval = 10,
        launchContextResolver: MihomoLaunchContextResolver = MihomoLaunchContextResolver(),
        processWaiter: MihomoProcessWaiter = MihomoProcessWaiter(),
        lifecycleQueue: DispatchQueue? = nil,
        validationQueue: DispatchQueue? = nil)
    {
        self.workingDirectoryManager = workingDirectoryManager
        self.fileManager = fileManager
        self.configValidationTimeout = configValidationTimeout
        self.launchContextResolver = launchContextResolver
        self.processWaiter = processWaiter
        self.lifecycleQueue = lifecycleQueue
            ?? DispatchQueue(label: "com.catbar.mihomo-process.operations", qos: .userInitiated)
        self.validationQueue = validationQueue
            ?? DispatchQueue(label: "com.catbar.mihomo-process.validation", qos: .userInitiated)
    }

    deinit {
        stop()
    }

    func validateConfig(configPath: String) throws {
        let binary = try self.resolveMihomoBinary()
        let context = self.launchContextResolver.validationContext(binaryPath: binary, configPath: configPath)
        try self.configValidationRunner.validate(context: context)
    }

    func validateConfigAsync(configPath: String) async throws {
        try await self.runBlockingOperation(on: self.validationQueue) {
            try self.validateConfig(configPath: configPath)
        }
    }

    @discardableResult
    func start(configPath: String, controller: String) throws -> CoreLifecycleStatus {
        if let runningPid = lock.withLock({ process?.isRunning == true ? process?.processIdentifier : nil }) {
            return .running(pid: runningPid)
        }

        self.lock.withLock {
            self.intentionalStop = false
            self.status = .starting
        }
        Task {
            await self.stateActor.setIntentionalStop(false)
            await self.stateActor.setStatus(.starting)
        }

        let binary = try self.resolveMihomoBinary()
        let context = self.launchContextResolver.runtimeContext(
            binaryPath: binary,
            configPath: configPath,
            controller: controller)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: context.binaryPath)
        proc.currentDirectoryURL = context.workingDirectoryURL
        proc.arguments = context.arguments

        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr
        self.stdoutHandle = stdout.fileHandleForReading
        self.stderrHandle = stderr.fileHandleForReading

        self.wireLogPipe(stdout.fileHandleForReading)
        self.wireLogPipe(stderr.fileHandleForReading)

        proc.terminationHandler = { [weak self] terminatedProcess in
            guard let self else { return }
            let code = terminatedProcess.terminationStatus
            self.handleProcessTermination(terminatedProcess, code: code)
        }

        do {
            try proc.run()
            self.lock.withLock {
                self.process = proc
                self.status = .running(pid: proc.processIdentifier)
            }
            Task {
                await self.stateActor.setStatus(.running(pid: proc.processIdentifier))
            }
            let startMessage =
                "[mihomo started] pid=\(proc.processIdentifier) " +
                "controller=\(controller) " +
                "binary=\(context.binaryPath) " +
                "workdir=\(context.workingDirectoryURL.path)"
            self.onLog?(startMessage)
            return self.status
        } catch {
            let reason = "Failed to launch mihomo: \(error.localizedDescription)"
            self.lock.withLock {
                self.status = .failed(reason: reason)
                self.intentionalStop = false
                self.releasePipeHandlesLocked()
            }
            Task {
                await self.stateActor.setIntentionalStop(false)
                await self.stateActor.setStatus(.failed(reason: reason))
            }
            self.onLog?("[mihomo error] \(reason)")
            throw error
        }
    }

    @discardableResult
    func startAsync(configPath: String, controller: String) async throws -> CoreLifecycleStatus {
        try await self.runBlockingOperation(on: self.lifecycleQueue) {
            try self.start(configPath: configPath, controller: controller)
        }
    }

    func stop() {
        let running: Process? = self.lock.withLock {
            self.intentionalStop = true
            return self.process
        }
        Task {
            await self.stateActor.setIntentionalStop(true)
        }

        guard let running else {
            self.lock.withLock {
                self.status = .stopped
                self.intentionalStop = false
                self.releasePipeHandlesLocked()
            }
            Task {
                await self.stateActor.setIntentionalStop(false)
                await self.stateActor.setStatus(.stopped)
            }
            return
        }

        guard running.isRunning else {
            self.handleProcessTermination(running, code: running.terminationStatus)
            return
        }

        self.onLog?("[mihomo stop] terminate signal sent pid=\(running.processIdentifier)")
        running.terminate()

        if self.processWaiter.waitForExit(running, timeout: 2.0) {
            self.handleProcessTermination(running, code: running.terminationStatus)
            return
        }

        self.onLog?("[mihomo stop] force kill pid=\(running.processIdentifier)")
        _ = Darwin.kill(running.processIdentifier, SIGKILL)
        _ = self.processWaiter.waitForExit(running, timeout: 1.0)
        self.handleProcessTermination(running, code: running.terminationStatus)
    }

    func stopAsync() async {
        await self.runBlockingOperation(on: self.lifecycleQueue) {
            self.stop()
        }
    }

    @discardableResult
    func restart(configPath: String, controller: String) throws -> CoreLifecycleStatus {
        self.stop()
        return try self.start(configPath: configPath, controller: controller)
    }

    @discardableResult
    func restartAsync(configPath: String, controller: String) async throws -> CoreLifecycleStatus {
        try await self.runBlockingOperation(on: self.lifecycleQueue) {
            try self.restart(configPath: configPath, controller: controller)
        }
    }

    private func handleProcessTermination(_ terminatedProcess: Process, code: Int32) {
        let outcome = self.lock.withLock { () -> (handled: Bool, intentional: Bool) in
            guard let current = process, current === terminatedProcess else {
                return (false, false)
            }

            let intentional = self.intentionalStop
            self.intentionalStop = false
            self.process = nil
            self.status = .stopped
            self.releasePipeHandlesLocked()
            return (true, intentional)
        }

        guard outcome.handled else { return }
        Task {
            await self.stateActor.setIntentionalStop(false)
            await self.stateActor.setStatus(.stopped)
        }

        if outcome.intentional {
            self.onLog?("[mihomo stopped] exit=\(code)")
        } else {
            self.onLog?("[mihomo terminated] exit=\(code)")
            self.onTermination?(code)
        }
    }

    private func runBlockingOperation<Value: Sendable>(
        on queue: DispatchQueue,
        _ operation: @escaping @Sendable () throws -> Value) async throws -> Value
    {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try continuation.resume(returning: operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runBlockingOperation(
        on queue: DispatchQueue,
        _ operation: @escaping @Sendable () -> Void) async
    {
        await withCheckedContinuation { continuation in
            queue.async {
                operation()
                continuation.resume()
            }
        }
    }

    private var binaryLocator: MihomoBinaryLocator {
        MihomoBinaryLocator(
            workingDirectoryManager: self.workingDirectoryManager,
            fileManager: self.fileManager,
            onLog: self.onLog)
    }

    private var configValidationRunner: MihomoConfigValidationRunner {
        MihomoConfigValidationRunner(
            timeout: self.configValidationTimeout,
            processWaiter: self.processWaiter,
            onLog: self.onLog)
    }

    private func resolveMihomoBinary() throws -> String {
        try self.binaryLocator.resolveBinary()
    }

    private func wireLogPipe(_ handle: FileHandle) {
        handle.readabilityHandler = { [weak self] readable in
            let data = readable.availableData
            if data.isEmpty { return }
            guard let line = String(data: data, encoding: .utf8) else { return }
            self?.onLog?(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func releasePipeHandlesLocked() {
        self.stdoutHandle?.readabilityHandler = nil
        self.stderrHandle?.readabilityHandler = nil
        self.stdoutHandle?.closeFile()
        self.stderrHandle?.closeFile()
        self.stdoutHandle = nil
        self.stderrHandle = nil
    }
}
