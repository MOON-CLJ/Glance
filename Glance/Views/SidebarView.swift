import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var rootNodes: [FileNode] = []

    var body: some View {
        Group {
            if appState.rootPath != nil {
                List(selection: Binding(
                    get: { appState.selectedFile },
                    set: { appState.selectedFile = $0 }
                )) {
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
        .onChange(of: appState.rootPath) { _, newPath in
            if let path = newPath {
                rootNodes = FileService.shared.listDirectory(path: path)
            } else {
                rootNodes = []
            }
        }
        .onAppear {
            if let path = appState.rootPath {
                rootNodes = FileService.shared.listDirectory(path: path)
            }
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
                .tag(node.path)
                .foregroundColor(.primary)
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
