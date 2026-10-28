import Foundation

// MARK: - 熟悉度 / 成长阶段 / 里程碑 / 习惯（见 CHARACTER_BIBLE.md 第 5–8、12 节）

/// 开蛋时选定、永远不可更改的语言路线
enum LangRoute: String, Codable, CaseIterable {
    case zh      // 路线 A：学中文
    case en      // 路线 A：学英文
    case dudu    // 路线 B：一直说嘟语

    var speaks: Bool { self != .dudu }
    var title: String {
        switch self { case .zh: return T("学中文"); case .en: return T("学 English"); case .dudu: return T("保留嘟语") }
    }
}

/// 会涨熟悉度的行为
enum BondAction: String, Codable, CaseIterable {
    case open, feed, drink, pet, play, chat, blanket, request, wake, steps

    /// (基础分, 当天第几次起减到 1, 当天第几次起减到 0, 当天这项最多累计多少)
    var rule: (base: Int, reduceFrom: Int, zeroFrom: Int, cap: Int) {
        switch self {
        case .open:    return (5, 99, 2, 5)
        case .feed:    return (3, 4, 7, 99)
        case .drink:   return (2, 4, 7, 99)
        case .pet:     return (1, 99, 99, 5)
        case .play:    return (5, 2, 4, 99)
        case .chat:    return (2, 99, 99, 10)
        case .blanket: return (3, 99, 2, 3)
        case .request: return (3, 99, 99, 9)
        case .wake:    return (2, 99, 2, 2)
        case .steps:   return (2, 99, 2, 2)
        }
    }
}

/// 一个"第一次"里程碑
enum Milestone: String, Codable, CaseIterable {
    case hatch, firstFood, firstDrink, favorite, bellyLaugh, firstWord, heardName, firstRequestMet
    case blanketHabit, shareSnack, fluent, signature, day7, day30, day100, day365

    var title: String {
        switch self {
        case .hatch:           return T("破壳")
        case .firstFood:       return T("第一口食物")
        case .firstDrink:      return T("第一杯饮料")
        case .favorite:        return T("发现它最爱吃的")
        case .bellyLaugh:      return T("摸肚子笑出声")
        case .firstWord:       return T("第一句话")
        case .heardName:       return T("第一次听懂名字")
        case .firstRequestMet: return T("第一次满足它的小愿望")
        case .blanketHabit:    return T("盖毯子成了习惯")
        case .shareSnack:      return T("它把零食分给了你")
        case .fluent:          return T("它会聊天了")
        case .signature:       return T("你们的专属嘟嘟")
        case .day7:            return T("陪伴 7 天")
        case .day30:           return T("陪伴 30 天")
        case .day100:          return T("陪伴 100 天")
        case .day365:          return T("陪伴一周年")
        }
    }
    var symbol: String {
        switch self {
        case .hatch: return "oval.portrait"
        case .firstFood, .favorite, .shareSnack: return "fork.knife"
        case .firstDrink: return "cup.and.saucer.fill"
        case .bellyLaugh: return "face.smiling"
        case .firstWord, .fluent: return "bubble.left.fill"
        case .heardName, .signature: return "ear"
        case .firstRequestMet: return "star.fill"
        case .blanketHabit: return "bed.double.fill"
        case .day7, .day30, .day100, .day365: return "calendar"
        }
    }
}

/// 嘟嘟星的梦境片段（熟悉度到这些值时，它睡觉会做一个梦）
enum Dream: Int, Codable, CaseIterable {
    case plant = 150, sky = 450, voices = 900, egg = 1500
    var text: String {
        switch self {
        case .plant:  return T("梦见一种会发光的植物，叶子一碰就亮。")
        case .sky:    return T("梦见一片紫色的天空，好多星星挨得很近。")
        case .voices: return T("梦见远处有人在说嘟嘟，声音跟我好像。")
        case .egg:    return T("梦见另一颗蛋，花纹跟我那颗一模一样。")
        }
    }
    var textEn: String {
        switch self {
        case .plant:  return "Dreamed of a plant that glows when you touch it."
        case .sky:    return "Dreamed of a purple sky, stars all close together."
        case .voices: return "Dreamed someone far away saying dudu. Like me."
        case .egg:    return "Dreamed of another egg. Same pattern as mine."
        }
    }
    var symbol: String {
        switch self { case .plant: return "leaf.fill"; case .sky: return "moon.stars.fill"; case .voices: return "waveform"; case .egg: return "oval.portrait.fill" }
    }
}

/// 一条小愿望（它主动要的东西），2 小时没被满足就作罢
struct PetRequest: Codable, Equatable {
    enum Kind: String, Codable { case food, drink, belly, blanket }
    var kind: Kind
    var item: String = ""      // food / drink 时是 Food.id
    var at: Date = Date()
    var expired: Bool { Date().timeIntervalSince(at) > 2 * 3600 }
}

