import SwiftUI

struct GrepSearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var results: [GrepSearchResult] = []
    @State private var selectedIndex = 0
    @State private var searchTask: Task<Void, Never>?
    @State private var previewContent = ""
    @State private var previewLanguage = "plaintext"
    @State private var previewLine: Int? = nil
    @StateObject private var previewWebViewStore = WebViewStore()

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search in files...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit { selectCurrent() }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 上下分栏：结果列表 + 代码预览
            VSplitView {
                // 上半：结果列表
                Group {
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
                                GrepSearchRow(result: result, isSelected: index == selectedIndex)
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
                .frame(minHeight: 150)

                // 下半：代码预览
                Group {
                    if previewContent.isEmpty {
                        Text("Select a result to preview")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        CodeWebView(
                            content: previewContent,
                            language: previewLanguage,
                            webViewStore: previewWebViewStore,
                            scrollToLine: previewLine,
                            highlightText: query
                        )
                    }
                }
                .frame(minHeight: 150)
            }
        }
        .frame(minWidth: 700, idealWidth: 800, minHeight: 600, idealHeight: 700)
        .onChange(of: query) { _, newQuery in
            performSearch(query: newQuery)
        }
        .onChange(of: selectedIndex) { _, _ in
            loadPreview()
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
            appState.showGrepSearch = false
            return .handled
        }
    }

    private func performSearch(query: String) {
        searchTask?.cancel()
        guard let root = appState.activeRootPath, !query.isEmpty else {
            results = []
            previewContent = ""
            return
        }

        searchTask = Task {
            // 防抖：等待 300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }

            let searchResults = await CLIService.shared.searchContent(query: query, in: root)
            if !Task.isCancelled {
                await MainActor.run {
                    results = Array(searchResults.prefix(100))
                    selectedIndex = 0
                    loadPreview()
                }
            }
        }
    }

    private func loadPreview() {
        guard results.indices.contains(selectedIndex) else {
            previewContent = ""
            return
        }
        let result = results[selectedIndex]
        previewLanguage = FileService.shared.detectLanguage(path: result.path)
        previewLine = result.lineNumber
        if let text = FileService.shared.readFile(path: result.path) {
            previewContent = text
        } else {
            previewContent = "// Unable to read file"
        }
    }

    private func selectCurrent() {
        guard results.indices.contains(selectedIndex) else { return }
        appState.activeProject?.openFile(path: results[selectedIndex].path)
        appState.showGrepSearch = false
    }
}

struct GrepSearchRow: View {
    let result: GrepSearchResult
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(result.fileName)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(":\(result.lineNumber)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(result.lineContent)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text(result.relativePath)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }
}
