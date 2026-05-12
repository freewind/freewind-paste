# AGENTS.md

## 1. 数据结构与分层

### 1.1 核心数据总览

项目是 macOS 菜单栏剪贴板历史工具。长期状态落盘到：

- `~/Library/Application Support/PasteBar/items.jsonl`
- `~/Library/Application Support/PasteBar/settings.json`
- `~/Library/Application Support/PasteBar/assets/images/*.png`

`items.jsonl` 一行一个 `ClipItem`。`settings.json` 存 `AppSettings`。图片真实位图不内嵌进 `jsonl`，只存相对路径。

### 1.2 关键 shape

核心领域对象：

- `ClipKind`: `text | image | file`
- `ClipContent`
  - `text?`
  - `imageAssetPath?`
  - `filePaths?`
- `ClipMeta`
  - 文本：`textPreview` `languageGuess`
  - 图片：`imageWidth` `imageHeight` `imageHash` `imageByteSize`
  - 文件：`fileName` `fileSize` `fileExists` `fileModifiedAt` `fileCount`
- `ClipItem`
  - `id`
  - `kind`
  - `createdAt` `updatedAt`
  - `trashedAt?`
  - `favorite`
  - `label`
  - `content`
  - `meta`
- `AppSettings`
  - `hotkey`
  - `launchAtLogin`
  - `popupHotkeys`

约束：

- `text` 项只用 `content.text`
- `image` 项只用 `content.imageAssetPath`
- `file` 项只用 `content.filePaths`
- `trashedAt == nil` → 正常项；非空 → 回收站项
- 去重 key：
  - `text` → 文本全文
  - `image` → `meta.imageHash`
  - `file` → `filePaths.joined`

最小示例：

```json
{"id":"c1","kind":"text","createdAt":"2026-05-12T12:00:00Z","updatedAt":"2026-05-12T12:00:00Z","trashedAt":null,"favorite":false,"label":"","content":{"text":"{\"a\":1}","imageAssetPath":null,"filePaths":null},"meta":{"textPreview":"{\"a\":1}","languageGuess":"json","imageWidth":null,"imageHeight":null,"imageHash":null,"imageByteSize":null,"fileName":null,"fileSize":null,"fileExists":null,"fileModifiedAt":null,"fileCount":null}}
```

```json
{"hotkey":{"keyCode":9,"modifiers":768},"launchAtLogin":false,"popupHotkeys":{"closePopup":{"keyCode":53,"modifiers":0},"paste":{"keyCode":36,"modifiers":0}}}
```

### 1.3 合法修改入口 op

领域数据只经 `ClipStore` 改：

- `insertOrPromote`
- `moveItems`
- `moveItemBlock`
- `reverseItems`
- `toggleFavorite` / `setFavorite`
- `updateLabel` / `updateText`
- `delete` / `restore` / `clearAll`
- `pruneExpiredTrash`

UI 查询态与选择态只经 `ClipViewState` 改：

- `select` / `focus` / `selectFirstVisible`
- `moveFocus`
- `moveFocusExtendingSelection`
- `moveFocusToScopeBoundary`
- `handleClick`
- `toggleChecked` / `setVisibleChecked` / `clearCheckedVisible`
- `normalizeSelection`

### 1.4 service 职责

纯数据层：

- `Domain/Models`：值对象、枚举、派生字段
- `Domain/Utils`：时间分组、路径规整、哈希等纯逻辑

编排层：

- `ClipboardParseService`：把粘贴板内容转 `ClipItem`
- `ClipboardCaptureService`：监听 copy/capture，产出新条目
- `ClipboardPasteService`：把选中条目写回系统粘贴板，再触发真实 paste
- `ClipWorkflowService`：收口 `store + uiState + repo + pasteService`

典型流程：

1. capture：`ClipboardCaptureService` 产出 `ClipItem`
2. workflow：`ClipWorkflowService.capture`
3. store：`insertOrPromote`
4. repo：`commitItems`
5. ui：`select` + `normalizeSelection`

### 1.5 gateway / repo / edge

