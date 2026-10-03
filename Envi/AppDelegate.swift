import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            self.syncHotKeyFromDefaults()
        }
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppDelegate.shared?.syncHotKeyFromDefaults()
            }
        }
        AppDelegate.shared = self
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Stay alive when a global hotkey is enabled so it can re-show the window.
        !UserDefaults.standard.bool(forKey: HotKeyDefaults.enabledKey)
    }

    private static weak var shared: AppDelegate?

    @MainActor
    private func syncHotKeyFromDefaults() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: HotKeyDefaults.enabledKey)
        guard enabled else {
            GlobalHotKey.shared.unregister()
            return
        }

        let keyCode = UInt32(
            defaults.object(forKey: HotKeyDefaults.keyCodeKey) as? Int
                ?? Int(HotKeyDefaults.defaultKeyCode)
        )
        let modifiers = UInt32(
            defaults.object(forKey: HotKeyDefaults.modifiersKey) as? Int
                ?? Int(HotKeyDefaults.defaultModifiers)
        )
        GlobalHotKey.shared.register(keyCode: keyCode, carbonModifiers: modifiers) {
            NotificationCenter.default.post(name: .toggleMainWindow, object: nil)
            AppDelegate.toggleMainWindow()
        }
    }

    @MainActor
    static func toggleMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let windows = NSApp.windows.filter { $0.canBecomeMain || $0.canBecomeKey }
        if let visible = windows.first(where: \.isVisible) {
            visible.orderOut(nil)
        } else if let window = windows.first {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }
}
