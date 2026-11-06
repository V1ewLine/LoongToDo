# LoongTodo

<img src="Resources/Brand/LoongTodo-icon.png" width="112" alt="LoongTodo 翻页的 L 图标">

一个原生 macOS 待办与日程应用。中文界面，以雾蓝主色、淡紫渐变、轻透圆角卡片和弹性反馈呈现；深色模式使用蓝灰背景与浅蓝文字。

## 运行

要求 macOS 14 或更新版本。仓库提供源码，首次使用先在项目目录构建：

```sh
zsh scripts/build-app.sh
open dist/LoongTodo.app
```

构建完成后也可以将 `dist/LoongTodo.app` 拖到“应用程序”。脚本使用本机 CPU 架构编译；当前已在 Apple Silicon 上验证。

第一次使用“连接系统日历”时，系统会请求日历权限；第一次保存带提醒的待办时，会请求通知权限。可以先使用不带提醒的本地待办，无需授权。

## 功能

- 待办新增、编辑、完成、恢复、删除与撤销删除；备注、重要标记、搜索。
- 可选截止日期及时间；截止时或提前 5 / 15 / 30 分钟、1 小时、1 天提醒。
- 今天、全部待办、未来七天、已完成四种视图。“今天”包含已逾期、今天到期及未设置日期的待办；“未来七天”为明天起的七个自然日。
- 月历标记待办截止日期；点击日期查看当天的系统日历安排。
- 写入指定的可编辑系统日历：单次、全天、每日、每周、每月日程，可设 1–99 个周期的间隔和重复结束日期。
- 每月重复按日号匹配，例如 31 日会跳过没有 31 日的月份。全天结束日期和重复结束日期均包含选中的当天。
- Todo 可以手动添加到日历；添加后的日程独立管理，修改、完成或删除 Todo 不会修改系统日历日程。编辑或删除日程使用系统“日历”应用。
- 不依赖第三方服务。Todo 保存在本机；日历是否同步到 iCloud / Exchange 等取决于你选择的系统日历账户。

## 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 新建待办 | ⌘ N |
| 新建日程 | ⇧ ⌘ N |
| 搜索待办 | ⌘ F |
| 撤销最近一次删除 | ⌥ ⌘ Z |
| 保存编辑 / 取消 | Return / Esc |

## 数据与提醒

数据文件：`~/Library/Application Support/com.loong.todo/todos.json`。左下角菜单可打开数据位置。写入采用原子替换；如果文件无法读取，会暂停写入并提示，而不会用空数据覆盖文件。

系统通知负责已安排的提醒，退出应用后仍可由系统展示；实际展示受通知设置、专注模式与设备状态影响。最多安排最近 60 条提醒，每次启动、激活或修改待办时重新补充。完成、删除或更改时间会更新待处理通知。

第一版不包含 Todo 的 iCloud 同步、菜单栏常驻入口、自动启动或独立的日程编辑器。

## 构建与检查

需要系统 Command Line Tools（Swift 编译器）及 Python 3。无第三方包或网络安装步骤。

```sh
zsh scripts/build-app.sh
zsh scripts/test.sh
```

构建输出为 `dist/LoongTodo.app`，带应用图标和本机临时签名。签名适合本机运行，未做 Developer ID 签名或公证，尚不是对外分发版本。

图标资源根据内容生成独立文件名，启动时直接加载当前应用包中的图标，避免更新 Logo 后 Dock 继续显示旧缓存。`.build` 与 `dist` 为本地生成目录，不纳入版本控制。

`Package.swift` 可由安装完整且版本一致的 Swift 6 / Xcode 打开；检查也可运行 `swift run TodoCoreChecks`。本机 CLT 含有重复的 `SwiftBridging` 模块声明及不一致的包管理接口，构建脚本通过项目内 VFS 覆盖隐藏重复声明，并直接调用 `swiftc`；不会修改系统工具链。

界面使用轻量半透明渐变卡片，侧栏保留 SwiftUI 原生 `.ultraThinMaterial`；背景渐变不使用大范围实时模糊，卡片阴影仅绘制背景形状。使用 Swift 6.2 / macOS 26 SDK 重新构建时，提示胶囊自动切换到 `.glassEffect`，旧系统使用渐变表面。遵从系统减少透明度和减少动态效果设置。

按钮按压与释放带弹性反馈，侧栏和日期选中背景平滑移动；完成待办后先显示勾选，再收起卡片，进度球同步反馈。数据立即保存，短暂停留只影响显示，切换分类或继续操作会取消过时的显示任务。列表按需创建可见卡片，分类与搜索替换不同时动画整批项目；提示条动画限定在自身区域。日期格式器复用，并按当前时区更新。

测试覆盖本地持久化、损坏数据保护、提醒日期、完成状态、日期筛选、夏令时下的全天日程、重复结束边界及无效日程校验。真实日历写入与通知投递需要在授权后的系统环境中验证。

## 源码

- `Sources/TodoCore`：模型、日期规则、输入校验与本地存储。
- `Sources/LoongToDo`：SwiftUI 界面、EventKit 集成、系统通知及应用状态。
- `Tests/TodoCoreTests`：不依赖 XCTest 的可执行检查，兼容仅有 Command Line Tools 的环境。
- `scripts`：本地构建、应用图标与检查脚本。
- `Resources/Brand`：原创「翻页的 L」标志与应用图标的 SVG / PNG 素材；侧栏和图标共用 `BrandMark.swift` 矢量母版。

设计预览可通过 `open dist/LoongTodo.app --args --demo` 启动（请先退出正式应用）。预览使用内存中的示例数据，不请求日历和通知权限，不保存待办，不写入日历。

系统 API 参考：[EventKit 访问权限](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui)、[重复日程](https://developer.apple.com/documentation/eventkit/creating-a-recurring-event)、[Liquid Glass](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))。
