import SwiftUI

struct ZellijSessionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var allSessions: [ZellijSession] = []
    @State private var groupedSessions: [(project: ProjectState, sessions: [ZellijSession])] = []
    @State private var otherSessions: [ZellijSession] = []
    @State private var currentProjectName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var copiedSessionName: String?
    @State private var showDeleteConfirmation = false
    @State private var sessionToDelete: ZellijSession?

    // MARK: - Group Sessions

    /// 更新分组数据（避免在渲染过程中计算）
    private func updateGroupedSessions() {
        let currentProject = appState.activeProject
        let otherProjects = appState.projects.filter { $0.id != currentProject?.id }

        var newGrouped: [(ProjectState, [ZellijSession])] = []

        // 当前项目在前
        if let current = currentProject {
            let baseName = ZellijService.shared.sessionName(for: current.path)
            let sessions = allSessions.filter { $0.name.hasPrefix(baseName) }
            if !sessions.isEmpty {
                newGrouped.append((current, sessions))
            }
        }

        // 其他项目在后
        for project in otherProjects {
            let baseName = ZellijService.shared.sessionName(for: project.path)
            let sessions = allSessions.filter { $0.name.hasPrefix(baseName) }
            if !sessions.isEmpty {
                newGrouped.append((project, sessions))
            }
        }

        groupedSessions = newGrouped

        // 计算其他 sessions
        let knownSessionNames = Set(newGrouped.flatMap { $0.1.map { $0.name } })
        otherSessions = allSessions.filter { !knownSessionNames.contains($0.name) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection()

            Divider()

            if let project = appState.activeProject {
                currentProjectSection(project: project)

                Divider()
            }

            sessionListSection()

            Divider()

            footerSection()
        }
        .frame(width: 480, height: 500)
        .onAppear {
            loadSessionName()
            Task { await refreshSessions() }
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let session = sessionToDelete {
                    Task { await deleteSession(session) }
                }
            }
        } message: {
            if let session = sessionToDelete {
                let message = session.status == .exited
                    ? "此 session 已退出。"
                    : "此操作将终止该 session。"
                Text("确定要删除 session \"\(session.name)\" 吗？\n\(message)")
            }
        }
    }

    // MARK: - Sections

    private func headerSection() -> some View {
        HStack {
            Text("Zellij Sessions")
                .font(.headline)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func currentProjectSection(project: ProjectState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前项目: \(project.name)")
                .font(.system(size: 13, weight: .medium))

            Text("Session: \(currentProjectName)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .textSelection(.enabled)

            Button(action: { copyCreateOrAttachCommand() }) {
                Label(copiedSessionName == currentProjectName ? "已复制!" : "复制New/Attach Session命令", systemImage: "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sessionListSection() -> some View {
        Group {
            if isLoading && allSessions.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if allSessions.isEmpty {
                Spacer()
                Text("无活跃的 Zellij Session")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                Spacer()
            } else {
                List {
                    // 已知项目的 sessions
                    ForEach(groupedSessions, id: \.project.id) { group in
                        Section(header: projectHeader(group.project)) {
                            ForEach(group.sessions) { session in
                                sessionRow(session)
                            }
                        }
                    }

                    // 其他 sessions
                    if !otherSessions.isEmpty {
                        Section(header: Text("其他")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)) {
                            ForEach(otherSessions) { session in
                                sessionRow(session)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func footerSection() -> some View {
        HStack {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { Task { await refreshSessions() } }) {
                Label("刷新", systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Row Components

    private func projectHeader(_ project: ProjectState) -> some View {
        HStack {
            Text(project.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()

            // 显示 session 数量
            let sessionCount = groupedSessions.first { $0.project.id == project.id }?.sessions.count ?? 0
            Text("\(sessionCount)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
        }
    }

    private func sessionRow(_ session: ZellijSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: session.status.color))

                    Text(session.name)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                    
                    statusBadge(for: session.status)
                }
                
                // 创建时间
                if !session.createdTime.isEmpty {
                    Text(session.createdTime)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if copiedSessionName == session.name {
                Text("已复制")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }

            Button(action: { copySwitchCommand(session.name) }) {
                Image(systemName: "arrow.right.arrow.left")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("复制Switch Session命令")

            Button(action: { copyAttachCommand(session.name) }) {
                Image(systemName: "link")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("复制Attach Session命令")

            Button(action: { 
                sessionToDelete = session
                showDeleteConfirmation = true
            }) {
                Image(systemName: deleteIcon(for: session.status))
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .help(deleteHelp(for: session.status))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func loadSessionName() {
        guard let project = appState.activeProject else { return }
        currentProjectName = ZellijService.shared.sessionName(for: project.path)
    }

    private func refreshSessions() async {
        isLoading = true
        defer { isLoading = false }

        errorMessage = nil
        allSessions = await ZellijService.shared.listSessions()
        updateGroupedSessions()
    }

    private func setCopiedSession(_ name: String) {
        copiedSessionName = name
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedSessionName == name {
                copiedSessionName = nil
            }
        }
    }

    private func copyCreateOrAttachCommand() {
        guard let project = appState.activeProject else { return }
        let sessionName = ZellijService.shared.sessionName(for: project.path)
        ZellijService.shared.copyCreateOrAttachCommand(for: sessionName, path: project.path)
        setCopiedSession(sessionName)
    }

    private func copySwitchCommand(_ sessionName: String) {
        ZellijService.shared.copySwitchCommand(for: sessionName)
        setCopiedSession(sessionName)
    }

    private func copyAttachCommand(_ sessionName: String) {
        ZellijService.shared.copyAttachCommand(for: sessionName)
        setCopiedSession(sessionName)
    }

    private func deleteSession(_ session: ZellijSession) async {
        do {
            errorMessage = nil
            if session.status == .exited {
                try await ZellijService.shared.deleteSession(session.name)
            } else {
                try await ZellijService.shared.killSession(session.name)
            }
            await refreshSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteIcon(for status: SessionStatus) -> String {
        status == .exited ? "trash" : "xmark"
    }

    private func deleteHelp(for status: SessionStatus) -> String {
        status == .exited ? "删除已退出 Session" : "关闭 Session"
    }

    private func statusBadge(for status: SessionStatus) -> some View {
        Text(status.displayName)
            .font(.system(size: 9))
            .foregroundColor(Color(nsColor: status.color))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color(nsColor: status.color).opacity(0.15))
            .cornerRadius(3)
    }
}

#Preview {
    ZellijSessionView()
        .environmentObject(AppState())
}
