import Foundation

struct PresentLogsUseCase {
    private static let retainedLogLimit = 120

    struct Input {
        let logs: [AppErrorLogEntry]
        let selectedSources: Set<AppLogSource>
        let selectedLevels: Set<LogLevelFilter>
        let searchText: String
        let searchTextContent: (AppErrorLogEntry) -> String
        let normalizedLevel: (String) -> String
        let levelFilter: (String) -> LogLevelFilter
    }

    func execute(_ input: Input) -> [AppErrorLogEntry] {
        let source = input.logs.prefix(Self.retainedLogLimit)
        let trimmedKeyword = input.searchText.trimmed
        let needsSourceFilter = !input.selectedSources.isEmpty
        let needsLevelFilter = !input.selectedLevels.isEmpty
        let needsSearch = !trimmedKeyword.isEmpty

        if !needsSearch, !needsSourceFilter, !needsLevelFilter {
            return Array(source)
        }

        var presented: [AppErrorLogEntry] = []
        presented.reserveCapacity(min(input.logs.count, Self.retainedLogLimit))

        for log in source {
            if needsSourceFilter, !input.selectedSources.contains(log.source) {
                continue
            }
            if needsSearch, !input.searchTextContent(log).localizedStandardContains(trimmedKeyword) {
                continue
            }
            if needsLevelFilter {
                let normalizedLevel = input.normalizedLevel(log.level)
                let levelFilter = input.levelFilter(normalizedLevel)
                if !input.selectedLevels.contains(levelFilter) {
                    continue
                }
            }
            presented.append(log)
        }

        return presented
    }
}
