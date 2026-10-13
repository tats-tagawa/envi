import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label("General", systemImage: "gearshape") }

            ColorSchemeSettingsPane()
                .tabItem { Label("Color Scheme", systemImage: "paintpalette") }

            KeyboardShortcutsSettingsPane()
                .tabItem { Label("Keyboard Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 540, height: 520)
    }
}

// MARK: - General

private struct GeneralSettingsPane: View {
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.sidebar.rawValue
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

// MARK: - Color Scheme

private struct ColorSchemeSettingsPane: View {
    @Environment(\.themeStore) private var themeStore

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: Binding(
                    get: { themeStore.preset },
                    set: { newValue in
                        // Light↔dark flips recolor a lot of controls; skip transitions that hitch.
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            themeStore.preset = newValue
                        }
                    }
                )) {
                    ForEach(ThemePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                if themeStore.hasOverrides {
                    Text("Some colors are customized for this theme.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Reset Colors") {
                    themeStore.resetOverrides()
                }
                .disabled(!themeStore.hasOverrides)
            }

            Section("Colors") {
                ForEach(AppThemeColors.Token.allCases) { token in
                    ColorPicker(
                        token.title,
                        selection: themeStore.colorBinding(for: token),
                        supportsOpacity: true
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Keyboard Shortcuts

private struct KeyboardShortcutsSettingsPane: View {
    @Environment(\.shortcutStore) private var shortcutStore
    @State private var recordingID: AppShortcutID?
    @State private var conflictMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Remap shortcuts used by envi (Vim motions are not included).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset All") {
                    shortcutStore.resetAll()
                    conflictMessage = nil
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if let conflictMessage {
                Text(conflictMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            List {
                ForEach(AppShortcutID.settingsOrdered) { id in
                    HStack {
                        Text(id.title)
                        Spacer()
                        Text(shortcutStore.binding(for: id).displayString)
                            .font(.body.monospaced())
                            .foregroundStyle(recordingID == id ? Color.accentColor : Color.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(recordingID == id
                                          ? Color.accentColor.opacity(0.15)
                                          : Color(nsColor: .controlBackgroundColor))
                            )
                        Button(recordingID == id ? "Cancel" : "Change…") {
                            conflictMessage = nil
                            recordingID = recordingID == id ? nil : id
                        }
                        .buttonStyle(.borderless)
                        Button("Reset") {
                            shortcutStore.reset(id)
                            conflictMessage = nil
                        }
                        .buttonStyle(.borderless)
                        .disabled(!shortcutStore.isCustom(id) && shortcutStore.conflicts(for: id).isEmpty)
                    }
                }
            }
            .listStyle(.inset)
        }
        .background(ShortcutRecorder(
            recordingID: $recordingID,
            onCapture: { id, binding in
                shortcutStore.setBinding(binding, for: id)
                let conflicts = shortcutStore.conflicts(for: id)
                if conflicts.isEmpty {
                    conflictMessage = nil
                } else {
                    let names = conflicts.map(\.title).joined(separator: ", ")
                    conflictMessage = "Also used by: \(names). Change one of them if both fire."
                }
                recordingID = nil
            },
            onCancel: {
                recordingID = nil
            }
        ))
    }
}

// MARK: - Recorders

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

    func makeCoordinator() -> HotKeyCoordinator { HotKeyCoordinator() }

    final class HotKeyCoordinator {
        var onCapture: ((NSEvent) -> Void)?
        private var monitor: Any?

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
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

        deinit { stop() }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    @Binding var recordingID: AppShortcutID?
    var onCapture: (AppShortcutID, AppShortcutBinding) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.onCapture = onCapture
        context.coordinator.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onCapture = onCapture
        context.coordinator.onCancel = onCancel
        context.coordinator.recordingID = recordingID
        if recordingID != nil {
            context.coordinator.start()
        } else {
            context.coordinator.stop()
        }
    }

    func makeCoordinator() -> ShortcutCoordinator { ShortcutCoordinator() }

    final class ShortcutCoordinator {
        var onCapture: ((AppShortcutID, AppShortcutBinding) -> Void)?
        var onCancel: (() -> Void)?
        var recordingID: AppShortcutID?
        private var monitor: Any?

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let id = self.recordingID else { return event }
                if event.keyCode == UInt16(kVK_Escape) {
                    self.onCancel?()
                    return nil
                }
                guard let binding = AppShortcutBinding.from(event: event) else { return nil }
                self.onCapture?(id, binding)
                return nil
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit { stop() }
    }
}