IO 与副作用层：

- `ClipPersistence`：读写 `items.jsonl` / `settings.json`
- `ImageAssetStore`：保存、缩放、删除图片资产
- `ClipRepository`：组合 `persistence + imageAssetStore`，对上层暴露 load/save/clear/prune
- `AccessibilityPasteTrigger`：触发无障碍 paste
- `PasteboardWatcher` / `CopyCommandMonitor`：系统监听
- `LaunchAtLoginService`：开机启动
- `PopupWindowController` / `SettingsWindowController` / `MenuBarController`：窗口与菜单栏边界
- `AppState`：app 壳层，持有所有 controller/service/store，转发用户动作

`AppState` 负责的 app 级状态：

- `settings`
- `statusMessage`
- `isPopupVisible`
- `searchFocusNonce`
- `imageOutputMode`
- `imageLowResMaxDimension`
- `accessibilityGranted`

### 1.6 约束与禁做项

- 新业务动作先进 `ClipWorkflowService`，不要在 view 里直接拼 `store + repo`
- `ClipStore` 不放 search/tab/window 等 UI 态
- `ClipViewState` 不做持久化，不碰文件系统
- 图片条目只存 asset 相对路径，不直接塞大二进制进 `jsonl`
- 副作用尽量留在 `AppState` / repo / system service 外层

## 2. 功能

### 2.1 整体

用户是 macOS 桌面用户。主入口有 2 个：

- 菜单栏图标
- 全局热键

打开 popup 后，界面结构以 `HistoryView` 为准：

- 最外层是 `VStack(spacing: 0)`
- 第 1 段是 `header`
- 第 2 段是 `Divider()`
- 第 3 段是 `NavigationSplitView`

`header` 是顶部 `HStack`：

- `SearchBarView()`
- 类型筛选 `Picker("Type")`

`NavigationSplitView` 下半区再左右分栏：

- 左栏：包一层 `VStack(spacing: 8)`，内部顺序是 `History/Favorites/Trash` 的 segmented `Picker`、`HistoryListView()`、`sidebarFooter`
- 右栏：`PreviewPaneView()`

### 2.2 历史区

下半区左栏行为：

- 搜索框按 `SearchService` 过滤可见项
- 类型筛选支持 `all/text/image/file`
- tab 支持 `history/favorites/trash`
- 列表按时间组：`Today / Yesterday / Earlier`
- 支持单选、多选、勾选、键盘 focus
- 支持拖拽改序

批量区行为：

- 勾选全部可见项 / 清空勾选
- `Trash Checked` / `Delete Checked`
- `Reverse`
- `Restore`
- `Settings`
- `Clear All`

删除语义：

- 历史/收藏页删除 → 进回收站
- 回收站删除 → 永久删除
- `Command + Backspace` → 直接永久删
- 回收站项可 `Restore`

### 2.3 右栏预览与修改

右栏主体是 `PreviewPaneView`。单选时：

- `text`：进入 `TextPreviewView`，可直接编辑并回写条目文本
- `image`：显示 `metaHeader` + `ImagePreviewView`
- `file`：显示 `metaHeader` + `FilePreviewView`

多选时：

- `split`：逐项预览
- `merged`：合并文本草稿，仅本地 scratch，不直接改原条目

### 2.4 捕获与粘贴

捕获：

- 监听 `text / image / file`
- 新内容入库时优先去重提升，不重复堆相同项

粘贴：

- `normal`：文本/文件尽量转纯文本；图片按图片对象写回
- `native`：文件保留原生 `file URL`；图片保留图片对象
- 图片支持 `original` / `lowResolution`
- popup 打开时会记录前台 app；粘贴前尝试 re-activate 目标 app，再触发系统 paste
- 回收站项禁止 paste

### 2.5 条目操作

用户可对条目做：

- 收藏 / 取消收藏
- 改 `label`
- 改文本内容
- 反转选中顺序
- 跨 `Today / Yesterday / Earlier` 的选中块移动；未选中项保持原顺序，移动后选中项并入目标分组
- 低清复制图片
- 打开资源 / Finder 定位 / 另存

