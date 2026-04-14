import SwiftUI

struct GrepSearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var options = SearchOptions()
    @State private var results: [GrepSearchResult] = []
    @State private var selectedIndex = 0
    @State private var searchTask: Task<Void, Never>?
    @State private var previewContent = ""
    @State private var previewLanguage = "plaintext"
    @State private var previewLine: Int? = nil
    @StateObject private var previewWebViewStore = WebViewStore()

    var body: some View {
        VStack(spacing: 0) {
            searchField("Search in files...", icon: "text.magnifyingglass", query: $query, onSubmit: selectCurrent)

            Divider()

            SearchOptionsBar(options: $options)

            Divider()

            VSplitView {
                Group {
                    if results.isEmpty && !query.isEmpty {
                        Text("No results")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        resultList
                    }
                }
                .frame(minHeight: 150)

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
        .onChange(of: options) { _, _ in
            performSearch(query: query)
        }
        .onChange(of: selectedIndex) { _, _ in
            loadPreview()
        }
        .searchKeyboardHandling(
            selectedIndex: $selectedIndex,
            resultCount: results.count,
            onClose: { appState.showGrepSearch = false }
        )
    }

    private var resultList: some View {
        List(selection: SearchSelection.binding(for: results, selectedIndex: selectedIndex) { idx in
            selectedIndex = idx
        }) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                GrepSearchRow(result: result)
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
            previewContent = ""
            return
        }

        let currentOptions = options
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }

            let searchResults = await CLIService.shared.searchContent(query: query, in: root, options: currentOptions)
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
        let result = results[selectedIndex]
        appState.pendingScrollToLine = result.lineNumber
        appState.pendingHighlightText = query
        appState.activeProject?.openFile(path: result.path)
        appState.showGrepSearch = false
    }
}

// MARK: - Options toolbar

struct SearchOptionsBar: View {
    @Binding var options: SearchOptions

    var body: some View {
        HStack(spacing: 4) {
            CaseSensitivityPicker(value: $options.caseSensitivity)

            ToggleChip(label: "Word", systemImage: "textformat", isOn: $options.wholeWord)
                .help("Whole word (\\b)")

            ToggleChip(label: "Regex", systemImage: "chevron.left.forwardslash.chevron.right", isOn: $options.regex)
                .help("Regular expression")

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 2)

            FileTypePicker(value: $options.fileType)

            GlobField(value: $options.fileGlob)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct CaseSensitivityPicker: View {
    @Binding var value: CaseSensitivity

    var body: some View {
        Menu {
            Button("Smart case")      { value = .smart }
            Button("Case sensitive")  { value = .sensitive }
            Button("Ignore case")     { value = .insensitive }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .medium))
                Text(shortLabel)
                    .font(.system(size: 11))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlColor))
            .cornerRadius(5)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Case sensitivity")
    }

    private var iconName: String {
        switch value {
        case .smart:       return "textformat.abc"
        case .sensitive:   return "textformat.abc.dottedunderline"
        case .insensitive: return "textformat"
        }
    }

    private var shortLabel: String {
        switch value {
        case .smart:       return "Smart"
        case .sensitive:   return "Aa"
        case .insensitive: return "aa"
        }
    }
}

private struct ToggleChip: View {
    let label: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isOn ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlColor))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isOn ? Color.accentColor : Color.clear, lineWidth: 1)
            )
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}

private struct FileTypePicker: View {
    @Binding var value: String

    private var selectedLabel: String {
        commonFileTypes.first { $0.id == value }?.label ?? "Any"
    }

    var body: some View {
        Menu {
            ForEach(commonFileTypes) { type in
                Button(type.label) { value = type.id }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                Text(selectedLabel)
                    .font(.system(size: 11))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(value.isEmpty ? Color(nsColor: .controlColor) : Color.accentColor.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(value.isEmpty ? Color.clear : Color.accentColor, lineWidth: 1)
            )
            .cornerRadius(5)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("File type filter")
    }
}

private struct GlobField: View {
    @Binding var value: String
    @State private var editing = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "asterisk")
                .font(.system(size: 10))
                .foregroundColor(value.isEmpty ? .secondary : .accentColor)
            TextField("*.ext", text: $value)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 80)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(value.isEmpty ? Color(nsColor: .controlColor) : Color.accentColor.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(value.isEmpty ? Color.clear : Color.accentColor, lineWidth: 1)
        )
        .cornerRadius(5)
        .help("File glob filter (e.g. *.swift)")
    }
}

// MARK: - Result row

struct GrepSearchRow: View {
    let result: GrepSearchResult

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
