# WezTerm vs Zellij 对比分析

> 分析日期：2026-03-26
> 目的：为 Glance 终端集成方案选型

## 架构差异

| 特性 | WezTerm | Zellij |
|------|---------|--------|
| **类型** | 原生 GUI 终端模拟器 | 终端复用器 (类似 tmux) |
| **运行方式** | 独立 macOS App | 需要运行在现有终端内 |
| **进程模型** | 单进程多窗口，CLI 通过 Unix Socket 控制 | 服务端/客户端分离，Session 持久化 |
| **窗口管理** | 原生 macOS 窗口，支持 Workspace | 虚拟 Session，attach/detach 机制 |

## CLI 能力对比（针对 Glance 需求）

### WezTerm (`wezterm/src/cli/mod.rs`)

- ✅ `rename-workspace` - 给 workspace 命名（用于标识项目）
- ✅ `spawn` - 在新窗口/tab 执行命令
- ✅ `list` - 列出所有窗口/tabs/panes
- ✅ `activate-tab` - 激活指定 tab
- ✅ Unix domain socket 连接控制运行中的实例

### Zellij (`zellij-utils/src/cli.rs`)

- ✅ `RenameSession` - 重命名 session（类似 workspace 命名）
- ✅ `SwitchSession` - 切换到指定 session
- ✅ `NewTab` / `GoToTabName` - Tab 管理
- ✅ `Attach` / `Detach` - 会话 attach/detach
- ✅ 丰富的 pane 管理（split, resize, focus 等）

## 关键区别

### WezTerm 优势

1. **原生 GUI** - 是真正的 macOS 应用，可以被 Dock/AltTab 识别
2. **Workspace 概念** - 一个窗口内多个 workspace，类似 VS Code
3. **启动即窗口** - 不需要先开终端再启动
4. **更易集成** - 作为外部窗口管理，与 Glance 配合更自然

### Zellij 优势

1. **Session 持久化** - detach 后进程继续运行，reattach 恢复
2. **更灵活的布局** - 插件系统、自定义布局更强大
3. **Web 界面** - 内置 web server 可远程访问

### Zellij 劣势（针对 Glance 场景）

- 需要在某个终端内运行，不是独立 GUI 应用
- 窗口激活需要额外的终端窗口管理

## 推荐结论：WezTerm

### 选择理由

1. **符合 Glance 架构设想** - WezTerm 作为独立应用，Glance 通过 CLI 控制，与 Ghostty/iTerm2 思路一致

2. **Workspace 命名** - 可以用 `wezterm cli rename-workspace` 给每个项目 workspace 命名，实现"项目 → 窗口"的映射

3. **激活机制** - 虽然不像 iTerm2 的 AppleScript 那样直接，但可以通过：
   - 给 workspace 命名
   - `wezterm cli list` 获取窗口列表
   - 通过 macOS API 或 `open` 命令激活窗口

4. **实现路径更清晰**

### 实现思路

```bash
# 1. 创建/切换到项目 workspace
wezterm cli rename-workspace --workspace "Glance:ProjectA"

# 2. 创建新窗口
wezterm cli spawn --cwd /path/to/project

# 3. 列出所有 workspace
wezterm cli list --format json
```

Glance 中维护 `projectId → workspaceName` 的映射，通过 WezTerm CLI：
- 项目切换时，检查是否存在对应 workspace
- 存在则激活，不存在则 `spawn` 新窗口并 `rename-workspace`

这比 Zellij 更适合，因为 Zellij 需要管理"在哪个终端窗口运行"这一层复杂性。

## 参考文件

- [WezTerm CLI 源码](https://github.com/wez/wezterm/blob/main/wezterm/src/cli/mod.rs)
- [Zellij CLI 源码](https://github.com/zellij-org/zellij/blob/main/zellij-utils/src/cli.rs)
