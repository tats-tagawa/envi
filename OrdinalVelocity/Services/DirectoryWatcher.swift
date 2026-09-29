import Foundation

/// Watches a directory for changes using DispatchSource (FSEvents under the hood on Darwin).
final class DirectoryWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
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
        sources = [source]
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        sources.forEach { $0.cancel() }
        sources.removeAll()
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
