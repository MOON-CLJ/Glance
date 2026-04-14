import Foundation

class CLIService {
    static let shared = CLIService()

    private let fdPath: String
    private let rgPath: String

    private init() {
        fdPath = Self.lookupPath("fd", fallback: "/opt/homebrew/bin/fd")
        rgPath = Self.lookupPath("rg", fallback: "/opt/homebrew/bin/rg")
    }

    static func lookupPath(_ command: String, fallback: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !path.isEmpty { return path }
            }
        } catch {}
        return fallback
    }

    /// 使用 fd 搜索文件名（包含 / 时按路径匹配）
    func searchFiles(query: String, in directory: String) async -> [FileSearchResult] {
        guard !query.isEmpty else { return [] }

        var args = [
            "--type", "f",
            "--hidden",
            "--follow",
            "--exclude", ".git",
            "--exclude", "node_modules",
            "--exclude", "__pycache__",
            "--exclude", "*.pyc",
        ]
        if query.contains("/") {
            args.append("--full-path")
        }
        args.append(contentsOf: [query, directory])

        let output = await runCommand(fdPath, arguments: args)

        return output
            .split(separator: "\n")
            .map { line in
                let path = String(line)
                let relativePath = path.hasPrefix(directory)
                    ? String(path.dropFirst(directory.count + 1))
                    : path
                return FileSearchResult(base: SearchResultBase(path: path, relativePath: relativePath))
            }
    }

    /// 使用 rg 搜索文件内容
    func searchContent(query: String, in directory: String, options: SearchOptions = SearchOptions()) async -> [GrepSearchResult] {
        guard !query.isEmpty else { return [] }

        var args: [String] = [
            "--json",
            "--glob", "!.git",
            "--glob", "!node_modules",
            "--glob", "!__pycache__",
        ]

        switch options.caseSensitivity {
        case .smart:       args.append("--smart-case")
        case .sensitive:   args.append("--case-sensitive")
        case .insensitive: args.append("--ignore-case")
        }

        if options.wholeWord { args.append("--word-regexp") }
        if !options.regex    { args.append("--fixed-strings") }

        if !options.fileType.isEmpty {
            args.append(contentsOf: ["--type", options.fileType])
        }
        if !options.fileGlob.isEmpty {
            args.append(contentsOf: ["--glob", options.fileGlob])
        }

        args.append(contentsOf: [query, directory])

        let output = await runCommand(rgPath, arguments: args)

        return output
            .split(separator: "\n")
            .compactMap { line -> GrepSearchResult? in
                parseRgJsonMatch(line: String(line), directory: directory)
            }
    }

    private func parseRgJsonMatch(line: String, directory: String) -> GrepSearchResult? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String, type == "match",
              let matchData = json["data"] as? [String: Any],
              let pathObj = matchData["path"] as? [String: Any],
              let path = pathObj["text"] as? String,
              let lineNumber = matchData["line_number"] as? Int,
              let linesObj = matchData["lines"] as? [String: Any],
              let lineText = linesObj["text"] as? String
        else { return nil }

        let relativePath = path.hasPrefix(directory + "/")
            ? String(path.dropFirst(directory.count + 1))
            : path

        return GrepSearchResult(
            base: SearchResultBase(path: path, relativePath: relativePath),
            lineNumber: lineNumber,
            lineContent: lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
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

    func runCommand(_ path: String, arguments: [String], cwd: String? = nil) async -> String {
        await runCommandFull(path, arguments: arguments, cwd: cwd).stdout
    }

    func runCommandFull(_ path: String, arguments: [String], cwd: String? = nil) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments

                if let cwd = cwd {
                    process.currentDirectoryURL = URL(fileURLWithPath: cwd)
                }

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                var stdoutData = Data()
                var stderrData = Data()

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    stdoutData.append(handle.availableData)
                }
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    stderrData.append(handle.availableData)
                }

                do {
                    try process.run()
                    process.waitUntilExit()

                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    stdoutData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                    stderrData.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    continuation.resume(returning: CommandResult(
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    continuation.resume(returning: CommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1))
                }
            }
        }
    }
}

struct CommandResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}
