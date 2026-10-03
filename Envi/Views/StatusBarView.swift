import SwiftUI

/// Compact footer used for Vim mode indication.
struct StatusBarView: View {
    var vimMode: VimMode = .insert

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Text(vimMode.statusLabel)
                .monospaced()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(.bar)
    }
}
