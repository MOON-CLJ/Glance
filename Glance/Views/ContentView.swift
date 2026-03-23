import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if appState.projects.isEmpty {
                WelcomeView()
            } else {
                VStack(spacing: 0) {
                    // 第一层：目录 tab 栏
                    ProjectTabBar()

                    Divider()

                    // 第二层 + 第三层：文件 tab 栏 + 预览区
                    if let project = appState.activeProject {
                        if project.openedFiles.isEmpty {
                            // 没有打开的文件，显示提示
                            VStack {
                                Spacer()
                                Text("Select a file from the sidebar")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            FileTabBar(project: project)

                            Divider()

                            if let file = project.activeFile {
                                FilePreviewView(filePath: file)
                            }
                        }
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
        .sheet(isPresented: $appState.showFileSearch) {
            FileSearchView()
                .modifier(ResizableSheet())
        }
        .sheet(isPresented: $appState.showGrepSearch) {
            GrepSearchView()
                .modifier(ResizableSheet())
        }
        .onAppear {
            if appState.projects.isEmpty {
                let args = ProcessInfo.processInfo.arguments
                if args.count > 1 {
                    let path = (args.last! as NSString).expandingTildeInPath
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                        appState.addFolder(path: path)
                    }
                }
            }
        }
    }
}

/// 让 sheet 的 underlying NSWindow 支持调整大小
struct ResizableSheet: ViewModifier {
    func body(content: Content) -> some View {
        content.background(SheetResizer())
    }
}

private struct SheetResizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask.insert(.resizable)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Glance")
                .font(.largeTitle)
                .fontWeight(.light)

            Text("Cmd+O to add a folder")
                .foregroundColor(.secondary)

            Text("Cmd+Shift+O to search files")
                .foregroundColor(.secondary)

            Text("Cmd+Shift+F to search content")
                .foregroundColor(.secondary)

            Button("Add Folder...") {
                appState.addFolder()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
