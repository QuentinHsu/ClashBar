import Foundation
import XCTest
@testable import CatBar

final class MihomoBinaryLocatorTests: XCTestCase {
    func testBundledBinaryCandidatesDeduplicateNormalizedPaths() {
        let root = URL(fileURLWithPath: "/tmp/resources")
        let locator = MihomoBinaryLocator(
            workingDirectoryManager: WorkingDirectoryManager(homeDirectory: URL(fileURLWithPath: "/tmp/home")),
            fileManager: .default,
            resourceRootsProvider: { [root, root.appendingPathComponent(".")] })

        let candidates = locator.bundledBinaryCandidates()

        XCTAssertEqual(
            candidates,
            [
                "/tmp/resources/bin/mihomo",
                "/tmp/resources/Resources/bin/mihomo",
                "/tmp/resources/mihomo",
            ])
    }

    func testValidateBinarySecurityRejectsSymbolicLinks() throws {
        let directory = try self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("mihomo-real")
        FileManager.default.createFile(atPath: target.path, contents: Data("binary".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)

        let symlink = directory.appendingPathComponent("mihomo-link")
        try FileManager.default.createSymbolicLink(atPath: symlink.path, withDestinationPath: target.path)

        let locator = MihomoBinaryLocator(
            workingDirectoryManager: WorkingDirectoryManager(homeDirectory: directory),
            fileManager: .default)

        XCTAssertThrowsError(try locator.validateBinarySecurity(at: symlink.path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("must not be a symbolic link"))
        }
    }

    func testValidateBinarySecurityRejectsWorldWritableBinary() throws {
        let directory = try self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("mihomo")
        FileManager.default.createFile(atPath: file.path, contents: Data("binary".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: file.path)

        let locator = MihomoBinaryLocator(
            workingDirectoryManager: WorkingDirectoryManager(homeDirectory: directory),
            fileManager: .default)

        XCTAssertThrowsError(try locator.validateBinarySecurity(at: file.path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("too permissive"))
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
