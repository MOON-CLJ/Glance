import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var projects: [ProjectState] = []
    @Published var activeProjectIndex: Int?
    @Published var showFileSearch = false
    @Published var showGrepSearch = false
    @Published var showInFileSearch = false
    /// 文件变化计数器，FileWatcher 触发时递增，用于通知预览刷新
    @Published var fileChangeCounter: Int = 0
    /// 打开文件后需要跳转的行号和高亮文本
    @Published var pendingScrollToLine: Int? = nil
    @Published var pendingHighlightText: String? = nil

    private var projectCancellables: [UUID: AnyCancellable] = [:]
    private let savedProjectsKey = "openedProjectPaths"

    init() {
        restoreProjects()
    }

    var activeProject: ProjectState? {
        guard let idx = activeProjectIndex, projects.indices.contains(idx) else {
            return nil
        }
        return projects[idx]
    }

    /// 当前激活的文件路径
    var activeFile: String? {
        activeProject?.activeFile
    }

    /// 当前激活的目录路径
    var activeRootPath: String? {
        activeProject?.path
    }

    /// 添加目录（弹出选择面板）
    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project folder"

        if panel.runModal() == .OK, let url = panel.url {
            addFolder(path: url.path)
        }
    }

    /// 添加目录（指定路径）
    func addFolder(path: String) {
        // 如果已打开则激活
        if let idx = projects.firstIndex(where: { $0.path == path }) {
            activeProjectIndex = idx
            return
        }

        let project = ProjectState(path: path)
        // 监听 ProjectState 的变化，转发给 AppState 让 SwiftUI 刷新
        projectCancellables[project.id] = project.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        projects.append(project)
        activeProjectIndex = projects.count - 1
        saveProjects()
    }

    /// 关闭目录
    func closeProject(at index: Int) {
        guard projects.indices.contains(index) else { return }
        let removed = projects[index]
        projectCancellables.removeValue(forKey: removed.id)
        projects.remove(at: index)

        if projects.isEmpty {
            activeProjectIndex = nil
        } else if let active = activeProjectIndex {
            if active >= projects.count {
                activeProjectIndex = projects.count - 1
            } else if active > index {
                activeProjectIndex = active - 1
            }
        }
        saveProjects()
    }

    // MARK: - 持久化

    private func saveProjects() {
        let paths = projects.map { $0.path }
        UserDefaults.standard.set(paths, forKey: savedProjectsKey)
    }

    private func restoreProjects() {
        guard let paths = UserDefaults.standard.stringArray(forKey: savedProjectsKey) else { return }
        let fm = FileManager.default
        for path in paths {
            // 只恢复仍然存在的目录
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                addFolder(path: path)
            }
        }
    }
}
