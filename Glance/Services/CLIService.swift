import Foundation

class CLIService {
    static let shared = CLIService()

    private let fdPath = "/opt/homebrew/bin/fd"
    private let rgPath = "/opt/homebrew/bin/rg"

    private init() {}

    /// 使用 fd 搜索文件名
    func searchFiles(query: String, in directory: String) async -> [FileSearchResult] {
        guard !query.isEmpty else { return [] }

        let output = await runCommand(
            fdPath,
            arguments: [
                "--type", "f",
                "--hidden",
                "--follow",
                "--exclude", ".git",
                "--exclude", "node_modules",
                "--exclude", "__pycache__",
                "--exclude", "*.pyc",
                query,
                directory
            ]
        )

        return output
            .split(separator: "\n")
            .map { line in
                let path = String(line)
                let relativePath = path.hasPrefix(directory)
                    ? String(path.dropFirst(directory.count + 1))
                    : path
                return FileSearchResult(path: path, relativePath: relativePath)
            }
    }

    /// 使用 rg 搜索文件内容
    func searchContent(query: String, in directory: String) async -> [GrepSearchResult] {
        guard !query.isEmpty else { return [] }

        let output = await runCommand(
            rgPath,
            arguments: [
                "--line-number",
                "--no-heading",
                "--color", "never",
                "--smart-case",
                "--glob", "!.git",
                "--glob", "!node_modules",
                "--glob", "!__pycache__",
                query,
                directory
            ]
        )

        return output
            .split(separator: "\n")
            .compactMap { line -> GrepSearchResult? in
                let str = String(line)
                // 格式: file:line_number:content
                let parts = str.split(separator: ":", maxSplits: 2)
                guard parts.count >= 3,
                      let lineNumber = Int(parts[1]) else { return nil }

                let path = String(parts[0])
                let content = String(parts[2])
                let relativePath = path.hasPrefix(directory)
                    ? String(path.dropFirst(directory.count + 1))
                    : path

                return GrepSearchResult(
                    path: path,
                    relativePath: relativePath,
                    lineNumber: lineNumber,
                    lineContent: content.trimmingCharacters(in: .whitespaces),
                    matchRanges: []
                )
            }
    }

    /// 获取 git 文件状态
    func gitStatus(rootPath: String) async -> [String: String] {
        let output = await runCommand(
            "/usr/bin/git",
            arguments: ["-C", rootPath, "status", "--porcelain", "-uall"]
        )

        var result: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let str = String(line)
            guard str.count >= 4 else { continue }
            let status = String(str.prefix(2))
            let path = String(str.dropFirst(3))
            // 处理重命名: "R  old -> new"
            let filePath: String
            if status.contains("R"), let arrowRange = path.range(of: " -> ") {
                filePath = String(path[arrowRange.upperBound...])
            } else {
                filePath = path
            }
            result[filePath] = status
        }
        return result
    }

    private func runCommand(_ path: String, arguments: [String]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
