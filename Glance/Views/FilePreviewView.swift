import SwiftUI
import WebKit

struct FilePreviewView: View {
    let filePath: String
    @State private var content: String = ""
    @State private var language: String = "plaintext"

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
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 代码预览
            if content.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CodeWebView(content: content, language: language)
            }
        }
        .onAppear { loadFile() }
        .onChange(of: filePath) { _, _ in loadFile() }
    }

    private func loadFile() {
        language = FileService.shared.detectLanguage(path: filePath)
        if let text = FileService.shared.readFile(path: filePath) {
            content = text
        } else {
            content = "// Unable to read file"
        }
    }

}

/// WKWebView 封装，用 highlight.js 渲染代码
struct CodeWebView: NSViewRepresentable {
    let content: String
    let language: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        loadHTML(into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadHTML(into: webView)
    }

    private func loadHTML(into webView: WKWebView) {
        let escaped = content
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'SF Mono', 'Menlo', 'Monaco', monospace;
                font-size: 13px;
                line-height: 1.5;
                background: #1e1e1e;
                color: #d4d4d4;
            }
            pre {
                padding: 12px;
                overflow-x: auto;
            }
            code { font-family: inherit; }
            .line-numbers {
                counter-reset: line;
            }
            .line-numbers .line::before {
                counter-increment: line;
                content: counter(line);
                display: inline-block;
                width: 3em;
                margin-right: 1em;
                text-align: right;
                color: #555;
                user-select: none;
            }
        </style>
        </head>
        <body>
        <pre><code class="language-\(language) line-numbers">\(addLineSpans(escaped))</code></pre>
        <script>
            hljs.highlightAll();
        </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }

    private func addLineSpans(_ text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "<span class=\"line\">\($0)</span>" }
            .joined(separator: "\n")
    }
}
