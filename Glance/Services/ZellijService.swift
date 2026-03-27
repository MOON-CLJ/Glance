import Foundation
import AppKit

struct ZellijSession: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

struct GitInfo {
    let org: String
    let repo: String
    let worktree: String?
}

enum ZellijError: LocalizedError {
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Zellij: \(message)"
        }
    }
}

class ZellijService {
    static let shared = ZellijService()

    private let zellijPath = "/opt/homebrew/bin/zellij"

    private init() {}

    // MARK: - Session Name

    func sessionName(for path: String) -> String {
        if let gitInfo = parseGitRepo(path) {
            var name = "\(gitInfo.org)·\(gitInfo.repo)"
            if let worktree = gitInfo.worktree {
                name += "·\(worktree)"
            }
            return name
        }

        return path.replacingOccurrences(of: "/", with: "·")
    }

    private func parseGitRepo(_ path: String) -> GitInfo? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: GitInfo?

        Task {
            // 执行 git remote -v 获取 origin
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

            guard let url = originUrl else {
                semaphore.signal()
                return
            }

            // 解析 org 和 repo
            let (org, repo) = parseGitUrl(url)
            guard let org = org, let repo = repo else {
                semaphore.signal()
                return
            }

            // 检测 worktree
            let worktree = await detectWorktree(path)

            result = GitInfo(org: org, repo: repo, worktree: worktree)
            semaphore.signal()
        }

        semaphore.wait()
        return result
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

        // 如果有 superproject，说明是 submodule，worktree 名称为当前目录名
        if !superproject.isEmpty && superproject != toplevel {
            return (path as NSString).lastPathComponent
        }

        // 检测是否是 git worktree
        let worktreeOutput = await CLIService.shared.runCommand(
            "/usr/bin/git",
            arguments: ["-C", path, "worktree", "list", "--porcelain"]
        )

        for line in worktreeOutput.split(separator: "\n") {
            let str = String(line)
            if str.hasPrefix("worktree ") {
                let worktreePath = String(str.dropFirst("worktree ".count))
                if worktreePath == path && worktreePath != toplevel {
                    // 这是一个 worktree，获取分支名
                    let branchOutput = await CLIService.shared.runCommand(
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

    // MARK: - Session Operations

    func listSessions() async -> [ZellijSession] {
        let output = await CLIService.shared.runCommand(
            zellijPath,
            arguments: ["list-sessions", "-s"]
        )

        return output
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }
            .map { ZellijSession(name: $0) }
    }

    func createOrAttach(sessionName: String, projectPath: String) async throws {
        try await runZellij(arguments: ["attach", "-c", sessionName], workingDirectory: projectPath)
    }

    func killSession(_ name: String) async throws {
        try await runZellij(arguments: ["kill-session", name])
    }

    func switchCommand(for name: String) -> String {
        "zellij action switch-session \"\(name)\""
    }

    func copySwitchCommand(for name: String) {
        let command = switchCommand(for: name)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    private func runZellij(arguments: [String], workingDirectory: String? = nil) async throws {
        let output = await CLIService.shared.runCommand(
            zellijPath,
            arguments: arguments,
            cwd: workingDirectory
        )

        // zellij 输出到 stderr 时返回空，需要检查实际是否有错误
        if output.contains("error") || output.contains("Error") {
            throw ZellijError.executionFailed(output)
        }
    }
}
