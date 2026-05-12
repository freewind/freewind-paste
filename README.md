# PasteBar

macOS 菜单栏剪贴板历史工具。当前实现重点：

- 捕获 `text / image / file`
- `jsonl + assets/images` 持久化
- 搜索、收藏、label、批量勾选
- 类型筛选、回收站
- 右侧预览/编辑
- 图片原图/低清预览与低清复制

## 持久化

目录：

```text
~/Library/Application Support/PasteBar/
├── items.jsonl
├── settings.json
└── assets/
    └── images/
        └── *.png
```

- `items.jsonl`
  - 一行一个 `ClipItem`
- `settings.json`
  - `AppSettings`
- `assets/images/*.png`
  - 图片条目的真实位图资产

## 核心数据结构

### ClipKind

```swift
enum ClipKind: String, Codable {
  case text
  case image
  case file
}
```

### ClipContent

```swift
struct ClipContent: Codable, Equatable, Hashable {
  var text: String?
  var imageAssetPath: String?
  var filePaths: [String]?
}
```

约束：

- `text` → 只用 `text`
- `image` → 只用 `imageAssetPath`
- `file` → 只用 `filePaths`

### ClipMeta

```swift
struct ClipMeta: Codable, Equatable, Hashable {
  var textPreview: String?
  var languageGuess: String?

  var imageWidth: Int?
  var imageHeight: Int?
  var imageHash: String?
  var imageByteSize: Int64?

  var fileName: String?
  var fileSize: Int64?
  var fileExists: Bool?
  var fileModifiedAt: Date?
  var fileCount: Int?
}
```

说明：

- 文本：
  - `textPreview` → 左栏摘要
  - `languageGuess` → 当前主要用于 `json` 高亮
- 图片：
  - `imageWidth/imageHeight` → 像素尺寸
  - `imageHash` → 去重 key
  - `imageByteSize` → 当前图片资产字节数
- 文件：
  - `fileName` → 首个文件名
  - `fileSize` → 总字节数
  - `fileExists` → 当前路径是否都存在
  - `fileModifiedAt` → 最新修改时间
  - `fileCount` → 文件数

### ClipItem

```swift
struct ClipItem: Identifiable, Codable, Equatable, Hashable {
  let id: String
  let kind: ClipKind
  var createdAt: Date
  var updatedAt: Date
  var trashedAt: Date?
  var favorite: Bool
  var label: String
  var content: ClipContent
  var meta: ClipMeta
}
```

补充语义：

- `id` → 稳定主键
- `favorite` → 收藏页入口
- `label` → 用户自定义名称
- `updatedAt` → 分组与排序参考
- `trashedAt`
  - `nil` → 正常项
  - 非空 → 回收站项
  - 超过 7 天自动清理
- 去重：
  - text → 文本全文
  - image → `imageHash`
  - file → `filePaths` 拼接值

### AppSettings

```swift
struct AppHotkey: Codable, Equatable {
  var keyCode: UInt32
  var modifiers: UInt32
}

struct AppSettings: Codable, Equatable {
  var hotkey: AppHotkey
  var launchAtLogin: Bool
}
```

## 运行态状态

### ClipStore

只放领域数据：

```swift
@Published var items: [ClipItem]
```

修改入口：

- `insertOrPromote`
- `moveItems`
- `reverseItems`
- `toggleFavorite / setFavorite`
- `updateLabel / updateText`
- `delete / restore / clearAll`
- `pruneExpiredTrash`

不放：

- 选中态
- 搜索态
- tab
- filter
- 任何窗口/UI 状态

### ClipViewState

只放 UI 查询态 + 选择态：

```swift
@Published var selectedIDs: Set<String>
@Published var checkedIDs: Set<String>
@Published var focusedID: String?
@Published var currentTab: MainTab
@Published var searchQuery: String
@Published var kindFilter: ClipKindFilter
var selectionAnchorID: String?
```

派生查询：

- `visibleItems`
- `groupedVisibleItems`
- `focusedItem`
- `selectedItems`
- `checkedVisibleItems`
- `visibleCheckedState`

交互入口：

- `normalizeSelection`
- `select / focus / selectFirstVisible`
- `moveFocus`
- `handleClick`
- `toggleChecked / setVisibleChecked / clearCheckedVisible`

### ClipWorkflowService

业务编排层：

- `capture`
- `pasteSelection`
- `updateText / updateLabel`
- `toggleFavorite / setFavorite`
- `moveItems / reverseSelection`
- `delete / restore / clearAll`
- `copyLowResolutionImage`
- `commitItems`

规则：

- 上层不自己拼 `store + repo`
- 一次业务动作内，持久化只经 `commitItems`
- `uiState` 修正与 `store` 改动一起收口在 service

删除语义：

- `Backspace`
  - 历史/收藏页 → 移到回收站
  - 回收站页 → 永久删除
- `Command + Backspace`
  - 直接永久删除
- 回收站支持 `Restore`
- 右键删除在历史/收藏页也是进回收站

### AppState

当前职责：

- app 壳层
- 绑定菜单栏 / 热键 / 窗口
- 调 workflow
- 维护少量 app 级展示态

主要字段：

```swift
@Published var settings: AppSettings
@Published var statusMessage: String
@Published var isPopupVisible: Bool
@Published var searchFocusNonce: Int
@Published var imageOutputMode: ImageOutputMode
@Published var imageLowResMaxDimension: Double
@Published var accessibilityGranted: Bool
```

说明：

- `imageOutputMode`
  - `original | lowResolution`
- `imageLowResMaxDimension`
  - 低清图片当前预览/粘贴/复制使用的最长边
- `accessibilityGranted`
  - Settings 窗口里轮询刷新

### 持久化边界

分两层：

- `ClipPersistence`
  - jsonl/json 文件 IO
  - 最底层文件读写
- `ClipRepository`
  - store backend
  - `loadItems/loadSettings/saveSettings/commitItems/clearAll`
  - 读入迁移
  - 图片资产清理

当前读入迁移：

- 旧文本项 `content.text` 缺失时，回填自 `meta.textPreview`
- 补齐 `textPreview`
- 文件项补 `fileCount/fileName`

### 系统交互边界

SDK 直接够用处，不额外包。

需要权限/系统事件/窗口生命周期的，走 access util：

- `AccessibilityPasteTrigger`
- `HotkeyService`
- `LaunchAtLoginService`
- `PasteboardWatcher`
- `CopyCommandMonitor`
- `PopupWindowController`
- `SettingsWindowController`
- `MenuBarController`

## 图片低清流

当前行为：

1. 原图入库为 `assets/images/*.png`
2. 预览侧切到 `Low`
3. 用 `imageLowResMaxDimension` 做最长边降采样
4. 右侧显示：
   - 原图尺寸/字节
   - 当前低清尺寸/字节
5. 点 `Copy`
   - 生成一条新的低清图片 `ClipItem`
   - 同样持久化进 `items.jsonl + assets/images`

## 当前未做

- 传输协议
- 双端在线/离线同步
- 撤回跨端联动
- 文件夹传输确认流
- 传输中取消/进度管理

上面这些应单独作为 Phase 2 数据结构，不应直接塞进当前 `ClipItem`。
