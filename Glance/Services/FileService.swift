import Foundation

class FileService {
    static let shared = FileService()

    private let fdPath = "/opt/homebrew/bin/fd"

    private init() {}

    /// 列出目录内容，目录优先，通过 fd 自动遵守 .gitignore
    func listDirectory(path: String) -> [FileNode] {
        let items = runFd(in: path)

        var dirs: [FileNode] = []
        var files: [FileNode] = []

        for fullPath in items {
            let name = (fullPath as NSString).lastPathComponent
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)

            let node = FileNode(name: name, path: fullPath, isDirectory: isDir.boolValue)
            if isDir.boolValue {
                dirs.append(node)
            } else {
                files.append(node)
            }
        }

        return dirs + files
    }

    /// 用 fd --max-depth 1 列出目录直接子项，自动遵守 .gitignore
    private func runFd(in directory: String) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: fdPath)
        process.arguments = [
            "--max-depth", "1",
            "--hidden",
            "--exclude", ".git",
            "--exclude", ".DS_Store",
            ".", directory
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return output
                .split(separator: "\n")
                .map { String($0) }
                .sorted { a, b in
                    (a as NSString).lastPathComponent.localizedStandardCompare(
                        (b as NSString).lastPathComponent
                    ) == .orderedAscending
                }
        } catch {
            return []
        }
    }

    /// 读取文件内容
    func readFile(path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// 根据文件名返回 SF Symbol 图标名
    func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "doc.text"
        case "go": return "doc.text"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json", "yaml", "yml", "toml": return "doc.text"
        case "md": return "doc.richtext"
        case "sh", "bash", "zsh": return "terminal"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        default: return "doc"
        }
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
