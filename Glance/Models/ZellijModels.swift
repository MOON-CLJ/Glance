import AppKit

enum SessionStatus: String, CaseIterable {
    case exited = "EXITED"
    case current = "current"
    case running = "running"

    var displayName: String {
        switch self {
        case .exited: return "已退出"
        case .current: return "当前"
        case .running: return "运行中"
        }
    }

    var color: NSColor {
        switch self {
        case .exited: return .systemGray
        case .current: return .systemGreen
        case .running: return .systemBlue
        }
    }
}

struct ZellijSession: Identifiable, Hashable {
    let id: String
    let name: String
    let status: SessionStatus
    let createdTime: String

    init(name: String, status: SessionStatus, createdTime: String) {
        self.id = name
        self.name = name
        self.status = status
        self.createdTime = createdTime
    }
}

struct GitInfo {
    let org: String
    let repo: String
    let worktree: String?
}

struct SessionGroup: Identifiable {
    let id: UUID
    let project: ProjectState
    let sessions: [ZellijSession]

    init(project: ProjectState, sessions: [ZellijSession]) {
        self.id = project.id
        self.project = project
        self.sessions = sessions
    }
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
