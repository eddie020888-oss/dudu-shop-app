import SwiftUI

/// 嘟嘟星季卡（2026-10-21）：免费的赛季通行证，4 周一季。交单、冲刺、每日目标、大订单攒季卡分，
/// 每 20 分升一级，30 级，一路自动发奖；每 10 级一个大宝箱，满级 300 币 + 大宝箱 + 季卡徽章。
/// 一季结束清零重来。以后每季可以换一件限定饰品当满级奖（跟着更新走）
enum MKSeason {
    static let epoch: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 22; c.hour = 0
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }()
    static let length: TimeInterval = 28 * 86400
    static let tierCost = 20
    static let tiers = 30

    static func index(_ now: Date = Date()) -> Int { max(0, Int(now.timeIntervalSince(epoch) / length)) }
    static func ends(_ now: Date = Date()) -> Date { epoch.addingTimeInterval(Double(index(now) + 1) * length) }

    /// 每季满级的限定饰品（第 1 季：星星头冠）；以后每季往后加一件
    static let exclusives: [String] = []   // 限定饰品要真「穿着」出图（可灵），做好了再填
    static func exclusive(_ idx: Int) -> String? { idx < exclusives.count ? exclusives[idx] : nil }

    struct Reward { let item: String?; let gems: Int; let energy: Int; let coins: Int; let packs: Int; let text: String }
    static func reward(_ lv: Int) -> Reward {
        if lv == tiers {
            if let a = exclusive(index()), let acc = Accessory.by(a) {
                return Reward(item: "chest3", gems: 10, energy: 0, coins: 300, packs: 1, text: T("满级：限定「{0}」+ 300 币 + 大宝箱 + 宝石 10 + 拍立得", acc.name))
            }
            return Reward(item: "chest3", gems: 10, energy: 0, coins: 300, packs: 1, text: T("满级：300 币 + 大宝箱 + 宝石 10 + 拍立得"))
        }
        if lv % 10 == 0 { return Reward(item: "chest3", gems: 0, energy: 0, coins: 0, packs: 0, text: T("大宝箱")) }
        switch lv % 5 {
        case 1: return Reward(item: nil, gems: 0, energy: 20, coins: 0, packs: 0, text: T("体力 +20"))
        case 2: return Reward(item: nil, gems: 3, energy: 0, coins: 0, packs: 0, text: T("宝石 +3"))
        case 3: return Reward(item: "luckybag", gems: 0, energy: 0, coins: 0, packs: 0, text: T("惊喜福袋"))
        case 4: return Reward(item: nil, gems: 0, energy: 0, coins: 40, packs: 0, text: T("40 币"))
        default: return Reward(item: "chest2", gems: 0, energy: 0, coins: 0, packs: 1, text: T("宝箱 + 拍立得"))
        }
    }
}

extension MKStore {
    var seasonLv: Int { s.seasonId == MKSeason.index() ? (s.seasonLv ?? 0) : 0 }
    var seasonPts: Int { s.seasonId == MKSeason.index() ? (s.seasonPts ?? 0) : 0 }
    /// 攒季卡分；升级就发奖
    func addSeason(_ n: Int) {
        guard n > 0, s.level >= 3 else { return }
        let idx = MKSeason.index()
        if s.seasonId != idx { s.seasonId = idx; s.seasonPts = 0; s.seasonLv = 0 }
        s.seasonPts = (s.seasonPts ?? 0) + n
        while (s.seasonLv ?? 0) < MKSeason.tiers, (s.seasonPts ?? 0) >= MKSeason.tierCost * ((s.seasonLv ?? 0) + 1) {
            let lv = (s.seasonLv ?? 0) + 1
            s.seasonLv = lv
            let r = MKSeason.reward(lv)
            earnGems(r.gems); s.energy += r.energy; coinsEarned += r.coins
            if r.packs > 0 { s.packs = (s.packs ?? 0) + r.packs }
            if let it = r.item { give(it) }
            if lv == MKSeason.tiers, let a = MKSeason.exclusive(idx) { accEarned.append(a) }
            say(T("🌟 季卡升到 {0} 级：{1}", lv, r.text))
            MKSfx.play("reward")
        }
    }
}

struct MKSeasonView: View {
    @ObservedObject var store: MKStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    let lv = store.seasonLv, pts = store.seasonPts
                    VStack(alignment: .leading, spacing: 6) {
                        Text(T("第 {0} 季 · 还剩 {1} 天", MKSeason.index() + 1, max(1, Int((MKSeason.ends().timeIntervalSinceNow / 86400).rounded(.up)))))
                            .font(.system(size: 13)).foregroundStyle(Theme.text3)
                        Text(T("季卡 {0} 级", lv)).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
                        if lv < MKSeason.tiers {
                            ProgressView(value: Double(pts - lv * MKSeason.tierCost), total: Double(MKSeason.tierCost)).tint(Theme.coin)
                            Text(T("{0}/{1} 分到下一级", pts - lv * MKSeason.tierCost, MKSeason.tierCost)).font(.system(size: 11)).foregroundStyle(Theme.text3)
                        } else {
                            Text(T("满级了！下一季再来。")).font(.system(size: 13)).foregroundStyle(Theme.coin)
                        }
                        Text(T("攒分：外卖单 1 分，大订单 5 分，限时冲刺 5 分，每日小目标 3 分。升级自动发奖，一季 4 周，结束后从头来。"))
                            .font(.system(size: 11)).foregroundStyle(Theme.text3)
                    }
                    .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    if let a = MKSeason.exclusive(MKSeason.index()), let acc = Accessory.by(a) {
                        HStack(spacing: 12) {
                            Image("acc_" + a).resizable().scaledToFit().frame(width: 64, height: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(T("满级送：{0}", acc.name)).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.coin)
                                Text(T("这一季限定，过了这季就拿不到了。戴上它，嘟嘟胸口会亮一颗星。"))
                                    .font(.system(size: 11)).foregroundStyle(Theme.text3)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12).background(Theme.coin.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }
                    ForEach(1...MKSeason.tiers, id: \.self) { t in
                        let r = MKSeason.reward(t), got = t <= lv
                        HStack {
                            Text("\(t)").font(.system(size: 13, weight: .bold)).monospacedDigit().frame(width: 28)
                                .foregroundStyle(t % 10 == 0 ? Theme.coin : Theme.text2)
                            Text(r.text).font(.system(size: 13)).foregroundStyle(got ? Theme.text3 : Theme.text)
                            Spacer()
                            if got { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                            else { Text(T("{0} 分", t * MKSeason.tierCost)).font(.system(size: 11)).foregroundStyle(Theme.text3) }
                        }
                        .padding(.horizontal, 12).frame(height: 40)
                        .background(t % 10 == 0 ? Theme.coin.opacity(0.12) : Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("嘟嘟星季卡")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
