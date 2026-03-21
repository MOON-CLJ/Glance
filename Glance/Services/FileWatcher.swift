import Foundation
import CoreServices
import Combine

/// 基于 FSEventStream 递归监听整个目录树的变更
class FileWatcher: ObservableObject {
    /// 变更的目录路径集合，SidebarView 据此精确刷新对应节点
    @Published var changedPaths: Set<String> = []

    private var stream: FSEventStreamRef?
    private var watchingPath: String?

    func watch(path: String) {
        // 如果已经在监听同一个路径，不重复创建
        if watchingPath == path { return }
        stop()
        watchingPath = path

        let pathsToWatch = [path] as CFArray

        // context 中传递 self 指针，供 C 回调使用
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,  // latency: 0.5s 防抖，合并短时间内的多次变更
            UInt32(
                kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagNoDefer
            )
        )

        guard let stream = stream else { return }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        self.watchingPath = nil
    }

    deinit {
        stop()
    }
}

/// FSEventStream 的 C 回调函数
private func fsEventCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()

    guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

    // 收集变更文件的父目录路径（去重）
    var parentDirs = Set<String>()
    for path in paths {
        let parent = (path as NSString).deletingLastPathComponent
        parentDirs.insert(parent)
    }

    DispatchQueue.main.async {
        watcher.changedPaths = parentDirs
    }
}
