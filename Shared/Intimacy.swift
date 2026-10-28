import Foundation

/// 亲密度（2026-10-20）：你把它伺候得好不好。和「熟悉度」不一样：熟悉度是它认不认识你（聊天、互动就涨），
/// 亲密度是照顾得好不好——它饿了、渴了、脏了、闷了，你及时管它就涨；让它饿到底、脏到底就掉。
/// 亲密度越高，嘟嘟小店里的「爆率」越高：产出器多掉东西、掉福袋、掉高一级的货、宝箱多掉一样。
struct Intimacy: Codable, Equatable {
    var value: Double = 20            // 0–100，新宠物从 20 起步
    var lastDay: String = ""          // 上次按天结算的日子
    var bottomToday: Int = 0          // 今天见底了几次（管家代劳）
    var caredToday: Int = 0           // 今天及时照顾了几次
    var penalized: [String] = []      // 今天已经因为「没钱，见底了也没人管」扣过的需求，一天一项只扣一次

    // MARK: 档位
    struct Tier { let level: Int; let name: String; let bonus: Double; let floor: Int }
    static let tiers: [Tier] = [
        Tier(level: 0, name: T("生分"), bonus: 0, floor: 0),
        Tier(level: 1, name: T("熟悉"), bonus: 0.05, floor: 20),
        Tier(level: 2, name: T("亲近"), bonus: 0.10, floor: 40),
        Tier(level: 3, name: T("贴心"), bonus: 0.15, floor: 60),
        Tier(level: 4, name: T("形影不离"), bonus: 0.25, floor: 80),
    ]
    var tier: Tier { Self.tiers.last { value >= Double($0.floor) } ?? Self.tiers[0] }
    var next: Tier? { Self.tiers.first { Double($0.floor) > value } }
    /// 小店爆率加成（0–0.25）
    var bonus: Double { tier.bonus }

    // MARK: 涨跌
    /// 它需要你的时候（低于告急线）你管了它
    mutating func cared(favorite: Bool = false) {
        rollDay()
        caredToday += 1
        // 一天前几次涨得多，刷不上去：第 1–6 次 +1.5，之后 +0.3
        add(caredToday <= 6 ? 1.5 : 0.3)
        if favorite { add(0.5) }
    }
    /// 小心愿满足了
    mutating func wishMet() { rollDay(); add(3) }
    /// 小店里交了它的饭
    mutating func shopMeal() { rollDay(); add(1) }
    /// 饿到底 / 渴到底 / 脏到底 / 闷到底：管家花钱代劳了，但它记着你没来
    mutating func hitBottom() { rollDay(); bottomToday += 1; add(-6) }
    /// 见底了还没钱请管家（一天一项只扣一次）
    mutating func neglected(_ need: String) -> Bool {
        rollDay()
        guard !penalized.contains(need) else { return false }
        penalized.append(need); add(-8)
        return true
    }
    /// 换天结算：昨天一次都没见底、还照顾过它 → +3；好几天没打开 → 每天 -2（最多 -10）
    mutating func rollDay(now: Date = Date()) {
        let today = Wallet.day(now)
        guard lastDay != today else { return }
        if !lastDay.isEmpty {
            if bottomToday == 0 && caredToday > 0 { add(3) }
            let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
            if let last = f.date(from: lastDay), let cur = f.date(from: today) {
                let gap = Int(cur.timeIntervalSince(last) / 86400) - 1
                if gap > 0 { add(-Double(min(10, gap * 2))) }
            }
        }
        lastDay = today; bottomToday = 0; caredToday = 0; penalized = []
    }
    private mutating func add(_ d: Double) { value = max(0, min(100, value + d)) }

    // MARK: 存取（App Group：主 App 和小店共用）
    private static let key = "intimacy.v1"
    static func load() -> Intimacy {
        if let d = UserDefaults(suiteName: Character.appGroup)?.data(forKey: key),
           let v = try? JSONDecoder().decode(Intimacy.self, from: d) { return v }
        return Intimacy()
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults(suiteName: Character.appGroup)?.set(d, forKey: Self.key) }
    }
    /// 读、改、存一步完成
    static func update(_ f: (inout Intimacy) -> Void) {
        var v = load(); f(&v); v.save()
        NotificationCenter.default.post(name: Notification.Name("intimacyChanged"), object: nil)
    }
    /// 小店用：现在的爆率加成
    static var currentBonus: Double { load().bonus }
}

/// 见底时管家代劳：用你的金币给它点最好的（比自己喂贵，算上跑腿费）
struct Rescue {
    let need: Need; let name: String; let emoji: String; let price: Int; let line: String
    var image: String { "rescue_" + need.rawValue }
    static func of(_ n: Need) -> Rescue {
        switch n {
        case .hungry:  return Rescue(need: n, name: T("嘟嘟星豪华大餐"), emoji: "🍱", price: 120, line: T("饿到底了……管家给我点了一份豪华大餐。好吃。可我等你等了好久。"))
        case .thirsty: return Rescue(need: n, name: T("鲜榨果汁大桶"), emoji: "🧃", price: 60, line: T("渴到嗓子冒烟，管家送来一大桶果汁。下次你给我倒杯水就行。"))
        case .dirty:   return Rescue(need: n, name: T("上门泡泡浴"), emoji: "🛁", price: 80, line: T("脏到自己都嫌弃，管家请人给我洗了个泡泡浴。香了。"))
        case .happy:   return Rescue(need: n, name: T("星星游乐园门票"), emoji: "🎡", price: 60, line: T("闷坏了，管家带我去了趟游乐园。好玩是好玩，就是没有你。"))
        }
    }
}
