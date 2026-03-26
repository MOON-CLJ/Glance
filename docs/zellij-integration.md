# Glance + Zellij 集成方案

> 状态：已确定
> 日期：2026-03-26

## 架构

```
┌─────────────────┐         ┌──────────────────┐
│   Glance App    │ ──────▶ │   Zellij CLI     │
│  (Session 管理器)│         │  (Session 生命周期)│
└─────────────────┘         └──────────────────┘
                                    │
                                    ▼
                            ┌──────────────────┐
                            │  Ghostty/Terminal │
                            │  (仅渲染，无状态)  │
                            └──────────────────┘
```

## 设计原则

1. Glance 只与 Zellij 交互，管理 session 生命周期
2. Ghostty 仅作为终端渲染器，用户只开一个窗口

## Session 命名规则

### 规则

1. **Git 仓库**：`{org}·{repo}` 或 `{org}·{repo}·{worktree}`
2. **非 Git 目录**：路径中 `/` 替换为 `·`

### 示例

| 项目路径 | Session 名 | 说明 |
|---------|-----------|------|
| `~/Projects/my-app` (git repo) | `my-app` | 单仓库，无远程时用目录名 |
| `~/src/github.com/user/repo` | `user·repo` | Git 仓库，取 org·repo |
| `~/work/repo/.worktrees/feature` | `user·repo·feature` | Git worktree，加 worktree 名 |
| `~/Documents/notes` (非 git) | `·Users·foo·Documents·notes` | 非 git 目录，路径编码 |

### Swift 实现

```swift
struct ZellijController {
    func sessionName(for project: Project) -> String {
        let path = project.path

        // 1. 检测 git 仓库
        if let gitInfo = parseGitRepo(path) {
            var name = "\(gitInfo.org)·\(gitInfo.repo)"
            if let worktree = gitInfo.worktree {
                name += "·\(worktree)"
            }
            return name
        }

        // 2. 非 git：路径编码，/ 替换为 ·
        return path.replacingOccurrences(of: "/", with: "·")
    }

    private func parseGitRepo(_ path: String) -> GitInfo? {
        // 执行 git remote -v 获取 origin
        // 执行 git rev-parse --show-toplevel 获取根目录
        // 执行 git rev-parse --show-toplevel --show-superproject-working-tree 检测 worktree
        // 解析出 org, repo, worktree(可选)
        return nil
    }
}

struct GitInfo {
    let org: String      // "user" or "mycompany"
    let repo: String     // "my-project"
    let worktree: String? // "feature-branch" or nil
}
```

### 限制

- Zellij session name 长度限制：socket 路径总长度 ≤ 108 bytes (Unix)
- `·` 替换 `/` 避免被解析为路径分隔符

## 核心操作

### 1. 创建/附加 Session
```bash
cd {project-path} && zellij attach -c "{session-name}"
```

> 注意：`attach -c` 不支持 `--cwd` 参数，需在目标目录下执行

### 2. 切换 Session（需在已 attach 的 session 内执行）
```bash
zellij action switch-session "{session-name}"
```

> 注意：`action` 命令需要在已 attach 的 session 内执行，Glance 无法直接执行，需复制命令在 Terminal 内执行

### 3. 查询 Session
```bash
zellij list-sessions
```

### 4. 关闭 Session
```bash
zellij kill-session "{session-name}"
```

## Swift 实现示例

```swift
struct ZellijController {
    func sessionName(for project: Project) -> String {
        return project.url.lastPathComponent
    }

    func openProject(_ project: Project) {
        let name = sessionName(for: project)
        let path = project.path
        // 在目标目录下执行 attach -c
        runCommand("zellij", "attach", "-c", name, cwd: path)
    }

    func generateSwitchCommand(for project: Project) -> String {
        let name = sessionName(for: project)
        return "zellij action switch-session \"\(name)\""
    }
}
```

## 依赖

- `brew install zellij`
- 任意终端（Ghostty/iTerm2/Terminal.app）

## UI 设计

### Session 管理浮窗

通过快捷键或菜单打开独立的 Session 管理浮窗：

```
┌─────────────────────────────────────┐
│ Zellij Sessions              [×]    │
├─────────────────────────────────────┤
│                                     │
│ 当前项目: my-project                 │
│                                     │
│ [创建/附加 Session]                 │
│ [复制切换命令]                      │
│                                     │
├─────────────────────────────────────┤
│                                     │
│ my-project                          │
│ ├─ editor                       [×] │
│ └─ server                       [×] │
│                                     │
│ another-project                     │
│ └─ main                         [×] │
│                                     │
├─────────────────────────────────────┤
│ [刷新]                              │
└─────────────────────────────────────┘
```

**功能说明**
- [创建/附加 Session]：Glance 直接执行 `attach -c` 创建或附加 session
- [复制切换命令]：复制 `zellij action switch-session "session-name"` 到剪贴板，用户在 Terminal 内粘贴执行
- 点击 [×]：Glance 直接执行 `kill-session` 关闭该 session
- [刷新]：重新查询 `zellij list-sessions` 更新列表
