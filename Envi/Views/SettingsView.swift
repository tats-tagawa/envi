import SwiftUI

struct SettingsView: View {
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.sidebar.rawValue

    var body: some View {
        Form {
            Picker("Layout", selection: $layoutMode) {
                ForEach(LayoutMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.radioGroup)
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding()
    }
}
