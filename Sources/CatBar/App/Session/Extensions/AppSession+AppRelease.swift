import Foundation

@MainActor
extension AppSession {
    var currentAppVersionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, !short.isEmpty { return short }
        if let build, !build.isEmpty { return build }
        return "0.0.1"
    }

    var availableAppUpdate: AppReleaseInfo? {
        self.presentedAvailableAppUpdate(currentVersion: self.currentAppVersionText)
    }

    var appReleaseIndexURL: URL? {
        URL(string: "https://github.com/QuentinHsu/cat-bar/releases")
    }

    var supportsInAppUpdates: Bool {
        self.appUpdater?.isSupported == true
    }

    func checkForAppUpdates() async {
        if self.supportsInAppUpdates {
            self.appUpdater?.checkForUpdates()
            return
        }

        await self.refreshLatestAppRelease()
    }

    func refreshLatestAppRelease() async {
        guard self.beginPresentedLatestAppReleaseCheck() else { return }

        defer {
            self.endPresentedLatestAppReleaseCheck()
        }

        do {
            let release = try await AppReleaseService.fetchLatestRelease(currentVersion: self.currentAppVersionText)
            guard !Task.isCancelled else { return }
            _ = self.updatePresentedLatestAppReleaseIfChanged(release)
        } catch {
            guard !Task.isCancelled else { return }
        }
    }
}
