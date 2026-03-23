import SwiftUI
import WebKit

struct FilePreviewView: View {
    let filePath: String
    @EnvironmentObject var appState: AppState
    @State private var content: String = ""
    @State private var language: String = "plaintext"
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var matchInfo = ""
    @StateObject private var webViewStore = WebViewStore()

    var body: some View {
        VStack(spacing: 0) {
            // 顶部文件路径栏
            HStack {
                Image(systemName: FileService.shared.iconForFile(filePath))
                    .foregroundColor(.secondary)
                Text(filePath)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 搜索栏
            if showSearch {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { findNext() }
                    if !matchInfo.isEmpty {
                        Text(matchInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Button(action: findPrevious) {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    Button(action: findNext) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    Button(action: closeSearch) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()
            }

            // 代码预览
            if content.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CodeWebView(content: content, language: language, webViewStore: webViewStore)
            }
        }
        .onAppear { loadFile() }
        .onChange(of: filePath) { _, _ in
            loadFile()
            if showSearch { closeSearch() }
        }
        .onChange(of: appState.fileChangeCounter) { _, _ in loadFile() }
        .onChange(of: searchQuery) { _, query in
            performSearch(query: query)
        }
        .onChange(of: appState.showInFileSearch) { _, show in
            showSearch = show
            if !show { clearSearch(); searchQuery = "" }
        }
        .onKeyPress(.escape) {
            if showSearch { closeSearch(); return .handled }
            return .ignored
        }
    }

    private func loadFile() {
        language = FileService.shared.detectLanguage(path: filePath)
        if let text = FileService.shared.readFile(path: filePath) {
            content = text
        } else {
            content = "// Unable to read file"
        }
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else { clearSearch(); return }
        let escaped = query.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        webViewStore.webView?.evaluateJavaScript("searchText('\(escaped)')") { result, _ in
            if let info = result as? String { matchInfo = info }
        }
    }

    private func findNext() {
        webViewStore.webView?.evaluateJavaScript("findNext()") { result, _ in
            if let info = result as? String { matchInfo = info }
        }
    }

    private func findPrevious() {
        webViewStore.webView?.evaluateJavaScript("findPrevious()") { result, _ in
            if let info = result as? String { matchInfo = info }
        }
    }

    private func clearSearch() {
        webViewStore.webView?.evaluateJavaScript("clearSearch()")
        matchInfo = ""
    }

    private func closeSearch() {
        showSearch = false
        searchQuery = ""
        appState.showInFileSearch = false
        clearSearch()
    }
}

/// 持有 WKWebView 引用，供 FilePreviewView 调用 JS
class WebViewStore: ObservableObject {
    var webView: WKWebView?
}

/// WKWebView 封装，用 highlight.js 渲染代码
struct CodeWebView: NSViewRepresentable {
    let content: String
    let language: String
    let webViewStore: WebViewStore

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webViewStore.webView = webView
        loadHTML(into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webViewStore.webView = webView
        loadHTML(into: webView)
    }

    private func loadHTML(into webView: WKWebView) {
        let escaped = content
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        let lines = escaped.split(separator: "\n", omittingEmptySubsequences: false)
        let lineCount = lines.count
        let lineNumbers = (1...max(lineCount, 1)).map { "\($0)" }.joined(separator: "\n")
        let codeContent = lines.joined(separator: "\n")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/styles/github-dark.min.css" integrity="sha384-wH75j6z1lH97ZOpMOInqhgKzFkAInZPPSPlZpYKYTOqsaizPvhQZmAtLcPKXpLyH" crossorigin="anonymous">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/highlight.min.js" integrity="sha384-RH2xi4eIQ/gjtbs9fUXM68sLSi99C7ZWBRX1vDrVv6GQXRibxXLbwO2NGZB74MbU" crossorigin="anonymous"></script>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'SF Mono', 'Menlo', 'Monaco', monospace;
                font-size: 13px;
                line-height: 1.5;
                background: #1e1e1e;
                color: #d4d4d4;
            }
            .code-container {
                display: flex;
                overflow-x: auto;
            }
            .line-numbers {
                flex-shrink: 0;
                padding: 12px 0;
                text-align: right;
                color: #555;
                user-select: none;
                border-right: 1px solid #333;
                padding-right: 12px;
                margin-right: 12px;
                white-space: pre;
            }
            .code-content {
                flex: 1;
                min-width: 0;
            }
            pre {
                padding: 12px 0;
                margin: 0;
                overflow-x: auto;
            }
            code {
                font-family: inherit;
            }
            .hljs { background: transparent !important; padding: 0 !important; }
            .search-match { background: #614d00; color: inherit; border-radius: 2px; }
            .search-current { background: #9e7700; outline: 1px solid #d4a800; }
        </style>
        </head>
        <body>
        <div class="code-container">
            <div class="line-numbers">\(lineNumbers)</div>
            <div class="code-content">
                <pre><code class="language-\(language)">\(codeContent)</code></pre>
            </div>
        </div>
        <script>
        hljs.highlightAll();

        var _matches = [];
        var _currentIdx = -1;

        function searchText(query) {
            clearSearch();
            if (!query) return '0/0';
            var content = document.querySelector('.code-content');
            var walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT);
            var textNodes = [];
            while (walker.nextNode()) textNodes.push(walker.currentNode);

            var lowerQuery = query.toLowerCase();
            textNodes.forEach(function(node) {
                var text = node.textContent;
                var lowerText = text.toLowerCase();
                var idx = lowerText.indexOf(lowerQuery);
                if (idx === -1) return;
                var parts = [];
                var lastIdx = 0;
                while (idx !== -1) {
                    if (idx > lastIdx) parts.push(document.createTextNode(text.substring(lastIdx, idx)));
                    var mark = document.createElement('mark');
                    mark.className = 'search-match';
                    mark.textContent = text.substring(idx, idx + query.length);
                    parts.push(mark);
                    _matches.push(mark);
                    lastIdx = idx + query.length;
                    idx = lowerText.indexOf(lowerQuery, lastIdx);
                }
                if (lastIdx < text.length) parts.push(document.createTextNode(text.substring(lastIdx)));
                var parent = node.parentNode;
                parts.forEach(function(p) { parent.insertBefore(p, node); });
                parent.removeChild(node);
            });

            if (_matches.length > 0) { _currentIdx = 0; highlightCurrent(); }
            return infoText();
        }

        function findNext() {
            if (_matches.length === 0) return infoText();
            _currentIdx = (_currentIdx + 1) % _matches.length;
            highlightCurrent();
            return infoText();
        }

        function findPrevious() {
            if (_matches.length === 0) return infoText();
            _currentIdx = (_currentIdx - 1 + _matches.length) % _matches.length;
            highlightCurrent();
            return infoText();
        }

        function clearSearch() {
            _matches.forEach(function(m) {
                var parent = m.parentNode;
                parent.replaceChild(document.createTextNode(m.textContent), m);
                parent.normalize();
            });
            _matches = [];
            _currentIdx = -1;
        }

        function highlightCurrent() {
            _matches.forEach(function(m, i) {
                m.className = i === _currentIdx ? 'search-match search-current' : 'search-match';
            });
            if (_matches[_currentIdx]) {
                _matches[_currentIdx].scrollIntoView({ block: 'center', behavior: 'smooth' });
            }
        }

        function infoText() {
            if (_matches.length === 0) return 'No results';
            return (_currentIdx + 1) + '/' + _matches.length;
        }
        </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}
