import Foundation
import AppKit

class ZellijService {
    static let shared = ZellijService()

    private let zellijPath: String
    private var sessionNameCache: [String: String] = [:]

    private init() {
        zellijPath = Self.resolveZellijPath()
    }

    private static func resolveZellijPath() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["zellij"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "zellij" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return path.isEmpty ? "/opt/homebrew/bin/zellij" : path
        } catch {
            return "/opt/homebrew/bin/zellij"
        }
    }

    // MARK: - Session Name

    func sessionName(for path: String) async -> String {
        if let cached = sessionNameCache[path] {
            return cached
        }

        let name: String
        if let gitInfo = await parseGitRepo(path) {
            var n = "\(gitInfo.org)·\(gitInfo.repo)"
            if let worktree = gitInfo.worktree {
                n += "·\(worktree)"
            }
            name = n
        } else {
            name = path.replacingOccurrences(of: "/", with: "·")
        }

        sessionNameCache[path] = name
        return name
    }

    private func parseGitRepo(_ path: String) async -> GitInfo? {
        let remoteOutput = await CLIService.shared.runCommand(
            "/usr/bin/git",
            arguments: ["-C", path, "remote", "-v"]
        )

        var originUrl: String?
        for line in remoteOutput.split(separator: "\n") {
            let str = String(line)
            if str.hasPrefix("origin") {
                let components = str.split(separator: "\t")
                if components.count >= 2 {
                    originUrl = String(components[1].split(separator: " ").first ?? "")
                    break
                }
            }
        }

        guard let url = originUrl else { return nil }

        let (org, repo) = parseGitUrl(url)
        guard let org = org, let repo = repo else { return nil }

        let worktree = await detectWorktree(path)

        return GitInfo(org: org, repo: repo, worktree: worktree)
    }

    /// 解析 git URL 获取 org 和 repo
    private func parseGitUrl(_ url: String) -> (String?, String?) {
        var cleanUrl = url

        // 移除 .git 后缀
        if cleanUrl.hasSuffix(".git") {
            cleanUrl = String(cleanUrl.dropLast(4))
        }

        let components: [String]

        if cleanUrl.hasPrefix("http") {
            guard let url = URL(string: cleanUrl) else { return (nil, nil) }
            components = url.pathComponents.filter { $0 != "/" }
        } else if cleanUrl.contains(":") {
            let parts = cleanUrl.split(separator: ":", maxSplits: 1)
            if parts.count >= 2 {
                components = String(parts[1]).split(separator: "/").map(String.init)
            } else {
                return (nil, nil)
            }
        } else {
            components = cleanUrl.split(separator: "/").map(String.init)
        }

        guard components.count >= 2 else { return (nil, nil) }
        return (components[components.count - 2], components[components.count - 1])
    }

    /// 检测是否是 worktree
    private func detectWorktree(_ path: String) async -> String? {
        let output = await CLIService.shared.runCommand(
            "/usr/bin/git",
            arguments: ["-C", path, "rev-parse", "--show-toplevel", "--show-superproject-working-tree"]
        )

        let lines = output.split(separator: "\n").map(String.init)
        guard lines.count >= 2 else { return nil }

        let toplevel = lines[0]
        let superproject = lines[1]

        if !superproject.isEmpty && superproject != toplevel {
            return (path as NSString).lastPathComponent
        }

        async let worktreeOutput = CLIService.shared.runCommand(
            "/usr/bin/git",
            arguments: ["-C", path, "worktree", "list", "--porcelain"]
        )
        async let branchOutput = CLIService.shared.runCommand(
            "/usr/bin/git",
            arguments: ["-C", path, "rev-parse", "--abbrev-ref", "HEAD"]
        )

        let worktreeList = await worktreeOutput
        for line in worktreeList.split(separator: "\n") {
            let str = String(line)
            if str.hasPrefix("worktree ") {
                let worktreePath = String(str.dropFirst("worktree ".count))
                if worktreePath == path && worktreePath != toplevel {
                    let branch = await branchOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    return branch.isEmpty ? nil : branch
                }
            }
        }

        return nil
    }

    // MARK: - Session Operations

    func listSessions() async -> [ZellijSession] {
        let output = await CLIService.shared.runCommand(
            zellijPath,
            arguments: ["list-sessions"]
        )

        return output
            .split(separator: "\n")
            .compactMap { line in
                parseSessionLine(String(line))
            }
    }
    
    /// 解析 session 输出行
    /// 格式: `session-name [Created X ago] (status)` 或 `session-name [Created X ago]`
    private func parseSessionLine(_ line: String) -> ZellijSession? {
        let cleanLine = removeANSICodes(line)
        
        // 查找 "[Created " 和 " ago]" 的位置
        let createdPrefix = "[Created "
        let createdSuffix = " ago]"
        
        guard let createdStart = cleanLine.range(of: createdPrefix),
              let createdEnd = cleanLine.range(of: createdSuffix, range: createdStart.upperBound..<cleanLine.endIndex) else {
            let name = cleanLine.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            return ZellijSession(name: name, status: .running, createdTime: "")
        }
        
        // 提取时间
        let createdTime = String(cleanLine[createdStart.upperBound..<createdEnd.lowerBound])
        
        // 提取名称（时间之前的部分）
        let name = String(cleanLine[..<createdStart.lowerBound]).trimmingCharacters(in: .whitespaces)
        
        // 提取状态（时间之后的部分）
        let statusPart = String(cleanLine[createdEnd.upperBound...]).trimmingCharacters(in: .whitespaces)
        
        let status: SessionStatus
        if statusPart.contains("EXITED") {
            status = .exited
        } else if statusPart.contains("current") {
            status = .current
        } else {
            status = .running
        }
        
        return ZellijSession(name: name, status: status, createdTime: createdTime)
    }
    
    // MARK: - ANSI Code Removal
    
    private static let ansiCodePattern = "\\x1B\\[[0-9;]*m"
    private static let ansiCodeRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: ansiCodePattern, options: [])
    }()
    
    /// 移除 ANSI 颜色码
    private func removeANSICodes(_ string: String) -> String {
        guard let regex = Self.ansiCodeRegex else { return string }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: "")
    }

    func createOrAttach(sessionName: String, projectPath: String) async throws {
        try await runZellij(arguments: ["attach", "-c", sessionName], workingDirectory: projectPath)
    }

    func killSession(_ name: String) async throws {
        try await runZellij(arguments: ["kill-session", name])
    }
    
    func deleteSession(_ name: String) async throws {
        try await runZellij(arguments: ["delete-session", name])
    }

    func switchCommand(for name: String) -> String {
        "zellij action switch-session \"\(name)\""
    }

    func copySwitchCommand(for name: String) {
        copyToClipboard(switchCommand(for: name))
    }

    func attachCommand(for name: String) -> String {
        "zellij attach \"\(name)\""
    }

    func copyAttachCommand(for name: String) {
        copyToClipboard(attachCommand(for: name))
    }

    func createOrAttachCommand(for name: String, path: String) -> String {
        "cd \"\(path)\" && zellij attach -c \"\(name)\""
    }

    func copyCreateOrAttachCommand(for name: String, path: String) {
        copyToClipboard(createOrAttachCommand(for: name, path: path))
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func runZellij(arguments: [String], workingDirectory: String? = nil) async throws {
        let result = await CLIService.shared.runCommandFull(
            zellijPath,
            arguments: arguments,
            cwd: workingDirectory
        )

        if result.exitCode != 0 {
            let message = result.stderr.isEmpty ? result.stdout : result.stderr
            throw ZellijError.executionFailed(message)
        }
    }
}
