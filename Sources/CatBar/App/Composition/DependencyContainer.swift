import Foundation

@MainActor
final class DependencyContainer {
    let appSession: AppSession
    let appUpdater: AppUpdating

    init(appSession: AppSession = AppSession()) {
        self.appSession = appSession
        self.appUpdater = SparkleAppUpdater()
        self.appSession.appUpdater = self.appUpdater
    }
}
