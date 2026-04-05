import Foundation

struct MenuBarDisplayResolver {
    func resolveIsRuntimeRunning(statusText: String, coreIsRunning: Bool) -> Bool {
        coreIsRunning || statusText.caseInsensitiveCompare("running") == .orderedSame
    }

    func resolveRuntimeVisualStatus(
        statusText: String,
        apiStatus: APIHealth,
        coreIsRunning: Bool) -> RuntimeVisualStatus
    {
        let normalized = statusText.lowercased()
        if normalized == "starting" { return .starting }
        if normalized == "failed" { return .failed }

        if self.resolveIsRuntimeRunning(statusText: statusText, coreIsRunning: coreIsRunning) {
            switch apiStatus {
            case .healthy:
                return .runningHealthy
            case .failed:
                return .failed
            case .degraded, .unknown:
                return .runningDegraded
            }
        }

        return .stopped
    }

    func resolveSymbolName(for status: RuntimeVisualStatus) -> String {
        switch status {
        case .runningHealthy:
            "bolt.horizontal.circle.fill"
        case .runningDegraded:
            "bolt.horizontal.circle"
        case .starting:
            "clock.arrow.circlepath"
        case .failed:
            "exclamationmark.triangle.fill"
        case .stopped:
            "bolt.slash.circle"
        }
    }

    func resolveSpeedLines(traffic: TrafficSnapshot, isRuntimeRunning: Bool) -> MenuBarSpeedLines {
        guard isRuntimeRunning else { return .zero }

        let up = ValueFormatter.speed(max(0, traffic.up)).replacingOccurrences(of: " ", with: "")
        let down = ValueFormatter.speed(max(0, traffic.down)).replacingOccurrences(of: " ", with: "")
        return MenuBarSpeedLines(up: "\(up)↑", down: "\(down)↓")
    }

    func resolveDisplay(
        mode: StatusBarDisplayMode,
        runtimeVisualStatus: RuntimeVisualStatus,
        isRuntimeRunning: Bool,
        traffic: TrafficSnapshot) -> MenuBarDisplay
    {
        let symbolName = self.resolveSymbolName(for: runtimeVisualStatus)
        let speedLines = self.resolveSpeedLines(traffic: traffic, isRuntimeRunning: isRuntimeRunning)

        switch mode {
        case .iconOnly:
            return MenuBarDisplay(
                mode: .iconOnly,
                symbolName: symbolName,
                speedLines: nil,
                isRunning: isRuntimeRunning)
        case .iconAndSpeed:
            return MenuBarDisplay(
                mode: .iconAndSpeed,
                symbolName: symbolName,
                speedLines: speedLines,
                isRunning: isRuntimeRunning)
        case .speedOnly:
            return MenuBarDisplay(
                mode: .speedOnly,
                symbolName: nil,
                speedLines: speedLines,
                isRunning: isRuntimeRunning)
        }
    }
}
