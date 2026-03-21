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
                    Label(node.name, systemImage: "folder.fill")
                        .foregroundColor(.accentColor)
                }
            )
            .onChange(of: node.isExpanded) { _, expanded in
                if expanded && !node.isLoaded {
                    node.loadChildren()
                }
            }
        } else {
            Label(node.name, systemImage: iconForFile(node.name))
                .foregroundColor(.primary)
                .onTapGesture {
                    appState.activeProject?.openFile(path: node.path)
                }
        }
    }

    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "doc.text"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json", "yaml", "yml", "toml": return "doc.text"
        case "md": return "doc.richtext"
        case "sh", "bash", "zsh": return "terminal"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        default: return "doc"
        }
    }
}
