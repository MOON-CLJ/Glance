# tmux vs Zellij 对比分析

> 分析日期：2026-03-26
> 目的：理解两个终端复用器（Terminal Multiplexer）的差异

## 什么是终端复用器？

终端复用器（Terminal Multiplexer）是一种允许用户在单个终端窗口中创建多个虚拟终端会话的工具。核心特性包括：
- 会话持久化（Session Persistence）- detach/reattach
- 多窗口/面板管理
- 远程 SSH 工作流支持

## 架构对比

| 特性 | tmux | Zellij |
|------|------|--------|
| **语言** | C (~50,000 行) | Rust (~100,000+ 行) |
| **内存管理** | 手动 malloc/free | Rust 所有权系统 |
| **并发模型** | Unix domain socket + event loop | Tokio async runtime + MPSC channels |
| **进程架构** | Client-Server 双进程 | Client-Server 多线程 |
| **插件系统** | 无原生支持（依赖外部脚本） | WebAssembly (Wasmtime) 原生支持 |
| **配置语言** | 自定义文本配置 (~/.tmux.conf) | KDL (结构化配置语言) |

## 层级结构对比

### tmux: Session → Window → Pane

```
Session (my-project)
├── Window 0: editor
│   ├── Pane 0: vim
│   └── Pane 1: terminal
├── Window 1: build
│   └── Pane 0: cargo build
└── Window 2: logs
    └── Pane 0: tail -f
```

- **Session**: 最顶层容器，可独立命名、attach/detach
- **Window**: 类似标签页，全屏显示
- **Pane**: 窗口内分割区域

### Zellij: Session → Tab → Pane

```
Session (my-project)
├── Tab 0: code
│   ├── Pane 0: editor
│   ├── Pane 1: tests
│   └── Floating Pane: git status
├── Tab 1: deploy
│   └── Pane 0: ssh production
└── Plugin Pane: file-manager
```

- **Session**: 类似 tmux，但支持"复活"（resurrect）
- **Tab**: 对应 tmux 的 Window，但可配置布局
- **Pane**: 支持浮动面板（Floating Pane）
- **Plugin**: 独立的 WebAssembly 插件面板

## 核心差异详解

### 1. 客户端-服务器架构

**tmux** (`server.c`)
```c
// Unix domain socket 作为 IPC
struct sockaddr_un sa;
sa.sun_family = AF_UNIX;
strlcpy(sa.sun_path, socket_path, sizeof sa.sun_path);
bind(fd, (struct sockaddr *)&sa, sizeof sa);
listen(fd, 128);
```

- 创建 Unix socket 监听客户端连接
- 单进程事件驱动 (libevent)
- 客户端通过 socket 文件发送命令

**Zellij** (`zellij-client/src/lib.rs`)
```rust
// Tokio runtime + async I/O
let runtime = tokio::runtime::Builder::new_multi_thread()
    .worker_threads(number_of_workers)
    .build()
    .expect("Failed to create tokio runtime");
```

- 多线程异步运行时
- 支持 WebSocket（远程连接）
- 内置 web server 能力

### 2. 配置方式对比

**tmux** - 脚本式配置
```bash
# ~/.tmux.conf
set -g prefix C-a
bind | split-window -h
bind - split-window -v
bind c new-window -c "#{pane_current_path}"
```

**Zellij** - 声明式 KDL 配置
```kdl
// config.kdl
keybinds {
    shared_except "locked" {
        bind "Ctrl a" { SwitchToMode "tmux"; }
    }
}

default_layout "compact"
```

### 3. 布局系统

**tmux**
- 运行时手动分割面板
- 布局保存/恢复依赖外部插件（如 tmux-resurrect）
- 无原生浮动面板

**Zellij**
- 声明式布局文件（类似 i3wm）
```kdl
// my-layout.kdl
layout {
    pane split_direction="vertical" {
        pane name="editor" focus=true
        pane split_direction="horizontal" {
            pane name="tests"
            pane name="logs"
        }
    }
    floating_panes {
        pane name="git" command="lazygit"
    }
}
```
- 原生支持浮动面板（floating panes）
- 布局自动保存/恢复
- 堆叠面板（stacked panes）- 垂直标签

### 4. CLI 控制接口

**tmux**
```bash
# 创建/附加会话
tmux new-session -s project
tmux attach -t project

# 发送命令到 pane
tmux send-keys -t project:1.0 "cargo build" Enter

# 列出会话
tmux list-sessions
```

**Zellij**
```bash
# 创建/附加会话（一键创建+附加）
zellij attach -c project

# 发送动作（action）
zellij action new-tab --name build --cwd /path

# 列出会话
zellij list-sessions

# 远程 web 连接
zellij attach --remote https://host
```

### 5. 插件系统

**tmux**
- 无原生插件架构
- 依赖外部脚本/工具
- 热门插件通过 TPM (Tmux Plugin Manager)

**Zellij**
- 原生 WebAssembly 插件系统
- 插件用任何支持 WASM 的语言编写
- 默认插件：文件管理器、状态栏、欢迎页
```rust
// 插件 API 示例
use zellij_tile::prelude::*;

#[zellij_tile::register_plugin]
fn main() {
    // 访问 pane 内容、发送命令等
}
```

## 性能对比

| 指标 | tmux | Zellij |
|------|------|--------|
| 内存占用 | ~6MB/会话 | ~22-80MB/会话 |
| 启动时间 | ~32ms | ~28ms |
| 二进制大小 | ~500KB | ~20MB+ |
| CPU 占用 | 极低 | ~1.5% (含 UI 渲染) |

## 使用场景建议

### 选择 tmux 如果：

- 在资源受限环境运行（嵌入式、旧服务器）
- 需要最大程度的兼容性（tmux 预装于大多数系统）
- 喜欢简洁、可预测的 Unix 工具哲学
- 已建立完善的配置工作流
- 需要低内存占用

### 选择 Zellij 如果：

- 想要开箱即用的现代体验
- 需要浮动面板、智能布局等高级功能
- 计划使用或开发 WebAssembly 插件
- 需要内置 web 客户端远程访问
- 喜欢可视化快捷键提示（bottom bar）
- 不介意额外的内存开销

## 与 Glance 场景的关联

### 关键洞察

**Zellij 的问题：**
- 与 tmux 一样，需要在"某个终端内"运行
- 没有独立的 GUI 窗口
- Glance 需要额外管理"承载 Zellij 的终端窗口"

**tmux 的问题：**
- 同样需要在终端内运行
- CLI 控制更底层（send-keys 而非高级 action）

### 结论

两者都是**终端复用器**，不是独立的 GUI 终端应用。它们都：
1. 需要运行在现有的终端模拟器内
2. 提供会话持久化、多窗口管理能力
3. 通过 CLI/Socket 外部控制

这与 **WezTerm**（原生 GUI 终端）有本质区别。对于 Glance 的"项目 → 终端窗口"工作流，WezTerm 更适合，因为它是独立的 macOS 应用，可以被 Dock/AltTab 识别和管理。

## 参考资源

- [tmux 官方仓库](https://github.com/tmux/tmux)
- [Zellij 官方仓库](https://github.com/zellij-org/zellij)
- [tmux 官方文档](https://github.com/tmux/tmux/wiki)
- [Zellij 官方文档](https://zellij.dev/documentation/)

## 来源

- [Terminal Multiplexers: tmux vs Zellij - Dasroot!](https://dasroot.net/posts/2026/02/terminal-multiplexers-tmux-vs-zellij-comparison/)
- [Tmux vs Zellij: Terminal Multiplexer Decision Guide](https://tmuxai.dev/tmux-vs-zellij/)
