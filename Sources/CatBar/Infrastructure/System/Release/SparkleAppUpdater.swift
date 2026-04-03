import Sparkle
import Foundation

@MainActor
protocol AppUpdating: AnyObject {
    var isSupported: Bool { get }
    func checkForUpdates()
}

@MainActor
final class SparkleAppUpdater: NSObject, AppUpdating {
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil)
    private var hasStartedUpdater = false

    var isSupported: Bool {
        self.sparkleFeedURL != nil && self.sparklePublicKey != nil
    }

    func checkForUpdates() {
        guard self.isSupported else { return }

        if !self.hasStartedUpdater {
            self.updaterController.startUpdater()
            self.hasStartedUpdater = true
        }

        guard self.updaterController.updater.canCheckForUpdates else { return }
        self.updaterController.checkForUpdates(nil)
    }

    private var sparkleFeedURL: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String else {
            return nil
        }
        return value.isEmpty ? nil : value
    }

    private var sparklePublicKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else {
            return nil
        }
        return value.isEmpty ? nil : value
    }
}
