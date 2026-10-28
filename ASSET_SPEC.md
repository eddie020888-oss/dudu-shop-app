# 岛台宠物 · 角色资产出图规范 v1

目标：让每只角色的 10 个状态帧在同一角度、同一光照、同一安全框内，缩到灵动岛 36pt 高仍能辨认表情。

## 1. 画幅与安全框
- 输出 **1024×1024，透明背景 PNG**（最终缩到 108×108 @3x 使用，约 30KB/张）。
- 角色必须落在中央 **安全框 760×760**（四边各留 132px），任何部位不得出框——岛台会硬裁切，爪子搭边缘的构图不可用。
- 角色重心略偏下：底边对齐安全框底部，顶部留空，像"从洞里探头"。
- 正面视角，微微仰视（镜头略低于角色眼睛），所有帧相同。

## 2. 光照与材质（所有帧一致）
- 主光：左上 45°，柔光；辅光：右下冷色（淡蓝）轮廓光，保证深色角色在黑底上有边。
- 材质：软体毛绒/磨砂质感，3D 渲染，皮克斯式；不要描边、不要卡通线稿。
- 不要投影、不要地面、不要背景元素。

## 3. 角色一致性锚点（每只角色固定写进提示词）
每只角色定义一张"身份卡"，所有帧都引用：
- 体型（圆/扁/立）、主色 HEX、副色 HEX
- 头部特征：角/耳/独眼/多眼，形状和位置
- **腿型（必须单独写）**：如 "round body, NO visible legs, only two tiny stubby paw-feet directly under the body, two tiny stubby arms"。不写这条，模型在 walk/run 帧会自动画出长腿，与主图不一致（紫角 v1 已踩坑）。
- 眼睛：大小比例、高光位置（固定左上一点）
- 嘴：默认表情形状
- 禁止项：不加衣服、不加道具（道具另出）

示例——默认角色「紫角」：圆润毛绒体，主色 #B9A6E8，副色 #F2C9A3（角、腮红）；两只小尖角；大圆黑眼，左上高光；小张嘴微笑；无腿，身体下方直接两只短爪，两只短手臂。
动作帧的规则：**走路/跑步只用倾斜、抬脚、摆臂表示，不改变身体结构。**

## 4. 状态帧清单（每只 10 帧，文件名固定）
| 文件名 | 状态 | 表情/动作描述 | 右侧小符号（App 内绘制，不出图） |
|---|---|---|---|
| idle | 默认 | 正视、微笑、放松 | 无 |
| walk | 走路 | 身体略向左倾，眼睛看向前方，开心 | 脚印 |
| run | 跑步 | 眼睛眯起，毛/耳向后吹，嘴张开 | 风线 |
| phone | 看手机 | 大眼睛直盯镜头，略歪头，好奇 | 👀 省略号 |
| work | 工作 | 戴小圆眼镜，眉头微皱，专注 | 铅笔 |
| movie | 看电影 | 眼睛放光，嘴微张，入迷 | 爆米花 |
| eat | 吃饭 | 两腮鼓起，满足，闭眼 | 饭碗 |
| sleep | 睡觉 | 闭眼，身体缩小 10%，头微低 | z |
| blink | 眨眼 | 与 idle 相同，仅闭眼 | 无 |
| yawn | 打哈欠 | 大张嘴，眼睛紧闭，一滴泪 | 月亮 |


### 4.1 需求帧（电子宠物合并后新增，每只 3 帧）
| 文件名 | 状态 | 描述 |
|---|---|---|
| hungry | 饿了 | 身体微塌、眼睛下垂、嘴小撇、一只手按肚子 |
| thirsty | 渴了 | 眼半闭、嘴张开吐一点舌头、手摸喉咙 |
| dirty | 脏了 | 毛凌乱、肚子和脸颊几块灰褐污渍、头顶一片叶子、低头看自己 |

### 4.2 探头帧（岛台紧凑态专用，每只至少 2 帧）
紧凑态左耳只有 36pt 高，全身缩放后脸太小。探头帧 = 只画头和搭在边上的两只爪子，身体被一条**透明的水平线**切掉，切线在画面下方约 30% 处，头占画幅宽约 75%。
| 文件名 | 状态 |
|---|---|
| peek | 探头·开心（紧凑态默认） |
| peek_sleep | 探头·趴着睡（同构图，闭眼头歪靠在爪子上） |
入库时探头帧**不留底边**：裁到紧贴，宽 324，高按比例（约 253），岛台里用 `frame(width: 44, height: 36, alignment: .bottom)`。
配饰叠加在探头帧上时按映射：头顶 0.08→0.02、眼睛 0.37→0.50、横向 ×1.5，脖子部位不画（见 AccessoryOverlay.swift）。
提示词要点："PEEKING OVER A LEDGE… the ledge itself must be INVISIBLE (transparent)… cut off by a clean straight horizontal line"。第二张用 "EXACTLY the same framing as the previous peeking image"。

规则：
- 所有帧与 idle 的轮廓差异 ≤ 15%（位置、大小、角度），否则切换时会"跳"。
- 不要在帧里画符号（爱心、汗滴等），这些由 App 在右侧区域绘制，便于复用和本地化。
- 道具（眼镜、爆米花）只能贴在角色身上，不能超出安全框。

## 5. 提示词模板
```
[身份卡全文], front view, slight low angle, centered, character occupies 70% of frame,
bottom-aligned, [状态描述], soft fluffy 3D render, Pixar style, soft key light from
upper left, cool rim light from lower right, no outline, no shadow, no ground,
no background, transparent background, PNG
Negative: text, watermark, extra limbs, props outside body, cropped, border
```

