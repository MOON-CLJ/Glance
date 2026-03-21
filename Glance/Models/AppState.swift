import SwiftUI

class AppState: ObservableObject {
    @Published var rootPath: String?
    @Published var selectedFile: String?
    @Published var showFileSearch = false
    @Published var showGrepSearch = false

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project folder"

        if panel.runModal() == .OK, let url = panel.url {
            rootPath = url.path
        }
    }

    func openFolder(path: String) {
        rootPath = path
    }
}
