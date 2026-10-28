import SwiftUI

/// “我”页的所有变量 + 金币 + 已买/已戴的配饰。App 与 Widget 共用。
struct Profile: Codable, Equatable {
    var petName: String = T("嘟嘟")
    var myName: String = ""            // 你的昵称
    var callMe: String = ""            // 它怎么称呼你（空 = 用昵称）
    var gender: String = ""            // 自填
    var birthday: Date? = nil
    var wakeHour: Int = 7              // 作息：起床
    var sleepHour: Int = 23            // 作息：睡觉
    var coins: Int = 100
    var owned: [String] = []           // 配饰 id
    var equipped: [String] = []        // 正在戴的配饰 id（每个部位一件）

    var displayCall: String { callMe.isEmpty ? (myName.isEmpty ? T("你") : myName) : callMe }

    private static let key = "profile.v1"
    static func load() -> Profile {
        if let d = UserDefaults(suiteName: Character.appGroup)?.data(forKey: key),
           var p = try? JSONDecoder().decode(Profile.self, from: d) {
            // 2026-10-19 正式改名：默认名「芋圆」→「嘟嘟」（自己起过别的名字的不动）
            if p.petName == "芋圆" { p.petName = T("嘟嘟"); p.save() }
            return p
        }
        return Profile()
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults(suiteName: Character.appGroup)?.set(d, forKey: Self.key) }
    }
}

/// 商城配饰。slot 相同的只能戴一件。真图之后按 ASSET_SPEC 出，v1 先用矢量画。
struct Accessory: Identifiable, Hashable {
    let id: String
    let name: String
    let slot: String      // head / eyes / neck
    let price: Int
    /// 限定：不在这个时间段就买不到（季卡满级奖励的只能靠季卡拿）
    var only: Only? = nil
    enum Only: Hashable {
        case dates(Int, Int, Int, Int)      // 起 月/日 — 止 月/日（可跨年）
        case season(Int)                    // 第几季（从 0 起）季卡满级
    }
    /// 现在能不能买
    func onSale(_ now: Date = Date()) -> Bool {
        guard let o = only else { return true }
        guard case let .dates(m1, d1, m2, d2) = o else { return false }
        let c = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: now)
        let v = (c.month ?? 1) * 100 + (c.day ?? 1), a = m1 * 100 + d1, b = m2 * 100 + d2
        return a <= b ? (v >= a && v <= b) : (v >= a || v <= b)
    }
    /// 买不到时写什么
    var lockText: String {
        switch only {
        case .dates(let m1, let d1, let m2, let d2)?: return T("限时 {0}/{1}–{2}/{3}", m1, d1, m2, d2)
        case .season(let i)?: return T("第 {0} 季季卡满级", i + 1)
        default: return ""
        }
    }

    static let all: [Accessory] = [
        .init(id: "hat_straw",   name: T("草帽"),     slot: "head", price: 450),
        .init(id: "hat_party",   name: T("派对帽"),   slot: "head", price: 400),
        .init(id: "hat_beanie",  name: T("毛线帽"),   slot: "head", price: 420),
        .init(id: "glasses_sun", name: T("墨镜"),     slot: "eyes", price: 380),
        .init(id: "glasses_round", name: T("圆框眼镜"), slot: "eyes", price: 180),
        .init(id: "bow_red",     name: T("红蝴蝶结"), slot: "neck", price: 150),
        .init(id: "scarf_blue",  name: T("蓝围巾"),   slot: "neck", price: 480),
        // 2026-10-21 调价：可灵真穿着出的几件是精品（380–480），入门两件 150/180；撤掉 5 件贴纸感的脖子饰品后全部加起来约 7,000 币
        .init(id: "hat_chef",    name: T("小厨师帽"), slot: "head", price: 380),
        .init(id: "hat_flower",  name: T("小花环"),   slot: "head", price: 300),
        .init(id: "hat_beret",   name: T("草莓贝雷帽"), slot: "head", price: 340),
        .init(id: "hat_witch",   name: T("小巫师帽"), slot: "head", price: 520),
        .init(id: "hat_crown",   name: T("小皇冠"),   slot: "head", price: 1500),
        .init(id: "glasses_heart", name: T("爱心眼镜"), slot: "eyes", price: 260),
        .init(id: "glasses_star",  name: T("星星眼镜"), slot: "eyes", price: 300),
        .init(id: "glasses_goggle", name: T("游泳镜"), slot: "eyes", price: 220),
        .init(id: "glasses_3d",    name: T("3D 眼镜"), slot: "eyes", price: 240),
        .init(id: "glasses_cat",   name: T("粉色猫眼镜"), slot: "eyes", price: 360),
        .init(id: "neck_bell",   name: T("小铃铛"),   slot: "neck", price: 220),
    ]
    static func by(_ id: String) -> Accessory? { all.first { $0.id == id } }
    /// 正在戴的那一件（老存档可能戴了几件：帽子 > 眼镜 > 脖子）
    static func worn(_ ids: [String]) -> String? {
        ids.filter { by($0) != nil }.min { rank($0) < rank($1) }
    }
    private static func rank(_ id: String) -> Int { id.hasPrefix("hat") ? 0 : (id.hasPrefix("glasses") ? 1 : 2) }
    var tier: String { price >= 500 ? T("大件") : (price >= 200 ? T("中档") : T("小件")) }
    /// 2026-10-19 这批是在待机视频上逐帧贴上去烘焙的：为了给高帽子留头顶空间，画面里的它缩到 0.82，
    /// 播放/显示时再放大回去（以脚底为中心），和其他片段一样大。
    static let bakedScale: CGFloat = 0.82
    static let feet = UnitPoint(x: 0.5, y: 0.935)
    static let bakedIDs: Set<String> = ["hat_chef", "hat_flower", "hat_beret", "hat_witch", "hat_crown", "glasses_heart", "glasses_star", "glasses_goggle", "glasses_3d", "glasses_cat", "neck_bell"]
    static func baked(_ id: String?) -> Bool { id.map { bakedIDs.contains($0) } ?? false }
}
