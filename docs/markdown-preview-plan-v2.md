# Glance Markdown 预览功能实施计划 V2

## 目标
为 Glance 添加 Markdown 文件的原生预览功能，支持源码/渲染视图切换。

## 背景
Glance 目前使用 WKWebView + highlight.js 显示代码文件。本方案沿用现有 WebView 架构，引入 marked.js 实现 Markdown 渲染，无需额外 Swift 依赖。

## 技术选型

| 库 | 用途 | 说明 |
|---|---|---|
| marked.js | Markdown 渲染 | 纯 JS 实现，速度快，GitHub 在用 |
| github-markdown-css | 样式主题 | 复刻 GitHub Markdown 外观 |
| highlight.js | 代码高亮 | 已集成，继续复用 |

**优势：**
- 零 Swift 依赖，不增加包体积
- 复用现有 WKWebView 架构
- 渲染效果与 GitHub 一致

## 改动范围

### 1. Glance/Resources/markdown-preview.html（新建，约 60 行）

HTML 模板文件，嵌入到 App Bundle：

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/github-markdown-css/github-markdown.min.css">
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/highlight.js/lib/highlight.min.js"></script>
    <style>
        body { margin: 0; padding: 32px; }
        .markdown-body { max-width: 900px; margin: 0 auto; }
    </style>
</head>
<body class="markdown-body">
    <div id="content"></div>
    <script>
        function renderMarkdown(text) {
            document.getElementById('content').innerHTML = marked.parse(text);
            document.querySelectorAll('pre code').forEach((block) => {
                hljs.highlightElement(block);
            });
        }
    </script>
</body>
</html>
```

### 2. Glance/Views/FilePreviewView.swift（修改，约 40 行）

改动点：
1. 添加状态变量 `@State private var showMarkdownPreview = true`
2. 添加工具栏切换按钮（仅在 Markdown 文件时显示）
3. 条件渲染逻辑：
   - Markdown 文件 + 预览模式 → `MarkdownWebView`（新）
   - Markdown 文件 + 源码模式 → `CodeWebView`（保留行号、搜索）
   - 非 Markdown 文件 → `CodeWebView`（原有逻辑）

切换按钮使用 SF Symbol：
- 预览模式显示 `doc.plaintext`（切换到源码）
- 源码模式显示 `doc.richtext`（切换到预览）

### 3. Glance/Views/MarkdownWebView.swift（新建，约 50 行）

WKWebView 封装，加载本地 HTML 模板并通过 JS 注入 Markdown 内容：

```swift
import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let content: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        loadAndRender(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        renderContent(in: webView)
    }

    private func loadAndRender(in webView: WKWebView) {
        // 加载本地 HTML 模板
        guard let htmlURL = Bundle.main.url(forResource: "markdown-preview", withExtension: "html"),
              let htmlString = try? String(contentsOf: htmlURL) else {
            return
        }
        webView.loadHTMLString(htmlString, baseURL: nil)

        // 等待加载完成后渲染 Markdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.renderContent(in: webView)
        }
    }

    private func renderContent(in webView: WKWebView) {
        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let script = "renderMarkdown('\(escaped)');"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}
```

## 功能对照

| 功能 | 源码模式（CodeWebView） | 预览模式（MarkdownWebView） |
|---|---|---|
| 行号 | ✅ | ❌ |
| 代码高亮 | ✅ highlight.js | ✅ highlight.js |
| 文件内搜索 | ✅ | ❌（本期不做）|
| 滚动性能 | 中等 | 中等 |
| 内存占用 | 高（WebView）| 高（WebView）|
| 暗/亮模式 | ✅ | ✅（github-markdown-css 支持）|

## 实现步骤

1. **创建 HTML 模板** - `Glance/Resources/markdown-preview.html`
2. **更新 project.yml** - 将 HTML 文件加入 Copy Bundle Resources
3. **创建 MarkdownWebView** - `Glance/Views/MarkdownWebView.swift`
4. **集成切换功能** - 修改 `FilePreviewView.swift`
5. **测试验证**：
   - 打开 .md 文件，默认显示渲染视图
   - 点击切换按钮，切换到源码视图（带行号）
   - 代码块语法高亮正常
   - 暗/亮模式切换正常
   - 打开非 Markdown 文件，不显示切换按钮

## 预计工作量

约 25-35 分钟。

## 后续可扩展（本期不做）

- Markdown 文件内搜索
- 自定义 CSS 主题
- 导出 HTML/PDF
- 图片本地路径解析

## V1 vs V2 对比

| | V1 (MarkdownUI) | V2 (marked.js) |
|---|---|---|
| 依赖 | MarkdownUI + Highlightr | 无 Swift 依赖 |
| 架构 | 原生 SwiftUI | WKWebView |
| 包体积 | +~500KB | +~0KB |
| 渲染一致性 | 需微调 | 与 GitHub 一致 |
| 暗/亮模式 | 需手动实现主题 | CSS 自动适配 |
| 代码复用 | 低（新架构）| 高（复用 WebView）|
