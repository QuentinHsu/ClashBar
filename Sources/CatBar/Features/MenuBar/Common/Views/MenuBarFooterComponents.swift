import SwiftUI

extension MenuBarRootView {
    var footerBar: some View {
        let mihomoRepositoryURL = URL(string: "https://github.com/MetaCubeX/mihomo")
        let mihomoSymbol = "cpu"

        return VStack(spacing: 0) {
            HStack(spacing: MenuBarLayoutTokens.space6) {
                HStack(spacing: MenuBarLayoutTokens.space6) {
                    self.footerInfo(
                        tr("ui.footer.core_mihomo", appSession.version),
                        url: mihomoRepositoryURL,
                        iconSystemName: mihomoSymbol)

                    self.footerCoreUpgradeControl
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                self.footerVersionInfo
                    .fixedSize(horizontal: true, vertical: false)
            }
            .menuRowPadding(vertical: MenuBarLayoutTokens.space2)
            .background(self.footerSurfaceBackground)
            .padding(.bottom, MenuBarLayoutTokens.space8)
        }
    }

    var footerSurfaceBackground: some View {
        RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
            .fill(self.nativeControlFill.opacity(self.isDarkAppearance ? 0.54 : 0.38))
            .overlay {
                RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                    .stroke(
                        self.nativeControlBorder.opacity(self.isDarkAppearance ? 0.40 : 0.12),
                        lineWidth: MenuBarLayoutTokens.stroke)
            }
    }

    @ViewBuilder
    func footerInfo(_ text: String, url: URL?, iconSystemName: String? = nil) -> some View {
        if let url {
            Link(destination: url) {
                self.footerInfoLabel(text, iconSystemName: iconSystemName)
            }
            .buttonStyle(.plain)
        } else {
            self.footerInfoLabel(text, iconSystemName: iconSystemName)
        }
    }

    func footerInfoLabel(_ text: String, iconSystemName: String?) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            if let iconSystemName {
                Image(systemName: iconSystemName)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                    .foregroundStyle(self.nativeSecondaryLabel)
            }

            Text(text)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(self.nativeSecondaryLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
                .allowsTightening(true)
        }
        .help(text)
    }

    var footerCoreUpgradeControl: some View {
        self.compactAsyncIconButton(
            symbol: self.footerCoreUpgradeButtonSymbolName ?? "arrow.down.circle",
            label: self.footerCoreUpgradeButtonTitle,
            tint: self.footerCoreUpgradeButtonTint,
            baseTint: self.nativeSecondaryLabel,
            isLoading: self.appSession.isCoreUpgradeInFlight,
            size: 18,
            fontSize: MenuBarLayoutTokens.FontSize.caption,
            hierarchicalSymbol: true)
        {
            await self.appSession.upgradeCore()
        }
        .disabled(!self.isFooterCoreUpgradeEnabled)
        .help(self.footerCoreUpgradeButtonHelp)
    }

    var isFooterCoreUpgradeEnabled: Bool {
        self.appSession.isCoreUpgradeAvailable && !self.appSession.isCoreUpgradeInFlight
    }

    var footerCoreUpgradeButtonTitle: String {
        switch self.appSession.coreUpgradeState {
        case .idle:
            tr("ui.action.upgrade_core")
        case .running:
            tr("ui.footer.core_upgrade.running")
        case .succeeded:
            tr("ui.footer.core_upgrade.success")
        case .alreadyLatest:
            tr("ui.footer.core_upgrade.latest")
        case .failed:
            tr("ui.footer.core_upgrade.failed")
        }
    }

    var footerCoreUpgradeButtonSymbolName: String? {
        switch self.appSession.coreUpgradeState {
        case .idle:
            "arrow.down.circle"
        case .running:
            nil
        case .succeeded:
            "checkmark.circle.fill"
        case .alreadyLatest:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    var footerCoreUpgradeButtonTint: Color {
        switch self.appSession.coreUpgradeState {
        case .idle, .running:
            self.nativeAccent.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .succeeded, .alreadyLatest:
            self.nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .failed:
            self.nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid)
        }
    }

    var footerCoreUpgradeButtonHelp: String {
        if !self.appSession.isCoreUpgradeAvailable {
            return tr("ui.footer.core_upgrade.help.disabled")
        }

        switch self.appSession.coreUpgradeState {
        case .idle:
            return tr("ui.footer.core_upgrade.help")
        case .running:
            return tr("ui.footer.core_upgrade.help.running")
        case .succeeded:
            return tr("ui.footer.core_upgrade.help.success")
        case let .alreadyLatest(version):
            if let version, !version.isEmpty {
                return tr("ui.footer.core_upgrade.help.latest_version", version)
            }
            return tr("ui.footer.core_upgrade.help.latest")
        case let .failed(message):
            return tr("ui.footer.core_upgrade.help.failed", message)
        }
    }

    @ViewBuilder
    var footerVersionInfo: some View {
        if self.appSession.supportsInAppUpdates {
            Button {
                Task {
                    await self.appSession.checkForAppUpdates()
                }
            } label: {
                self.footerVersionBadge(
                    text: tr("ui.footer.version", self.appSession.currentAppVersionText),
                    symbol: "arrow.clockwise",
                    tint: self.nativeSecondaryLabel,
                    emphasized: false)
            }
            .buttonStyle(.plain)
            .help(tr("ui.footer.version_check_help"))
            .accessibilityLabel(tr(
                "ui.footer.version_check_accessibility",
                self.appSession.currentAppVersionText))
        } else if let update = self.appSession.availableAppUpdate {
            Link(destination: update.releaseURL) {
                self.footerVersionBadge(
                    text: tr("ui.footer.version", update.displayVersion),
                    symbol: "arrow.down.circle.fill",
                    tint: self.nativeAccent.opacity(MenuBarLayoutTokens.Opacity.solid),
                    emphasized: true)
            }
            .buttonStyle(.plain)
            .help(tr("ui.footer.version_update_help", update.displayVersion))
            .accessibilityLabel(tr(
                "ui.footer.version_update_accessibility",
                self.appSession.currentAppVersionText,
                update.displayVersion))
        } else if self.appSession.isLatestAppReleaseCheckInFlight {
            self.footerVersionBadge(
                text: tr("ui.footer.version", self.appSession.currentAppVersionText),
                symbol: "arrow.triangle.2.circlepath",
                tint: self.nativeSecondaryLabel,
                emphasized: false)
            .help(tr("ui.footer.version_check_running"))
        } else {
            Button {
                Task {
                    await self.appSession.checkForAppUpdates()
                }
            } label: {
                self.footerVersionBadge(
                    text: tr("ui.footer.version", self.appSession.currentAppVersionText),
                    symbol: "arrow.clockwise",
                    tint: self.nativeSecondaryLabel,
                    emphasized: false)
            }
            .buttonStyle(.plain)
            .help(tr("ui.footer.version_check_help"))
            .accessibilityLabel(tr(
                "ui.footer.version_check_accessibility",
                self.appSession.currentAppVersionText))
        }
    }

    func footerVersionBadge(text: String, symbol: String?, tint: Color, emphasized: Bool) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            }

            Text(text)
                .font(.app(
                    size: MenuBarLayoutTokens.FontSize.caption,
                    weight: emphasized ? .bold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(MenuBarLayoutTokens.minimumScale)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, MenuBarLayoutTokens.space6)
        .padding(.vertical, MenuBarLayoutTokens.space2)
    }
}
