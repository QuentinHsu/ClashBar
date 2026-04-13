import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

private struct SystemSettingsSectionCard<HeaderTrailing: View, Content: View>: View {
    let title: String
    let symbol: String
    let headerTint: Color
    @ViewBuilder let headerTrailing: () -> HeaderTrailing
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: T.space6) {
                Image(systemName: self.symbol)
                    .font(.app(size: T.FontSize.caption, weight: .semibold))
                    .foregroundStyle(self.headerTint)
                Text(self.title)
                    .font(.app(size: T.FontSize.body, weight: .bold))
                    .foregroundStyle(self.headerTint)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                self.headerTrailing()
            }
            .menuRowPadding(vertical: T.space2)

            self.content()
        }
    }
}

private extension SystemSettingsSectionCard where HeaderTrailing == EmptyView {
    init(
        title: String,
        symbol: String,
        headerTint: Color,
        @ViewBuilder content: @escaping () -> Content)
    {
        self.init(
            title: title,
            symbol: symbol,
            headerTint: headerTint,
            headerTrailing: { EmptyView() },
            content: content)
    }
}

extension MenuBarRootView {
    private var coreNetworkHealthRow: NetworkHealthRowState {
        SystemTabViewModel.networkHealthRows(session: appSession).first { $0.id == "core" }
            ?? NetworkHealthRowState(
                id: "core",
                title: tr("ui.network_health.row.core"),
                statusText: tr("ui.network_health.status.unavailable"),
                detail: nil,
                symbol: "bolt.horizontal.circle",
                kind: .info)
    }

    private var systemProxyHealthRow: NetworkHealthRowState {
        SystemTabViewModel.networkHealthRows(session: appSession).first { $0.id == "system_proxy" }
            ?? NetworkHealthRowState(
                id: "system_proxy",
                title: tr("ui.network_health.row.system_proxy"),
                statusText: tr("ui.network_health.status.unavailable"),
                detail: nil,
                symbol: "network",
                kind: .info)
    }

    private var tunHealthRow: NetworkHealthRowState {
        SystemTabViewModel.networkHealthRows(session: appSession).first { $0.id == "tun" }
            ?? NetworkHealthRowState(
                id: "tun",
                title: tr("ui.network_health.row.tun"),
                statusText: tr("ui.network_health.status.unavailable"),
                detail: nil,
                symbol: "shield.lefthalf.filled",
                kind: .info)
    }

    private var pathNetworkHealthRow: NetworkHealthRowState {
        let summary = SystemTabViewModel.networkHealthSummary(session: appSession)
        return NetworkHealthRowState(
            id: "path",
            title: tr("ui.network_health.row.path"),
            statusText: summary.message,
            detail: nil,
            symbol: summary.symbol,
            kind: summary.kind)
    }

    private func networkHealthColor(for kind: SystemFeedbackKind) -> Color {
        switch kind {
        case .error:
            self.nativeCritical.opacity(T.Opacity.solid)
        case .warning:
            self.nativeWarning.opacity(T.Opacity.solid)
        case .success:
            self.nativePositive.opacity(T.Opacity.solid)
        case .info:
            self.nativeInfo.opacity(T.Opacity.solid)
        }
    }

