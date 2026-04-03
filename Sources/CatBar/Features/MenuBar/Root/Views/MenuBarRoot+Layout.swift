import SwiftUI

extension MenuBarRootView {
    private var preferredStaticTabScrollAreaHeight: CGFloat? {
        switch self.rootViewModel.currentTab {
        case .connections:
            360
        case .logs:
            360
        default:
            nil
        }
    }

    private var cachedCurrentTabContentHeight: CGFloat? {
        let cached = self.tabContentHeights[self.rootViewModel.currentTab] ?? 0
        guard cached > 0 else { return nil }
        return cached
    }

    private var hasMeasuredFixedSections: Bool {
        topHeaderHeight > 0 && modeAndTabSectionHeight > 0 && footerBarHeight > 0
    }

    private var hasResolvedCurrentTabLayout: Bool {
        self.hasMeasuredFixedSections && self.currentTabContentHeight > 0
    }

    private var fixedSectionHeight: CGFloat {
        topHeaderHeight + modeAndTabSectionHeight + footerBarHeight + connectionsControlHeight
    }

    private var unresolvedTargetPanelHeight: CGFloat {
        if let cachedCurrentTabContentHeight {
            return min(
                self.fixedSectionHeight + cachedCurrentTabContentHeight,
                popoverLayoutModel.maxPanelHeight)
        }

        let minimumPanelHeight = min(popoverLayoutModel.minPanelHeight, popoverLayoutModel.maxPanelHeight)
        let preferredStaticHeight = self.preferredStaticTabScrollAreaHeight.map { self.fixedSectionHeight + $0 } ?? 0
        return min(
            popoverLayoutModel.maxPanelHeight,
            max(minimumPanelHeight, max(self.fixedSectionHeight + 1, preferredStaticHeight)))
    }

    private var fallbackTabScrollAreaHeight: CGFloat {
        max(0, self.unresolvedTargetPanelHeight - self.fixedSectionHeight)
    }

    private var availableTabScrollAreaHeight: CGFloat {
        max(0, popoverLayoutModel.maxPanelHeight - self.fixedSectionHeight)
    }

    var tabScrollAreaHeight: CGFloat {
        guard self.hasResolvedCurrentTabLayout else { return self.fallbackTabScrollAreaHeight }
        return min(max(1, self.currentTabContentHeight), self.availableTabScrollAreaHeight)
    }

    var resolvedPanelHeight: CGFloat {
        guard self.hasResolvedCurrentTabLayout else { return self.unresolvedTargetPanelHeight }
        return max(1, min(self.fixedSectionHeight + self.tabScrollAreaHeight, popoverLayoutModel.maxPanelHeight))
    }

    enum SectionHeightTarget {
        case header
        case modeAndTab
        case connectionsControl
        case footer
    }

    func updateSectionHeight(_ measured: CGFloat, target: SectionHeightTarget) {
        let normalized = max(0, measured)

        switch target {
        case .header:
            if abs(topHeaderHeight - normalized) > 0.5 {
                topHeaderHeight = normalized
            }
        case .modeAndTab:
            if abs(modeAndTabSectionHeight - normalized) > 0.5 {
                modeAndTabSectionHeight = normalized
            }
        case .connectionsControl:
            if abs(connectionsControlHeight - normalized) > 0.5 {
                connectionsControlHeight = normalized
            }
        case .footer:
            if abs(footerBarHeight - normalized) > 0.5 {
                footerBarHeight = normalized
            }
        }
    }

    func updateCurrentTabContentHeight(_ measured: CGFloat, for tab: RootTab) {
        guard tab == self.rootViewModel.currentTab else { return }

        let normalized = max(1, measured)
        guard abs(self.currentTabContentHeight - normalized) > 0.5 else { return }

        self.currentTabContentHeight = normalized
        self.tabContentHeights[tab] = normalized
    }

    func publishPreferredPanelHeight() {
        guard self.hasResolvedCurrentTabLayout else { return }
        popoverLayoutModel.requestPanelHeight(max(1, self.resolvedPanelHeight.rounded(.up)))
    }
}
