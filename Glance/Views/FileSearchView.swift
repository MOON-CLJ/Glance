import SwiftUI

struct FileSearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var results: [FileSearchResult] = []
    @State private var selectedIndex = 0
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files by name...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit { selectCurrent() }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 结果列表
            if results.isEmpty && !query.isEmpty {
                Text("No results")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { results.indices.contains(selectedIndex) ? results[selectedIndex].id : nil },
                    set: { newId in
                        if let idx = results.firstIndex(where: { $0.id == newId }) {
                            selectedIndex = idx
                        }
                    }
                )) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        FileSearchRow(result: result, isSelected: index == selectedIndex)
                            .tag(result.id)
                            .onTapGesture(count: 2) {
                                selectedIndex = index
                                selectCurrent()
                            }
                            .onTapGesture {
                                selectedIndex = index
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 600, height: 400)
        .onChange(of: query) { _, newQuery in
            performSearch(query: newQuery)
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < results.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            appState.showFileSearch = false
            return .handled
        }
    }

    private func performSearch(query: String) {
        searchTask?.cancel()
        guard let root = appState.activeRootPath, !query.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            let searchResults = await CLIService.shared.searchFiles(query: query, in: root)
            if !Task.isCancelled {
                await MainActor.run {
                    results = Array(searchResults.prefix(50))
                    selectedIndex = 0
                }
            }
        }
    }

    private func selectCurrent() {
        guard results.indices.contains(selectedIndex) else { return }
        appState.activeProject?.openFile(path: results[selectedIndex].path)
        appState.showFileSearch = false
    }
}

struct FileSearchRow: View {
    let result: FileSearchResult
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.fileName)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
            Text(result.relativePath)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }
}
