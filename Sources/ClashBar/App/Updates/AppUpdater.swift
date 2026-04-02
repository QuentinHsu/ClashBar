import AppKit
import Foundation
import Sparkle

@MainActor
final class AppUpdater: NSObject, ObservableObject {
    private var updaterController: SPUStandardUpdaterController?

    override init() {
        self.updaterController = nil

        super.init()
    }

    var isConfigured: Bool {
        Self.hasSecureUpdateConfiguration
    }

    func checkForUpdates() {
        guard Self.hasSecureUpdateConfiguration else {
            NSWorkspace.shared.open(AppReleaseConfiguration.releasesPageURL)
            return
        }

        let isFirstManualInitialization = self.updaterController == nil
        let updaterController = self.updaterController ?? SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil)
        updaterController.updater.automaticallyChecksForUpdates = false
        updaterController.updater.automaticallyDownloadsUpdates = false
        self.updaterController = updaterController

        if isFirstManualInitialization {
            self.logManualUpdaterInitialization()
        }

        updaterController.checkForUpdates(nil)
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(AppReleaseConfiguration.releasesPageURL)
    }

    private static var hasSecureUpdateConfiguration: Bool {
        guard
            let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            !feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        return true
    }

    private func logManualUpdaterInitialization() {
        NotificationCenter.default.post(name: .appUpdaterDidInitializeManually, object: nil)

        #if DEBUG
            NSLog("[AppUpdater] Sparkle updater initialized lazily via manual check trigger.")
        #endif
    }
}

extension Notification.Name {
    static let appUpdaterDidInitializeManually = Notification.Name("catbar.appUpdater.didInitializeManually")
}
