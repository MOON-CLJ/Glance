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
        </style>
        </head>
        <body>
        <div class="code-container">
            <div class="line-numbers">\(lineNumbers)</div>
            <div class="code-content">
                <pre><code class="language-\(language)">\(codeContent)</code></pre>
            </div>
        </div>
        <script>hljs.highlightAll();</script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}
