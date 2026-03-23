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
            CommandGroup(after: .textEditing) {
                Button("Find in File") {
                    appState.showInFileSearch.toggle()
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Go to File...") {
                    appState.showFileSearch = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Find in Files...") {
                    appState.showGrepSearch = true
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            // Cmd+O: 添加目录
            CommandGroup(replacing: .newItem) {
                Button("Add Folder...") {
                    appState.addFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
