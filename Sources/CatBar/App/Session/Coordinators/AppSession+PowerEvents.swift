import AppKit
import Foundation

@MainActor
extension AppSession {
    func startPowerEventMonitoringIfNeeded() {
        guard self.powerEventObservers.isEmpty else { return }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let mainCenter = NotificationCenter.default
        let handler: @MainActor () -> Void = { [weak self] in
            self?.handlePowerEventResume()
        }

        let workspaceNotifications: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
        ]

        for name in workspaceNotifications {
            let observer = workspaceCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main)
            { _ in
                Task { @MainActor in
                    handler()
                }
            }
            self.powerEventObservers.append((center: workspaceCenter, observer: observer))
        }

        let appObserver = mainCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main)
        { _ in
            Task { @MainActor in
                handler()
            }
        }
        self.powerEventObservers.append((center: mainCenter, observer: appObserver))
    }

    func stopPowerEventMonitoring() {
        for entry in self.powerEventObservers {
            entry.center.removeObserver(entry.observer)
        }
        self.powerEventObservers.removeAll(keepingCapacity: false)
    }

    func handlePowerEventResume() {
        guard self.isRemoteTarget || self.coreRepository.isRunning else { return }
        self.updateDataAcquisitionPolicy(forceRestartEnabledStreams: true)

        guard self.isPanelPresented else { return }
        self.scheduleRefreshForActivatedTab(self.activeMenuTab)
    }
}
