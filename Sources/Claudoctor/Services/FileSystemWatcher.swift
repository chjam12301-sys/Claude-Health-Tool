import CoreServices
import Foundation

/// FSEvents 封装，监听目录递归变化，1 秒去抖合并（TechSpec §09.1 / BR-022 / CD-012）。
final class FileSystemWatcher {
    private let path: URL
    private let debounceInterval: TimeInterval
    private var stream: FSEventStreamRef?
    private var debounceWorkItem: DispatchWorkItem?
    private var callback: (() -> Void)?
    private let queue = DispatchQueue(label: "com.sunnycao.claudoctor.fswatcher")

    init(path: URL, debounceInterval: TimeInterval = 1.0) {
        self.path = path
        self.debounceInterval = debounceInterval
    }

    /// 开始监听。callback 在主队列调用（UI 更新安全）。失败时降级为不监听（CD-012）。
    func start(callback: @escaping () -> Void) {
        self.callback = callback

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )

        let streamCallback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.scheduleDebounced()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            streamCallback,
            &context,
            [path.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            flags
        ) else {
            NSLog("[CD-012] FSEventStreamCreate failed; falling back to periodic scan only")
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        if !FSEventStreamStart(stream) {
            NSLog("[CD-012] FSEventStreamStart failed; falling back to periodic scan only")
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        debounceWorkItem?.cancel()
    }

    /// 1 秒内多次事件合并触发一次（BR-022）。
    private func scheduleDebounced() {
        queue.async { [weak self] in
            guard let self else { return }
            self.debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let callback = self.callback else { return }
                DispatchQueue.main.async { callback() }
            }
            self.debounceWorkItem = work
            self.queue.asyncAfter(deadline: .now() + self.debounceInterval, execute: work)
        }
    }

    deinit { stop() }
}
