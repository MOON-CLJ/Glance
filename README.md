# Glance

macOS 原生代码浏览器，用于在终端工作流中快速查看代码，替代打开 IDE。

## 核心功能

- **目录树浏览** -- 左侧 Sidebar，展开/收拢目录，过滤 .git/node_modules 等
- **文件预览** -- 右侧代码预览，基于 highlight.js 语法高亮
- **快速定位文件** -- `Cmd+Shift+O` 模糊搜索文件名（调用 fd）
- **全文搜索** -- `Cmd+Shift+F` 搜索文件内容（调用 rg）
- **打开目录** -- `Cmd+O` 选择项目目录

## 依赖

- macOS 14+
- [fd](https://github.com/sharkdp/fd) -- 文件搜索
- [ripgrep](https://github.com/BurntSushi/ripgrep) -- 内容搜索

```bash
brew install fd ripgrep
```

## 构建与运行

```bash
make run    # 编译并启动
make build  # 仅编译
make clean  # 清理
```

## 使用

在 .zshrc 中添加：

```bash
glance() { open ~/dev/Glance/.build/Glance.app --args "${1:-$(pwd)}"; }
```

然后在任意项目目录下执行 `glance` 即可启动。

## 技术栈

- Swift / SwiftUI
- WKWebView + highlight.js（代码高亮）
- 复用 fd、rg 等 CLI 工具的能力
