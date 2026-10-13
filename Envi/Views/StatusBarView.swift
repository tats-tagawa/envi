import SwiftUI

/// Compact footer used for Vim mode indication.
struct StatusBarView: View {
    var vimMode: VimMode = .insert
    @Environment(\.themeStore) private var themeStore

    var body: some View {
        let theme = themeStore.resolvedColors
        HStack {
            Spacer(minLength: 0)
            Text(vimMode.statusLabel)
                .monospaced()
        }
        .font(.caption)
        .foregroundStyle(theme.statusBarText.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(theme.statusBarBackground.color)
    }
}
