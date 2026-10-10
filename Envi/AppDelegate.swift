import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var defaultsObserver: NSObjectProtocol?
    /// Last hotkey config we applied — skip no-op re-registers.
    private var appliedHotKey: (enabled: Bool, keyCode: UInt32, modifiers: UInt32)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        Task { @MainActor in
            self.syncHotKeyFromDefaults()
        }
        // Only react to our hotkey keys. `didChangeNotification` fires for many writes
        // (including our own `lastRegisterFailed` flag) and was waking the main actor idle.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.syncHotKeyFromDefaultsIfNeeded()
            }
        }
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
    private func syncHotKeyFromDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: HotKeyDefaults.enabledKey)
        let keyCode = UInt32(
            defaults.object(forKey: HotKeyDefaults.keyCodeKey) as? Int
                ?? Int(HotKeyDefaults.defaultKeyCode)
        )
        let modifiers = UInt32(
            defaults.object(forKey: HotKeyDefaults.modifiersKey) as? Int
                ?? Int(HotKeyDefaults.defaultModifiers)
        )
        if let applied = appliedHotKey,
           applied.enabled == enabled,
           applied.keyCode == keyCode,
           applied.modifiers == modifiers {
            return
        }
        syncHotKeyFromDefaults()
    }

    @MainActor
    private func syncHotKeyFromDefaults() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: HotKeyDefaults.enabledKey)
        let keyCode = UInt32(
            defaults.object(forKey: HotKeyDefaults.keyCodeKey) as? Int
                ?? Int(HotKeyDefaults.defaultKeyCode)
        )
        let modifiers = UInt32(
            defaults.object(forKey: HotKeyDefaults.modifiersKey) as? Int
                ?? Int(HotKeyDefaults.defaultModifiers)
        )

        appliedHotKey = (enabled, keyCode, modifiers)

        guard enabled else {
            GlobalHotKey.shared.unregister()
            if defaults.bool(forKey: HotKeyDefaults.lastRegisterFailedKey) {
                defaults.set(false, forKey: HotKeyDefaults.lastRegisterFailedKey)
            }
            return
        }

        let ok = GlobalHotKey.shared.register(keyCode: keyCode, carbonModifiers: modifiers) {
            AppDelegate.toggleMainWindow()
        }
        let failed = !ok
        if defaults.bool(forKey: HotKeyDefaults.lastRegisterFailedKey) != failed {
            defaults.set(failed, forKey: HotKeyDefaults.lastRegisterFailedKey)
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
