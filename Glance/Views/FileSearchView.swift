import SwiftUI

struct FileSearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var results: [FileSearchResult] = []
    @State private var selectedIndex = 0
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            searchField("Search files by name...", icon: "magnifyingglass", query: $query, onSubmit: selectCurrent)

            Divider()

            if results.isEmpty && !query.isEmpty {
                Text("No results")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultList
            }
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 400, idealHeight: 500)
        .onChange(of: query) { _, newQuery in
            performSearch(query: newQuery)
        }
        .searchKeyboardHandling(
            selectedIndex: $selectedIndex,
            resultCount: results.count,
            onClose: { appState.showFileSearch = false }
        )
    }

    private var resultList: some View {
        List(selection: SearchSelection.binding(for: results, selectedIndex: selectedIndex) { idx in
            selectedIndex = idx
        }) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                FileSearchRow(result: result)
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

    private func performSearch(query: String) {
        searchTask?.cancel()
        guard let root = appState.activeRootPath, !query.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }

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
