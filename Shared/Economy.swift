import Foundation

// MARK: - 金币经济
//
// 钱从哪来：你自己的生活（签到、按时起床、步数、运动、和它聊天）。照顾它本身不给钱，防刷。
// 钱花在哪：食物（消耗品，喂了就没）和配饰（买一次永久）。水、清理、陪玩免费。

/// 食物：消耗品。效果按需求加减（负数 = 副作用）。
struct Food: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let price: Int
    let effects: [Need: Double]
    let pose: Pose           // 喂完舞台播哪段视频
    let favorite: Bool       // 它的最爱：额外 +5% 开心 + 多说一句
    let note: String
    var dish = false         // 嘟嘟小店做出来的菜：不能买，只能从店里带回来
    var clip: String? = nil  // 吃的时候播哪段（没有专门视频就借相近的）
    var icon: String? = nil  // 用店里的菜图标

    /// 主要满足的需求（用于"吃不下了"判断）
    var main: Need { effects.filter { $0.value > 0 }.max { $0.value < $1.value }?.key ?? .hungry }

    var effectText: String {
        let order: [Need] = [.hungry, .thirsty, .happy, .dirty]
        var parts: [String] = []
        for n in order {
            guard let v = effects[n], v != 0 else { continue }
            let pct = Int((v * 100).rounded())
            parts.append(n.careName + (v > 0 ? "+" : "") + String(pct) + "%")
        }
        return parts.joined(separator: " ")
    }

    static let water   = Food(id: "water",    name: T("水"),   emoji: "💧", price: 0,  effects: [.thirsty: 0.45],                           pose: .coffee, favorite: false, note: T("免费，随便喝"))
    static let carrot  = Food(id: "carrot",   name: T("胡萝卜"), emoji: "🥕", price: 5,  effects: [.hungry: 0.20],                            pose: .eat,    favorite: false, note: T("便宜管饱"))
    static let rice    = Food(id: "riceball", name: T("饭团"),  emoji: "🍙", price: 12, effects: [.hungry: 0.45, .happy: 0.05],              pose: .eat,    favorite: false, note: T("正餐"))
    static let coffee  = Food(id: "coffee",   name: T("咖啡"),  emoji: "☕️", price: 8,  effects: [.thirsty: 0.35, .happy: 0.10],             pose: .coffee, favorite: true,  note: T("它的最爱"))
    static let popcorn = Food(id: "popcorn",  name: T("爆米花"), emoji: "🍿", price: 15, effects: [.hungry: 0.20, .happy: 0.30],              pose: .movie,  favorite: true,  note: T("看电影时开心翻倍"))
    static let cake    = Food(id: "cake",     name: T("蛋糕"),  emoji: "🍰", price: 20, effects: [.hungry: 0.35, .happy: 0.25, .dirty: -0.15], pose: .eat,    favorite: false, note: T("好吃但会弄脏嘴"))

    static let goji    = Food(id: "goji",     name: T("枸杞茶"), emoji: "🍵", price: 6,  effects: [.thirsty: 0.30, .happy: 0.05],             pose: .coffee, favorite: false, note: T("养生，保温杯泡的"))

    // 2026-10-19 新上架：有图标（food_<id>）；2026-10-22 起每样都有自己的吃相视频 purple_eat_<id>.mp4（Kling 出的）
    private static func s(_ id: String, _ name: String, _ emoji: String, _ price: Int, _ e: [Need: Double], drink: Bool = false,
                          fav: Bool = false, _ note: String) -> Food {
        Food(id: id, name: name, emoji: emoji, price: price, effects: e, pose: drink ? .coffee : .eat,
             favorite: fav, note: note, clip: id, icon: "food_" + id)
    }
    static let starcandy   = s("starcandy", T("星星糖"), "🍬", 10, [.hungry: 0.10, .happy: 0.25], T("一颗一颗含着吃，嘟嘟星的味道"))
    static let sweetpotato = s("sweetpotato", T("烤红薯"), "🍠", 16, [.hungry: 0.55, .happy: 0.05], T("养生家认证，热乎乎的"))
    static let strawmilk   = s("strawmilk", T("草莓牛奶"), "🍓", 14, [.thirsty: 0.40, .hungry: 0.10, .happy: 0.15], drink: true, T("粉粉的，它会抱着喝"))
    static let pudding     = s("pudding", T("布丁"), "🍮", 18, [.hungry: 0.30, .happy: 0.25], T("duang duang 的"))
    static let donut       = s("donut", T("甜甜圈"), "🍩", 22, [.hungry: 0.35, .happy: 0.30, .dirty: -0.10], T("糖霜会粘在嘴边"))
    static let icecream    = s("icecream", T("冰淇淋"), "🍦", 25, [.thirsty: 0.25, .hungry: 0.15, .happy: 0.40], T("化得快，要快点吃"))
    static let boba        = s("boba", T("珍珠奶茶"), "🧋", 28, [.thirsty: 0.40, .hungry: 0.25, .happy: 0.35], drink: true, fav: true, T("它的最爱之二，店里做不出这个味"))
    static let watermelon  = s("watermelon", T("一角西瓜"), "🍉", 30, [.thirsty: 0.50, .hungry: 0.30, .happy: 0.25], T("抱着比它的脸还大"))

    // 2026-10-27：越贵的一口越顶用（发财哥：吃别的不如胡萝卜回得快）。胡萝卜最便宜但一次只回 20%
    static let shop: [Food] = [carrot, goji, coffee, starcandy, rice, strawmilk, popcorn, sweetpotato, pudding, cake, donut, icecream, boba, watermelon]

    /// 嘟嘟小店的 18 道菜：店里做好点「带回家」，在首页喂它（比商城的吃的更顶饱、更开心）
    private static func d(_ id: String, _ name: String, _ emoji: String, _ clip: String, drink: Bool = false) -> Food {
        let e: [Need: Double] = drink ? [.thirsty: 0.45, .hungry: 0.10, .happy: 0.20] : [.hungry: 0.55, .happy: 0.20]
        return Food(id: id, name: name, emoji: emoji, price: 0, effects: e, pose: drink ? .coffee : .eat, favorite: false,
                    note: T("嘟嘟小店做的"), dish: true, clip: clip, icon: "mk_" + id)
    }
    static let dishes: [Food] = [
        d("dish_bento", T("胡萝卜便当"), "🍱", "riceball"), d("dish_curry", T("胡萝卜咖喱饭"), "🍛", "riceball"),
        d("dish_teacake", T("法式吐司"), "🍞", "cake"), d("dish_pudding", T("焦糖布丁"), "🍮", "pudding"),
        d("dish_tea", T("下午茶套餐"), "🫖", "goji", drink: true), d("dish_juiceset", T("果汁双人份"), "🧃", "goji", drink: true),
        d("dish_picnic", T("野餐篮"), "🧺", "riceball"), d("dish_parfait", T("草莓芭菲"), "🍨", "cake"),
        d("dish_popcake", T("爆米花蛋糕"), "🎂", "popcorn"), d("dish_party", T("派对拼盘"), "🍢", "cake"),
        d("dish_shake", T("草莓奶昔双杯"), "🥤", "strawmilk", drink: true), d("dish_sundae", T("水果圣代"), "🍧", "icecream"),
        d("dish_omurice", T("蛋包饭"), "🍳", "riceball"), d("dish_tartset", T("蛋挞下午茶"), "🥧", "cake"),
        d("dish_bun", T("迷你披萨"), "🍕", "cake"), d("dish_hotpot", T("番茄意面"), "🍝", "riceball"),
        d("dish_mooncake", T("星星苹果派"), "🥧", "cake"), d("dish_feast", T("嘟嘟星宴席"), "🎉", "riceball"),
        // 菜谱书里的 12 道
        d("dish_onigiriset", T("墨西哥卷饼"), "🌯", "riceball"), d("dish_carrotcake", T("胡萝卜蛋糕"), "🥕", "cake"),
        d("dish_honeytea", T("草莓可颂"), "🥐", "cake"), d("dish_fruitsando", T("水果三明治"), "🥪", "cake"),
        d("dish_daifuku", T("草莓大福"), "🍡", "cake"), d("dish_bobaroll", T("奶茶蛋糕卷"), "🍥", "boba"),
        d("dish_icesando", T("冰淇淋三明治"), "🍦", "icecream"), d("dish_popsicle", T("水果冰棍"), "🍭", "coffee", drink: true),
        d("dish_ramen", T("小拉面"), "🍜", "riceball"), d("dish_dumpling", T("一盘饺子"), "🥟", "riceball"),
        d("dish_pancake", T("松饼塔"), "🥞", "cake"), d("dish_pumpkin", T("星星南瓜汤"), "🎃", "carrot", drink: true),
        // 咖啡、蜂蜜两条新链的菜
        d("dish_latteart", T("拉花拿铁双杯"), "☕️", "coffee", drink: true), d("dish_affogato", T("阿芙佳朵"), "🍨", "cake"),
        d("dish_tiramisu", T("提拉米苏"), "🍰", "cake"), d("dish_honeytoast", T("蜂蜜厚吐司"), "🍞", "cake"),
        d("dish_honeylemon", T("蜂蜜柠檬冰饮"), "🍋", "goji", drink: true),
        // 2026-10-19 深菜：三样料、菜做成菜
        d("dish_bubbletea", T("草莓珍珠奶茶"), "🧋", "coffee", drink: true), d("dish_deluxebento", T("豪华便当"), "🍱", "riceball"),
        d("dish_fruittart", T("水果挞"), "🥧", "cake"), d("dish_mocha", T("摩卡下午茶"), "☕️", "coffee", drink: true),
        d("dish_honeycrepe", T("蜂蜜千层"), "🍰", "cake"), d("dish_curryomu", T("咖喱蛋包饭"), "🍛", "riceball"),
        d("dish_teatower", T("三层下午茶塔"), "🫖", "cake"), d("dish_parfaittower", T("芭菲塔"), "🍨", "cake"),
        d("dish_starbox", T("嘟嘟星双层食盒"), "🍱", "riceball"),
    ]
    static let all: [Food] = [water] + shop + dishes
    static func by(_ id: String) -> Food? { all.first { $0.id == id } }
}