## 6. 验收
- 缩到 36pt（≈108px）后，眼睛和嘴仍可辨认；深色角色有可见轮廓。
- 10 帧并排播放不抖动。
- 每张透明通道干净，无白边（出图后用 `alpha matting` 检查边缘）。

## 6.5 主体一致性（2026-10-16 教训）
- 同一个长对话里连续出图会漂：毛色越来越灰白、脸型眼睛跑偏、出现“腰”。35 帧里被打回 24 张。
- **正确做法：开新对话，把主图（idle）作为参考图附上，每条提示词都写 "Same character as the attached reference"**，并把身份卡里的禁止项写死：one round egg-like blob, belly is the widest part, NO waist, NO neck。
- 出完先程序校色（把毛色 HSV 中位数拉到主图），再人眼逐张和主图并排比，不像就重出，不凑数。
- 入库统一尺寸：全身帧按身高归一（头顶有道具/举手的按肚宽），底对齐；探头帧按头宽归一、切线贴底。脚本 `import_final.py`。

## 7. 实际流程（已验证，ChatGPT 图像生成）
1. 同一个 ChatGPT 对话里连续出图，第一帧用完整身份卡，后续帧用 "exact same character… only change the pose: …"。
2. 每帧约 2 分钟。出完先缩到 36pt 看表情是否可辨，再入库。
3. 入库：去透明边 → 等比缩进 324 框、底对齐、4% 留白 → `Pets.xcassets/<pet>_<pose>.imageset`。
4. 紫角 v1 全套 10 帧已完成（2026-10-16），walk/run 返工一次。
5. 紫角全套 35 帧定稿（2026-10-16）：10 基础 + 3 需求 + 5 作息（wash/coffee/gym/read/wake）+ bath + 8 情绪（happy/angry/cry/laugh/surprised/shy/think/party）+ 8 探头（peek/sleep/work/eat/run/phone/hungry/thirsty）。

## 8. 角色范围（2026-10-16 定）
只做一个角色：**小紫（紫角）**。其余 7 个角色取消——每加一个动作/成长阶段/配饰都要做 N 遍，成本是乘法。
Kling 积分全部投在小紫身上：更多日常动作、表情、成长阶段。想要变化就做"换色皮肤"（同一套视频调色，动作通用）。

## 7. 动作视频（Kling 图生视频）
**人设硬规矩（每条提示词都要满足，见设定 3.1）**：以懒为主，不出现跑步、打球、健身等主动运动；手很短，道具放在肚子上/怀里/手边，绝不为了拿东西把手伸长或往远处够；任何动作都不能把它拉长、拉瘦。提示词里固定加：
每个动作的姿势照《小紫设定》3.2 的"懒姿势表"写进提示词（待机坐着、吃喝躺着、看电影靠软垫、走路坐小滑板……）。
"It is very lazy and moves as little as possible, mostly sitting or lying. Its arms are very short: everything it holds rests on its belly or lap, it never stretches or reaches its arms out. Body stays round and chubby, never stretched."

首页舞台不再换图，播 Kling 4.0 生成的 5 秒循环视频；岛台探头帧也从这些视频截取，保证静态和动态是同一个它。
- **参考图**：`kling_ref.png`（idle 帧合成到 1024 纯黑底），上传一次进 Kling Assets → Uploads，之后每条都从 Uploads 里选它当 Omni reference。
- **设置**：Kling 4.0 · Omni reference · 720p · 5s · 1:1 · 1 条。45 积分/条。每次从素材库挑参考后比例会变成 Auto，要重新点回 1:1。
- **提示词骨架**："The fluffy lavender monster from the reference <动作>. Same character as the reference image: round egg-shaped body with no waist and no neck, small cream horns, big dark eyes, pink cheeks, same colors. Pure solid black background, nothing else in the scene except <道具>. Static camera, no zoom, no pan, no lighting change. Cute 3D animated style. Seamless loop: ends in the same pose it starts."
  - 镜头乱动（健身第一版）→ 加 "whole body always fully visible and centered… camera completely locked… the character never leaves the frame"。
  - 姿势走样（趴着睡第一版像另一只）→ 改成 "standing upright facing the camera but fast asleep"，保持正面站姿。
- **取回**：页面内 `GET /api/creation/v4/projects-assets/feeds?projectId=…` 返回每条的 `resource.resource` 直链（无水印），curl 直接下。
- **入库**：`xfade` 把片尾 0.5s 与片头交叉淡化做成无缝循环 → 512×512、24fps、H.264 crf24、无音轨 → `IslandMe/Resources/Clips/<pet>_<pose>.mp4`（stand 用 idle）。13 条共 2.6MB。
- **探头帧**：`peek_from_video.py name=秒` 抠黑底（maxRGB 12→48 软阈值 + 反预乘去黑边）→ 取身高上 58% → 宽 324 贴底 → `purple_peek_<pose>`。
- **App**：`VideoPetView` 有片段就 `AVPlayerLooper` 静音循环（换动作 0.35s 淡入淡出，手机倾斜视差，点击 Q 弹），需求/表情覆盖帧和没片段的动作回退 `AnimatedPetView`。
- 当前 23 条：idle walk run phone work eat sleep wash coffee gym read wake movie drive + 实时互动 music dance call charge type + 小紫自己的生活 ball study paint uke（全部主体一致，已审）。
- 提示词加 "Super cute chubby bouncy 3D animated style" 更可爱；道具写进 "nothing else in the scene except …"。页面里 tiptap 编辑器用 `document.querySelector('.tiptap').editor.commands.insertContent(...)` 填提示词最稳。
