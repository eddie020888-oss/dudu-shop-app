import Foundation

/// 电子宠物需求：饥饿 / 口渴 / 清洁。
/// 不靠后台定时器：只记"上次满足时间"，读取时按流逝时间折算，App 冻结也不会漏。
enum Need: String, Codable, CaseIterable, Hashable {
    case hungry, thirsty, dirty, happy

    var label: String {
        switch self {
        case .hungry:  return T("饿了")
        case .thirsty: return T("渴了")
        case .dirty:   return T("该清理了")
        case .happy:   return T("不开心")
        }
    }
    /// 岛台右耳的小图标
    /// 灵动岛右耳：一个图标 + 两个字
    var emoji: String { switch self { case .hungry: return "🍙"; case .thirsty: return "💧"; case .dirty: return "🫧"; case .happy: return "🥺" } }
    var short: String { switch self { case .hungry: return T("饿了"); case .thirsty: return T("渴了"); case .dirty: return T("脏了"); case .happy: return T("无聊") } }
    /// 长按展开时它说的
    var wantLine: String { switch self { case .hungry: return T("饿……喂一口？"); case .thirsty: return T("渴了，给口水。"); case .dirty: return T("想洗澡……"); case .happy: return T("陪我一下嘛。") } }

    var symbol: String {
        switch self {
        case .hungry:  return "fork.knife"
        case .thirsty: return "drop.fill"
        case .dirty:   return "bubbles.and.sparkles"
        case .happy:   return "heart.fill"
        }
    }
    /// 对应的角色帧名（缺图时 PetView 自动回退 idle）
    var frame: String { self == .happy ? "cry" : rawValue }
    /// 满 → 空 需要的小时数
    var hoursToEmpty: Double {
        switch self {
        // 数值模拟（2026-10-16）：原来饿 6 小时见底，一天要喂 ~110 币，谁都养不起；
        // 改成 16 小时 + 睡觉时段只消耗 30% 后，一天约 30 币伙食，躺平党刚好够、上班族每天结余 ~25
        case .hungry:  return 16
        case .thirsty: return 12
        case .dirty:   return 24
        case .happy:   return 12
        }
    }
    /// 照顾一次加多少（不是一口回满：喂三次才饱，和别的宠物游戏一样）
    var careAmount: Double {
        switch self {
        case .hungry:  return 0.35
        case .thirsty: return 0.45
        case .dirty:   return 0.6
        case .happy:   return 0.3
        }
    }
    var careVerb: String {
        switch self {
        case .hungry:  return T("喂食")
        case .thirsty: return T("喝水")
        case .dirty:   return T("清理")
        case .happy:   return T("陪玩")
        }
    }
    var careSymbol: String {
        switch self {
        case .hungry:  return "carrot.fill"
        case .thirsty: return "cup.and.saucer.fill"
        case .dirty:   return "shower.fill"
        case .happy:   return "gamecontroller.fill"
        }
    }
    /// 未告急时显示的名称
    var careName: String {
        switch self { case .hungry: return T("饱食"); case .thirsty: return T("水"); case .dirty: return T("清洁"); case .happy: return T("快乐") }
    }
    static let threshold = 0.3   // 低于此值 = 需要照顾
}

struct PetNeeds: Codable, Equatable {
    /// 睡觉时段（App 从资料里同步）：这段时间它也在睡，需求只按 nightFactor 消耗
    static var sleepStart = 23
    static var sleepEnd = 7
    static let nightFactor = 0.3

    private static func isNight(_ h: Int) -> Bool {
        sleepStart > sleepEnd ? (h >= sleepStart || h < sleepEnd) : (h >= sleepStart && h < sleepEnd)
    }
    /// a→b 之间的"有效小时"：白天 1:1，睡觉时段打折
    static func effectiveHours(from a: Date, to b: Date) -> Double {
        guard b > a else { return 0 }
        let cal = Calendar.current
        var t = a, total = 0.0
        while t < b {
            let nextHour = cal.nextDate(after: t, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) ?? b
            let end = min(nextHour, b)
            let hrs = end.timeIntervalSince(t) / 3600
            total += isNight(cal.component(.hour, from: t)) ? hrs * nightFactor : hrs
            t = end
        }
        return total
    }

    /// 上次记账时各项的值（0–1）和记账时间；读取时按流逝时间扣减，App 冻结也不会漏
    var levels: [Need: Double] = [:]
    var updatedAt: Date = Date()

    /// 0 = 空，1 = 满
    func level(_ n: Need, at now: Date = Date()) -> Double {
        let base = levels[n] ?? 1
        let hrs = Self.effectiveHours(from: updatedAt, to: now)
        return max(0, min(1, base - hrs / n.hoursToEmpty))
    }
    /// 当前最急的需求（按剩余比例最低），没有则 nil
    func urgent(at now: Date = Date()) -> Need? {
        Need.allCases.map { ($0, level($0, at: now)) }
            .filter { $0.1 < Need.threshold }
            .min { $0.1 < $1.1 }?.0
    }
    /// 某需求会在什么时候跌到阈值（用于预约本地通知）
    func timeUntilNeed(_ n: Need, at now: Date = Date()) -> TimeInterval {
        // 按有效小时往后推，找跌破阈值的时刻（每 10 分钟一步，最多 3 天）
        let need = (level(n, at: now) - Need.threshold) * n.hoursToEmpty
        guard need > 0 else { return 0 }
        var t = now, acc = 0.0
        while acc < need && t.timeIntervalSince(now) < 3 * 86400 {
            let next = t.addingTimeInterval(600)
            acc += Self.effectiveHours(from: t, to: next)
            t = next
        }
        return t.timeIntervalSince(now)
    }
    /// 把所有项折算到 now（改任何一项前先调用）
    private mutating func settle(at now: Date) {
        for n in Need.allCases { levels[n] = level(n, at: now) }
        updatedAt = now
    }
    /// 照顾一次：加 careAmount，封顶 1
    mutating func care(_ n: Need, at now: Date = Date()) { add(n, n.careAmount, at: now) }
    /// 加减某项（互动/聊天/运动顺带加开心）
    mutating func add(_ n: Need, _ delta: Double, at now: Date = Date()) {
        settle(at: now)
        levels[n] = max(0, min(1, (levels[n] ?? 1) + delta))
    }

    // 旧格式（只记上次照顾时间）→ 新格式
    private struct Legacy: Codable { var lastCared: [Need: Date] }
    private static func migrate(_ old: Legacy) -> PetNeeds {
        var n = PetNeeds(); let now = Date()
        for k in Need.allCases {
            let since = now.timeIntervalSince(old.lastCared[k] ?? now)
            n.levels[k] = max(0, 1 - since / (k.hoursToEmpty * 3600))
        }
        n.levels[.happy] = 0.8
        n.updatedAt = now
        return n
    }

    private static let key = "petneeds.v1"
    static func load() -> PetNeeds {
        let d = UserDefaults(suiteName: Character.appGroup)
        if let data = d?.data(forKey: key) {
            if let v = try? JSONDecoder().decode(PetNeeds.self, from: data), !v.levels.isEmpty { return v }
            if let old = try? JSONDecoder().decode(Legacy.self, from: data) { let m = migrate(old); m.save(); return m }
        }
        var fresh = PetNeeds(); Need.allCases.forEach { fresh.levels[$0] = 1 }   // 新宠物：全满
        fresh.levels[.happy] = 0.8
        fresh.save()   // 必须落盘，否则每次启动都重置成全满、永远不会饿
        return fresh
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults(suiteName: Character.appGroup)?.set(data, forKey: Self.key) }
    }
}
