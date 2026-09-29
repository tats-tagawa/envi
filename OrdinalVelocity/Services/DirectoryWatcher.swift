import Foundation

/// Watches a directory for changes via DispatchSource and `O_EVTONLY`
/// (kernel file-system events for that path, not the FSEvents API).
final class DirectoryWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.ordinalvelocity.dirwatch", qos: .utility)
    private var debounceWork: DispatchWorkItem?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func watch(url: URL) {
        stop()

        let path = url.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .delete, .rename, .revoke, .link],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleNotify()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.source = source
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        source?.cancel()
        source = nil
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
