import Foundation

class FileNode: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    @Published var children: [FileNode]?
    @Published var isExpanded = false

    var isLoaded: Bool { children != nil }

    init(name: String, path: String, isDirectory: Bool) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
    }

    func loadChildren() {
        guard isDirectory, !isLoaded else { return }
        children = FileService.shared.listDirectory(path: path)
    }

    func toggleExpanded() {
        if !isLoaded {
            loadChildren()
        }
        isExpanded.toggle()
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
