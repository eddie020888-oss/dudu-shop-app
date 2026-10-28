import Foundation
import ActivityKit
import SwiftUI
import WidgetKit

@main
struct IslandMeWidgetBundle: WidgetBundle {
    var body: some Widget {
        IslandMeLiveActivity()
        XiaoziHomeWidget()
    }
}

struct IslandMeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IslandMeAttributes.self) { context in
            // 锁屏 / 通知中心横幅：它 + 一句话 + 三个按钮（不用解锁就能喂、喝、摸）
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    DressedPetView(pet: context.state.character.pet, pose: context.state.pose, frame: context.state.frame.isEmpty ? context.state.need : context.state.frame, tick: context.state.tick, accessories: context.state.character.accessories ?? [])
                        .frame(width: 64, height: 64)
                    Group {
                        if !context.state.frame.isEmpty, !context.state.lastLine.isEmpty { Text(context.state.lastLine) }
                        else if let need = Need(rawValue: context.state.need) { Text(need.wantLine).foregroundStyle(.orange) }
                        else if !context.state.lastLine.isEmpty { Text("“\(context.state.lastLine)”") }
                    }
                    .font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    IslandButton(emoji: "🍙", title: T("喂"), action: "feed", hot: context.state.need == Need.hungry.rawValue)
                    IslandButton(emoji: "💧", title: T("喝"), action: "drink", hot: context.state.need == Need.thirsty.rawValue)
                    IslandButton(emoji: "🤚", title: T("摸"), action: "pet", hot: context.state.need == Need.happy.rawValue)
                }
            }
            .padding(14)
            .activityBackgroundTint(Color(hex: context.state.character.backgroundHex))
            .widgetURL(URL(string: (context.state.shopAt != nil || (context.state.shopTickets ?? 0) > 0) ? "islandme://shop" : "islandme://chat"))
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开态（长按岛台）：左边大大的它（点它 = 摸摸），右边它刚说的 / 它想要的，下面三个按钮。别的都不放。
                DynamicIslandExpandedRegion(.leading) {
                    Button(intent: IslandCareIntent(action: "pet")) {
                        if let img = ShopLook(state: context.state).image {
                            Image(img).resizable().scaledToFit().frame(width: 84, height: 84)
                        } else {
                            DressedPetView(pet: context.state.character.pet, pose: context.state.pose, frame: context.state.frame.isEmpty ? context.state.need : context.state.frame, tick: context.state.tick, accessories: context.state.character.accessories ?? [])
                                .frame(width: 84, height: 84)
                        }
                    }
                    .buttonStyle(.plain)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if !context.state.frame.isEmpty, !context.state.lastLine.isEmpty {
                            Text(context.state.lastLine).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        } else if let need = Need(rawValue: context.state.need) {
                            Text(need.wantLine).font(.system(size: 15, weight: .semibold)).foregroundStyle(.orange)
                        } else if ShopLook(state: context.state).on {
                            ShopHeader(state: context.state)
                        } else if let at = context.state.shopAt, let line = context.state.shopLine, at.timeIntervalSinceNow > -1800 {
                            Text(line).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "#FFD166")).lineLimit(2)
                                .multilineTextAlignment(.trailing)
                            if at > Date() {
                                Text(timerInterval: Date()...at, countsDown: true).font(.system(size: 12)).monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.trailing)
                            }
                        } else {
                            Text(T("点我摸摸")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        IslandButton(emoji: "🍙", title: T("喂"), action: "feed", hot: context.state.need == Need.hungry.rawValue)
                        IslandButton(emoji: "💧", title: T("喝"), action: "drink", hot: context.state.need == Need.thirsty.rawValue)
                        IslandButton(emoji: "🤚", title: T("摸"), action: "pet", hot: context.state.need == Need.happy.rawValue)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // 紧凑态：左耳用“探头”帧（变窄时系统自己缩放，没有公开接口能判断）
                LeadingEar(state: context.state)
            } compactTrailing: {
                // 右耳：有需求 → 需求图标+“饿了”；否则它最近说的话（第一小句，最多 7 字）；不显示动作名
                TrailingEar(state: context.state)
            } minimal: {
                // 小圆点：只放脸的特写（全身缩到 22pt 看不清）
                FaceView(state: context.state).frame(width: 24, height: 24)
            }
            .keylineTint(Color(hex: context.state.character.figureHex))
            .widgetURL(URL(string: (context.state.shopAt != nil || (context.state.shopTickets ?? 0) > 0) ? "islandme://shop" : "islandme://chat"))
        }
    }
}

