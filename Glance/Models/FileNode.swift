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

    func loadChildren() async {
        guard isDirectory, !isLoaded else { return }
        children = await FileService.shared.listDirectory(path: path)
    }

    func reloadChildren() async {
        guard isDirectory, isLoaded else { return }
        let latest = await FileService.shared.listDirectory(path: path)
        children = await Self.merge(existing: children ?? [], with: latest)
    }

    func toggleExpanded() async {
        if !isLoaded {
            await loadChildren()
        }
        isExpanded.toggle()
    }

    func refreshNode(forPath targetPath: String) async {
        if self.path == targetPath {
            await reloadChildren()
            return
        }
        guard let children = children else { return }
        for child in children where child.isDirectory {
            if targetPath.hasPrefix(child.path + "/") || targetPath == child.path {
                await child.refreshNode(forPath: targetPath)
                return
            }
        }
    }

    @discardableResult
    func expandToPath(_ targetPath: String) async -> Bool {
        let normalizedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard isDirectory else { return normalizedPath == targetPath }
        if !isLoaded { await loadChildren() }
        guard let children = children else { return false }
        for child in children {
            let childPath = child.path.hasSuffix("/") ? String(child.path.dropLast()) : child.path
            if childPath == targetPath {
                isExpanded = true
                return true
            }
            if child.isDirectory && targetPath.hasPrefix(childPath + "/") {
                if await child.expandToPath(targetPath) {
                    isExpanded = true
                    return true
                }
            }
        }
        return false
    }

    static func merge(existing: [FileNode], with latest: [FileNode]) async -> [FileNode] {
        let existingMap = Dictionary(existing.map { ($0.path, $0) }, uniquingKeysWith: { _, new in new })
        var result: [FileNode] = []
        for newNode in latest {
            if let old = existingMap[newNode.path] {
                if old.isDirectory, old.isLoaded, let oldChildren = old.children {
                    let latestChildren = await FileService.shared.listDirectory(path: old.path)
                    old.children = await merge(existing: oldChildren, with: latestChildren)
                }
                result.append(old)
            } else {
                result.append(newNode)
            }
        }
        return result
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
