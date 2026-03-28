import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var rootNodes: [FileNode] = []
    @StateObject private var watcher = FileWatcher()

    var body: some View {
        VStack(spacing: 0) {
            if appState.activeProject != nil {
                // 工具栏
                HStack {
                    Spacer()
                    Button(action: locateActiveFile) {
                        Image(systemName: "scope")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .help("Locate active file in tree")
                    .disabled(appState.activeFile == nil)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                List {
                    ForEach(rootNodes) { node in
                        FileTreeRow(node: node)
                    }
                }
                .listStyle(.sidebar)
            } else {
                VStack {
                    Text("No folder opened")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: appState.activeProjectIndex) { _, _ in
            reloadCurrentProject()
        }
        .onChange(of: watcher.changeId) { _, _ in
            Task {
                guard let rootPath = appState.activeRootPath else { return }
                let latest = await FileService.shared.listDirectory(path: rootPath)
                rootNodes = await FileNode.merge(existing: rootNodes, with: latest)
                appState.activeProject?.refreshGitStatus()
                appState.fileChangeCounter += 1
            }
        }
        .onAppear {
            reloadCurrentProject()
        }
    }

    private func reloadCurrentProject() {
        if let path = appState.activeRootPath {
            watcher.watch(path: path)
            Task {
                rootNodes = await FileService.shared.listDirectory(path: path)
            }
        } else {
            rootNodes = []
            watcher.stop()
        }
    }

    private func locateActiveFile() {
        guard let filePath = appState.activeFile else { return }
        Task {
            for node in rootNodes {
                if await node.expandToPath(filePath) { return }
            }
        }
    }
}

struct FileTreeRow: View {
    @ObservedObject var node: FileNode
    @EnvironmentObject var appState: AppState

    /// git 状态对应的颜色
    /// porcelain 格式: XY, X=index状态, Y=工作区状态
    private var gitColor: Color? {
        let status: String?
        if node.isDirectory {
            status = appState.activeProject?.gitStatus(forDirectory: node.path)
        } else {
            status = appState.activeProject?.gitStatus(forPath: node.path)
        }
        guard let s = status, s.count == 2 else { return nil }
        let index = s.first!      // 暂存区状态
        let workTree = s.last!    // 工作区状态

        // 工作区有未暂存修改 -> 黄色
        if workTree == "M" || workTree == "D" { return .yellow }
        // untracked -> 灰色
        if s == "??" { return .gray }
        // 全部已暂存 (A/M/D/R + 空格) -> 绿色
        if index != " " && index != "?" && workTree == " " { return .green }

        return .yellow
    }

    private var labelColor: Color {
        if let gc = gitColor { return gc }
        return node.isHidden ? .secondary : (node.isDirectory ? .accentColor : .primary)
    }

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(
                isExpanded: $node.isExpanded,
                content: {
                    if let children = node.children {
                        ForEach(children) { child in
                            FileTreeRow(node: child)
                        }
                    }
                },
                label: {
                    HStack(spacing: 2) {
                        Label(node.name, systemImage: "folder.fill")
                            .foregroundColor(labelColor)
                        if node.isSymlink {
                            Image(systemName: "arrow.turn.right.up")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            )
            .onChange(of: node.isExpanded) { _, expanded in
                if expanded && !node.isLoaded {
                    Task { await node.loadChildren() }
                }
            }
        } else {
            HStack(spacing: 2) {
                Label(node.name, systemImage: FileService.shared.iconForFile(node.name))
                    .foregroundColor(labelColor)
                if node.isSymlink {
                    Image(systemName: "arrow.turn.right.up")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .onTapGesture {
                appState.activeProject?.openFile(path: node.path)
            }
        }
    }
}
