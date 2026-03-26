# Glance Terminal 集成需求

> 状态：等待生态成熟
> 最后更新：2026-03-25

## 问题描述

当前 Glance 作为多项目代码浏览器，每个项目需要配合独立的 Ghostty 终端窗口。当同时打开多个项目时，终端窗口管理混乱，难以快速找到对应项目的终端。

## 目标体验

```
┌─────────────────────────────────────────────┐
│  [Project A]  [Project B] ...                 │  ← ProjectTabBar
├───────────────┬─────────────────────────────┤
│               │                             │
│  📁  >_       │   Terminal 1 │ Terminal 2   │  ← Terminal TabBar
│               │   ────────────────────────  │
│  ┌─────────┐  │                             │
│  │ 目录树  │  │   $                         │  ← Terminal 嵌入
│  │    或   │  │                             │
│  │ Terminal│  │                             │
│  │ 列表    │  │                             │
│  └─────────┘  │                             │
└───────────────┴─────────────────────────────┘
     Sidebar              Main Content Area
```

### 核心功能

1. **Sidebar 模式切换**：文件树图标 📁 / 终端图标 >_ 切换 Sidebar 内容
2. **Terminal 会话列表**：>_ 模式下显示当前项目的所有 terminal 会话
3. **主内容区 Terminal**：像代码预览一样支持多 tab，嵌入显示 terminal
4. **每个项目独立**：切换 Project Tab 时，Terminal 列表和会话独立

## 技术方案调研

### 1. SwiftTerm 嵌入
- **状态**：技术成熟，功能完整
- **问题**：用户认为"太重"
- **结论**：暂缓

### 2. Ghostty 窗口管理
- **启动**：`open -na Ghostty.app --args --working-directory=/path`
- **激活**：尝试通过 AppleScript `set frontmost`、`click window` 等方式
- **问题**：`set frontmost` 对 Ghostty 无效，无法可靠激活已有窗口
- **结论**：部分可行，体验不完整

### 3. libghostty 嵌入
- **状态**：API 处于 alpha 阶段，预计 2026 年中稳定
- **问题**：需要自处理 Metal 渲染 surface，集成复杂度高
- **参考**：cmux 项目使用此方案，但实现复杂
- **结论**：等待生态成熟

### 4. iTerm2 集成（待验证）
- **优势**：iTerm2 有完整的 AppleScript API，可以精确控制窗口、tab、会话
- **方案**：测试是否可以通过 AppleScript 创建/激活指定目录的窗口
- **待定**：需要验证可行性

## 可行路径

### 路径 A：iTerm2 集成（推荐尝试）
```applescript
tell application "iTerm"
    tell current window
        create tab with default profile
        tell current session
            write text "cd /project/path"
        end tell
    end tell
end tell
```

### 路径 B：降级为启动器
- 只负责启动 Ghostty，记录"已开"状态
- 不管理窗口激活，由用户自行切换
- 实现简单，但体验有限

### 路径 C：等待生态
- Ghostty 的 socket API 正在发展
- libghostty Swift 框架 2026 年可能稳定
- cmux 模式参考

## 相关文件（未来实现）

```
Glance/
├── Models/
│   ├── TerminalSession.swift      # Terminal 会话模型
│   └── ProjectState.swift         # 添加 terminalSessions 数组
├── Views/
│   ├── TerminalView.swift         # Terminal 嵌入视图
│   ├── TerminalTabBar.swift       # Terminal tabs
│   └── TerminalListView.swift     # Sidebar terminal 列表
└── ...
```

## 参考项目

- [cmux](https://github.com/manaflow-ai/cmux) - Ghostty 多窗口管理，使用 libghostty
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - Swift 终端模拟器库
- [Ghostty](https://ghostty.org) - 目标终端应用

## 下一步

1. 测试 iTerm2 AppleScript API 的可行性
2. 或等待 Ghostty/libghostty 生态成熟
3. 需求已固化，技术方案确定后可继续实现