struct BondState: Codable {
    var hatched = false
    var hatchDate: Date? = nil
    var route: LangRoute? = nil
    var familiarity = 0
    var day = ""
    var todayPoints = 0
    var counts: [String: Int] = [:]            // 今天每种行为的次数
    var milestones: [String: Date] = [:]
    var habitLog: [String: [Date]] = [:]       // 习惯：每次发生的时间
    var habitTotal: [String: Int] = [:]
    var favoriteFood = ""                      // 开蛋时随机，不告诉用户
    var favoriteFound = false
    var signature = ""                         // 专属嘟嘟
    var firstFood = ""
    var firstDrink = ""
    var lastDrink = ""
    var dreams: [Int] = []                     // 已做过的梦
    var pendingDream: Int? = nil               // 达到阈值、等它睡觉时讲
    var firstWordPending = false
    var lastActive: Date? = nil
    var request: PetRequest? = nil
    var requestsToday = 0
}

@MainActor
final class BondStore: ObservableObject {
    static let shared = BondStore()

    @Published private(set) var s: BondState = BondStore.load() {
        didSet { save(); Voice.route = s.route ?? .zh; Voice.stage = stage; IslandTalk.store(route: (s.route ?? .zh).rawValue, stage: stage) }
    }
    /// 刚解锁的里程碑，首页弹卡片
    @Published var justUnlocked: Milestone? = nil

    init() { Voice.route = s.route ?? .zh; Voice.stage = stage; Voice.signature = s.signature; IslandTalk.store(route: (s.route ?? .zh).rawValue, stage: stage) }

    // MARK: 状态读

