# Glance 代码优化计划

## 高优先级

### 1. FileService 同步阻塞主线程

**问题**: `FileService.listDirectory()` 和 `runFd()` 是同步方法，内部用 `Process.waitUntilExit()` 阻塞。以下场景全部卡 UI：
- 目录展开（`FileNode.loadChildren`）
- 文件变化刷新（`SidebarView.onChange` → `FileNode.merge` 对每个展开目录都同步调 `fd`）
- App 启动（`restoreProjects` → `addFolder` → `listDirectory`）

**建议**: 将 `listDirectory` / `runFd` 改为 `async`，`SidebarView` 和 `FileTreeRow` 中的调用用 `Task { await }` 包裹。`FileNode` 内部方法（`loadChildren`、`merge`、`expandToPath` 等）也需同步改为 async。注意：改动面较广，需要全链路测试。

**涉及文件**: `FileService.swift`、`FileNode.swift`、`SidebarView.swift`

### 2. FilePreviewView 每次 loadFile 都重建 210 行 HTML 模板

**问题**: `loadHTML()` 每次加载文件都拼接完整 HTML/CSS/JS 字符串（含 highlight.js CDN 引用）。

**建议**: 做成静态模板或从 bundle 加载；CDN 引用改为本地 bundle。

**涉及文件**: `FilePreviewView.swift`（行 248-458）

### 3. CLI 工具路径硬编码

**问题**: `/opt/homebrew/bin/fd` 和 `/opt/homebrew/bin/rg` 在 `CLIService` 和 `FileService` 中各出现一次，Intel Mac 上会失败。

**建议**: 用 `which` 动态查找（同 zellij 的处理方式）。

**涉及文件**: `CLIService.swift`（行 6-7）、`FileService.swift`（行 6）

---

## 中优先级

### 4. FileSearchView / GrepSearchView 重复代码

**问题**: 两个搜索视图有大量重复逻辑：
- 选择绑定逻辑（完全相同）
- 键盘处理（完全相同）
- `isSelected` 参数在两个 Row 中都未使用（死代码）

**建议**: 提取共享的 `SearchViewHelper` 或用泛型 View 统一；移除 `isSelected` 死参数。

**涉及文件**: `FileSearchView.swift`、`GrepSearchView.swift`

### 5. closeProject / closeFile 索引调整重复

**问题**: `AppState.closeProject` 和 `ProjectState.closeFile` 的 index 调整逻辑结构一致。

**建议**: 提取泛型方法 `adjustIndex(afterRemoving:from:active:)`。

**涉及文件**: `AppState.swift`（行 78-87）、`ProjectState.swift`（行 78-91）

### 6. JS 字符串转义重复

**问题**: `FilePreviewView` 中三处相同的 `replacingOccurrences(of: "\\", with: "\\\\")` + `replacingOccurrences(of: "'", with: "\\'")`。

**建议**: 提取 `escapeJSString(_:)` helper 方法。

**涉及文件**: `FilePreviewView.swift`（行 157-158、224-225、241-242）

### 7. detectLanguage() 每次调用都创建新字典

**问题**: 25+ 条目的 `languageMap` 字典每次调用都分配。

**建议**: 改为 `static let languageMap`。

**涉及文件**: `FileService.swift`（行 114-124）

### 8. iconForFile() 可简化

**问题**: 多个扩展名映射到 `"doc.text"`，用 switch-case 逐个写。

**建议**: 用 `Set<String>` 分组简化。

**涉及文件**: `FileService.swift`（行 91-108）

---

## 低优先级

### 9. GrepSearchResult.matchRanges 死代码

**问题**: `matchRanges` 初始化为 `[]` 后从未填充。

**建议**: 移除该字段。

**涉及文件**: `SearchResult.swift`（行 19）

### 10. FileSearchResult / GrepSearchResult 重复字段

**问题**: 两个 struct 都有 `path`、`relativePath`、`fileName`。

**建议**: 用 protocol 或共享父 struct。

**涉及文件**: `SearchResult.swift`

### 11. restoreProjects 中 N 次 saveProjects

**问题**: 每次 `addFolder` 都触发 `saveProjects()`，启动时白写 N-1 次 UserDefaults。

**建议**: 批量 restore 后只 save 一次。

**涉及文件**: `AppState.swift`（行 92-107）

### 12. GrepSearchView 多余的 DispatchQueue.main.async

**问题**: `onChange` 已在主线程，不需要再 dispatch。

**涉及文件**: `GrepSearchView.swift`（行 88）