    private func networkHealthRow(_ row: NetworkHealthRowState) -> some View {
        HStack(alignment: .top, spacing: T.space8) {
            self.settingsRowLabel(symbol: row.symbol, title: row.title)
                .layoutPriority(1)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: T.space2) {
                Text(row.statusText)
                    .font(.app(size: T.FontSize.caption, weight: .semibold))
                    .foregroundStyle(self.networkHealthColor(for: row.kind))
                    .lineLimit(1)
            }
        }
        .menuRowPadding(vertical: T.space4)
    }

    private func proxyFeatureControlCard(
        _ row: NetworkHealthRowState,
        isOn: Binding<Bool>,
        isDisabled: Bool,
        hint: String? = nil) -> some View
    {
        VStack(alignment: .leading, spacing: T.space4) {
            HStack(alignment: .center, spacing: T.space8) {
                self.settingsRowLabel(symbol: row.symbol, title: row.title)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                Text(row.statusText)
                    .font(.app(size: T.FontSize.caption, weight: .semibold))
                    .foregroundStyle(self.networkHealthColor(for: row.kind))
                    .lineLimit(1)

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(isDisabled)
            }

            if let hint = hint?.trimmedNonEmpty {
                self.settingsInlineHintRow(
                    text: hint,
                    color: self.nativeCritical.opacity(T.Opacity.solid),
                    symbol: "exclamationmark.triangle.fill")
            }
        }
        .menuRowPadding(vertical: T.space6)
    }

    var networkHealthSectionCard: some View {
        return SystemSettingsSectionCard(
            title: tr("ui.section.network_health"),
            symbol: "waveform.path.ecg",
            headerTint: nativeTertiaryLabel)
        {
            VStack(alignment: .leading, spacing: T.space4) {
                self.networkHealthRow(self.pathNetworkHealthRow)
                self.networkHealthRow(self.coreNetworkHealthRow)
            }
            .menuRowPadding(vertical: T.space4)
        }
    }

    var systemCoreToggleItems: [(id: String, title: String, symbol: String, isOn: Binding<Bool>)] {
        [
            (
                AppSession.EditableCoreSetting.allowLan.id,
                tr("ui.settings.allow_lan"),
                "network",
                self.editableCoreSettingBinding(.allowLan)),
            (
                AppSession.EditableCoreSetting.ipv6.id,
                tr("ui.settings.ipv6"),
                "globe",
                self.editableCoreSettingBinding(.ipv6)),
            (
                AppSession.EditableCoreSetting.tcpConcurrent.id,
                tr("ui.settings.tcp_concurrent"),
                "point.3.connected.trianglepath.dotted",
                self.editableCoreSettingBinding(.tcpConcurrent)),
        ]
    }

    var systemMaintenanceActions: [(titleKey: String, symbol: String, action: @MainActor () async -> Void)] {
        [
            ("ui.action.flush_fakeip_cache", "externaldrive.badge.minus", { await appSession.flushFakeIPCache() }),
            ("ui.action.flush_dns_cache", "network.badge.shield.half.filled", { await appSession.flushDNSCache() }),
        ]
    }

    var selectedCoreLogLevel: String {
        appSession.stringValue(for: .logLevel)
    }

    var proxyControlSettingsSectionCard: some View {
        SystemSettingsSectionCard(
            title: tr("ui.section.proxy_control"),
            symbol: "antenna.radiowaves.left.and.right",
            headerTint: nativeTertiaryLabel)
        {
            if !appSession.isRemoteTarget {
                HStack(spacing: T.space8) {
                    self.settingsRowLabel(symbol: "doc.text", title: tr("ui.quick.switch_config"))
                        .layoutPriority(1)
                    Spacer(minLength: 0)
                    AttachedPopoverMenu(
                        onWillPresent: {
                            self.appSession.refreshRemoteConfigMenuStates()
                        },
                        label: { _ in
                            HStack(spacing: T.space2) {
                                Text(appSession.selectedConfigName)
                                    .foregroundStyle(nativeSecondaryLabel)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Image(systemName: "chevron.right")
                                    .font(.app(size: T.FontSize.caption, weight: .semibold))
                                    .foregroundStyle(nativeTertiaryLabel)
                            }
                            .font(.app(size: T.FontSize.caption, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        },
                        content: { dismiss in
                            self.configMenuContent(dismiss: dismiss)
                        })
                        .frame(width: self.settingsMenuControlWidth, alignment: .trailing)
                        .appBorderedButtonStyle()
                        .controlSize(.small)
                }
                .menuRowPadding(vertical: T.space4)
            }

            if !appSession.isRemoteTarget {
                self.proxyFeatureControlCard(
                    self.systemProxyHealthRow,
                    isOn: Binding(
                        get: { appSession.isSystemProxyEnabled },
                        set: { value in
                            Task { await appSession.toggleSystemProxy(value) }
                        }),
                    isDisabled: appSession.isProxySyncing,
                    hint: appSession.systemProxyOpenFailureHint.map { "\(tr("app.system_proxy.alert.title")): \($0)" })
            }

            self.proxyFeatureControlCard(
                self.tunHealthRow,
                isOn: Binding(
                    get: { appSession.isTunEnabled },
                    set: { value in
                        Task { await appSession.toggleTunMode(value) }
                    }),
                isDisabled: !appSession.isTunToggleEnabled)

            self.settingsCopyProxyCommandRow
        }
    }

    var appSettingsSectionCard: some View {
        SystemSettingsSectionCard(
            title: tr("ui.section.app_settings"),
            symbol: "slider.horizontal.3",
            headerTint: nativeTertiaryLabel)
        {
            self.settingsToggleRow(
                tr("ui.settings.launch_at_login"),
                symbol: "person.crop.circle.badge.checkmark",
                isOn: Binding(
                    get: { appSession.launchAtLoginEnabled },
                    set: { appSession.applyLaunchAtLogin($0) }))

            if !appSession.isRemoteTarget {
                self.settingsToggleRow(
                    tr("ui.settings.auto_start_core"),
                    symbol: "power.circle",
                    isOn: Binding(
                        get: { appSession.autoStartCoreEnabled },
                        set: { appSession.autoStartCoreEnabled = $0 }))

                self.settingsToggleRow(
                    tr("ui.settings.auto_core_network_recovery"),
                    symbol: "network.badge.shield.half.filled",
                    isOn: Binding(
                        get: { appSession.autoManageCoreOnNetworkChangeEnabled },
                        set: { appSession.autoManageCoreOnNetworkChangeEnabled = $0 }))
            }

            self.settingsSelectionRow(.init(
                title: tr("ui.settings.menu_bar_style"),
                symbol: "menubar.rectangle",
                valueText: self.statusBarModeLabel(appSession.statusBarDisplayMode),
                options: StatusBarDisplayMode.allCases,
                optionTitle: self.statusBarModeLabel,
                isSelected: { appSession.statusBarDisplayMode == $0 },
                onSelect: { appSession.statusBarDisplayMode = $0 }))
            self.settingsSelectionRow(.init(
                title: tr("ui.settings.language"),
                symbol: "character.book.closed",
                valueText: appSession.uiLanguage == .zhHans ? tr("ui.language.zh_hans") : tr("ui.language.en"),
                options: AppLanguage.allCases,
                optionTitle: { $0 == .zhHans ? tr("ui.language.zh_hans") : tr("ui.language.en") },
                isSelected: { appSession.uiLanguage == $0 },
                onSelect: appSession.setUILanguage))
            self.settingsSelectionRow(.init(
                title: tr("ui.settings.appearance"),
                symbol: "circle.lefthalf.filled",
                valueText: self.appearanceModeLabel(appSession.appearanceMode),
                options: AppAppearanceMode.allCases,
                optionTitle: self.appearanceModeLabel,
                isSelected: { appSession.appearanceMode == $0 },
                onSelect: appSession.setAppearanceMode))
        }
    }

    var coreSettingsSectionCard: some View {
        SystemSettingsSectionCard(
            title: tr("ui.section.core_settings"),
            symbol: "gearshape.2",
            headerTint: nativeTertiaryLabel)
        {
            ForEach(self.systemCoreToggleItems, id: \.id) { item in
                self.settingsToggleRow(
                    item.title,
                    symbol: item.symbol,
                    isOn: item.isOn,
                    isDisabled: appSession.isCoreSettingSyncing)
            }
            self.settingsSelectionRow(.init(
                title: tr("ui.settings.log_level"),
                symbol: "text.alignleft",
                valueText: self.selectedCoreLogLevel,
                options: ConfigLogLevel.allCases,
                optionTitle: \.rawValue,
                isSelected: { self.selectedCoreLogLevel.caseInsensitiveCompare($0.rawValue) == .orderedSame },
                onSelect: { level in
                    Task { await appSession.applyEditableCoreSetting(.logLevel, to: level.rawValue) }
                }))
        }
    }

    var proxyPortsSectionCard: some View {
        SystemSettingsSectionCard(
            title: tr("ui.section.proxy_ports"),
            symbol: "point.3.connected.trianglepath.dotted",
            headerTint: nativeTertiaryLabel)
        {
            if appSession.isRemoteTarget {
                Text(tr("ui.machine.remote_readonly"))
                    .font(.app(size: T.FontSize.caption, weight: .regular))
                    .foregroundStyle(nativeTertiaryLabel)
                    .padding(.trailing, T.space8)
            }
        } content: {
            VStack(alignment: .leading, spacing: T.space4) {
                self.settingsPortFieldRow(
                    tr("ui.settings.port.port"),
                    symbol: "network",
                    text: $appSession.settingsPort)
                self.settingsPortFieldRow(
                    tr("ui.settings.port.socks"),
                    symbol: "wave.3.right",
                    text: $appSession.settingsSocksPort)
                self.settingsPortFieldRow(
                    tr("ui.settings.port.mixed"),
                    symbol: "arrow.triangle.merge",
                    text: $appSession.settingsMixedPort)
                self.settingsPortFieldRow(
                    tr("ui.settings.port.redir"),
                    symbol: "arrowshape.turn.up.right",
                    text: $appSession.settingsRedirPort)
                self.settingsPortFieldRow(
                    tr("ui.settings.port.tproxy"),
                    symbol: "shield.lefthalf.filled",
                    text: $appSession.settingsTProxyPort)
            }
            .menuRowPadding(vertical: T.space4)
            .disabled(appSession.isRemoteTarget)
        }
    }

    var maintenanceSectionCard: some View {
        SystemSettingsSectionCard(
            title: tr("ui.section.maintenance"),
            symbol: "wrench.and.screwdriver",
            headerTint: nativeTertiaryLabel)
        {
            VStack(alignment: .leading, spacing: T.space4) {
                self.maintenanceCoreUpgradeButton()

                if let feedback = self.maintenanceCoreUpgradeFeedbackState {
                    self.settingsFeedbackBanner(
                        text: feedback.message,
                        color: feedback.color,
                        symbol: feedback.symbol,
                        isLoading: feedback.isLoading)
                }

                HStack(spacing: T.space6) {
                    ForEach(self.systemMaintenanceActions, id: \.titleKey) { item in
                        self.maintenanceActionButton(tr(item.titleKey), symbol: item.symbol) {
                            await item.action()
                        }
                    }
                }

                if !appSession.isRemoteTarget {
                    HStack(spacing: T.space6) {
                        Button {
                            appSession.showCoreDirectoryInFinder()
                        } label: {
                            Label(tr("ui.action.open_core_directory"), systemImage: "folder")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .appBorderedButtonStyle()
                        .controlSize(.small)
                    }
                }
            }
            .menuRowPadding(vertical: T.space4)
        }
    }
}
