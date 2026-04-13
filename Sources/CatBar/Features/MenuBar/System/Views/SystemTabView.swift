import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct SettingsSelectionRowConfiguration<Option: Hashable> {
    let title: String
    let symbol: String
    let valueText: String
    let options: [Option]
    let optionTitle: (Option) -> String
    let isSelected: (Option) -> Bool
    let onSelect: (Option) -> Void
}

extension MenuBarRootView {
    func settingsRowLabel(symbol: String, title: String) -> some View {
        HStack(spacing: T.space6) {
            Image(systemName: symbol)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeTertiaryLabel)
                .frame(width: 14, alignment: .center)
            Text(title)
                .font(.app(size: T.FontSize.body, weight: .medium))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    func settingsToggleRow(
        _ title: String,
        symbol: String,
        isOn: Binding<Bool>,
        isDisabled: Bool = false) -> some View
    {
        HStack(spacing: T.space8) {
            self.settingsRowLabel(symbol: symbol, title: title)
                .layoutPriority(1)
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isDisabled)
        }
        .menuRowPadding(vertical: T.space4)
    }

    func settingsMenuRow(
        _ title: String,
        symbol: String,
        valueText: String,
        controlWidth: CGFloat? = nil,
        popoverWidth: CGFloat? = nil,
        @ViewBuilder options: @escaping (_ dismiss: @escaping () -> Void) -> some View) -> some View
    {
        let resolvedControlWidth = controlWidth ?? self.settingsMenuControlWidth

        return HStack(spacing: T.space8) {
            self.settingsRowLabel(symbol: symbol, title: title)
                .layoutPriority(1)
            Spacer(minLength: 0)
            AttachedPopoverMenu(width: popoverWidth ?? resolvedControlWidth) { _ in
                HStack(spacing: T.space2) {
                    Text(valueText)
                        .foregroundStyle(nativeSecondaryLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.right")
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(nativeTertiaryLabel)
                }
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .trailing)
            } content: { dismiss in
                options(dismiss)
            }
            .frame(width: resolvedControlWidth, alignment: .trailing)
            .appBorderedButtonStyle()
            .controlSize(.small)
        }
        .menuRowPadding(vertical: T.space4)
    }

    func settingsSelectionRow(
        _ configuration: SettingsSelectionRowConfiguration<some Hashable>) -> some View
    {
        self.settingsMenuRow(
            configuration.title,
            symbol: configuration.symbol,
            valueText: configuration.valueText)
        { dismiss in
            ForEach(configuration.options, id: \.self) { option in
                AttachedPopoverMenuItem(
                    title: configuration.optionTitle(option),
                    selected: configuration.isSelected(option))
                {
                    configuration.onSelect(option)
                    dismiss()
                }
            }
        }
    }

    func settingsPortFieldRow(_ title: String, symbol: String, text: Binding<String>) -> some View {
        HStack(spacing: T.space8) {
            self.settingsRowLabel(symbol: symbol, title: title)
                .layoutPriority(1)

            Spacer(minLength: 0)

            SettingsPortTextField(placeholder: tr("ui.placeholder.port"), text: text) {
                appSession.scheduleProxyPortsAutoSaveIfNeeded()
            } onSubmit: {
                Task { await appSession.applyProxyPorts(autoSaved: true) }
            }
            .frame(width: self.settingsPortFieldWidth, alignment: .trailing)
        }
    }

