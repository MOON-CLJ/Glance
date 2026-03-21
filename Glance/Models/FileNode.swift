import Foundation

class FileNode: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let isSymlink: Bool
    let isHidden: Bool
    @Published var children: [FileNode]?
    @Published var isExpanded = false

    var isLoaded: Bool { children != nil }

    init(name: String, path: String, isDirectory: Bool, isSymlink: Bool = false, isHidden: Bool = false) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.isSymlink = isSymlink
        self.isHidden = isHidden
    }

    func loadChildren() {
        guard isDirectory, !isLoaded else { return }
        children = FileService.shared.listDirectory(path: path)
    }

    /// 重新加载子节点（已加载过的目录才刷新）
    func reloadChildren() {
        guard isDirectory, isLoaded else { return }
        children = FileService.shared.listDirectory(path: path)
    }

    func toggleExpanded() {
        if !isLoaded {
            loadChildren()
        }
        isExpanded.toggle()
    }

    /// 在树中查找路径匹配的节点并刷新其 children
    func refreshNode(forPath targetPath: String) {
        if self.path == targetPath {
            reloadChildren()
            return
        }
        // 只在已加载的子目录中递归查找
        guard let children = children else { return }
        for child in children where child.isDirectory {
            if targetPath.hasPrefix(child.path + "/") || targetPath == child.path {
                child.refreshNode(forPath: targetPath)
                return
            }
        }
    }
}

extension FileNode: Hashable {
    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
