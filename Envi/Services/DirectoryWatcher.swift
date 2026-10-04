import Foundation

/// Watches a directory (and its contents) for changes via FSEvents so external
/// edits to existing files are picked up, not only add/remove/rename.
final class DirectoryWatcher {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.envi.dirwatch", qos: .utility)
    private var debounceWork: DispatchWorkItem?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func watch(url: URL) {
        stop()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let paths = [url.path] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.scheduleNotify()
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    private func scheduleNotify() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.onChange()
            }
        }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    deinit {
        stop()
    }
}
