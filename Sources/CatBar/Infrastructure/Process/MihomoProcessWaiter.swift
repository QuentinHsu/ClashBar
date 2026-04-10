import Darwin
import Foundation

struct MihomoProcessWaiter {
    func waitForExit(_ process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            usleep(50_000)
        }
        return !process.isRunning
    }

    func normalizedTimeoutSeconds(_ timeout: TimeInterval) -> Int {
        max(1, Int(timeout.rounded(.awayFromZero)))
    }
}