### 2.6 设置

设置页当前分 4 块：

- `Accessibility`：查看权限状态，跳系统设置
- `Behavior`：`launchAtLogin`
- `Global Hotkey`：打开 popup 的全局热键，要求带 modifier
- `Popup Hotkeys`：popup 内部动作热键
- `Data`：危险区，`Clear All Items`

当前 popup shortcut action 已覆盖：

- `closePopup`
- `focusList`
- `paste`
- `nativePaste`
- `focusPrevious` / `focusNext`
- `expandPrevious` / `expandNext`
- `jumpToTop` / `jumpToBottom`
- `moveSelectionUp` / `moveSelectionDown`
- `deleteSelection`
- `deleteSelectionPermanently`

### 2.7 边界与限制

- 自动 paste 依赖无障碍权限
- 搜索/筛选/tab 都只影响 `visibleItems`
- `Cmd+↑/↓` 总是重置成单选；无搜索时只在 `Today` 范围跳首/尾，有搜索时只在当前搜索结果范围跳首/尾
- `Alt+Shift+↑/↓` 按当前 `visibleItems` 顺序整体搬运选中块 1 格；若跨组，会把选中项的分组时间并到目标邻项所在组
- 当前仓库无测试目录；改状态机与快捷键逻辑时需手动回归

## 3. todo

- [x] 调整 popup 选区跳转与跨组块移动
  目的：让 `Cmd+↑/↓` 重置成单选跳首尾；让 `Alt+Shift+↑/↓` 支持跨 `Today/Yesterday/Earlier` 的选中块整体移动。
  当前：`Cmd+↑/↓` 已固定为单选范围跳转；跨组块移动已按 `visibleItems` 顺序整体移动，并把选中项并入目标分组。
  完成标准：`Cmd+↑/↓` 始终收敛为单选；跨组多选可整体移动 1 格，未选中项保持原顺序，移动后选中项并入目标分组。
  完成后：升格到“功能”与“边界与限制”。

- [ ] 收口 popup hotkeys 功能
  目的：让 popup 内所有动作都可配置，替掉写死按键。
  当前：worktree 已改 `AppState`、`AppSettings`、`UIState`、`ClipboardPasteService`、`HotkeyRecorderView`、`SettingsView` 等文件；已出现 `PopupShortcutAction`、`PopupHotkeys`、目标 app re-activate、范围扩选、块移动等实现。
  完成标准：设置页可稳定录入/显示快捷键；popup 内动作映射完整；搜索框与列表焦点切换不互相抢键；手动回归通过。
  完成后：升格到“数据结构与分层”与“功能”。

- [ ] 补状态/快捷键回归测试
  目的：降低 `selectedIDs`、`focusedID`、删除语义、shortcut 映射回归风险。
  当前：仓库未见测试目录，graph 也显示 test gap 多。
  完成标准：至少覆盖 `ClipViewState` 选择移动、`ClipStore` 删除/恢复、`ClipWorkflowService` paste/delete 分支、`PopupHotkeys` decode 默认值。
  完成后：升格到“功能”或新增“测试约束”。

- [ ] 文档对齐
  目的：避免 `README.md` 与实际设置页/shortcut 行为脱节。
  当前：`README.md` 已描述旧版设置与核心结构，未完整覆盖 popup hotkeys 与目标 app re-activate。
  完成标准：功能落稳后，同步 `README.md` 最小差异。
  完成后：升格到“功能”。

- [ ] 移除 `Popup Hotkeys`
  目的：收简交互模型，popup 内不再支持内部动作热键，只保留 1 个外部唤起 hotkey。
  当前：代码与设置页仍存在 `PopupHotkeys`、`PopupShortcutAction`、popup 内动作录制与映射。
  完成标准：删除 popup 内动作热键配置与映射；设置页只保留外部唤起 hotkey；相关状态、文案、持久化结构、文档同步收口。
  完成后：升格到“数据结构与分层”与“功能”。