    var hatched: Bool { s.hatched }
    var route: LangRoute { s.route ?? .zh }
    var familiarity: Int { s.familiarity }
    /// 0 嘟嘟 · 1 单词/听懂名字 · 2 短句/听懂常用话 · 3 能聊天/专属嘟嘟
    var stage: Int {
        switch s.familiarity { case ..<80: return 0; case ..<300: return 1; case ..<900: return 2; default: return 3 }
    }
    var stageName: String {
        if route == .dudu {
            return [T("只会嘟嘟"), T("听懂名字"), T("听懂常用话"), T("有了专属嘟嘟")][stage]
        }
        return [T("只会嘟嘟"), T("会说单词"), T("会说短句"), T("能聊天")][stage]
    }
    var nextThreshold: Int? { [80, 300, 900].first { $0 > s.familiarity } }
    var daysTogether: Int {
        guard let d = s.hatchDate else { return 0 }
        return (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: d), to: Calendar.current.startOfDay(for: Date())).day ?? 0) + 1
    }
    var milestones: [(Milestone, Date)] {
        s.milestones.compactMap { k, v in Milestone(rawValue: k).map { ($0, v) } }.sorted { $0.1 < $1.1 }
    }
    func has(_ m: Milestone) -> Bool { s.milestones[m.rawValue] != nil }
    var favoriteFood: Food? { s.favoriteFound ? Food.by(s.favoriteFood) : nil }
    var favoriteFoodSecret: String { s.favoriteFood }
    var firstFood: Food? { Food.by(s.firstFood) }
    var firstDrink: Food? { Food.by(s.firstDrink) }
    var lastDrink: String { s.lastDrink }
    var dreams: [Dream] { s.dreams.compactMap(Dream.init(rawValue:)) }
    var pendingDream: Dream? { s.pendingDream.flatMap(Dream.init(rawValue:)) }
    var hatchDate: Date? { s.hatchDate }
    var signature: String { s.signature }
    var request: PetRequest? { s.request }
    var requestsToday: Int { rollDay(); return s.requestsToday }
    var lastActive: Date? { s.lastActive }

    // MARK: 开蛋

    func hatch(route r: LangRoute) {
        guard !s.hatched else { return }
        s.route = r
        s.hatched = true
        s.hatchDate = Date()
        s.favoriteFood = Food.shop.randomElement()!.id
        s.signature = [T("嘟嘟·嘟"), T("嘟·嘟嘟"), T("嘟～嘟"), T("嘟嘟嘟·嘟"), T("嘟·嘟～")].randomElement()! + "♡"
        Voice.signature = s.signature
        unlock(.hatch)
        Analytics.log("hatch_done", ["route": r.rawValue])
    }

    // MARK: 熟悉度

    private func rollDay() {
        let today = Wallet.day()
        if s.day != today { s.day = today; s.todayPoints = 0; s.counts = [:]; s.requestsToday = 0 }
    }

    /// 记一次行为，按递减规则加熟悉度；返回实际加了多少
    @discardableResult
    func add(_ a: BondAction) -> Int {
        guard s.hatched else { return 0 }
        rollDay()
        let n = (s.counts[a.rawValue] ?? 0) + 1
        s.counts[a.rawValue] = n
        let r = a.rule
        var pts = n >= r.zeroFrom ? 0 : (n >= r.reduceFrom ? 1 : r.base)
        let usedThisKind = s.counts["pts." + a.rawValue] ?? 0
        pts = min(pts, max(0, r.cap - usedThisKind))
        pts = min(pts, max(0, 60 - s.todayPoints))
        guard pts > 0 else { return 0 }
        s.counts["pts." + a.rawValue] = usedThisKind + pts
        s.todayPoints += pts
        grow(pts)
        return pts
    }

    /// 熟悉度增长 + 跨阈值触发
    private func grow(_ pts: Int) {
        let before = s.familiarity
        s.familiarity += pts
        let after = s.familiarity
        if before < 80 && after >= 80 { s.firstWordPending = true }
        if before < 900 && after >= 900 { unlock(route == .dudu ? .signature : .fluent) }
        for d in Dream.allCases where before < d.rawValue && after >= d.rawValue && !s.dreams.contains(d.rawValue) {
            s.pendingDream = d.rawValue
        }
    }

    /// 解锁里程碑：+10 熟悉度（不受每日上限），弹卡片
    @discardableResult
    func unlock(_ m: Milestone) -> Bool {
        guard s.milestones[m.rawValue] == nil else { return false }
        s.milestones[m.rawValue] = Date()
        if m != .hatch { grow(10) }
        justUnlocked = m
        Analytics.log("milestone", ["m": m.rawValue])
        return true
    }

    /// 纪念日检查（每天打开时调）
    func checkAnniversaries() {
        let d = daysTogether
        if d >= 7 { unlock(.day7) }
        if d >= 30 { unlock(.day30) }
        if d >= 100 { unlock(.day100) }
        if d >= 365 { unlock(.day365) }
    }

    // MARK: 吃喝记录

    /// 喂了一样东西；返回 true = 这是它最爱、第一次被发现
    @discardableResult
    func fed(_ f: Food) -> Bool {
        if f.main == .thirsty {
            add(.drink)
            s.lastDrink = f.id
            if s.firstDrink.isEmpty { s.firstDrink = f.id; unlock(.firstDrink) }
        } else {
            add(.feed)
            if s.firstFood.isEmpty { s.firstFood = f.id; unlock(.firstFood) }
        }
        if f.id == s.favoriteFood && !s.favoriteFound {
            s.favoriteFound = true
            unlock(.favorite)
            return true
        }
        return false
    }

    /// 第一句话（路线 A）：熟悉度过 80 后，下一次吃完东西时说出"还……要。"
    func consumeFirstWord() -> Bool {
        guard s.firstWordPending, route.speaks else { return false }
        s.firstWordPending = false
        unlock(.firstWord)
        return true
    }
    /// 路线 B：过 80 后第一次叫它名字
    func consumeHeardName() -> Bool {
        guard s.firstWordPending, route == .dudu else { return false }
        s.firstWordPending = false
        unlock(.heardName)
        return true
    }

    // MARK: 习惯

    /// 记一次习惯；返回当前等级 0/1/2（7 天内满 3 次 = 1，累计 10 次 = 2）
    @discardableResult
    func habit(_ key: String) -> Int {
        var log = (s.habitLog[key] ?? []).filter { Date().timeIntervalSince($0) < 7 * 86400 }
        log.append(Date())
        s.habitLog[key] = log
        s.habitTotal[key, default: 0] += 1
        let lv = habitLevel(key)
        if key == "blanket" && lv >= 1 { unlock(.blanketHabit) }
        return lv
    }
    func habitLevel(_ key: String) -> Int {
        if (s.habitTotal[key] ?? 0) >= 10 { return 2 }
        let recent = (s.habitLog[key] ?? []).filter { Date().timeIntervalSince($0) < 7 * 86400 }.count
        return recent >= 3 ? 1 : 0
    }
    func didToday(_ key: String) -> Bool {
        (s.habitLog[key] ?? []).contains { Calendar.current.isDateInToday($0) }
    }

    // MARK: 梦

    func takeDream() -> Dream? {
        guard let d = pendingDream else { return nil }
        s.pendingDream = nil
        s.dreams.append(d.rawValue)
        Analytics.log("dream", ["d": "\(d.rawValue)"])
        return d
    }

    // MARK: 小愿望

    func setRequest(_ r: PetRequest?) {
        rollDay()
        if r != nil { s.requestsToday += 1; Analytics.log("request_made", ["k": r!.kind.rawValue]) }
        s.request = r
    }
    /// 满足了它的愿望
    func requestMet() {
        guard let r = s.request else { return }
        s.request = nil
        add(.request)
        if r.kind == .drink || r.kind == .food { unlock(.firstRequestMet) }
        Analytics.log("request_met", ["k": r.kind.rawValue])
    }

    // MARK: 在不在

    func markActive() { s.lastActive = Date() }

    // MARK: 调试 / 重来

    func resetForTesting() { s = BondState(); justUnlocked = nil }

    // MARK: 存取

    private static let key = "bond.v1"
    private static func load() -> BondState {
        guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(BondState.self, from: d) else { return BondState() }
        return s
    }
    private func save() {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: Self.key) }
    }
}
