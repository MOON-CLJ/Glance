import Foundation
import AppKit

struct ZellijSession: Identifiable {
    let id: String
    let name: String
    let isActive: Bool
}

struct GitInfo {
    let org: String
    let repo: String
    let worktree: String?
}

class ZellijService {
    static let shared = ZellijService()

    private init() {}

    /// 获取 Zellij session 名称
    func sessionName(for path: String) async -> String {
        // 1. 检测 git 仓库
        if let gitInfo = await parseGitRepo(path) {
            var name = "\(gitInfo.org)·\(gitInfo.repo)"
            if let worktree = gitInfo.worktree {
                name += "·\(worktree)"
            }
            return name
        }

        // 2. 非 git：路径编码，/ 替换为 ·
        return path.replacingOccurrences(of: "/", with: "·")
    }

    /// 解析 git 仓库信息
    private func parseGitRepo(_ path: String) async -> GitInfo? {
        // 执行 git remote -v 获取 origin
        let remoteOutput = await runCommand(
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

        // 解析 org 和 repo
        let (org, repo) = parseGitUrl(url)
        guard let org = org, let repo = repo else { return nil }

        // 检测 worktree
        let worktree = await detectWorktree(path)

        return GitInfo(org: org, repo: repo, worktree: worktree)
    }

    /// 解析 git URL 获取 org 和 repo
    private func parseGitUrl(_ url: String) -> (String?, String?) {
        // 支持格式：
        // - https://github.com/org/repo.git
        // - git@github.com:org/repo.git
        // - /path/to/repo (本地路径)

        var cleanUrl = url

        // 移除 .git 后缀
        if cleanUrl.hasSuffix(".git") {
            cleanUrl = String(cleanUrl.dropLast(4))
        }

        let components: [String]

        if cleanUrl.hasPrefix("http") {
            // HTTPS: https://github.com/org/repo
            guard let url = URL(string: cleanUrl) else { return (nil, nil) }
            components = url.pathComponents.filter { $0 != "/" }
        } else if cleanUrl.contains(":") {
            // SSH: git@github.com:org/repo
            let parts = cleanUrl.split(separator: ":", maxSplits: 1)
            if parts.count >= 2 {
                components = String(parts[1]).split(separator: "/").map(String.init)
            } else {
                return (nil, nil)
            }
        } else {
            // 本地路径
            components = cleanUrl.split(separator: "/").map(String.init)
        }

        guard components.count >= 2 else { return (nil, nil) }
        return (components[components.count - 2], components[components.count - 1])
    }

    /// 检测是否是 worktree
    private func detectWorktree(_ path: String) async -> String? {
        let output = await runCommand(
            "/usr/bin/git",
            arguments: ["-C", path, "rev-parse", "--show-toplevel", "--show-superproject-working-tree"]
        )

        let lines = output.split(separator: "\n").map(String.init)
        guard lines.count >= 2 else { return nil }

        let toplevel = lines[0]
        let superproject = lines[1]

        // 如果有 superproject，说明是 submodule，worktree 名称为当前目录名
        if !superproject.isEmpty && superproject != toplevel {
            return (path as NSString).lastPathComponent
        }

        // 检测是否是 git worktree
        let worktreeOutput = await runCommand(
            "/usr/bin/git",
            arguments: ["-C", path, "worktree", "list", "--porcelain"]
        )

        for line in worktreeOutput.split(separator: "\n") {
            let str = String(line)
            if str.hasPrefix("worktree ") {
                let worktreePath = String(str.dropFirst("worktree ".count))
                if worktreePath == path && worktreePath != toplevel {
                    // 这是一个 worktree，获取分支名
                    let branchOutput = await runCommand(
                        "/usr/bin/git",
                        arguments: ["-C", path, "rev-parse", "--abbrev-ref", "HEAD"]
                    )
                    let branch = branchOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    return branch.isEmpty ? nil : branch
                }
            }
        }

        return nil
    }

    /// 获取所有 sessions
    func listSessions() async -> [ZellijSession] {
        let output = await runCommand("/opt/homebrew/bin/zellij", arguments: ["list-sessions", "-s"])

        return output
            .split(separator: "\n")
            .map { line in
                let name = String(line).trimmingCharacters(in: .whitespaces)
                return ZellijSession(
                    id: name,
                    name: name,
                    isActive: false // list-sessions -s 不显示当前 session
                )
            }
    }

    /// 创建或附加 session
    func attachOrCreateSession(name: String, in path: String) async {
        _ = await runCommand(
            "/opt/homebrew/bin/zellij",
            arguments: ["attach", "-c", name],
            cwd: path
        )
    }

    /// 生成切换 session 的命令（用于复制到剪贴板）
    func generateSwitchCommand(for path: String) async -> String {
        let name = await sessionName(for: path)
        return "zellij action switch-session \"\(name)\""
    }

    /// 关闭 session
    func killSession(name: String) async {
        _ = await runCommand("/opt/homebrew/bin/zellij", arguments: ["kill-session", name])
    }

    /// 复制切换命令到剪贴板
    func copySwitchCommand(for path: String) async {
        let command = await generateSwitchCommand(for: path)
        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(command, forType: .string)
        }
    }

    /// 执行命令
    private func runCommand(_ path: String, arguments: [String], cwd: String? = nil) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments

                if let cwd = cwd {
                    process.currentDirectoryURL = URL(fileURLWithPath: cwd)
                }

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
