import Foundation
import CoreServices
import Combine

/// 基于 FSEventStream 递归监听整个目录树的变更
class FileWatcher: ObservableObject {
    /// 自增 ID，确保每次文件变化都触发 SwiftUI onChange
    @Published var changeId: Int = 0
    /// 最近一次变更涉及的目录路径
    var changedPaths: Set<String> = []

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

    // 收集变更文件的父目录路径（去重），过滤 .git 目录
    var parentDirs = Set<String>()
    for path in paths {
        if path.contains("/.git/") || path.hasSuffix("/.git") { continue }
        let parent = (path as NSString).deletingLastPathComponent
        parentDirs.insert(parent)
    }

    guard !parentDirs.isEmpty else { return }

    DispatchQueue.main.async {
        watcher.changedPaths = parentDirs
        watcher.changeId += 1
    }
}
