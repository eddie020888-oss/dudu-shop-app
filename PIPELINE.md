# 岛台小怪 · 发布流水线（无 Mac）

状态：2026-10-16 构建 0.1.0 (1)、(7) 已上传并通过 Apple 处理，内测群组自动分发。

## 链路
GitHub `eddie020888-oss/island-me`（main）→ Codemagic 应用 `island-me`（webhook 已配，push 自动构建）→ XcodeGen 生成工程 → 自动签名 → 上传 App Store Connect → TestFlight 内部群组「内测」自动分发。

## 各处的名字
- Bundle ID：`com.eddiejiang.islandme`（主）/ `com.eddiejiang.islandme.widget`（Widget），Team `7Q5J9H485X`
- App Store Connect App：岛台小怪，App ID 6823709415，SKU `islandme`
- Codemagic 签名：证书 `ParentLearning Distribution 20261008`；描述文件引用 `islandme_app_store`、`islandme_widget_app_store`（在 Personal account → Code signing identities）
- Codemagic 集成：App Store Connect API 密钥 `ParentLearning Codemagic R2`

## 踩过的坑
- `ios_signing.bundle_identifier` 只接受字符串；描述文件必须先在开发者后台生成，再在 Codemagic 后台“Fetch profiles”拉进来，yaml 只是引用。
- 上传前 App Store Connect 必须已有 App 记录，且账户持有人已接受最新开发者协议，否则 altool 报 "Cannot determine the Apple ID"。
- 纯 iPhone App 需要 `UIRequiresFullScreen=true`，否则上传报 ITMS-90474（iPad 多任务方向）。
- 版本号查询 `app-store-connect get-latest-build-number` 要传 ASC 数字 App ID（6823709415），不是 Bundle ID；传错会得到 0，上传报 "bundle version must be higher"。现在取 max(ASC 最新+1, Codemagic 构建序号)。
- `submit_to_testflight: true` 会把构建提交“外部测试审核”，需要在 ASC 填测试信息（姓名/电话/反馈邮箱），否则构建后处理报错；内部群组自动分发不需要，故设为 false。
- 第一次 push 若早于 Codemagic 添加应用，不会触发；在应用设置 → Webhooks 点 Update webhook。

## 日常改动
改代码 → push 到 main → 约 4 分钟后 TestFlight 推送更新（Apple 处理另需 5–15 分钟）。版本号自动递增。

## 给 App ID 加能力（HealthKit 已做，以后加别的照此）
Codemagic 用的描述文件是存在它后台的副本，不会自动跟着 Apple 变。流程：
1. `scripts/enable_capabilities.py`（构建第 3 步）用 ASC API 开能力；若没有有效的 App Store 描述文件就用发布证书新建 `islandme_app_store`（可用环境变量 `RESET_PROFILES=1` 强制删旧建新）。
2. Codemagic 后台 Settings → Code signing identities → iOS provisioning profiles → **Fetch profiles** → 勾新的 → 起个新引用名（如 `islandme_app_store_hk`）→ Download；删掉旧的那张（同 bundle id 只留一张，自动签名按 bundle id 匹配）。
3. 重新 push 构建。Widget 的描述文件不动。
- 2026-10-16：HealthKit 已开，当前用 `islandme_app_store_hk`。
