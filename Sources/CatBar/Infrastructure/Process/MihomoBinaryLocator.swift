import Darwin
import Foundation

struct MihomoBinaryLocator {
    let workingDirectoryManager: WorkingDirectoryManager
    let fileManager: FileManager
    let resourceRootsProvider: () -> [URL]
    let onLog: ((String) -> Void)?

    init(
        workingDirectoryManager: WorkingDirectoryManager,
        fileManager: FileManager,
        resourceRootsProvider: @escaping () -> [URL] = AppResourceBundleLocator.candidateResourceRoots,
        onLog: ((String) -> Void)? = nil)
    {
        self.workingDirectoryManager = workingDirectoryManager
        self.fileManager = fileManager
        self.resourceRootsProvider = resourceRootsProvider
        self.onLog = onLog
    }

    func resolveBinary() throws -> String {
        try self.workingDirectoryManager.bootstrapDirectories(fileManager: self.fileManager)

        let managedBinaryPath = self.workingDirectoryManager.managedMihomoBinaryURL.path

        if self.fileManager.fileExists(atPath: managedBinaryPath) {
            try self.ensureExecutableIfNeeded(at: managedBinaryPath)
            if self.fileManager.isExecutableFile(atPath: managedBinaryPath) {
                try self.validateBinarySecurity(at: managedBinaryPath)
                return managedBinaryPath
            }
        }

        if let bundledBinaryPath = self.firstBundledExecutableBinaryPath() {
            try self.validateBinarySecurity(at: bundledBinaryPath)
            let migratedBinaryPath = try self.copyBundledBinaryToManagedCore(
                bundledPath: bundledBinaryPath,
                managedPath: managedBinaryPath)
            try self.validateBinarySecurity(at: migratedBinaryPath)
            return migratedBinaryPath
        }

        guard let bundledCompressedBinaryPath = self.firstBundledCompressedBinaryPath() else {
            throw MihomoBinaryResolutionError.binaryNotFound(
                expectedDirectory: self.workingDirectoryManager.coreDirectoryURL.path)
        }

        try self.validateBinarySecurity(at: bundledCompressedBinaryPath)
        let migratedBinaryPath = try self.decompressBundledBinaryToManagedCore(
            compressedPath: bundledCompressedBinaryPath,
            managedPath: managedBinaryPath)
        try self.validateBinarySecurity(at: migratedBinaryPath)
        return migratedBinaryPath
    }

    func firstBundledExecutableBinaryPath() -> String? {
        for candidate in self.bundledBinaryCandidates() where self.fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }

    func firstBundledCompressedBinaryPath() -> String? {
        for candidate in self.bundledCompressedBinaryCandidates() where self.fileManager.fileExists(atPath: candidate) {
            return candidate
        }
        return nil
    }

    func bundledBinaryCandidates() -> [String] {
        self.deduplicatedCandidatePaths(fileName: "mihomo")
    }

    func bundledCompressedBinaryCandidates() -> [String] {
        self.deduplicatedCandidatePaths(fileName: "mihomo.gz")
    }

    func ensureExecutableIfNeeded(at path: String) throws {
        guard self.fileManager.fileExists(atPath: path) else {
            throw NSError(
                domain: "CatBar.Core",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "mihomo binary not found at \(path)"])
        }

        guard !self.fileManager.isExecutableFile(atPath: path) else { return }
        try self.fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }

    func validateBinarySecurity(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])

        if values.isSymbolicLink == true {
            throw NSError(
                domain: "CatBar.Core",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "mihomo binary path must not be a symbolic link: \(path)"])
        }
        if values.isRegularFile != true {
            throw NSError(
                domain: "CatBar.Core",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "mihomo binary must be a regular file: \(path)"])
        }

        let attrs = try self.fileManager.attributesOfItem(atPath: path)
        let uid = Int(getuid())
        if let owner = attrs[.ownerAccountID] as? NSNumber {
            let ownerID = owner.intValue
            if ownerID != 0, ownerID != uid {
                throw NSError(
                    domain: "CatBar.Core",
                    code: 403,
                    userInfo: [NSLocalizedDescriptionKey: "mihomo binary owner must be current user or root: \(path)"])
            }
        }

        if let perm = attrs[.posixPermissions] as? NSNumber {
            let mode = perm.intValue
            if (mode & 0o022) != 0 {
                throw NSError(
                    domain: "CatBar.Core",
                    code: 403,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "mihomo binary permissions are too permissive " +
                            "(writable by group/others): \(path)",
                    ])
            }
        }
    }

    private func deduplicatedCandidatePaths(fileName: String) -> [String] {
        var candidates: [String] = []

        for root in self.resourceRootsProvider() {
            candidates.append(root.appendingPathComponent("bin/\(fileName)").path)
            candidates.append(root.appendingPathComponent("Resources/bin/\(fileName)").path)
            candidates.append(root.appendingPathComponent(fileName).path)
        }

        var deduplicated: [String] = []
        var seen = Set<String>()
        for path in candidates {
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            if seen.insert(normalized).inserted {
                deduplicated.append(normalized)
            }
        }
        return deduplicated
    }

    private func copyBundledBinaryToManagedCore(bundledPath: String, managedPath: String) throws -> String {
        if self.fileManager.fileExists(atPath: managedPath) {
            try self.fileManager.removeItem(atPath: managedPath)
        }

        do {
            try self.fileManager.copyItem(atPath: bundledPath, toPath: managedPath)
            self.onLog?("[mihomo binary] copied bundled core to \(managedPath)")
            try self.ensureExecutableIfNeeded(at: managedPath)
            return managedPath
        } catch {
            throw NSError(
                domain: "CatBar.Core",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "failed to migrate mihomo binary to \(managedPath): \(error.localizedDescription)",
                ])
        }
    }

    private func decompressBundledBinaryToManagedCore(compressedPath: String, managedPath: String) throws -> String {
        let temporaryPath = managedPath + ".tmp"
        if self.fileManager.fileExists(atPath: temporaryPath) {
            try self.fileManager.removeItem(atPath: temporaryPath)
        }
        if self.fileManager.fileExists(atPath: managedPath) {
            try self.fileManager.removeItem(atPath: managedPath)
        }

        self.fileManager.createFile(atPath: temporaryPath, contents: nil)
        let outputURL = URL(fileURLWithPath: temporaryPath)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-c", compressedPath]
        process.standardOutput = outputHandle
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            try outputHandle.close()

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
                try? self.fileManager.removeItem(atPath: temporaryPath)
                throw NSError(
                    domain: "CatBar.Core",
                    code: 500,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "failed to decompress bundled mihomo binary from \(compressedPath): \(errorText)",
                    ])
            }

            try self.fileManager.moveItem(atPath: temporaryPath, toPath: managedPath)
            self.onLog?("[mihomo binary] decompressed bundled core to \(managedPath)")
            try self.ensureExecutableIfNeeded(at: managedPath)
            return managedPath
        } catch {
            try? outputHandle.close()
            try? self.fileManager.removeItem(atPath: temporaryPath)
            if let error = error as NSError?, error.domain == "CatBar.Core" {
                throw error
            }
            throw NSError(
                domain: "CatBar.Core",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "failed to migrate compressed mihomo binary to \(managedPath): \(error.localizedDescription)",
                ])
        }
    }
}
