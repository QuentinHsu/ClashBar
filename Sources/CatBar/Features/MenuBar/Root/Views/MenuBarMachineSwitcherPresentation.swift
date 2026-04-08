import SwiftUI

extension MenuBarRootView {
    var machineSwitcherLabel: String {
        switch remoteMachineStore.activeTarget {
        case .local:
            tr("ui.machine.local")
        case let .remote(machine):
            machine.name
        }
    }

    var machineSwitcherSubtitle: String {
        switch remoteMachineStore.activeTarget {
        case .local:
            appSession.externalControllerDisplay
        case let .remote(machine):
            machine.displayAddress
        }
    }

    var machineSwitcherTint: Color {
        switch self.machineSwitcherStatus {
        case .unknown, nil:
            remoteMachineStore.activeTarget.isLocal
                ? nativeInfo.opacity(MenuBarLayoutTokens.Opacity.solid)
                : nativeSecondaryLabel
        case .checking:
            nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .connected:
            nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .failed:
            nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid)
        }
    }

    var machineSwitcherStatus: MachineConnectionStatus? {
        guard case let .remote(machine) = remoteMachineStore.activeTarget else { return nil }
        return remoteMachineStore.statusFor(machine.id)
    }

    func machineSwitcherStatusBadge(_ status: MachineConnectionStatus) -> some View {
        HStack(spacing: 6) {
            switch status {
            case .checking:
                ProgressView()
                    .controlSize(.mini)
            default:
                Circle()
                    .fill(self.machineStatusTint(status))
                    .frame(width: 6, height: 6)
            }

            Text(self.machineStatusText(status))
                .font(.app(size: 10, weight: .semibold))
                .foregroundStyle(self.machineStatusTint(status))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(self.machineStatusTint(status).opacity(0.12), in: Capsule())
    }

    func machineStatusText(_ status: MachineConnectionStatus) -> String {
        switch status {
        case .unknown:
            "?"
        case .checking:
            "…"
        case let .connected(version):
            version
        case let .failed(reason):
            reason
        }
    }

    func machineStatusTint(_ status: MachineConnectionStatus) -> Color {
        switch status {
        case .unknown:
            nativeSecondaryLabel
        case .checking:
            nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .connected:
            nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .failed:
            nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid)
        }
    }
}
