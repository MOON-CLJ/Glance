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

    /// 重新加载子节点（已加载过的目录才刷新），保留展开状态
    func reloadChildren() {
        guard isDirectory, isLoaded else { return }
        let latest = FileService.shared.listDirectory(path: path)
        children = Self.merge(existing: children ?? [], with: latest)
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

    /// 递归展开到目标文件路径，返回是否找到
    @discardableResult
    func expandToPath(_ targetPath: String) -> Bool {
        let normalizedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard isDirectory else { return normalizedPath == targetPath }
        if !isLoaded { loadChildren() }
        guard let children = children else { return false }
        for child in children {
            let childPath = child.path.hasSuffix("/") ? String(child.path.dropLast()) : child.path
            if childPath == targetPath {
                isExpanded = true
                return true
            }
            if child.isDirectory && targetPath.hasPrefix(childPath + "/") {
                if child.expandToPath(targetPath) {
                    isExpanded = true
                    return true
                }
            }
        }
        return false
    }

    /// 增量合并：保留已存在节点的展开状态和 children，移除已删除的，插入新增的
    static func merge(existing: [FileNode], with latest: [FileNode]) -> [FileNode] {
        let existingMap = Dictionary(existing.map { ($0.path, $0) }, uniquingKeysWith: { _, new in new })
        return latest.map { newNode in
            if let old = existingMap[newNode.path] {
                // 对已展开且已加载的子目录递归 merge
                if old.isDirectory, old.isLoaded, let oldChildren = old.children {
                    let latestChildren = FileService.shared.listDirectory(path: old.path)
                    old.children = merge(existing: oldChildren, with: latestChildren)
                }
                return old
            }
            return newNode
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
