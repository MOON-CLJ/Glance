import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if let file = appState.selectedFile {
                FilePreviewView(filePath: file)
            } else {
                WelcomeView()
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
        .sheet(isPresented: $appState.showFileSearch) {
            FileSearchView()
        }
        .sheet(isPresented: $appState.showGrepSearch) {
            GrepSearchView()
        }
        .onAppear {
            if appState.rootPath == nil {
                // 优先读取命令行参数
                let args = ProcessInfo.processInfo.arguments
                if args.count > 1 {
                    let path = (args.last! as NSString).expandingTildeInPath
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                        appState.rootPath = path
                    }
                }
            }
        }
    }
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

            Text("Cmd+O to open a folder")
                .foregroundColor(.secondary)

            Text("Cmd+Shift+O to search files")
                .foregroundColor(.secondary)

            Text("Cmd+Shift+F to search content")
                .foregroundColor(.secondary)

            if appState.rootPath == nil {
                Button("Open Folder...") {
                    appState.openFolder()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
