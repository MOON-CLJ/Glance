import Foundation

class ProjectState: Identifiable, ObservableObject {
    let id = UUID()
    let path: String
    let name: String

    @Published var openedFiles: [String] = []
    @Published var activeFileIndex: Int?

    init(path: String) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
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
