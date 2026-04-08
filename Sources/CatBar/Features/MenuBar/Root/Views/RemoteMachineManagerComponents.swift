import SwiftUI

extension RemoteMachineManagerView {
    struct RemoteMachineManagerPalette {
        let cardPadding: CGFloat
        let cardCornerRadius: CGFloat
        let trailingActionAreaWidth: CGFloat
        let primaryTextColor: Color
        let secondaryTextColor: Color
        let tertiaryTextColor: Color
        let borderColor: Color
        let separatorColor: Color
        let cardFill: Color
        let cardHoverFill: Color
        let cardSelectedFill: Color
        let accentTint: Color
        let isDarkAppearance: Bool
    }
}

struct RemoteMachineListView: View {
    private enum RowAction: Hashable {
        case edit
        case delete

        var symbol: String {
            switch self {
            case .edit:
                "pencil"
            case .delete:
                "trash"
            }
        }

        var accessibilityKey: String {
            switch self {
            case .edit:
                "ui.machine.edit"
            case .delete:
                "ui.action.delete"
            }
        }

        var isDestructive: Bool {
            switch self {
            case .edit:
                false
            case .delete:
                true
            }
        }
    }

    private struct HoveredRowAction: Hashable {
        let machineID: UUID
        let action: RowAction
    }

    @ObservedObject var store: RemoteMachineStore
    let localControllerDisplay: String
    let palette: RemoteMachineManagerView.RemoteMachineManagerPalette
    let onSelectTarget: (MachineTarget) -> Void
    let onAdd: () -> Void
    let onEdit: (RemoteMachine) -> Void
    let onDelete: (RemoteMachine) -> Void

