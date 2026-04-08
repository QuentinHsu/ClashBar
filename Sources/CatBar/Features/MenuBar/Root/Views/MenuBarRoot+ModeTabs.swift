import SwiftUI

extension MenuBarRootView {
    var modeAndTabSection: some View {
        VStack(spacing: MenuBarLayoutTokens.space2) {
            self.modeSwitcher
            self.topTabs
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
