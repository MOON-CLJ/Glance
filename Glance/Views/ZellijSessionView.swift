import SwiftUI

struct ZellijSessionView: View {
    @EnvironmentObject var appState: AppState
    @State private var sessions: [ZellijSession] = []
    @State private var sessionName: String = ""
    @State private var currentProjectName: String = ""
    @State private var isLoading = false
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Zellij Sessions")
                    .font(.headline)
                Spacer()
                Button(action: { appState.showZellijSession = false }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Current Project Section
            if let project = appState.activeProject {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前项目: \(project.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Session: \(currentProjectName.isEmpty ? "..." : currentProjectName)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Button(action: { createOrAttachSession() }) {
                            Label("创建/附加 Session", systemImage: "terminal")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: { copySwitchCommand() }) {
                            Label(showCopied ? "已复制!" : "复制切换命令", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
            }

            // Sessions List
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                Text("没有 Zellij sessions")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sessions) { session in
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundColor(.secondary)

                            Text(session.name)
                                .font(.system(.body, design: .monospaced))

                            Spacer()

                            Button(action: { killSession(session) }) {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Footer
            HStack {
                Button(action: { refreshSessions() }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(12)
        }
        .frame(minWidth: 400, idealWidth: 450, minHeight: 300, idealHeight: 400)
        .onAppear {
            loadSessionName()
            refreshSessions()
        }
        .onKeyPress(.escape) {
            appState.showZellijSession = false
            return .handled
        }
    }

    private func loadSessionName() {
        guard let project = appState.activeProject else { return }

        Task {
            let name = await ZellijService.shared.sessionName(for: project.path)
            await MainActor.run {
                currentProjectName = name
            }
        }
    }

    private func refreshSessions() {
        isLoading = true

        Task {
            let result = await ZellijService.shared.listSessions()
            await MainActor.run {
                sessions = result
                isLoading = false
            }
        }
    }

    private func createOrAttachSession() {
        guard let project = appState.activeProject else { return }

        Task {
            await ZellijService.shared.attachOrCreateSession(
                name: currentProjectName,
                in: project.path
            )
            await MainActor.run {
                appState.showZellijSession = false
            }
        }
    }

    private func copySwitchCommand() {
        guard let project = appState.activeProject else { return }

        Task {
            await ZellijService.shared.copySwitchCommand(for: project.path)
            await MainActor.run {
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showCopied = false
                }
            }
        }
    }

    private func killSession(_ session: ZellijSession) {
        Task {
            await ZellijService.shared.killSession(name: session.name)
            refreshSessions()
        }
    }
}

#Preview {
    ZellijSessionView()
        .environmentObject(AppState())
}
