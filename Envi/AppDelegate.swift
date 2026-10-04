import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            self.syncHotKeyFromDefaults()
        }
        defaultsObserver = NotificationCenter.default.addObserver(
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

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .flushPendingNotes, object: nil)
    }

    func applicationDidResignActive(_ notification: Notification) {
        NotificationCenter.default.post(name: .flushPendingNotes, object: nil)
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
            defaults.set(false, forKey: HotKeyDefaults.lastRegisterFailedKey)
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
        let ok = GlobalHotKey.shared.register(keyCode: keyCode, carbonModifiers: modifiers) {
            AppDelegate.toggleMainWindow()
        }
        defaults.set(!ok, forKey: HotKeyDefaults.lastRegisterFailedKey)
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
