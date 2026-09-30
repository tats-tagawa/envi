import SwiftUI

struct StatusBarView: View {
    let note: Note?

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            if let note {
                Text("Created \(Self.formatter.string(from: note.createdAt))")
                Text("·")
                Text("Updated \(Self.formatter.string(from: note.updatedAt))")
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
