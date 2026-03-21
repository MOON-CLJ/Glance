import Foundation

class FileService {
    static let shared = FileService()

    private let ignoredNames: Set<String> = [
        ".git", "node_modules", "__pycache__", ".DS_Store",
        "venv", ".venv", ".idea", ".vscode"
    ]

    private let ignoredExtensions: Set<String> = ["pyc"]

    private init() {}

    /// 列出目录内容，目录优先，过滤忽略项
    func listDirectory(path: String) -> [FileNode] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else {
            return []
        }

        var dirs: [FileNode] = []
        var files: [FileNode] = []

        for item in items.sorted() {
            // 过滤
            if ignoredNames.contains(item) { continue }
            let ext = (item as NSString).pathExtension.lowercased()
            if ignoredExtensions.contains(ext) { continue }

            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)

            let node = FileNode(name: item, path: fullPath, isDirectory: isDir.boolValue)
            if isDir.boolValue {
                dirs.append(node)
            } else {
                files.append(node)
            }
        }

        return dirs + files
    }

    /// 读取文件内容
    func readFile(path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// 检测文件语言（用于语法高亮）
    func detectLanguage(path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        let languageMap: [String: String] = [
            "swift": "swift", "py": "python", "js": "javascript",
            "ts": "typescript", "tsx": "tsx", "jsx": "jsx",
            "go": "go", "rs": "rust", "rb": "ruby",
            "java": "java", "kt": "kotlin", "c": "c",
            "cpp": "cpp", "h": "c", "hpp": "cpp",
            "m": "objectivec", "mm": "objectivec",
            "sh": "bash", "zsh": "bash", "bash": "bash",
            "json": "json", "yaml": "yaml", "yml": "yaml",
            "toml": "toml", "xml": "xml", "html": "html",
            "css": "css", "scss": "scss", "less": "less",
            "md": "markdown", "sql": "sql", "lua": "lua",
            "vim": "vim", "dockerfile": "dockerfile",
            "makefile": "makefile", "cmake": "cmake",
            "r": "r", "php": "php", "pl": "perl",
        ]

        let fileName = (path as NSString).lastPathComponent.lowercased()
        if fileName == "makefile" || fileName == "gnumakefile" { return "makefile" }
        if fileName == "dockerfile" { return "dockerfile" }
        if fileName == "cmakelists.txt" { return "cmake" }

        return languageMap[ext] ?? "plaintext"
    }
}