/// 赚钱规则（每天一次的用 key 去重）
enum EarnRule: String, CaseIterable {
    case checkin, wake, chat, play, found, steps4k, steps8k, steps12k, workout1, workout2

    var title: String {
        switch self {
        case .checkin:  return T("每日签到（连续签到每天多 +2，最多 +10）")
        case .wake:     return T("按时起床（起床时间后 1 小时内打开）")
        case .chat:     return T("今天第一次和它聊天")
        case .play:     return T("陪它玩一局接金币（接到几个给几个，每天第一局）")
        case .found:    return T("你不在时它会捡金币（每离开 1 小时 +2）")
        case .steps4k:  return T("今天走到 4,000 步")
        case .steps8k:  return T("今天走到 8,000 步")
        case .steps12k: return T("今天走到 12,000 步")
        case .workout1: return T("完成一次运动（Apple 健康记录）")
        case .workout2: return T("再完成一次运动")
        }
    }
    var amount: Int {
        switch self {
        case .checkin: return 10
        case .wake: return 10
        case .chat: return 5
        case .play: return Self.playCap
        case .found: return Self.foundCap
        case .steps4k: return 5
        case .steps8k: return 10
        case .steps12k: return 15
        case .workout1, .workout2: return 20
        }
    }
    static let playCap = 10      // 小游戏每天第一局最多给 10
    static let foundCap = 15     // 离线捡钱每天最多 15
    var short: String {
        switch self {
        case .checkin: return T("签到")
        case .wake: return T("按时起床")
        case .chat: return T("聊天")
        case .play: return T("陪它玩")
        case .found: return T("它捡到的")
        case .steps4k: return T("4千步")
        case .steps8k: return T("8千步")
        case .steps12k: return T("1万2千步")
        case .workout1, .workout2: return T("运动")
        }
    }
}

