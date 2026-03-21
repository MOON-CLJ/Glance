import SwiftUI

@main
struct GlanceApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .commands {
            // Cmd+Shift+O: 文件搜索
            CommandGroup(after: .textEditing) {
                Button("Go to File...") {
                    appState.showFileSearch = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Find in Files...") {
                    appState.showGrepSearch = true
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            // Cmd+O: 打开目录
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    appState.openFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