    func maintenanceActionButton(_ title: String, symbol: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label {
                Text(title)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            } icon: {
                Image(systemName: symbol)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .appBorderedButtonStyle()
        .controlSize(.small)
        .disabled(!self.maintenanceActionEnabled)
        .opacity(self.maintenanceActionEnabled ? 1 : 0.62)
    }

    func maintenanceCoreUpgradeButton() -> some View {
        Button {
            Task { await self.appSession.upgradeCore() }
        } label: {
            HStack(spacing: T.space6) {
                Group {
                    if self.appSession.isCoreUpgradeInFlight {
                        ProgressView()
                            .controlSize(.small)
                    } else if let symbol = self.footerCoreUpgradeButtonSymbolName {
                        Image(systemName: symbol)
                            .foregroundStyle(self.footerCoreUpgradeButtonTint)
                    }
                }
                .frame(width: 14, alignment: .center)

                Text(self.footerCoreUpgradeButtonTitle)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(nativePrimaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .appBorderedButtonStyle()
        .controlSize(.small)
        .disabled(!self.isFooterCoreUpgradeEnabled)
        .opacity(self.isFooterCoreUpgradeEnabled ? 1 : 0.62)
        .help(self.footerCoreUpgradeButtonHelp)
    }

    func settingsFeedbackBanner(
        text: String,
        color: Color,
        symbol: String? = nil,
        isLoading: Bool = false) -> some View
    {
        HStack(spacing: T.space6) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
            .frame(width: 14, alignment: .center)

            Text(text)
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(nativePrimaryLabel)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .menuRowPadding(vertical: T.space4)
        .background {
            RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                .fill(nativeControlFill)
                .overlay {
                    RoundedRectangle(cornerRadius: T.cornerRadius, style: .continuous)
                        .stroke(color.opacity(0.26), lineWidth: T.stroke)
                }
                .shadow(
                    color: Color(nsColor: .shadowColor).opacity(T.Shadow.standard.opacity),
                    radius: T.Shadow.standard.radius,
                    x: T.Shadow.standard.x,
                    y: T.Shadow.standard.y)
        }
    }

    func settingsInlineHintRow(text: String, color: Color, symbol: String) -> some View {
        HStack(alignment: .top, spacing: T.space6) {
            Image(systemName: symbol)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 14, alignment: .center)

            Text(text)
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .foregroundStyle(nativeSecondaryLabel)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .menuRowPadding(vertical: T.space4)
    }

    func statusBarModeLabel(_ mode: StatusBarDisplayMode) -> String {
        switch mode {
        case .iconAndSpeed:
            tr("ui.settings.display_mode.icon_and_speed")
        case .iconOnly:
            tr("ui.settings.display_mode.icon_only")
        case .speedOnly:
            tr("ui.settings.display_mode.speed_only")
        }
    }

    func appearanceModeLabel(_ mode: AppAppearanceMode) -> String {
        switch mode {
        case .system:
            tr("ui.settings.appearance.system")
        case .light:
            tr("ui.settings.appearance.light")
        case .dark:
            tr("ui.settings.appearance.dark")
        }
    }

    var settingsMenuControlWidth: CGFloat {
        min(152, max(118, contentWidth * 0.43))
    }

    var settingsPortFieldWidth: CGFloat {
        min(108, max(92, contentWidth * 0.30))
    }

    var maintenanceActionEnabled: Bool {
        SystemTabViewModel.maintenanceActionEnabled(session: appSession)
    }

    var settingsFeedbackState: (message: String, color: Color, symbol: String)? {
        guard let feedback = SystemTabViewModel.feedbackState(session: appSession) else { return nil }
        let color: Color = switch feedback.kind {
        case .error:
            nativeCritical.opacity(T.Opacity.solid)
        case .warning:
            nativeWarning.opacity(T.Opacity.solid)
        case .success:
            nativePositive.opacity(T.Opacity.solid)
        case .info:
            nativeInfo.opacity(T.Opacity.solid)
        }
        return (feedback.message, color, feedback.symbol)
    }

    var maintenanceCoreUpgradeFeedbackState: (
        message: String,
        color: Color,
        symbol: String?,
        isLoading: Bool
    )? {
        switch self.appSession.coreUpgradeState {
        case .idle:
            return nil
        case .running:
            return (
                tr("ui.footer.core_upgrade.help.running"),
                self.nativeAccent.opacity(T.Opacity.solid),
                nil,
                true)
        case .succeeded:
            return (
                tr("ui.footer.core_upgrade.help.success"),
                self.nativePositive.opacity(T.Opacity.solid),
                "checkmark.circle.fill",
                false)
        case let .alreadyLatest(version):
            let message = if let version, !version.isEmpty {
                tr("ui.footer.core_upgrade.help.latest_version", version)
            } else {
                tr("ui.footer.core_upgrade.help.latest")
            }
            return (
                message,
                self.nativePositive.opacity(T.Opacity.solid),
                "checkmark.circle",
                false)
        case let .failed(message):
            return (
                tr("ui.footer.core_upgrade.help.failed", message),
                self.nativeCritical.opacity(T.Opacity.solid),
                "exclamationmark.triangle.fill",
                false)
        }
    }

    func editableCoreSettingBinding(_ setting: AppSession.EditableCoreSetting) -> Binding<Bool> {
        Binding(
            get: { self.appSession.boolValue(for: setting) },
            set: { value in
                Task { await self.appSession.applyEditableCoreSetting(setting, to: value) }
            })
    }

    var settingsCopyProxyCommandRow: some View {
        let localTargetDisplay = self.appSession.localProxyCommandTargetDisplay()
        let managedTargetDisplay = self.appSession.managedEndpointProxyCommandTargetDisplay()
        let showManagedTargetAction = localTargetDisplay != managedTargetDisplay

        return HStack(spacing: T.space8) {
            self.settingsRowLabel(symbol: "terminal", title: tr("ui.quick.copy_terminal"))
                .layoutPriority(1)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                if !appSession.isRemoteTarget {
                    self.proxyCommandActionButton(
                        title: self.appSession.localProxyCommandHostDisplay(),
                        target: .local,
                        helpTitle: tr("ui.quick.copy_terminal"),
                        helpDetail: localTargetDisplay)
                    {
                        self.appSession.copyLocalProxyCommand()
                    }
                }

                if appSession.isRemoteTarget || showManagedTargetAction {
                    self.proxyCommandActionButton(
                        title: self.appSession.managedEndpointProxyCommandHostDisplay(),
                        target: .currentEndpoint,
                        helpTitle: tr("ui.quick.copy_terminal_current_endpoint"),
                        helpDetail: managedTargetDisplay)
                    {
                        self.appSession.copyManagedEndpointProxyCommand()
                    }
                }
            }
        }
        .menuRowPadding(vertical: T.space4)
    }

    func proxyCommandActionButton(
        title: String,
        target: ProxyCommandCopyTarget,
        helpTitle: String,
        helpDetail: String,
        action: @escaping () -> Void) -> some View
    {
        let copied = self.copiedProxyCommandTarget == target
        let foreground = copied
            ? self.nativePositive.opacity(T.Opacity.solid)
            : self.nativeSecondaryLabel
        let iconForeground = copied
            ? self.nativePositive.opacity(T.Opacity.solid)
            : self.nativeTertiaryLabel

        return Button {
            self.handleCopyProxyCommand(target) {
                action()
            }
        } label: {
            HStack(spacing: T.space4) {
                Text(title)
                    .font(.app(size: T.FontSize.caption, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(T.minimumScale)
                    .monospacedDigit()
                    .foregroundStyle(foreground)
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.app(size: T.FontSize.caption, weight: .semibold))
                    .foregroundStyle(iconForeground)
            }
            .padding(T.space2)
            .background {
                Capsule(style: .continuous)
                    .fill(copied ? self.nativePositive.opacity(T.Opacity.tint) : self.nativeBadgeFill)
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                copied
                                    ? self.nativePositive.opacity(0.18)
                                    : self.nativeControlBorder.opacity(0.42),
                                lineWidth: T.stroke)
                    }
            }
        }
        .buttonStyle(.plain)
        .help("\(helpTitle)\n\(helpDetail)")
    }

    var systemTabBody: some View {
        return VStack(alignment: .leading, spacing: T.space6) {
            self.networkHealthSectionCard
            self.proxyControlSettingsSectionCard
            self.appSettingsSectionCard
            self.coreSettingsSectionCard
            self.proxyPortsSectionCard
            self.maintenanceSectionCard
        }
        .overlay(alignment: .top) {
            if let feedback = settingsFeedbackState {
                self.settingsFeedbackBanner(
                    text: feedback.message,
                    color: feedback.color,
                    symbol: feedback.symbol)
            }
        }
    }
}