struct LeadingEar: View {
    let state: IslandMeAttributes.ContentState

    var body: some View {
        let special = state.frame.isEmpty ? state.need : state.frame
        if let img = ShopLook(state: state).image {
            // 店面：它在柜台后面（看小票 / 打瞌睡 / 肚子上放钱 / 拍手）
            Image(img).resizable().scaledToFit().frame(width: 36, height: 36).padding(.leading, 2)
        } else if special.isEmpty {
            // 头+爪子搭在边上；有需求/特殊帧时才换成对应全身帧
            DressedPetView(pet: state.character.pet, pose: state.pose, frame: state.pose == .sleep ? "peek_sleep" : "peek", tick: state.tick, accessories: state.character.accessories ?? [])
                .frame(width: 44, height: 36, alignment: .bottom)
                .padding(.leading, 2)
        } else {
            DressedPetView(pet: state.character.pet, pose: state.pose, frame: special, tick: state.tick, accessories: state.character.accessories ?? [])
                .frame(width: 36, height: 36)
                .padding(.leading, 2)
        }
    }
}

struct TrailingEar: View {
    let state: IslandMeAttributes.ContentState

    var body: some View {
        Group {
            if !state.frame.isEmpty, let line = shortLine(state.lastLine, keepEmoji: true) {
                // 刚被喂/摸：几秒内显示它的反应
                Text(line).foregroundStyle(.white)
            } else if let need = Need(rawValue: state.need) {
                // 它想要什么：一个图标 + 两个字
                HStack(spacing: 2) {
                    Text(need.emoji)
                    Text(need.short).foregroundStyle(.orange)
                }
            } else if ShopLook(state: state).on {
                ShopEar(state: state)
            } else if let at = state.shopAt, let icon = state.shopIcon, at.timeIntervalSinceNow > -1800 {
                // 嘟嘟小店：还有多久好（倒计时到 0 就停住）
                HStack(spacing: 2) {
                    Text(icon)
                    if at > Date() {
                        Text(timerInterval: Date()...at, countsDown: true).monospacedDigit().foregroundStyle(Color(hex: "#FFD166"))
                            .frame(maxWidth: 40)
                    } else {
                        Text(T("好了")).foregroundStyle(Color(hex: "#FFD166"))
                    }
                }
            } else {
                // 它在干嘛：一个图标
                Text(Self.doing[state.pose] ?? "✦").foregroundStyle(Color(hex: "#C9B8F5"))
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1).minimumScaleFactor(0.7)
        .padding(.trailing, 4)
    }

    static let doing: [Pose: String] = [
        .sleep: "💤", .eat: "🍙", .coffee: "☕️", .music: "🎧", .dance: "🎶", .movie: "🍿", .walk: "🛹", .run: "🛹",
        .work: "💻", .type: "⌨️", .phone: "📱", .call: "📞", .read: "📖", .wake: "🥱", .wash: "🫧", .gym: "🚩",
        .drive: "🚗", .charge: "🔋", .uke: "🎸", .study: "📖", .paint: "🎨", .ball: "🏀",
    ]
}

/// 展开态底下的按钮：点了不打开 App，它当场有反应
struct IslandButton: View {
    let emoji: String
    let title: String
    let action: String
    var hot = false
    var body: some View {
        Button(intent: IslandCareIntent(action: action)) {
            HStack(spacing: 4) {
                Text(emoji)
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(hot ? Color.orange.opacity(0.35) : Color.white.opacity(0.12), in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

/// 脸部特写：按 当前特殊帧 → 需求 → 动作 → idle 依次找 purple_face_xxx
struct FaceView: View {
    let state: IslandMeAttributes.ContentState

    var body: some View {
        let pet = state.character.pet
        // 特殊帧（被喂/摸、眨眼）→ 需求 → 它在做的事（带道具的小半身：耳机、方向盘、滑板……）→ 表情 → 默认
        let candidates = [state.frame, Need(rawValue: state.need)?.frame ?? "", state.pose == .stand ? "" : "pose_" + state.pose.rawValue,
                          Self.poseFace[state.pose] ?? "", "idle"].filter { !$0.isEmpty }
        let name = candidates.map { "\(pet)_face_\($0)" }.first { UIImage(named: $0) != nil }
        if let name {
            Image(name).resizable().scaledToFit().clipShape(Circle())
        } else {
            DressedPetView(pet: pet, pose: state.pose, frame: state.frame.isEmpty ? state.need : state.frame, tick: state.tick, accessories: state.character.accessories ?? [])
        }
    }

    static let poseFace: [Pose: String] = [
        .sleep: "sleep", .eat: "eat", .coffee: "coffee", .wake: "yawn",
        .music: "happy", .dance: "laugh", .read: "think", .type: "think"
    ]
}

/// 把一整句压成岛台右耳放得下的短句：按标点切第一段，最多 7 个字
func shortLine(_ line: String, keepEmoji: Bool = false) -> String? {
    let seps = keepEmoji ? T("，。！？,.!?~～…、\n") : T("，。！？,.!?~～…、 \n")
    var first = ""
    for ch in line {
        if seps.contains(ch) { if !first.isEmpty { break } else { continue } }
        first.append(ch)
    }
    if first.isEmpty { return nil }
    if first.count > 7 { return String(first.prefix(6)) + "…" }
    return first
}


// MARK: - 嘟嘟小店店面（岛台像一个小橱窗）

/// 什么时候岛台显示店面：开过店、没急事、它没被喂摸、你没在走路开车睡觉
struct ShopLook {
    let state: IslandMeAttributes.ContentState
    var now: Date { Date() }
    var on: Bool {
        // 你在做具体的事（走路、听歌、打电话、充电……）时岛台跟着你，不显示店面；只有它闲着时才看店
        state.shopOpen == true && state.frame.isEmpty && state.need.isEmpty
            && [.stand, .work, .movie].contains(state.pose)
    }
    var hour: Int { Calendar.current.component(.hour, from: now) }
    var closed: Bool { hour >= 23 || hour < 7 }
    var ready: Bool { if let at = state.shopAt { return at <= now && at.timeIntervalSinceNow > -1800 }; return false }
    /// 它在柜台后面的样子：有东西好了 → 拍手；其余按钟点轮
    var image: String? {
        guard on, !closed else { return nil }
        if ready { return "purple_shopi_wow" }
        switch hour {
        case 7..<11: return "purple_shopi_counter"
        case 11..<14: return (state.shopTickets ?? 0) > 0 ? "purple_shopi_ticket" : "purple_shopi_counter"
        case 14..<17: return "purple_shopi_doze"
        case 17..<21: return (state.shopTickets ?? 0) > 0 ? "purple_shopi_ticket" : "purple_shopi_cash"
        default: return "purple_shopi_taste"
        }
    }
}

/// 右耳：有东西在倒计时 → 图标+倒计时；好了 → 好了；有单在等 → 🧾几；打烊 → 💤
struct ShopEar: View {
    let state: IslandMeAttributes.ContentState
    var body: some View {
        let look = ShopLook(state: state)
        let gold = Color(hex: "#FFD166")
        HStack(spacing: 2) {
            if look.closed {
                Text("💤")
                Text(T("打烊")).foregroundStyle(.white.opacity(0.6))
            } else if look.ready {
                Text(state.shopIcon ?? "✨")
                Text(T("好了")).foregroundStyle(gold)
            } else if let at = state.shopAt, at > Date() {
                Text(state.shopIcon ?? "🧾")
                Text(timerInterval: Date()...at, countsDown: true).monospacedDigit().foregroundStyle(gold).frame(maxWidth: 40)
            } else if let n = state.shopTickets, n > 0 {
                Text("🧾")
                Text(T("{0}单", n)).foregroundStyle(gold)
            } else {
                Text("🏪")
            }
        }
    }
}

/// 展开态右上：店名、营业状态、下一件事
struct ShopHeader: View {
    let state: IslandMeAttributes.ContentState
    var body: some View {
        let look = ShopLook(state: state)
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 4) {
                Text(state.shopSign == 1 ? "🪧" : "📦").font(.system(size: 12))
                Text(T("嘟嘟小店")).font(.system(size: 15, weight: .bold))
            }
            Text(look.closed ? T("打烊了 · 明早 7 点见") : ((state.shopTickets ?? 0) > 0 ? T("营业中 · {0} 单能交", state.shopTickets ?? 0) : T("营业中")))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(look.closed ? .white.opacity(0.5) : Color(hex: "#FFD166"))
                .lineLimit(1).minimumScaleFactor(0.7)
            if let line = state.shopLine, let at = state.shopAt, at > Date() {
                HStack(spacing: 3) {
                    Text(line).lineLimit(1)
                    Text(timerInterval: Date()...at, countsDown: true).monospacedDigit().frame(maxWidth: 44)
                }
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
            }
        }
        .multilineTextAlignment(.trailing)
    }
}
