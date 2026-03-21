import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var rootNodes: [FileNode] = []
    @StateObject private var watcher = FileWatcher()

    var body: some View {
        Group {
            if appState.activeProject != nil {
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
        .onChange(of: watcher.changedPaths) { _, changedPaths in
            guard let rootPath = appState.activeRootPath else { return }
            for dirPath in changedPaths {
                if dirPath == rootPath {
                    rootNodes = FileService.shared.listDirectory(path: rootPath)
                } else {
                    for node in rootNodes {
                        node.refreshNode(forPath: dirPath)
                    }
                }
            }
        }
        .onAppear {
            reloadCurrentProject()
        }
    }

    private func reloadCurrentProject() {
        if let path = appState.activeRootPath {
            rootNodes = FileService.shared.listDirectory(path: path)
            watcher.watch(path: path)
        } else {
            rootNodes = []
            watcher.stop()
        }
    }
}

struct FileTreeRow: View {
    @ObservedObject var node: FileNode
    @EnvironmentObject var appState: AppState

    private var labelColor: Color {
        node.isHidden ? .secondary : (node.isDirectory ? .accentColor : .primary)
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
                    node.loadChildren()
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
