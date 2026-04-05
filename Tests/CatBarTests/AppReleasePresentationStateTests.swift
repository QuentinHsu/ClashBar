import XCTest
@testable import CatBar

final class AppReleasePresentationStateTests: XCTestCase {
    func testBeginAndEndCheckingLatestReleaseGuardConcurrentChecks() {
        var state = AppReleasePresentationState()

        XCTAssertTrue(state.beginCheckingLatestRelease())
        XCTAssertFalse(state.beginCheckingLatestRelease())

        state.endCheckingLatestRelease()

        XCTAssertFalse(state.isCheckingLatestRelease)
    }

    func testUpdateLatestReleaseIfChangedSkipsEqualValue() {
        var state = AppReleasePresentationState()
        let release = makeRelease(tagName: "v1.2.3")
        state.latestReleaseInfo = release

        XCTAssertFalse(state.updateLatestReleaseIfChanged(release))
        XCTAssertEqual(state.latestReleaseInfo, release)
    }

    func testAvailableUpdateFiltersDraftPrereleaseAndNonNewerVersions() {
        var state = AppReleasePresentationState()

        state.latestReleaseInfo = makeRelease(tagName: "v1.2.3", isDraft: true)
        XCTAssertNil(state.availableUpdate(currentVersion: "1.0.0"))

        state.latestReleaseInfo = makeRelease(tagName: "v1.2.3", isPrerelease: true)
        XCTAssertNil(state.availableUpdate(currentVersion: "1.0.0"))

        state.latestReleaseInfo = makeRelease(tagName: "v1.0.0")
        XCTAssertNil(state.availableUpdate(currentVersion: "1.0.0"))

        let newer = makeRelease(tagName: "v1.2.3")
        state.latestReleaseInfo = newer
        XCTAssertEqual(state.availableUpdate(currentVersion: "1.0.0"), newer)
    }

    private func makeRelease(
        tagName: String,
        isDraft: Bool = false,
        isPrerelease: Bool = false) -> AppReleaseInfo
    {
        AppReleaseInfo(
            tagName: tagName,
            name: tagName,
            releaseURL: URL(string: "https://example.com/releases/\(tagName)")!,
            isDraft: isDraft,
            isPrerelease: isPrerelease)
    }
}
