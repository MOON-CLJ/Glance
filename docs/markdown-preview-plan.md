# Glance Markdown 预览功能实施计划

## 目标
为 Glance 添加 Markdown 文件的原生预览功能，支持源码/渲染视图切换。

## 背景
Glance 目前使用 WKWebView + highlight.js 显示代码文件，但 Markdown 文件（.md）仅作为纯文本显示，没有渲染预览功能。本计划引入 MarkdownUI + Highlightr 实现原生的 Markdown 渲染。

## 技术选型

| 库 | 用途 | 说明 |
|---|---|---|
| MarkdownUI | Markdown 渲染 | 纯 Swift 实现，原生 SwiftUI 视图 |
| Highlightr | 代码高亮 | Swift 封装 highlight.js，支持 190+ 语言 |

## 改动范围

### 1. Package.swift（依赖添加）

添加两个 Swift Package 依赖：
- `swift-markdown-ui` (≥2.4.0)
- `Highlightr` (≥2.2.1)

### 2. Glance/Views/MarkdownPreviewView.swift（新建，约 80 行）

核心功能：
- 使用 MarkdownUI 渲染 Markdown 内容
- 使用 Highlightr 高亮代码块
- 支持暗/亮模式自动切换

```swift
import SwiftUI
import MarkdownUI
import Highlightr

struct MarkdownPreviewView: View {
    let content: String

    var body: some View {
        ScrollView {
            Markdown(content)
                .markdownTheme(.gitHub)
                .markdownCodeSyntaxHighlighter(HighlightrSyntaxHighlighter())
                .padding()
        }
    }
}

struct HighlightrSyntaxHighlighter: CodeSyntaxHighlighter {
    // 使用 Highlightr 高亮代码
}
```

### 3. Glance/Views/FilePreviewView.swift（修改，约 30 行）

改动点：
1. 添加状态变量 `@State private var showMarkdownPreview = true`
2. 添加工具栏切换按钮（仅在 Markdown 文件时显示）
3. 条件渲染逻辑：
   - Markdown 文件 + 预览模式 → `MarkdownPreviewView`
   - Markdown 文件 + 源码模式 → `CodeWebView`（保留行号、搜索）
   - 非 Markdown 文件 → `CodeWebView`（原有逻辑）

切换按钮使用 SF Symbol：
- 预览模式显示 `doc.plaintext`（切换到源码）
- 源码模式显示 `doc.richtext`（切换到预览）

## 功能对照

| 功能 | 源码模式（WebView） | 预览模式（MarkdownUI） |
|---|---|---|
| 行号 | ✅ | ❌（MarkdownUI 不支持）|
| 代码高亮 | ✅ highlight.js | ✅ Highlightr |
| 文件内搜索 | ✅ | ❌（本期不做）|
| 滚动性能 | 中等 | 好 |
| 内存占用 | 高（WebView）| 低 |

## 实现步骤

1. **添加依赖** - 修改 Package.swift
2. **创建预览视图** - MarkdownPreviewView.swift
3. **集成切换功能** - 修改 FilePreviewView.swift
4. **测试验证**：
   - 打开 .md 文件，默认显示渲染视图
   - 点击切换按钮，切换到源码视图（带行号）
   - 代码块语法高亮正常
   - 打开非 Markdown 文件，不显示切换按钮

## 预计工作量
约 30-45 分钟。

## 后续可扩展（本期不做）
- Markdown 文件内搜索
- 自定义 CSS 主题
- 导出 HTML/PDF
