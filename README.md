# 岛台小人 · Island Me — Xcode 工程骨架

灵动岛里的剪影小人，跟着你的真实动作走。iOS 16.2+，iPhone 14 Pro 及以上才有灵动岛（旧机型显示在锁屏横幅）。

## 目录
```
Shared/                      两个 target 都要加入
  IslandMeAttributes.swift   Pose 枚举、Character 外观模型、Live Activity 属性
  SilhouetteView.swift       剪影绘制（Canvas，保留作备用风格）
  PetView.swift              角色帧加载（Asset: <pet>_<pose>）+ 右耳状态小符号
IslandMe/                    主 App
  IslandMeApp.swift          设置界面（动作来源、人物参数、颜色）
  ActivityDetector.swift     CoreMotion → Pose 识别
  LiveActivityManager.swift  启动/更新/结束 Live Activity
  ChatStore.swift            聊天记录（App Group 持久化）+ 本地规则回复 + 小人主动开口
  ChatView.swift             聊天页（从岛台 zoom 放大进入，头像同步动作）
IslandMeWidget/              Widget Extension
  IslandMeWidget.swift       灵动岛三态 + 锁屏视图
```

## 无 Mac 流程（当前采用）：GitHub → Codemagic → TestFlight
- `project.yml` 用 XcodeGen 生成 Xcode 工程，仓库里不提交 .xcodeproj。
- `codemagic.yaml`：推送到 main → Codemagic 云端 Mac 生成工程、自动签名（复用 "ParentLearning Codemagic R2" 的 App Store Connect 密钥）、打包、上传 TestFlight。
- 前置：App Store Connect 里需要存在 Bundle ID 为 `com.eddiejiang.islandme` 的 App 记录（名称"岛台小怪"）。Widget 的 `com.eddiejiang.islandme.widget` 由自动签名注册。
- v1 不使用 App Groups / 推送，避免额外的能力配置；`Character.appGroup` 仅作占位。

## 有 Mac 时在 Xcode 里搭起来（约 10 分钟）
1. File → New → Project → iOS App，名字 `IslandMe`，SwiftUI，Swift。删掉默认 `ContentView.swift`。
2. File → New → Target → **Widget Extension**，名字 `IslandMeWidget`，勾选 **Include Live Activity**。删掉它自动生成的 swift 文件。
3. 把本目录的文件拖进对应 target：`Shared/` 两个文件同时勾选两个 target。
4. 两个 target 都添加 **App Groups** capability，ID 改成你自己的，并同步修改 `Character.appGroup`。
5. 主 App 的 Info.plist 添加：
   - `NSSupportsLiveActivities` = YES
   - `NSMotionUsageDescription` = “用于识别你是在走路、跑步还是静止，让岛台小人跟着动。”
6. 主 App 的 Info.plist 添加 URL Scheme `islandme`（URL Types → Identifier 任意，URL Schemes = islandme），岛台点击通过 `islandme://chat` 深链接打开聊天页。
7. 真机运行（模拟器没有 CoreMotion 活动数据，但可以用“动作来源”手动选动作看效果）。

## 角色资产
- 出图规范见 `ASSET_SPEC.md`。每只角色 10 帧，放进 **IslandMeWidget 的 Asset Catalog**（主 App 也要勾选同一 Asset），命名 `<pet>_<pose>`，如 `purple_idle`、`purple_run`。
- 没放图时 `PetView` 会画一个紫色占位圆脸，流程照样能跑通。
- 紧凑态左耳 36×36pt 贴底对齐，右耳是 SF Symbols 小符号（`PoseGlyph`），不放文字。
- Widget 扩展内存上限约 30MB：每帧用 324×324 像素（@3x）即可，别放 1024 原图。

## 识别规则（ActivityDetector）
| 信号 | 动作 |
|---|---|
| CMMotionActivity.running | 跑步 |
| walking / cycling | 走路 |
| stationary + 屏幕亮 + 屏幕朝上倾斜 | 看手机 |
| stationary + 23:00–06:00 | 睡觉 |
| stationary + 09:00–18:00 | 工作 |
| stationary + 19:00–23:00 | 看电影 |
| 其它 | 站立 |

“吃饭”没有可靠传感器信号，当前只能手动选；后续可接日历/Focus。

## 聊天与岛台的分工
- 岛台展开态（长按）只显示：小人 + 当前动作 + 它最近说的一句（`lastLine`）。Live Activity 不能放输入框。
- 点击岛台任意位置 → `islandme://chat` → App 内 `ChatView` 以 zoom 转场从岛台位置放大。
- 动作变化时 `ChatStore.speak(for:)` 让小人主动说一句，并发本地通知，同时更新岛台上的 `lastLine`。
- `ChatStore.reply(to:pose:)` 现在是本地规则，换成 LLM 时把 pose / 时间 / 步数作为上下文传入即可。

## 已知限制（Apple 平台规则，不是 bug）
- Live Activity 不能逐帧动画，所以走路/跑步是固定的迈步姿态，切换动作时有系统过渡。
- 后台更新有预算，节流为 ≥20 秒一次；动作变化会立即更新。
- Live Activity 最长 8 小时自动结束，之后需要重新打开 App 开启（可用后台推送续期，后续再做）。
- 岛台区域本身是黑色硬件，背景色只在展开态和锁屏看得出来。
