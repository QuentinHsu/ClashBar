import AppKit
import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

private struct LogFilterGroupConfiguration<Item: Hashable> {
    let symbol: String
    let allTitle: String
    let allSelected: Bool
    let selectAll: () -> Void
    let items: [Item]
    let itemTitle: (Item) -> String
    let itemSelected: (Item) -> Bool
    let toggleItem: (Item) -> Void
}

extension MenuBarRootView {
    private var logEntryPresentationResolver: LogEntryPresentationResolver {
        LogEntryPresentationResolver(fallbackText: tr("ui.common.na"))
    }

    var logsTabBody: some View {
        let logs = self.logsViewModel.visibleLogs

        return VStack(alignment: .leading, spacing: T.space6) {
            self.logsControlCard(filteredCount: logs.count)

            if logs.isEmpty {
                emptyCard(tr("ui.empty.logs"))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    SeparatedForEach(data: logs, id: \.id, separator: nativeSeparator) { log in
                        self.logEntryRow(log)
                            .padding(.horizontal, T.space4)
                            .padding(.vertical, T.space4)
                    }
                }
            }
        }
    }

    func logsControlCard(filteredCount: Int) -> some View {
        VStack(alignment: .leading, spacing: T.space4) {
            HStack(spacing: T.space6) {
                self.logsSourceFilterButtons

                Spacer(minLength: 0)

                self.fractionSummaryBadge(current: filteredCount, total: appSession.errorLogs.count)
            }
            self.logsSecondaryControlRow
            NonActivatingTextField(
                placeholder: tr("ui.placeholder.search_logs"),
                text: $logsViewModel.searchText,
                style: .roundedBorder,
                font: NSFont.monospacedSystemFont(ofSize: T.FontSize.body, weight: .regular))
        }
        .menuRowPadding(vertical: T.space4)
    }

    var logsSecondaryControlRow: some View {
        HStack(spacing: T.space6) {
            self.logsLevelFilterButtons

            Spacer(minLength: 0)

            self.compactTopIcon(
                "doc.on.doc",
                label: tr("ui.action.copy_all_logs"),
                toneOverride: nativeSecondaryLabel)
            {
                appSession.copyAllLogs()
            }
            .help(tr("ui.action.copy_all_logs"))
            .disabled(appSession.errorLogs.isEmpty)

            self.compactTopIcon(
                "trash",
                label: tr("ui.action.clear_all_logs"),
                role: .destructive,
                warning: true)
            {
                appSession.clearAllLogs()
            }
            .help(tr("ui.action.clear_all_logs"))
            .disabled(appSession.errorLogs.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var logsSourceFilterButtons: some View {
        self.logFilterGroup(.init(
            symbol: "line.3.horizontal.decrease.circle",
            allTitle: tr("ui.log_source.all"),
            allSelected: false,
            selectAll: { self.logsViewModel.selectedSources = [] },
            items: AppLogSource.allCases,
            itemTitle: { self.logSourcePresentation($0).label },
            itemSelected: { self.logsViewModel.selectedSources.contains($0) },
            toggleItem: { self.logsViewModel.toggleSource($0) }))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var logsLevelFilterButtons: some View {
        self.logFilterGroup(.init(
            symbol: "slider.horizontal.3",
            allTitle: tr("ui.log_filter.all"),
            allSelected: false,
            selectAll: { self.logsViewModel.selectedLevels = [] },
            items: LogLevelFilter.allCases,
            itemTitle: { tr($0.titleKey) },
            itemSelected: { self.logsViewModel.selectedLevels.contains($0) },
            toggleItem: { self.logsViewModel.toggleLevel($0) }))
    }

    private func logFilterGroup(
        _ configuration: LogFilterGroupConfiguration<some Hashable>) -> some View
    {
        HStack(spacing: T.space2) {
            Image(systemName: configuration.symbol)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(nativeTertiaryLabel)

            self.filterChipButton(
                title: configuration.allTitle,
                selected: configuration.allSelected,
                action: configuration.selectAll)

            ForEach(configuration.items, id: \.self) { item in
                self.filterChipButton(
                    title: configuration.itemTitle(item),
                    selected: configuration.itemSelected(item),
                    action: { configuration.toggleItem(item) })
            }
        }
    }

    func refreshVisibleLogs() {
        self.logsViewModel.updateVisibleLogs(
            from: self.appSession.errorLogs,
            searchTextContent: { log in self.logSearchTextContent(for: log) },
            normalizedLevel: { level in self.logEntryPresentationResolver.normalizedLevel(level) },
            levelFilter: { level in self.logLevelFilter(level) })
    }

    func logEntryRow(_ log: AppErrorLogEntry) -> some View {
        let presentation = self.logEntryPresentationResolver.parseMessage(log.message)
        let sourceInfo = self.logSourcePresentation(log.source)
        let levelInfo = self.logLevelPresentation(self.normalizedLogLevel(log.level))
        let tone = levelInfo.color
        let symbol = levelInfo.symbol

        return HStack(alignment: .center, spacing: T.space6) {
            Image(systemName: symbol)
                .font(.app(size: T.FontSize.caption, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: T.rowLeadingIcon, height: T.rowLeadingIcon)

            VStack(alignment: .leading, spacing: T.space2) {
                HStack(spacing: T.space2) {
                    Text(sourceInfo.label)
                        .font(.app(size: T.FontSize.caption, weight: .semibold))
                        .foregroundStyle(sourceInfo.color)

                    if let protocolTag = presentation.protocolTag {
                        self.logMetadataSeparator
                        Text(protocolTag)
                            .font(.app(size: T.FontSize.caption, weight: .semibold))
                            .foregroundStyle(self.logProtocolColor(presentation.protocolStyle))
                    }

                    self.logMetadataSeparator
                    Text(ValueFormatter.dateTime(log.timestamp))
                        .font(.app(size: T.FontSize.caption, weight: .regular))
                        .foregroundStyle(nativeTertiaryLabel)
                        .lineLimit(1)
                }

                Text(presentation.mainText)
                    .font(.app(size: T.FontSize.caption, weight: .regular))
                    .foregroundStyle(nativePrimaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                if let detailText = presentation.detailText {
                    Text(detailText)
                        .font(.app(size: T.FontSize.caption, weight: .regular))
                        .foregroundStyle(nativeSecondaryLabel)
                        .lineLimit(2)
                        .padding(.leading, T.space6)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(tone.opacity(T.Opacity.tint))
                                .frame(width: T.space1)
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contextMenu {
            Button {
                appSession.copyLogMessage(log)
            } label: {
                Label(tr("ui.action.copy_log_message"), systemImage: "doc.on.doc")
            }

            Button {
                appSession.copyLogEntry(log)
            } label: {
                Label(tr("ui.action.copy_log_entry"), systemImage: "doc.plaintext")
            }
        }
    }

    var logMetadataSeparator: some View {
        Text("•")
            .font(.app(size: T.FontSize.caption, weight: .regular))
            .foregroundStyle(nativeTertiaryLabel)
    }

    func normalizedLogLevel(_ raw: String) -> String {
        self.logEntryPresentationResolver.normalizedLevel(raw)
    }

    func logSourcePresentation(_ source: AppLogSource) -> (label: String, color: Color) {
        switch source {
        case .catbar:
            (tr("ui.log_source.catbar"), nativeSecondaryLabel)
        case .mihomo:
            (tr("ui.log_source.mihomo"), nativeAccent.opacity(T.Opacity.solid))
        }
    }

    func logLevelPresentation(_ normalizedLevel: String)
        -> (filter: LogLevelFilter, label: String, color: Color, symbol: String)
    {
        let filter = self.logLevelFilter(normalizedLevel)
        switch filter {
        case .error:
            return (
                LogLevelFilter.error,
                tr("ui.log_filter.error"),
                nativeCritical.opacity(T.Opacity.solid),
                "exclamationmark.octagon.fill")
        case .warning:
            return (
                LogLevelFilter.warning,
                tr("ui.log_filter.warning"),
                nativeWarning.opacity(T.Opacity.solid),
                "exclamationmark.triangle.fill")
        case .info:
            return (
                LogLevelFilter.info,
                tr("ui.log_filter.info"),
                nativeAccent.opacity(T.Opacity.solid),
                "info.circle.fill")
        }
    }

    func logLevelFilter(_ normalizedLevel: String) -> LogLevelFilter {
        switch normalizedLevel {
        case "ERROR":
            .error
        case "WARNING":
            .warning
        default:
            .info
        }
    }

    private func logProtocolColor(_ style: LogMessageProtocolStyle) -> Color {
        switch style {
        case .accent:
            nativeAccent.opacity(T.Opacity.solid)
        case .warning:
            nativeWarning.opacity(T.Opacity.solid)
        case .positive:
            nativePositive.opacity(T.Opacity.solid)
        }
    }

    func logSearchTextContent(for log: AppErrorLogEntry) -> String {
        let source = self.logSourcePresentation(log.source).label
        let time = ValueFormatter.dateTime(log.timestamp)
        return self.logEntryPresentationResolver.searchText(for: log, sourceText: source, timeText: time)
    }
}