    @State private var hoveredMachineID: UUID?
    @State private var hoveredRowAction: HoveredRowAction?
    @State private var hoveringLocalCard = false

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "catbar.ui.language") ?? "") ?? .zhHans
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            self.machineCards
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            self.primaryActionButton(title: self.tr("ui.machine.add"), systemImage: "plus", action: self.onAdd)
        }
    }

    private var machineCards: some View {
        ScrollView {
            VStack(spacing: 10) {
                self.localCard
                ForEach(self.store.machines) { machine in
                    self.remoteCard(machine)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var localCard: some View {
        let isActive = self.store.activeTarget.isLocal
        let hovered = self.hoveringLocalCard

        return Button {
            guard !isActive else { return }
            self.onSelectTarget(.local)
        } label: {
            HStack(spacing: 14) {
                self.iconTile(symbol: "desktopcomputer", tint: .blue)

                VStack(alignment: .leading, spacing: 3) {
                    Text(self.tr("ui.machine.local"))
                        .font(.app(size: 14, weight: .semibold))
                        .foregroundStyle(self.palette.primaryTextColor)
                    Text(self.localControllerDisplay)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(self.palette.secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? Color.green : self.palette.tertiaryTextColor)
                    .opacity(isActive ? 1 : 0)
            }
            .padding(self.palette.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(self.cardBackground(selected: isActive, hovered: hovered))
            .contentShape(RoundedRectangle(cornerRadius: self.palette.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isActive)
        .onHover { self.hoveringLocalCard = $0 }
    }

    private func remoteCard(_ machine: RemoteMachine) -> some View {
        let status = self.store.statusFor(machine.id)
        let isActive = self.store.activeTargetID == machine.id
        let isSwitchEnabled = status.isConnected && !isActive
        let hovered = self.hoveredMachineID == machine.id

        return HStack(spacing: 10) {
            Button {
                guard isSwitchEnabled else { return }
                self.onSelectTarget(.remote(machine))
            } label: {
                HStack(spacing: 14) {
                    self.iconTile(symbol: "network", tint: self.statusTint(status, active: isActive))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(machine.name)
                            .font(.app(size: 14, weight: .semibold))
                            .foregroundStyle(self.palette.primaryTextColor)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            self.statusDot(status)
                            Text(machine.displayAddress)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(self.palette.secondaryTextColor)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: self.palette.cardCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isSwitchEnabled)

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .bold))
                    .foregroundStyle(.green)
                    .frame(width: self.palette.trailingActionAreaWidth, alignment: .trailing)
            } else {
                self.inlineActionGroup(
                    machineID: machine.id,
                    emphasized: hovered,
                    editAction: { self.onEdit(machine) },
                    deleteAction: { self.onDelete(machine) })
                    .frame(width: self.palette.trailingActionAreaWidth, alignment: .trailing)
            }
        }
        .padding(self.palette.cardPadding)
        .background(self.cardBackground(selected: isActive, hovered: hovered))
        .onHover { isHovering in
            self.hoveredMachineID = isHovering ? machine.id : nil
            if !isHovering, self.hoveredRowAction?.machineID == machine.id {
                self.hoveredRowAction = nil
            }
        }
        .contextMenu {
            Button(self.tr("ui.machine.edit")) {
                self.onEdit(machine)
            }
            Divider()
            Button(self.tr("ui.action.delete"), role: .destructive) {
                self.onDelete(machine)
            }
        }
    }

    private func primaryActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.app(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: self.palette.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white)
        .background(
            RoundedRectangle(cornerRadius: self.palette.cardCornerRadius, style: .continuous)
                .fill(self.palette.accentTint))
        .overlay {
            RoundedRectangle(cornerRadius: self.palette.cardCornerRadius, style: .continuous)
                .stroke(self.palette.accentTint.opacity(0.65), lineWidth: MenuBarLayoutTokens.stroke)
        }
        .shadow(color: Color.black.opacity(self.palette.isDarkAppearance ? 0.20 : 0.10), radius: 10, x: 0, y: 4)
    }

    private func iconTile(symbol: String, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(tint.opacity(self.palette.isDarkAppearance ? 0.16 : 0.10))
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(tint)
            }
    }

    private func inlineActionButton(
        machineID: UUID,
        rowAction: RowAction,
        emphasized: Bool,
        action: @escaping () -> Void) -> some View
    {
        let hoveredAction = HoveredRowAction(machineID: machineID, action: rowAction)
        let isHovered = self.hoveredRowAction == hoveredAction
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        let tint = self.actionButtonTint(for: rowAction, hovered: isHovered, emphasized: emphasized)
        let fill = self.actionButtonFill(for: rowAction, hovered: isHovered, emphasized: emphasized)
        let border = self.actionButtonBorder(for: rowAction, hovered: isHovered, emphasized: emphasized)
        let opacity = (emphasized || isHovered) ? 1.0 : 0.84

        return Button(action: action) {
            Image(systemName: rowAction.symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(shape.fill(fill))
                .overlay {
                    shape.stroke(border, lineWidth: MenuBarLayoutTokens.stroke)
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .opacity(opacity)
        .accessibilityLabel(self.tr(rowAction.accessibilityKey))
        .onHover { isHovering in
            self.hoveredRowAction = isHovering ? hoveredAction :
                (self.hoveredRowAction == hoveredAction ? nil : self.hoveredRowAction)
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: emphasized)
    }

    private func inlineActionGroup(
        machineID: UUID,
        emphasized: Bool,
        editAction: @escaping () -> Void,
        deleteAction: @escaping () -> Void) -> some View
    {
        HStack(spacing: 6) {
            self.inlineActionButton(machineID: machineID, rowAction: .edit, emphasized: emphasized, action: editAction)
            self.inlineActionButton(machineID: machineID, rowAction: .delete, emphasized: emphasized, action: deleteAction)
        }
    }

    private func actionButtonTint(for rowAction: RowAction, hovered: Bool, emphasized: Bool) -> Color {
        if rowAction.isDestructive {
            return hovered ? .red : .red.opacity(emphasized ? 0.92 : 0.70)
        }

        return hovered ? self.palette.accentTint : self.palette.tertiaryTextColor.opacity(emphasized ? 1 : 0.88)
    }

    private func actionButtonFill(for rowAction: RowAction, hovered: Bool, emphasized: Bool) -> Color {
        if hovered {
            if rowAction.isDestructive {
                return Color.red.opacity(self.palette.isDarkAppearance ? 0.18 : 0.10)
            }
            return self.palette.accentTint.opacity(self.palette.isDarkAppearance ? 0.18 : 0.09)
        }

        if emphasized {
            return Color.black.opacity(self.palette.isDarkAppearance ? 0.18 : 0.06)
        }

        return Color.black.opacity(self.palette.isDarkAppearance ? 0.12 : 0.035)
    }

    private func actionButtonBorder(for rowAction: RowAction, hovered: Bool, emphasized: Bool) -> Color {
        if hovered {
            return rowAction.isDestructive
                ? Color.red.opacity(self.palette.isDarkAppearance ? 0.48 : 0.28)
                : self.palette.accentTint.opacity(self.palette.isDarkAppearance ? 0.48 : 0.28)
        }

        return self.palette.borderColor.opacity(emphasized ? 1 : (self.palette.isDarkAppearance ? 0.94 : 0.78))
    }

    private func cardBackground(selected: Bool, hovered: Bool) -> some View {
        RoundedRectangle(cornerRadius: self.palette.cardCornerRadius, style: .continuous)
            .fill(selected ? self.palette.cardSelectedFill : (hovered ? self.palette.cardHoverFill : self.palette.cardFill))
            .overlay {
                RoundedRectangle(cornerRadius: self.palette.cardCornerRadius, style: .continuous)
                    .stroke(self.palette.borderColor, lineWidth: MenuBarLayoutTokens.stroke)
            }
            .shadow(color: Color.black.opacity(self.palette.isDarkAppearance ? 0.12 : 0.06), radius: 14, x: 0, y: 3)
    }

    private func statusDot(_ status: MachineConnectionStatus) -> some View {
        Group {
            if case .checking = status {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Circle()
                    .fill(self.statusTint(status, active: false))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func statusTint(_ status: MachineConnectionStatus, active: Bool) -> Color {
        switch status {
        case .unknown:
            self.palette.tertiaryTextColor
        case .checking:
            .orange
        case .connected:
            active ? Color.green : Color(red: 0.10, green: 0.73, blue: 0.34)
        case .failed:
            .red
        }
    }
}

struct RemoteMachineEditorCard: View {
    private enum Field {
        case name
        case host
        case port
        case secret
    }

    @ObservedObject var store: RemoteMachineStore
    let machine: RemoteMachine?
    let palette: RemoteMachineManagerView.RemoteMachineManagerPalette
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "9090"
    @State private var secret: String = ""
    @State private var useHTTPS = false
    @State private var showsWebDashboardButton = false
    @FocusState private var focusedField: Field?

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "catbar.ui.language") ?? "") ?? .zhHans
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    private var isValid: Bool {
        !self.name.trimmingCharacters(in: .whitespaces).isEmpty &&
            !self.host.trimmingCharacters(in: .whitespaces).isEmpty &&
            !self.hostContainsProtocolPrefix &&
            (Int(self.port) ?? 0) > 0 &&
            (Int(self.port) ?? 0) <= 65535
    }

    private var trimmedHost: String {
        self.host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hostContainsProtocolPrefix: Bool {
        let lowercased = self.trimmedHost.lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }

    private var connectionPreview: String {
        let resolvedHost = self.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "controller.example.com"
            : self.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPort = self.port.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "9090"
            : self.port.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheme = self.useHTTPS ? "https" : "http"
        return "\(scheme)://\(resolvedHost):\(resolvedPort)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(self.name.trimmingCharacters(in: .whitespaces).isEmpty ? self.tr("ui.machine.field.name") : self.name)
                    .font(.app(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(self.connectionPreview)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.secondaryTextColor)
                    .lineLimit(1)
            }

            self.formCard

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                RemoteMachineEditorActionButton(
                    title: self.tr("ui.action.cancel"),
                    palette: self.palette,
                    variant: .secondary,
                    action: self.onCancel)
                RemoteMachineEditorActionButton(
                    title: self.tr("ui.machine.save"),
                    palette: self.palette,
                    variant: .primary,
                    action: self.save)
                    .disabled(!self.isValid)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if let machine {
                self.name = machine.name
                self.host = machine.host
                self.port = "\(machine.port)"
                self.secret = machine.secret ?? ""
                self.useHTTPS = machine.useHTTPS
                self.showsWebDashboardButton = machine.showsWebDashboardButton
            } else {
                self.focusedField = .name
            }
        }
    }

    private var formCard: some View {
        VStack(spacing: 0) {
            RemoteMachineEditorLabeledRow(title: self.tr("ui.machine.field.name"), palette: self.palette) {
                TextField(self.tr("ui.machine.field.name"), text: self.$name)
                    .textFieldStyle(.roundedBorder)
                    .font(.app(size: 13, weight: .regular))
                    .focused(self.$focusedField, equals: .name)
            }
            self.separator
            RemoteMachineEditorLabeledRow(title: self.tr("ui.machine.field.host"), palette: self.palette) {
                TextField(self.tr("ui.machine.field.host_placeholder"), text: self.$host)
                    .textFieldStyle(.roundedBorder)
                    .font(.app(size: 13, weight: .regular))
                    .focused(self.$focusedField, equals: .host)
            }
            if self.hostContainsProtocolPrefix {
                self.separator
                RemoteMachineEditorValidationRow(text: self.tr("ui.machine.error.host_protocol"))
            }
            self.separator
            RemoteMachineEditorLabeledRow(title: self.tr("ui.machine.field.port"), palette: self.palette) {
                HStack(spacing: 10) {
                    TextField(self.tr("ui.machine.field.port"), text: self.$port)
                        .textFieldStyle(.roundedBorder)
                        .font(.app(size: 13, weight: .regular))
                        .frame(width: 92)
                        .focused(self.$focusedField, equals: .port)

                    Spacer(minLength: 0)

                    Toggle("HTTPS", isOn: self.$useHTTPS)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.app(size: 12, weight: .medium))
                }
            }
            self.separator
            RemoteMachineEditorLabeledRow(title: self.tr("ui.machine.field.secret"), palette: self.palette) {
                SecureField(self.tr("ui.machine.field.secret"), text: self.$secret)
                    .textFieldStyle(.roundedBorder)
                    .font(.app(size: 13, weight: .regular))
                    .focused(self.$focusedField, equals: .secret)
            }
            self.separator
            RemoteMachineEditorLabeledRow(title: self.tr("ui.machine.field.show_web_ui_button"), palette: self.palette) {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    Toggle("", isOn: self.$showsWebDashboardButton)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
        }
        .background(self.formSurface)
    }

    private var separator: some View {
        Rectangle()
            .fill(self.palette.separatorColor)
            .frame(height: MenuBarLayoutTokens.stroke)
    }

    private var formSurface: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(self.palette.cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(self.palette.borderColor, lineWidth: MenuBarLayoutTokens.stroke)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 3)
    }

    private func save() {
        let trimmedName = self.name.trimmingCharacters(in: .whitespaces)
        let trimmedHost = self.trimmedHost
        let portValue = Int(self.port) ?? 9090
        let trimmedSecret = self.secret.trimmingCharacters(in: .whitespaces)

        guard !self.hostContainsProtocolPrefix else { return }

        if let existing = self.machine {
            var updated = existing
            updated.name = trimmedName
            updated.host = trimmedHost
            updated.port = portValue
            updated.secret = trimmedSecret.isEmpty ? nil : trimmedSecret
            updated.useHTTPS = self.useHTTPS
            updated.showsWebDashboardButton = self.showsWebDashboardButton
            self.store.updateMachine(updated)
        } else {
            self.store.addMachine(
                RemoteMachine(
                    name: trimmedName,
                    host: trimmedHost,
                    port: portValue,
                    secret: trimmedSecret.isEmpty ? nil : trimmedSecret,
                    useHTTPS: self.useHTTPS,
                    showsWebDashboardButton: self.showsWebDashboardButton))
        }

        self.onSave()
    }
}

private struct RemoteMachineEditorLabeledRow<Content: View>: View {
    let title: String
    let palette: RemoteMachineManagerView.RemoteMachineManagerPalette
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            Text(self.title)
                .font(.app(size: 12, weight: .semibold))
                .foregroundStyle(self.palette.secondaryTextColor)
                .frame(width: 56, alignment: .leading)

            self.content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct RemoteMachineEditorValidationRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.app(size: 12, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 14, alignment: .center)

            Text(self.text)
                .font(.app(size: 12, weight: .medium))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct RemoteMachineEditorActionButton: View {
    enum Variant {
        case primary
        case secondary
    }

    let title: String
    let palette: RemoteMachineManagerView.RemoteMachineManagerPalette
    let variant: Variant
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Text(self.title)
                .font(.app(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(self.foregroundColor)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(self.backgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(self.borderColor, lineWidth: MenuBarLayoutTokens.stroke)
        }
    }

    private var foregroundColor: Color {
        switch self.variant {
        case .primary:
            Color.white
        case .secondary:
            .primary
        }
    }

    private var backgroundColor: Color {
        switch self.variant {
        case .primary:
            self.palette.accentTint
        case .secondary:
            self.palette.cardFill
        }
    }

    private var borderColor: Color {
        switch self.variant {
        case .primary:
            self.palette.accentTint.opacity(0.65)
        case .secondary:
            self.palette.borderColor
        }
    }
}