/// 钱包：背包里的食物、流水、今天领过哪些奖励、连续签到。单独存，旧版 Profile 不受影响。
struct Wallet: Codable, Equatable {
    struct Entry: Codable, Equatable, Identifiable {
        var id = UUID()
        var at: Date
        var amount: Int
        var reason: String
    }
    var bag: [String: Int] = [:]
    var ledger: [Entry] = []
    var claimed: [String] = []       // "yyyy-MM-dd|rule"
    var streak: Int = 0
    var lastCheckIn: String = ""
    // 离线捡钱（可选字段，旧存档解码为 nil）
    var lastSeen: Date? = nil
    var foundDay: String? = nil
    var foundToday: Int? = nil

    static func day(_ d: Date = Date()) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }

    private static let key = "wallet.v1"
    static func load() -> Wallet {
        if let d = UserDefaults(suiteName: Character.appGroup)?.data(forKey: key),
           let w = try? JSONDecoder().decode(Wallet.self, from: d) { return w }
        // 新手礼包：3 根胡萝卜 + 1 个饭团 + 1 杯咖啡
        var w = Wallet(); w.bag = ["carrot": 3, "riceball": 1, "coffee": 1]
        w.ledger = [Entry(at: Date(), amount: 0, reason: T("新手礼包：🥕×3 🍙×1 ☕️×1"))]
        w.save(); return w
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults(suiteName: Character.appGroup)?.set(d, forKey: Self.key) }
    }
}
