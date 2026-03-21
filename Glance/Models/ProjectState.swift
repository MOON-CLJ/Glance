import Foundation

class ProjectState: Identifiable, ObservableObject {
    let id = UUID()
    let path: String
    let name: String

    @Published var openedFiles: [String] = []
    @Published var activeFileIndex: Int?
    /// git 文件状态: [相对路径: 状态码]
    @Published var gitStatusMap: [String: String] = [:]

    init(path: String) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
        refreshGitStatus()
    }

    /// 刷新 git 状态
    func refreshGitStatus() {
        Task {
            let map = await CLIService.shared.gitStatus(rootPath: path)
            await MainActor.run {
                self.gitStatusMap = map
            }
        }
    }

    /// 获取指定绝对路径的 git 状态
    func gitStatus(forPath filePath: String) -> String? {
        let relativePath = filePath.hasPrefix(path + "/")
            ? String(filePath.dropFirst(path.count + 1))
            : filePath
        return gitStatusMap[relativePath]
    }

    /// 获取目录的 git 状态（如果目录下有任何变更文件，返回优先级最高的状态）
    func gitStatus(forDirectory dirPath: String) -> String? {
        let prefix = dirPath.hasPrefix(path + "/")
            ? String(dirPath.dropFirst(path.count + 1)) + "/"
            : dirPath + "/"
        var hasUnstaged = false
        var hasStaged = false
        var hasUntracked = false
        for (filePath, status) in gitStatusMap {
            guard filePath.hasPrefix(prefix), status.count == 2 else { continue }
            let workTree = status.last!
            let index = status.first!
            if status == "??" { hasUntracked = true; continue }
            if workTree == "M" || workTree == "D" { hasUnstaged = true }
            if index != " " && index != "?" && workTree == " " { hasStaged = true }
        }
        // 优先级: 未暂存 > 已暂存 > untracked
        if hasUnstaged { return " M" }
        if hasStaged { return "M " }
        if hasUntracked { return "??" }
        return nil
    }

    var activeFile: String? {
        guard let idx = activeFileIndex, openedFiles.indices.contains(idx) else {
            return nil
        }
        return openedFiles[idx]
    }

    /// 打开文件（已打开则激活，未打开则新增 tab）
    func openFile(path: String) {
        if let idx = openedFiles.firstIndex(of: path) {
            activeFileIndex = idx
        } else {
            openedFiles.append(path)
            activeFileIndex = openedFiles.count - 1
        }
    }

    /// 关闭文件 tab
    func closeFile(at index: Int) {
        guard openedFiles.indices.contains(index) else { return }
        openedFiles.remove(at: index)

        if openedFiles.isEmpty {
            activeFileIndex = nil
        } else if let active = activeFileIndex {
            if active >= openedFiles.count {
                activeFileIndex = openedFiles.count - 1
            } else if active > index {
                activeFileIndex = active - 1
            }
        }
    }
}
