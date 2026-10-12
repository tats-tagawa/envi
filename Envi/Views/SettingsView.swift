import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.sidebar.rawValue
    @AppStorage(AppearanceMode.storageKey) private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("vimModeEnabled") private var vimModeEnabled = false
    @AppStorage("vimJKMovesByDisplayLines") private var vimJKMovesByDisplayLines = true
    @AppStorage(ModifiedDateOrder.storageKey) private var dateOrder = ModifiedDateOrder.monthDayYear.rawValue
    @AppStorage(ModifiedDateFormat.use24HourKey) private var use24Hour = false
    @AppStorage(HotKeyDefaults.enabledKey) private var hotKeyEnabled = false
    @AppStorage(HotKeyDefaults.keyCodeKey) private var hotKeyCode = Int(HotKeyDefaults.defaultKeyCode)
    @AppStorage(HotKeyDefaults.modifiersKey) private var hotKeyModifiers = Int(HotKeyDefaults.defaultModifiers)
    @AppStorage(HotKeyDefaults.lastRegisterFailedKey) private var hotKeyRegisterFailed = false
    @State private var isRecordingHotKey = false

    private var hotKeyDisplay: String {
        HotKeyDefaults.displayString(
            keyCode: UInt32(hotKeyCode),
            carbonModifiers: UInt32(hotKeyModifiers)
        )
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Layout") {
                Picker("Layout", selection: $layoutMode) {
                    ForEach(LayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Editing") {
                Toggle("Vim mode (note body)", isOn: $vimModeEnabled)
                Toggle("j/k move by wrapped lines", isOn: $vimJKMovesByDisplayLines)
                    .disabled(!vimModeEnabled)
                Text("When enabled, j and k step one soft-wrapped screen line instead of jumping to the next newline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Date Modified") {
                Picker("Date order", selection: $dateOrder) {
                    ForEach(ModifiedDateOrder.allCases) { order in
                        Text(order.title).tag(order.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                Toggle("24-hour time", isOn: $use24Hour)

                Text("Recent notes show relative time (within 6 hours), or Today / Yesterday. Older notes use a short medium date; hover for the full timestamp.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Activation") {
                Toggle("Global bring-to-front hotkey", isOn: $hotKeyEnabled)

                HStack {
                    Text("Shortcut")
                    Spacer()
                    if isRecordingHotKey {
                        Text("Press shortcut…")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Text(hotKeyDisplay)
                            .font(.body.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Button(isRecordingHotKey ? "Cancel" : "Change…") {
                        isRecordingHotKey.toggle()
                    }
                }
                .disabled(!hotKeyEnabled)

                if hotKeyEnabled, hotKeyRegisterFailed {
                    Text("Could not register this shortcut. It may conflict with another app — try a different combination.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("While enabled, closing the window hides envi instead of quitting, so the hotkey can bring it back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
        .background(HotKeyRecorder(isRecording: $isRecordingHotKey) { event in
            let carbon = HotKeyDefaults.carbonModifiers(from: event.modifierFlags)
            guard carbon != 0 else { return }
            hotKeyCode = Int(event.keyCode)
            hotKeyModifiers = Int(carbon)
            hotKeyEnabled = true
            isRecordingHotKey = false
        })
    }
}

/// Captures the next key-down with modifiers while recording a global hotkey.
private struct HotKeyRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onCapture = onCapture
        if isRecording {
            context.coordinator.start()
        } else {
            context.coordinator.stop()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onCapture: ((NSEvent) -> Void)?
        private var monitor: Any?

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // Ignore bare modifier taps.
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard !flags.isEmpty else { return event }
                if event.keyCode == UInt16(kVK_Escape) {
                    return nil
                }
                self?.onCapture?(event)
                return nil
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            stop()
        }
    }
}
