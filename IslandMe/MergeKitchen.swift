import SwiftUI
import UserNotifications

// MARK: - 小紫的小厨房（照搬合成经营类的完整玩法，换成小紫的东西）
//
// 产出器（可升级、有次数、会冷却）→ 两个一样的合成更高级（6 条链 × 8 级）→ 厨具做菜（小锅/烤箱/榨汁机，真实计时）
// → 交订单（它是唯一的客人，交了它真的吃）→ 得币/经验/星星 → 星星拿去装修小厨房（章节 + 嘟嘟星线索）。
// 另外：纸箱格子（旁边合成才打开）、泡泡（限时用宝石买下）、宝箱（计时开）、万能星、剪刀、背包、每日小铺、图鉴、出售撤销。
// 人设：它懒，躺在上面等吃；你在下面忙。

// MARK: 数据表
enum MK {
    static let cols = 8, rows = 9
    static let maxEnergy = 100
    static let regenSeconds: Double = 120     // 回满约 3.3 小时（2026-10-20 从 90 秒调紧）：早中晚各开一次正好
    static let maxTier = 12      // 2026-10-20 从 10 级加到 12 级（同类游戏主力链 10–15 级）

    struct Chain { let key: String; let names: [String]; let gen: String; let genName: String; let unlock: Int; let food: String }
    static let chains: [Chain] = [
        Chain(key: "rice",  names: [T("米粒"), T("一碗米饭"), T("小饭团"), T("蛋炒饭"), T("寿司卷"), T("寿司拼盘"), T("便当"), T("三层豪华便当"), T("便当塔"), T("寿司船"), T("宴会长桌便当"), T("嘟嘟星宴席便当")], gen: "gen_rice", genName: T("米袋"), unlock: 1, food: "riceball"),
        Chain(key: "veg",   names: [T("胡萝卜苗"), T("胡萝卜"), T("一把胡萝卜"), T("胡萝卜篮"), T("小沙拉"), T("大沙拉"), T("蔬菜拼盘"), T("菜园礼篮"), T("蔬菜花束"), T("沙拉餐车"), T("巨型彩虹沙拉碗"), T("胡萝卜国王")], gen: "gen_veg", genName: T("菜篮"), unlock: 1, food: "carrot"),
        // 2026-10-20 原来的「茶」链（枸杞、保温杯）太本土，换成面包房；id 还叫 tea，老存档不用迁移
        Chain(key: "tea",   names: [T("麦穗"), T("小圆面包"), T("吐司"), T("黄油吐司"), T("可颂"), T("三明治"), T("汉堡"), T("早餐拼盘"), T("面包篮"), T("面包餐车"), T("面包派对长桌"), T("嘟嘟星面包塔")], gen: "gen_tea", genName: T("面包箱"), unlock: 2, food: "cake"),
        // 2026-10-20 开头从「面粉、面团」改成「方糖、奶油」，和面包房（麦穗）分开
        Chain(key: "sweet", names: [T("方糖"), T("一碗奶油"), T("星星饼干"), T("一盒饼干"), T("杯子蛋糕"), T("草莓蛋糕块"), T("整个草莓蛋糕"), T("三层生日蛋糕"), T("城堡蛋糕"), T("婚礼蛋糕"), T("甜点旋转木马"), T("星星蛋糕塔")], gen: "gen_sweet", genName: T("糖罐"), unlock: 3, food: "cake"),
        Chain(key: "fruit", names: [T("樱桃"), T("草莓"), T("一碗草莓"), T("水果篮"), T("鲜榨果汁"), T("水果茶"), T("水果拼盘"), T("水果塔"), T("水果花篮"), T("水果餐车"), T("水果瀑布塔"), T("金苹果")], gen: "gen_fruit", genName: T("小果树"), unlock: 5, food: "cake"),
        Chain(key: "snack", names: [T("玉米粒"), T("玉米"), T("一把爆米花"), T("爆米花桶"), T("焦糖爆米花"), T("派对爆米花"), T("零食拼盘"), T("电影零食礼盒"), T("巨无霸爆米花桶"), T("电影院零食车"), T("爆米花热气球"), T("爆米花城堡")], gen: "gen_snack", genName: T("玉米袋"), unlock: 7, food: "popcorn"),
        Chain(key: "milk",  names: [T("一滴牛奶"), T("一瓶牛奶"), T("热牛奶"), T("奶茶"), T("珍珠奶茶"), T("草莓奶昔"), T("冰淇淋球"), T("冰淇淋圣代"), T("三层冰淇淋"), T("冰淇淋车"), T("冰淇淋摩天轮"), T("冰淇淋城堡")], gen: "gen_milk", genName: T("牛奶罐"), unlock: 10, food: "coffee"),
        Chain(key: "egg",   names: [T("鸡蛋"), T("一篮鸡蛋"), T("荷包蛋"), T("玉子烧"), T("班尼迪克蛋"), T("蛋挞"), T("一盒蛋挞"), T("蛋糕卷"), T("舒芙蕾"), T("早餐蛋塔"), T("彩蛋蛋糕车"), T("金蛋")], gen: "gen_egg", genName: T("鸡蛋窝"), unlock: 13, food: "cake"),
        // 2026-10-19：中后期新链（15 级以后也有新东西开）
        Chain(key: "coffee", names: [T("一颗咖啡豆"), T("一把咖啡豆"), T("一袋咖啡粉"), T("一杯黑咖啡"), T("拿铁"), T("爱心拉花"), T("咖啡点心套餐"), T("手冲咖啡套餐"), T("咖啡餐车"), T("咖啡蛋糕塔"), T("咖啡甜品台"), T("嘟嘟星咖啡树")], gen: "gen_coffee", genName: T("咖啡豆袋"), unlock: 16, food: "coffee"),
        Chain(key: "honey",  names: [T("一滴蜂蜜"), T("一罐蜂蜜"), T("一块蜂巢"), T("蜂蜜罐和勺"), T("蜂蜜柠檬水"), T("蜂蜜松饼"), T("蜂蜜蛋糕"), T("蜂蜜礼盒"), T("蜂巢蛋糕"), T("蜂蜜松饼塔"), T("蜂蜜蛋糕城堡"), T("嘟嘟星金蜂蜜")], gen: "gen_honey", genName: T("小蜂箱"), unlock: 19, food: "cake"),
    ]
    struct Appliance { let id: String; let name: String; let unlock: Int }
    static let appliances: [Appliance] = [
        Appliance(id: "pot", name: T("小锅"), unlock: 4), Appliance(id: "oven", name: T("烤箱"), unlock: 6), Appliance(id: "juicer", name: T("榨汁机"), unlock: 8),
        Appliance(id: "icecream", name: T("冰淇淋机"), unlock: 11), Appliance(id: "steamer", name: T("蒸笼"), unlock: 14),
        Appliance(id: "coffeemaker", name: T("咖啡机"), unlock: 16),
    ]
    struct Recipe { let id: String; let name: String; let at: String; let needs: [String]; let minutes: Double; let unlock: Int; let food: String
        var book: String? = nil   // 要先在商城买这本菜谱才会做（2026-10-19）
    }
    /// 商城卖的菜谱书：币回到商城 → 小店多几道菜
    struct Book { let id: String; let name: String; let price: Int; let level: Int; let note: String }
    static let books: [Book] = [
        Book(id: "book_home",  name: T("早午餐菜谱"), price: 150, level: 5,  note: T("4 道早午餐：墨西哥卷饼、胡萝卜蛋糕、草莓可颂、水果三明治")),
        Book(id: "book_sweet", name: T("甜品屋菜谱"),   price: 320, level: 10, note: T("4 道甜品：草莓大福、奶茶蛋糕卷、冰淇淋三明治、水果冰棍")),
        Book(id: "book_star",  name: T("嘟嘟星家常菜"), price: 600, level: 14, note: T("奶奶的 4 道菜：小拉面、一盘饺子、松饼塔、星星南瓜汤")),
    ]
    static func hasBook(_ id: String?) -> Bool {
        guard let id else { return true }
        return (UserDefaults.standard.stringArray(forKey: "mk.books") ?? []).contains(id)
    }
    static func addBook(_ id: String) {
        var a = UserDefaults.standard.stringArray(forKey: "mk.books") ?? []
        if !a.contains(id) { a.append(id); UserDefaults.standard.set(a, forKey: "mk.books") }
    }
    /// 这道菜现在能做吗：等级够、要菜谱的已经买了
    static func can(_ r: Recipe, _ level: Int) -> Bool { r.unlock <= level && hasBook(r.book) }
    static let recipes: [Recipe] = [
        Recipe(id: "dish_bento",    name: T("胡萝卜便当"),   at: "pot",      needs: ["rice3", "veg3"],    minutes: 2,  unlock: 4,  food: "riceball"),
        Recipe(id: "dish_curry",    name: T("胡萝卜咖喱饭"), at: "pot",      needs: ["rice2", "veg4"],    minutes: 5,  unlock: 5,  food: "riceball"),
        Recipe(id: "dish_teacake",  name: T("法式吐司"),     at: "oven",     needs: ["tea3", "sweet2"],   minutes: 3,  unlock: 6,  food: "cake"),
        Recipe(id: "dish_pudding",  name: T("焦糖布丁"),     at: "oven",     needs: ["sweet2", "snack5"], minutes: 6,  unlock: 7,  food: "cake"),
        Recipe(id: "dish_tea",      name: T("下午茶套餐"),   at: "juicer",   needs: ["sweet5", "tea4"],   minutes: 4,  unlock: 8,  food: "goji"),
        Recipe(id: "dish_juiceset", name: T("果汁双人份"),   at: "juicer",   needs: ["fruit4", "fruit2"],   minutes: 5,  unlock: 8,  food: "goji"),
        Recipe(id: "dish_picnic",   name: T("野餐篮"),       at: "pot",      needs: ["rice3", "fruit4"],  minutes: 12, unlock: 9,  food: "riceball"),
        Recipe(id: "dish_parfait",  name: T("草莓芭菲"),     at: "juicer",   needs: ["fruit3", "sweet2"], minutes: 8,  unlock: 9,  food: "cake"),
        Recipe(id: "dish_popcake",  name: T("爆米花蛋糕"),   at: "oven",     needs: ["sweet6", "snack4"], minutes: 10, unlock: 10, food: "popcorn"),
        Recipe(id: "dish_party",    name: T("派对拼盘"),     at: "pot",      needs: ["rice7", "sweet6"],  minutes: 20, unlock: 11, food: "cake"),
        Recipe(id: "dish_shake",    name: T("草莓奶昔双杯"), at: "icecream", needs: ["milk2", "fruit3"],  minutes: 6,  unlock: 11, food: "coffee"),
        Recipe(id: "dish_sundae",   name: T("水果圣代"),     at: "icecream", needs: ["milk7", "fruit5"],  minutes: 15, unlock: 12, food: "cake"),
        Recipe(id: "dish_omurice",  name: T("蛋包饭"),       at: "pot",      needs: ["egg3", "rice4"],    minutes: 10, unlock: 13, food: "riceball"),
        Recipe(id: "dish_tartset",  name: T("蛋挞下午茶"),   at: "oven",     needs: ["egg6", "tea5"],     minutes: 18, unlock: 14, food: "cake"),
        Recipe(id: "dish_bun",      name: T("迷你披萨"),     at: "oven",     needs: ["tea2", "veg4"],     minutes: 12, unlock: 14, food: "riceball"),
        Recipe(id: "dish_hotpot",   name: T("番茄意面"),     at: "pot",      needs: ["tea1", "veg6"],     minutes: 25, unlock: 16, food: "carrot"),
        Recipe(id: "dish_mooncake", name: T("星星苹果派"),   at: "oven",     needs: ["fruit7", "tea1"],   minutes: 30, unlock: 18, food: "cake"),
        Recipe(id: "dish_feast",    name: T("嘟嘟星宴席"),   at: "steamer",  needs: ["rice9", "milk8"],   minutes: 45, unlock: 20, food: "riceball"),
        // 新链的菜
        Recipe(id: "dish_latteart",  name: T("拉花拿铁双杯"), at: "coffeemaker", needs: ["coffee6", "milk2"], minutes: 12, unlock: 16, food: "coffee"),
        Recipe(id: "dish_affogato",  name: T("阿芙佳朵"),     at: "icecream",    needs: ["coffee4", "milk7"], minutes: 10, unlock: 16, food: "cake"),
        Recipe(id: "dish_tiramisu",  name: T("提拉米苏"),     at: "oven",        needs: ["coffee4", "sweet2"], minutes: 20, unlock: 17, food: "cake"),
        Recipe(id: "dish_honeytoast", name: T("蜂蜜厚吐司"),  at: "oven",        needs: ["honey2", "tea4"], minutes: 15, unlock: 19, food: "cake"),
        Recipe(id: "dish_honeylemon", name: T("蜂蜜柠檬冰饮"), at: "juicer",     needs: ["honey5", "fruit5"], minutes: 12, unlock: 20, food: "goji"),
        // 2026-10-19 后期变深：三样料的菜（12 级起）
        Recipe(id: "dish_bubbletea",  name: T("草莓珍珠奶茶"), at: "juicer",      needs: ["milk5", "fruit2", "sweet1"],   minutes: 15, unlock: 12, food: "coffee"),
        Recipe(id: "dish_deluxebento", name: T("豪华便当"),    at: "pot",         needs: ["rice6", "veg5", "egg4"],     minutes: 20, unlock: 13, food: "riceball"),
        Recipe(id: "dish_fruittart",  name: T("水果挞"),       at: "oven",        needs: ["sweet2", "fruit4", "tea1"],  minutes: 22, unlock: 14, food: "cake"),
        Recipe(id: "dish_mocha",      name: T("摩卡下午茶"),   at: "coffeemaker", needs: ["coffee4", "milk2", "sweet3"], minutes: 20, unlock: 17, food: "coffee"),
        Recipe(id: "dish_honeycrepe", name: T("蜂蜜千层"),     at: "oven",        needs: ["honey2", "milk3", "egg2"], minutes: 25, unlock: 20, food: "cake"),
        // 菜做成菜（15 级起）：先做半成品，再拿它下锅
        Recipe(id: "dish_curryomu",   name: T("咖喱蛋包饭"),   at: "pot",         needs: ["dish_curry", "egg4"],        minutes: 20, unlock: 15, food: "riceball"),
        Recipe(id: "dish_teatower",   name: T("三层下午茶塔"), at: "oven",        needs: ["dish_tea", "fruit5"],        minutes: 25, unlock: 16, food: "cake"),
        Recipe(id: "dish_parfaittower", name: T("芭菲塔"),     at: "icecream",    needs: ["dish_parfait", "milk6"],     minutes: 25, unlock: 18, food: "cake"),
        Recipe(id: "dish_starbox",    name: T("嘟嘟星双层食盒"), at: "steamer",   needs: ["dish_bento", "dish_omurice"], minutes: 30, unlock: 19, food: "riceball"),
        // 菜谱书里的菜（买了书才出现在厨具和订单里）
        Recipe(id: "dish_onigiriset", name: T("墨西哥卷饼"), at: "pot",      needs: ["rice4", "veg4"],    minutes: 6,  unlock: 5,  food: "riceball", book: "book_home"),
        Recipe(id: "dish_carrotcake", name: T("胡萝卜蛋糕"), at: "oven",     needs: ["sweet2", "veg2"],   minutes: 8,  unlock: 6,  food: "cake",     book: "book_home"),
        Recipe(id: "dish_honeytea",   name: T("草莓可颂"),   at: "oven",     needs: ["tea5", "fruit3"],   minutes: 6,  unlock: 8,  food: "cake",     book: "book_home"),
        Recipe(id: "dish_fruitsando", name: T("水果三明治"), at: "oven",     needs: ["tea3", "fruit3"], minutes: 9,  unlock: 6,  food: "cake",     book: "book_home"),
        Recipe(id: "dish_daifuku",    name: T("草莓大福"),   at: "oven",     needs: ["rice2", "fruit2"], minutes: 10, unlock: 10, food: "cake",     book: "book_sweet"),
        Recipe(id: "dish_bobaroll",   name: T("奶茶蛋糕卷"), at: "oven",     needs: ["milk4", "sweet2"],  minutes: 14, unlock: 10, food: "cake",     book: "book_sweet"),
        Recipe(id: "dish_icesando",   name: T("冰淇淋三明治"), at: "icecream", needs: ["milk7", "sweet3"], minutes: 10, unlock: 11, food: "cake",    book: "book_sweet"),
        Recipe(id: "dish_popsicle",   name: T("水果冰棍"),   at: "icecream", needs: ["fruit5", "milk2"],  minutes: 12, unlock: 11, food: "coffee",   book: "book_sweet"),
        Recipe(id: "dish_ramen",      name: T("小拉面"),     at: "pot",      needs: ["tea1", "egg3"],     minutes: 18, unlock: 14, food: "riceball", book: "book_star"),
        Recipe(id: "dish_dumpling",   name: T("一盘饺子"),   at: "steamer",  needs: ["tea1", "veg3"],   minutes: 15, unlock: 14, food: "riceball", book: "book_star"),
        Recipe(id: "dish_pancake",    name: T("松饼塔"),     at: "oven",     needs: ["egg2", "milk2"],    minutes: 20, unlock: 14, food: "cake",     book: "book_star"),
        Recipe(id: "dish_pumpkin",    name: T("星星南瓜汤"), at: "pot",      needs: ["veg6", "milk2"],    minutes: 25, unlock: 15, food: "carrot",   book: "book_star"),
    ]
    /// 宝箱：开箱要等多久（分钟），开出几样
    static let chests: [String: (minutes: Double, drops: Int)] = ["gift": (0, 3), "chest2": (10, 5), "chest3": (30, 8), "chest_daily": (0, 4)]

    static func chain(_ id: String) -> Chain? {
        chains.first { id.hasPrefix($0.key) && Int(id.dropFirst($0.key.count)) != nil }
    }
    static func tier(_ id: String) -> Int { chain(id).flatMap { Int(id.dropFirst($0.key.count)) } ?? 0 }
    static func recipe(_ id: String) -> Recipe? { recipes.first { $0.id == id } }
    /// 这道菜最终要用到哪几条链（半成品往下拆）
    static func baseChains(_ r: Recipe) -> Set<String> {
        Set(r.needs.flatMap { n -> [String] in
            if let c = chain(n) { return [c.key] }
            if let d = recipe(n) { return Array(baseChains(d)) }
            return []
        })
    }
    /// 深菜：三样料，或者要用半成品
    static func isDeep(_ r: Recipe) -> Bool { r.needs.count > 2 || r.needs.contains { recipe($0) != nil } }
    /// 这道菜从头做要哪些东西（半成品拆开也算上）
    static func allNeeds(_ id: String) -> [String] {
        guard let r = recipe(id) else { return [] }
        return r.needs + r.needs.flatMap(allNeeds)
    }
    static func isGen(_ id: String) -> Bool { id.hasPrefix("gen_") }
    static func isAppliance(_ id: String) -> Bool { appliances.contains { $0.id == id } }
    static func name(_ id: String) -> String {
        if let c = chain(id) { return c.names[tier(id) - 1] }
        if let r = recipe(id) { return r.name }
        if let c = chains.first(where: { $0.gen == id }) { return c.genName }
        if let a = appliances.first(where: { $0.id == id }) { return a.name }
        switch id {
        case "gift": return T("小礼盒")
        case "chest2": return T("宝箱")
        case "chest3": return T("大宝箱")
        case "energy": return T("体力瓶")
        case "wildcard": return T("万能星")
        case "scissors": return T("小剪刀")
        case "gem": return T("宝石")
        case "coins": return T("一堆币")
        case "star": return T("星星")
        case "chest_daily": return T("每日宝箱")
        case "ticket": return T("外卖小票")
        case "calendar": return T("签到礼")
        case "event_basket": return T("活动篮子")
        case "luckybag": return T("惊喜福袋")
        default: return id
        }
    }
    /// 价值：订单报酬 / 出售价
    static func value(_ id: String) -> Int {
        if chain(id) != nil { return 1 << (tier(id) - 1) }
        // 2026-10-20 配方按「合不合逻辑」挑原料（法式吐司 = 吐司 + 奶油），原料级别可能很低；报酬按解锁等级保底，后期的菜照样值钱
        if let r = recipe(id) { return max(r.needs.map(value).reduce(0, +) * 2, r.unlock * 4) }
        return 1
    }
    /// 越往后越慢：前 10 级一两周，之后每级要好几天
    /// 数值按 sim/sim.py 模拟调过：每天 15–20 分钟，第 3 周左右解锁全部食材和厨具，装修约 70 天做完
    static func xpNeed(_ level: Int) -> Int { 30 + level * 20 + max(0, level - 8) * level * 4 }
    /// 订单要几级的：最高 7 级（8–10 级是收藏和图鉴用的）
    // 2026-10-19 按 sim/kitchen_sim.py 调：一开始就要到 4 级；星星按价值给（难单多给），第 8 章约第 4 周、第 12 章约第 9 周
    static func orderTop(_ level: Int) -> Int { min(6, 4 + level / 6) }
    static func orderStars(_ v: Int) -> Int { max(1, min(8, Int((Double(v) / 3.5).rounded()))) }
    static func orderCoins(_ v: Int) -> Int { max(1, Int((Double(v) / 8).rounded())) }
    // 2026-10-27 发财哥实测：每次上线 7 分钟左右产出器就点空了、体力还剩一大半。
    // 改成体力才是真正的限制：产出器次数够一整局用，空了很快补满
    static let genCharges = [0, 40, 60, 80]
    static let genRefill: [Double] = [0, 10, 8, 6]         // 分钟
}

// MARK: 存档
struct MKSlot: Codable, Equatable {
    var item: String? = nil
    var glv = 1                      // 产出器等级
    var charges = 0                  // 产出器剩余次数
    var refillAt: Date? = nil        // 产出器冷却结束
    var boxed = false                // 被纸箱盖着
    var bubbleUntil: Date? = nil     // 泡泡：到点变成币
    var openAt: Date? = nil          // 宝箱开箱完成时间
}

struct MKCook: Codable, Equatable { var putIn: [String] = []; var dish: String? = nil; var doneAt: Date? = nil }
struct MKOrder: Codable, Identifiable, Equatable {
    var id = UUID(); var items: [String]; var stars: Int; var gems: Int = 0
    var meal: String                 // 外卖：送到哪；小紫：哪一顿
    var pet: Bool? = nil             // 小紫自己的饭
    var isPet: Bool { pet == true }
    var event: Bool? = nil           // 周末活动单
    var isEvent: Bool { event == true }
    var made: Date? = nil            // 什么时候来的单（换单用）
    var regular: String? = nil       // 熟客（灯塔、图书馆……）
    var signature: Bool? = nil       // 今日招牌菜：一天一单，奖励高
    var isSignature: Bool { signature == true }
    var door: Int? = nil             // 门单：嘟嘟星第几区（1…14）
    var rushUntil: Date? = nil       // 急单：到点没交就走（不罚）
    var isRush: Bool { rushUntil != nil }
    var isDoor: Bool { door != nil }
    /// 招牌和门单：不换、不补新单、双倍币
    var big: Bool? = nil             // 大订单：要 8–12 级的高级货，奖励大，一天一张
    var isBig: Bool { big == true }
    var isSpecial: Bool { isSignature || isDoor || isBig }
    var band: Int? = nil             // 难度档：0 易 1 中 2 难（老存档没有，按内容估）
}
struct MKDeal: Codable, Identifiable, Equatable { var id = UUID(); var item: String; var price: Int; var gem: Bool; var sold = false }
struct MKSold: Equatable { let index: Int; let slot: MKSlot }
struct MKGoal: Codable, Identifiable, Equatable {
    var kind: String; var target: Int; var progress = 0; var claimed = false
    var id: String { kind }
    var done: Bool { progress >= target }
    var title: String {
        switch kind {
        case "merge": return T("合成 {0} 次", target)
        case "ticket": return T("送 {0} 单外卖", target)
        case "pet": return T("喂{0}吃 {1} 顿饭", Voice.petName, target)
        case "dish": return T("用厨具做 {0} 道菜", target)
        case "gen": return T("点产出器 {0} 次", target)
        case "chest": return T("开 {0} 个宝箱", target)
        default: return kind
        }
    }
}
struct MKDaily: Codable, Equatable { var day: String; var goals: [MKGoal]; var bonus = false }
/// 限时冲刺（2026-10-21，学同类上面那一排计时卡）：3 小时内做完一件小事，领体力 / 福袋 / 宝石 / 宝箱。
/// 领完（或过期）歇 20–40 分钟来下一个，任何时候打开都有一个在倒计时
struct MKSprint: Codable, Equatable {
    var kind: String; var target: Int; var progress = 0; var ends: Date; var reward: String; var claimed = false
    var done: Bool { progress >= target }
    var title: String {
        switch kind {
        case "merge": return T("合成 {0} 次", target)
        case "gen": return T("点产出器 {0} 次", target)
        case "ticket": return T("送 {0} 单外卖", target)
        case "dish": return T("做 {0} 道菜", target)
        default: return T("开 {0} 个宝箱", target)
        }
    }
    var rewardText: String {
        switch reward {
        case "energy": return T("体力 +50")
        case "gems": return T("宝石 +6")
        case "luckybag": return T("惊喜福袋")
        default: return T("宝箱")
        }
    }
}
struct MKEventState: Codable, Equatable { var week: String; var points = 0; var claimed: [Int] = [] }

/// 周末活动：周五晚上 6 点到周日结束；12 种轮换
enum MKEvent {
    struct Def { let id: String; let name: String; let chains: [String]; let line: String }
    /// 2026-10-22：从 3 种加到 12 种，每周末换一个，三个月不重样（每个活动至少两条前期就有的链，新手也能玩）
    static let defs: [Def] = [
        Def(id: "picnic", name: T("周末野餐"), chains: ["rice", "fruit", "tea"], line: T("野餐垫是你铺的，它负责躺在正中间，说今天谁也别想让它站起来。")),
        Def(id: "teaparty", name: T("下午茶会"), chains: ["sweet", "tea", "milk"], line: T("它戴上了小围裙，宣布今天的茶要配三块蛋糕。")),
        Def(id: "movie", name: T("爆米花电影夜"), chains: ["snack", "milk", "fruit"], line: T("它抱着毯子占好了沙发最中间的位置。")),
        Def(id: "breakfast", name: T("赖床早午餐"), chains: ["egg", "tea", "rice"], line: T("它说早饭要在床上吃才香。床是它的，碗是你端的。")),
        Def(id: "garden", name: T("菜园丰收节"), chains: ["veg", "fruit", "rice"], line: T("它坐在胡萝卜堆上，宣布自己是今年的丰收大王。")),
        Def(id: "bakery", name: T("面包烘焙日"), chains: ["tea", "sweet", "egg"], line: T("烤箱一开，它就把脸贴过去：「我在帮它保温。」")),
        Def(id: "cafe", name: T("星星咖啡馆"), chains: ["coffee", "milk", "sweet"], line: T("它学着拉花，拉出来一个歪歪的星星，坚持说这是嘟嘟星的样子。")),
        Def(id: "honey", name: T("蜂蜜采收周"), chains: ["honey", "tea", "fruit"], line: T("它把手指伸进蜂蜜罐，说是在检查甜度。检查了很多次。")),
        Def(id: "sushi", name: T("饭团寿司节"), chains: ["rice", "veg", "egg"], line: T("它捏的饭团是圆的。它说三角的太累了。")),
        Def(id: "dessert", name: T("甜品派对"), chains: ["sweet", "fruit", "milk"], line: T("它把草莓挨个摆在蛋糕上，摆一个吃一个，最后蛋糕上只剩一个。")),
        Def(id: "stargaze", name: T("屋顶观星夜"), chains: ["snack", "tea", "honey"], line: T("它躺在屋顶数星星，数到第三颗就睡着了，手里还攥着一把爆米花。")),
        Def(id: "rainy", name: T("下雨天煮汤"), chains: ["veg", "rice", "coffee"], line: T("外面下雨，锅里咕嘟咕嘟。它说下雨天就是用来喝汤和不出门的。")),
    ]
    /// 季节活动：这几天每天都开（盖过周末活动）。万圣节、圣诞
    static let seasons: [(def: Def, from: (m: Int, d: Int), to: (m: Int, d: Int))] = [
        (Def(id: "halloween", name: T("南瓜夜市"), chains: ["veg", "sweet", "snack"], line: T("它把南瓜扣在头上当帽子，说这叫过节，然后就在里面睡着了。")), (10, 24), (11, 2)),
        (Def(id: "xmas", name: T("圣诞热可可夜"), chains: ["milk", "sweet", "fruit"], line: T("窗外下雪了。它说热可可要配三块饼干，少一块都不叫圣诞。")), (12, 18), (12, 31)),
        (Def(id: "thanks", name: T("感恩丰收宴"), chains: ["veg", "rice", "sweet"], line: T("它说今天要感谢每一个给它做过饭的人。然后看着你，等你做饭。")), (11, 25), (11, 29)),
        (Def(id: "newyear", name: T("新年第一锅"), chains: ["rice", "egg", "tea"], line: T("新年第一顿要吃饱。它说今年的愿望是：多睡一点。和去年一样。")), (1, 1), (1, 4)),
        (Def(id: "lunar", name: T("春节团圆饭"), chains: ["rice", "veg", "honey"], line: T("它学着包饺子，包出来一个圆滚滚的，说这个像它。")), (2, 5), (2, 12)),
        (Def(id: "valentine", name: T("草莓巧克力日"), chains: ["sweet", "fruit", "milk"], line: T("它做了一块爱心巧克力，自己先咬了一口，说是检查一下够不够甜。")), (2, 13), (2, 15)),
    ]
    /// 7 档：越往后越大，最后一档送拍立得
    static let milestones: [(points: Int, item: String, gems: Int)] = [
        (8, "luckybag", 3), (20, "chest2", 5), (35, "luckybag", 5), (50, "chest3", 8), (70, "wildcard", 12), (95, "chest3", 15), (120, "chest3", 25)]
    static var goal: Int { milestones.last?.points ?? 120 }
    static func left(_ end: Date) -> String {
        let t = max(0, Int(end.timeIntervalSinceNow))
        let d = t / 86400, h = (t % 86400) / 3600, m = (t % 3600) / 60
        return d > 0 ? T("{0}天{1}时", d, h) : (h > 0 ? T("{0}时{1}分", h, m) : T("{0}分", m))
    }
    /// 活动什么时候结束（倒计时用）
    static func endDate(_ d: Date = Date()) -> Date? {
        let cal = Calendar.current
        if let se = season(d) {
            let to = se.to
            var c = cal.dateComponents([.year], from: d); c.month = to.m; c.day = to.d; c.hour = 23; c.minute = 59; c.second = 59
            return cal.date(from: c)
        }
        guard current(d) != nil else { return nil }
        let wd = cal.component(.weekday, from: d)
        let days = wd == 1 ? 0 : (8 - wd)     // 到周日
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: d.addingTimeInterval(Double(days) * 86400))
    }
    static func season(_ d: Date) -> (def: Def, from: (m: Int, d: Int), to: (m: Int, d: Int))? {
        let cal = Calendar.current
        let k = cal.component(.month, from: d) * 100 + cal.component(.day, from: d)
        return seasons.first { k >= $0.from.m * 100 + $0.from.d && k <= $0.to.m * 100 + $0.to.d }
    }
    static func current(_ d: Date = Date()) -> (def: Def, week: String)? {
        let cal = Calendar.current
        if let s = season(d) { return (s.def, s.def.id + "-\(cal.component(.year, from: d))") }
        let wd = cal.component(.weekday, from: d)           // 1 周日 … 6 周五 7 周六
        let on = wd == 7 || wd == 1 || (wd == 6 && cal.component(.hour, from: d) >= 18)
        guard on else { return nil }
        let anchor = wd == 1 ? d.addingTimeInterval(-86400) : d   // 周日算进前一周
        let w = cal.component(.weekOfYear, from: anchor), y = cal.component(.yearForWeekOfYear, from: anchor)
        return (defs[w % defs.count], "\(y)-\(w)")
    }
}
struct MKStoryShow: Equatable { let title: String; let line: String }
struct MKScene: Identifiable { let id = UUID(); let title: String; let beats: [MKStory.Beat]; var page = 0 }
struct MKRenovation: Identifiable { let id = UUID(); let area: MKStory.Area; let task: MKStory.Task; let done: [String]; let chapter: Int?
    var areaDone = false; var allDone = false; var bagUp = false }

struct MKState: Codable {
    var board: [MKSlot] = Array(repeating: MKSlot(), count: MK.cols * MK.rows)
    var energy = MK.maxEnergy
    var energyAt = Date()
    var level = 1
    var xp = 0
    var gems = 10
    var stars = 0
    var orders: [MKOrder] = []
    var cooks: [String: MKCook] = [:]
    var bag: [String] = []
    var bagSlots = 6
    var found: [String] = []
    var done: [String] = []          // 完成的装修任务
    var deals: [MKDeal] = []
    var dealsDay = ""
    var energyBuyDay: String? = nil   // 宝石买体力：今天买了几次（越买越贵）
    var energyBuys: Int? = nil
    var served = 0
    var petMeals: [String]? = nil    // 今天吃过的顿："2026-10-17|晚饭"
    var daily: MKDaily? = nil
    var sprint: MKSprint? = nil
    var sprintNext: Date? = nil
    var seasonId: Int? = nil       // 嘟嘟星季卡：第几季、分数、等级
    var seasonPts: Int? = nil
    var seasonLv: Int? = nil
    var loginDay: String? = nil
    var loginStreak: Int? = nil
    var event: MKEventState? = nil
    var introSeen: Bool? = nil
    var regulars: [String: Int]? = nil   // 熟客故事进度
    var postcards: [String]? = nil
    var focusDay: String? = nil
    var focus: [String]? = nil       // 今天热卖的几条链（订单只从这几条里出，台面才放得下）
    var tut: Int? = nil              // 新手引导第几步；99 = 学完
    var lastSeen: Date? = nil
    var stepDay: String? = nil
    var stepEnergy: Int? = nil
    var firstDay: Date? = nil        // 第一次进店的日子
    var boostUntil: Date? = nil      // 无限体力到什么时候
    var boostDay: String? = nil      // 今天送过开店无限体力没有
    var signatureDay: String? = nil  // 今日招牌菜单出过的那天
    var bigDay: String? = nil        // 大订单交掉的那天（第二天再来一张）
    var cards: [String: Int]? = nil  // 小紫拍立得：每张有几张
    var dryPacks: Int? = nil          // 连续几包没出新卡（保底用）
    var packs: Int? = nil
    var stardust: Int? = nil
    var setsClaimed: [Int]? = nil
    var luckyDay: String? = nil      // 好运时刻：一天最多一次
    var luckyUntil: Date? = nil
    var freeRefills: [String: Int]? = nil   // 新手畅玩：今天免费装满过几次产出器（一天最多 6 次）
    var ordersDeduped: Bool? = nil
    var streak: Int? = nil           // 满贯条：每交 5 单开一个福袋
    var ticketsServed: Int? = nil    // 交过几张外卖单（不算小紫的饭）：开张那几句只看这个
    var doorLit: [Int]? = nil        // 嘟嘟星亮了哪几区

    static let key = "merge.v2"
    static func load() -> MKState {
        if let d = UserDefaults.standard.data(forKey: key), var s = try? JSONDecoder().decode(MKState.self, from: d) {
            // 老存档的台面是 7 列：按行列搬到 8 列，空出来的格子补空
            let n = MK.cols * MK.rows
            if s.board.count != n {
                let oldCols = s.board.count % MK.rows == 0 ? s.board.count / MK.rows : MK.cols
                var b = Array(repeating: MKSlot(), count: n)
                for (i, slot) in s.board.enumerated() {
                    let r = i / max(1, oldCols), c = i % max(1, oldCols)
                    let k = r * MK.cols + c
                    if r < MK.rows, c < MK.cols, k < n { b[k] = slot }
                }
                s.board = b
            }
            return s
        }
        return fresh()
    }
    static func fresh() -> MKState {
        var s = MKState()
        // 上面 4 行盖着纸箱，里面藏着东西；在旁边合成才会打开
        for i in 0..<(MK.cols * 4) {
            s.board[i].boxed = true
            s.board[i].item = (["rice", "veg"].randomElement() ?? "rice") + "\(Int.random(in: 1...3))"
        }
        s.board[MK.cols * 4 + 3].item = "gift"
        s.board[MK.cols * 8 + 1] = MKSlot(item: "gen_rice", charges: MK.genCharges[1])
        s.board[MK.cols * 8 + 5] = MKSlot(item: "gen_veg", charges: MK.genCharges[1])
        let starts: [(Int, String)] = [(MK.cols * 5 + 2, "rice1"), (MK.cols * 5 + 4, "rice1"), (MK.cols * 6 + 3, "veg1"), (MK.cols * 7 + 2, "veg1"), (MK.cols * 6 + 5, "rice2")]
        for p in starts { s.board[p.0].item = p.1 }
        s.found = ["rice1", "rice2", "veg1"]
        s.tut = 0
        return s
    }
    func save() { if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) } }
}

// MARK: 逻辑
@MainActor
final class MKStore: ObservableObject {
    /// 改一下就存一次太费（一次交单要存十几次）：0.4 秒内的改动合并成一次写；离店、退后台时马上存
    @Published var s = MKState.load() { didSet { if !noSave { scheduleSave() } } }
    var noSave = false
    private var saveQueued = false
    private func scheduleSave() {
        guard !saveQueued else { return }
        saveQueued = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.saveQueued else { return }
            self.saveQueued = false
            self.s.save()
        }
    }
    func flushSave() { guard !noSave else { return }; saveQueued = false; s.save() }
    @Published var toast: String? = nil
    @Published var recipeShow: String? = nil   // 点订单里的菜：弹配方卡
    @Published var pulse: Int? = nil
    @Published var levelUp: Int? = nil
    @Published var storyLine: MKStoryShow? = nil
    @Published var renovated: MKRenovation? = nil
    @Published var goldCard: MKCard? = nil
    @Published var setComplete: MKCards.CardSet? = nil
    var lucky: Bool { (s.luckyUntil ?? .distantPast) > Date() }
    @Published var selected: Int? = nil
    @Published var lastSold: MKSold? = nil
    @Published var newFind: String? = nil
    @Published var loginGift: (day: Int, text: String)? = nil
    @Published var intro = false
    @Published var introPage = 0
    /// 装修完一章（第几章）：主 App 收一封嘟嘟星来信
    var onChapter: ((Int) -> Void)? = nil
    /// 门单做完（嘟嘟星第几区亮了）：主 App 灵动岛闪一下
    var onDoor: ((Int) -> Void)? = nil
    /// 章末小戏 / 第一张门单那一晚
    @Published var scene: MKScene? = nil
    /// 台子塞满了：信息栏换成「一键收纳 / 背包」
    @Published var boardFull = false
    @Published var welcome: String? = nil
    @Published var fx: [MKFX] = []
    @Published var floaters: [MKFloat] = []
    @Published var shake = 0
    var idleSeconds: TimeInterval { Date().timeIntervalSince(lastAction) }
    @Published var petSay: MKSay? = nil
    @Published var petHappyUntil: Date? = nil
    @Published var wowUntil: Date? = nil
    @Published var reveal: MKStory.Mystery? = nil
    @Published var postcard: MKStory.Regular? = nil
    @Published var cashUntil: Date? = nil
    private var lastPlaced: Int? = nil
    private var mergeTimes: [Date] = []
    private var lastAction = Date()
    private var idleSpoke = false
    private var dedupeTries = 0
    /// 赚到 / 退回的币，由界面每秒交给 ProfileStore
    @Published var coinsEarned = 0
    /// 白送的配饰（季卡满级等），界面每秒交给 ProfileStore
    @Published var accEarned: [String] = []
    /// 体力用完了：弹一张小卡告诉玩家能干嘛（10 分钟内最多弹一次）
    @Published var outOfEnergy = false
    var outOfEnergyAt = Date.distantPast
    /// 亲密度带来的爆率加成（0–0.25）：主 App 里伺候得越好越高。每秒随 tick 刷新
    /// 自测时用 -selfTestLuck 0.1 这样的参数固定
    @Published var luck: Double = MKStore.readLuck()
    static func readLuck() -> Double {
        if MKDemo.on { return MKDemo.args.firstIndex(of: "-selfTestLuck").flatMap { Double(MKDemo.args[safe: $0 + 1] ?? "") } ?? 0 }
        return Intimacy.currentBonus
    }

    var unlocked: [MK.Chain] { MK.chains.filter { $0.unlock <= s.level } }

    init() {
        if MKDemo.on { s = MKDemo.fresh ? MKState.fresh() : (MKDemo.late ? MKState.late() : MKState.demo()) }
        refillEnergy()
        refreshDeals()
        if s.ticketsServed == nil { s.ticketsServed = s.served }
        // 2026-10-27 纪念款上线前已经装修完的地方：补发（ProfileStore.grant 会跳过已有的）
        if !MKDemo.on {
            for a in MKStory.areas where a.chapters.flatMap({ $0.tasks.map(\.id) }).allSatisfy({ s.done.contains($0) }) {
                if let k = NestItem.awardKey(for: a.key) { accEarned.append(k) }
            }
            if MKStory.all.allSatisfy({ s.done.contains($0.id) }), let k = NestItem.awardKey(for: "all") { accEarned.append(k) }
        }
        // 老存档台面上攒着的体力瓶：一次收掉，加到体力上，腾出格子
        if !MKDemo.on {
            let n = s.board.indices.filter { s.board[$0].item == "energy" && !s.board[$0].boxed }
            for k in n { s.board[k] = MKSlot() }
            if !n.isEmpty { s.energy += 20 * n.count }
        }
        // 第一张单：楼上那一份饭团（开场纸条说的那一单）
        if s.served == 0 && s.orders.isEmpty && !MKDemo.on {
            s.orders.append(MKOrder(items: ["rice2"], stars: 1, meal: T("📮 楼上"), made: Date()))
        }
        while s.orders.filter({ !$0.isPet && !$0.isEvent && !$0.isSpecial }).count < 4 { s.orders.append(newOrder()) }
        // 老存档里一排同样的单（全要胡萝卜）：同一条链超过 2 张的，多出来的换掉
        if !MKDemo.on, s.ordersDeduped != true {
            s.ordersDeduped = true
            var seenChain: [String: Int] = [:]
            for k in s.orders.indices where !s.orders[k].isPet && !s.orders[k].isEvent && !s.orders[k].isSpecial && !s.orders[k].isRush && s.orders[k].regular == nil {
                guard let key = s.orders[k].items.first.flatMap({ MK.chain($0)?.key }) else { continue }
                seenChain[key, default: 0] += 1
                if seenChain[key]! > 2 { s.orders[k] = newOrder(band: nextBand(except: s.orders[k].id)) }
            }
        }
        refreshPetOrder()
        refreshDaily()
        refreshEvent()
        if s.introSeen != true && !MKDemo.on { intro = true; s.introSeen = true }
        if !MKDemo.on || MKDemo.fresh { ensureCardsStarted() }
        if s.introSeen == true && !MKDemo.on { UserDefaults.standard.set(true, forKey: "merge.opened") }
        if s.firstDay == nil && (!MKDemo.on || MKDemo.fresh) {
            // 老存档（已经玩过不少的）不给新手畅玩
            s.firstDay = s.served > 30 ? Date().addingTimeInterval(-4 * 86400) : Date()
        }
        dailyBoost(first: s.served == 0)
        if Shot.on, let k = Shot.scene { debugScene(k) }
    }

    // 体力
    func refillEnergy() {
        guard s.energy < MK.maxEnergy else { return }
        let n = Int(Date().timeIntervalSince(s.energyAt) / MK.regenSeconds)
        guard n > 0 else { return }
        s.energy = min(MK.maxEnergy, s.energy + n)
        s.energyAt = s.energy >= MK.maxEnergy ? Date() : s.energyAt.addingTimeInterval(Double(n) * MK.regenSeconds)
    }
    /// 无限体力（2026-10-19 取代「新手 3 天无限」）：限时奖励，点产出器不花体力、空了马上装满
    var boosting: Bool { (s.boostUntil ?? .distantPast) > Date() }
    var boostLeft: TimeInterval { max(0, (s.boostUntil ?? Date()).timeIntervalSinceNow) }
    func grantBoost(_ minutes: Double, _ why: String) {
        s.boostUntil = max(s.boostUntil ?? Date(), Date()).addingTimeInterval(minutes * 60)
        say(T("⚡ {0}：无限体力 {1} 分钟", why, Int(minutes)))
    }
    /// 每天第一次开店送 15 分钟（第一次玩送 30 分钟）
    func dailyBoost(first: Bool) {
        guard !MKDemo.on else { return }
        let today = Wallet.day()
        guard s.boostDay != today else { return }
        s.boostDay = today
        // 2026-10-21：60/30 分钟太多（6 级时体力根本用不完，体力瓶全攒着）→ 第一次 30、每天 15
        grantBoost(first ? 30 : 15, first ? T("开张礼") : T("今天第一次开店"))
    }
    var nextEnergyIn: Int { s.energy >= MK.maxEnergy ? 0 : max(0, Int(MK.regenSeconds - Date().timeIntervalSince(s.energyAt))) }

    /// 每秒：体力、产出器冷却完成、泡泡过期
    func tick() {
        refreshSprint()
        if Int(Date().timeIntervalSince1970) % 10 == 0 { let l = Self.readLuck(); if l != luck { luck = l } }
        if s.focusDay != Wallet.day() { refreshFocus() }
        if !idleSpoke, Date().timeIntervalSince(lastAction) > 10, intro == false, !MKDemo.on, !Shot.on, scene == nil, storyLine == nil, reveal == nil, levelUp == nil, renovated == nil, postcard == nil, goldCard == nil, welcome == nil, tutStep >= 99 {
            idleSpoke = true
            let h = nextStep()
            say("👉 " + h)
            react([h])
        }
        refillEnergy()
        if !MKDemo.on, (s.lastSeen.map { Date().timeIntervalSince($0) > 60 } ?? true) {
            s.lastSeen = Date()
        }
        refreshPetOrder()
        refreshEvent()
        refreshSignature()
        refreshBig()
        refreshDoor()
        if s.boostDay != Wallet.day() { dailyBoost(first: false) }
        let now = Date()
        if let k = s.orders.firstIndex(where: { ($0.rushUntil ?? .distantFuture) < now }) {
            s.orders[k] = newOrder(band: nextBand(except: s.orders[k].id))
            say(T("⏱ 急单那家等不及，先走了。不要紧，下一单。"))
        }
        for i in s.board.indices {
            if let r = s.board[i].refillAt, now >= r, MK.isGen(s.board[i].item ?? "") {
                s.board[i].charges = MK.genCharges[s.board[i].glv]
                s.board[i].refillAt = nil
            }
            if let b = s.board[i].bubbleUntil, now >= b {
                s.board[i] = MKSlot(item: "coins")
            }
        }
    }

    // 订单
    /// 外卖单永远是「1 张易 + 2 张中 + 1 张难」（Travel Town 的做法）：打开总有一张能马上交，也总有一张值得追
    static let bandPlan = [0, 1, 1, 2]
    func bandOf(_ o: MKOrder) -> Int {
        if let b = o.band { return b }
        let top = MK.orderTop(s.level)
        let mx = o.items.map { MK.chain($0) != nil ? MK.tier($0) : top }.max() ?? 0
        return o.items.count >= 2 || mx >= top ? 2 : (mx <= top - 2 ? 0 : 1)
    }
    /// 现在四张里缺哪一档（except：要被换掉的那张不算）
    func nextBand(except: UUID? = nil) -> Int {
        var need = Self.bandPlan
        for o in s.orders where !o.isPet && !o.isEvent && !o.isSpecial && o.id != except {
            if let k = need.firstIndex(of: bandOf(o)) { need.remove(at: k) }
        }
        let b = need.first ?? 1
        // 简单单交掉以后隔 20 分钟才再来一张（不然一直刷简单的，难单永远没人管）
        if b == 0 && Date() < easyAt { return need.first { $0 != 0 } ?? 1 }
        return b
    }
    private var easyAt = Date.distantPast
    /// 离开 2 小时以上回来：保证一打开就有一张能马上交的。难单留着当长期目标，换掉的是一张中单
    func easeOnReturn() {
        easyAt = .distantPast
        let normal = s.orders.filter { !$0.isPet && !$0.isEvent && !$0.isSpecial }
        guard !normal.contains(where: { bandOf($0) == 0 }), !normal.contains(where: canServe) else { return }
        guard let k = s.orders.indices.first(where: { k in
            let o = s.orders[k]
            return !o.isPet && !o.isEvent && !o.isSpecial && !o.isRush && o.regular == nil && bandOf(o) == 1
        }) else { return }
        s.orders[k] = newOrder(band: 0)
        react([T("回来了？先接张简单的，我也刚醒。"), T("先来张简单的，热热手。")])
    }

    func newOrder(band want: Int? = nil) -> MKOrder {
        refreshFocus()
        let cs = focus
        // 新手：引导没走完、或者前 6 单，只要 2–3 级（先学会「两个一样的合成一个」）
        let gentle = tutStep < 99 || (s.ticketsServed ?? 0) < 6
        let band = gentle ? 0 : (want ?? nextBand())
        let top = gentle ? 3 : MK.orderTop(s.level)
        let r = Int.random(in: 0..<10)
        // 易：一样、低两三级；中：一两样、和以前一样，偶尔一道普通菜；难：两三样到顶级，常要一道菜（12 级后多是三样料或半成品的菜）
        // 按 sim/kitchen_sim.py 跑过：和原来比，第 8 章、第 12 章到达天数基本不变（约第 24 / 54 天），难单大约一天交一张
        let n: Int, lo: Int, hi: Int, dishOdds: Int
        switch band {
        case 0: n = 1; lo = max(2, top - 3); hi = max(2, top - 2); dishOdds = 0
        case 2: n = s.level < 2 ? 1 : (s.level >= 12 && r < 4 ? 3 : 2); lo = max(2, top - 1); hi = top; dishOdds = 2
        default: n = s.level < 4 ? 1 : (r < 6 ? 1 : 2); lo = max(2, top - 2); hi = top; dishOdds = 3
        }
        var items: [String] = []
        // 菜：今天热卖链能做的菜，再加上别的已解锁链能做的菜（只用热卖链时常常只有一两道可选，做菜的单只占 8%）
        let all = focusDishes() + otherDishes()
        let deep = all.filter(MK.isDeep), plain = all.filter { !MK.isDeep($0) }
        let dishes = band == 2 ? (deep.isEmpty ? plain : deep) : plain
        for _ in 0..<(gentle ? 1 : n) {
            // 同时要菜的外卖单：8 级前 1 张（只有一两台厨具），8 级起 2 张（自测：做菜只占 15% 的单，主题是开店做饭，提到 30% 左右）
            let dishOrders = s.orders.filter { !$0.isPet && !$0.isSignature && $0.items.contains { MK.recipe($0) != nil } }.count
            let dishBusy = dishOrders >= (s.level >= 8 ? 2 : 1) || items.contains { MK.recipe($0) != nil }
            // 没做过的菜优先上单（自测发现 44 道菜一半从来没人点过：总在那几道里打转）
            let fresh = dishes.filter { !s.found.contains($0.id) }
            let pickDish = (!fresh.isEmpty && Int.random(in: 0..<3) < 2) ? fresh.randomElement() : dishes.randomElement()
            if !gentle, dishOdds > 0, !dishBusy, let d = pickDish, Int.random(in: 0..<dishOdds) == 0 {
                items.append(d.id)
            } else if let c = { () -> MK.Chain? in
                // 哪条链现在单子最少就从哪条出：不会四张全要胡萝卜
                let used = s.orders.flatMap(\.items).compactMap { MK.chain($0)?.key } + items.compactMap { MK.chain($0)?.key }
                let cnt = { (k: String) in used.filter { $0 == k }.count }
                let m = cs.map { cnt($0.key) }.min() ?? 0
                return cs.filter { cnt($0.key) == m }.randomElement()
            }() {
                items.append(c.key + "\(Int.random(in: lo...max(lo, hi)))")
            }
        }
        if items.isEmpty { items = ["rice2"] }
        // 别一下来好几张一模一样的单：重了就再抽一次（最多 6 次）
        if s.orders.contains(where: { $0.items.sorted() == items.sorted() }), dedupeTries < 6 {
            dedupeTries += 1
            defer { dedupeTries = 0 }
            return newOrder(band: band)
        }
        let v = items.map(MK.value).reduce(0, +)
        let special = s.level >= 4 && Int.random(in: 0..<8) == 0
        let to = [T("3 号楼"), T("蘑菇小区"), T("星星路 12 号"), T("河边公寓"), T("学校门口"), T("图书馆"), T("东门"), T("花店楼上"), T("公园长椅"), T("灯塔")]
        // 熟客：有自己的小故事，一家一家来
        let present = Set(s.orders.compactMap(\.regular))
        if s.level >= 3, Int.random(in: 0..<10) < 3,
           let rg = MKStory.regulars.filter({ (s.regulars?[$0.key] ?? 0) < $0.notes.count && !present.contains($0.key) }).randomElement() {
            return MKOrder(items: items, stars: MK.orderStars(v) + 1, gems: 1, meal: rg.icon + " " + rg.place, made: Date(), regular: rg.key, band: band)
        }
        // 急单：5 分钟内交星星翻倍 + 宝石；没赶上它就自己走了，不扣任何东西。难单不做急单（5 分钟做不完）
        if s.level >= 2, !gentle, band < 2, Int.random(in: 0..<6) == 0, !s.orders.contains(where: { $0.isRush }) {
            return MKOrder(items: items, stars: MK.orderStars(v) * 2 + 1, gems: 1, meal: T("⏱ 急单 · ") + (to.randomElement() ?? T("3 号楼")), made: Date(), rushUntil: Date().addingTimeInterval(5 * 60), band: band)
        }
        return MKOrder(items: items, stars: MK.orderStars(v), gems: special ? 2 + v / 20 : (band == 2 ? 1 : 0), meal: T("外卖 · ") + (to.randomElement() ?? T("3 号楼")), made: Date(), band: band)
    }

    /// 好运时刻：每天第一次进店（8–22 点）有一半机会，15 分钟内交单星星翻倍
    func maybeLucky() {
        guard !MKDemo.on else { return }
        let today = Wallet.day()
        let h = Calendar.current.component(.hour, from: Date())
        guard s.luckyDay != today, (8..<22).contains(h) else { return }
        s.luckyDay = today
        guard Bool.random() else { return }
        s.luckyUntil = Date().addingTimeInterval(15 * 60)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.say(T("✨ {0}今天心情好：15 分钟内交单，星星翻倍。", Voice.petName))
            self.react([T("今天运气好，我感觉到了。"), T("快，趁我心情好。")], happy: true)
        }
    }

    /// 门单：开张以后，每章一张从灵动岛门缝掉进来；做完点亮嘟嘟星一个区。不催、不过期、不能换
    func refreshDoor() {
        guard !MKDemo.on, s.tut == nil || s.tut == 99, (s.ticketsServed ?? 0) >= 3,
              !s.orders.contains(where: { $0.isDoor }) else { return }
        let chaptersDone = MKStory.chapters.filter { $0.tasks.allSatisfy { s.done.contains($0.id) } }.count
        let lit = Set(s.doorLit ?? [])
        guard let r = (1...MKStory.doors.count).first(where: { !lit.contains($0) }), r <= chaptersDone + 1 else { return }
        refreshFocus()
        let item: String
        if r == 1 { item = "rice3" }
        else if let d = showcaseDishes().randomElement() ?? MK.recipes.filter({ MK.can($0, s.level) }).randomElement() { item = d.id }
        else { item = (focus.first?.key ?? "rice") + "\(max(2, MK.orderTop(s.level) - 1))" }
        let v = MK.value(item)
        s.orders.insert(MKOrder(items: [item], stars: MK.orderStars(v) + 3, gems: 3, meal: "🌙 " + MKStory.doors[r - 1].name, made: Date(), door: r), at: 0)
        if r == 1, scene == nil, let b = MKStory.scenes[0] { scene = MKScene(title: T("门缝里的小票"), beats: b) }
        else { say(T("🌙 灵动岛的门缝里，掉进来一张小票：嘟嘟星 · ") + MKStory.doors[r - 1].name) }
    }

    /// 今日招牌菜：每天一单，要一道用厨具做的菜；奖励 = 星星 +3、宝石 3、双倍币。不做也不罚，第二天换一道
    /// 大订单（同类游戏的做法：高级货的去处是大单）：9 级开放，一次一张、交掉后第二天再来；
    /// 要的级别跟着等级涨（9 级要 8 级货，24 级以后要 12 级），奖励按级别给：大把星星、宝石、拍立得，10 级以上再送大宝箱。不过期、不换
    static func bigTier(_ level: Int) -> Int { min(11, 8 + max(0, level - 9) / 4) }   // 12 级（嘟嘟星金苹果之类）是传说收藏，不进订单
    func refreshBig() {
        guard s.level >= 9, tutStep >= 99, !s.orders.contains(where: { $0.isBig }), s.bigDay != Wallet.day() else { return }
        guard let c = unlocked.randomElement() else { return }
        let t = Self.bigTier(s.level)
        let who = [T("嘟嘟星大使"), T("城里的大饭店"), T("婚礼派对"), T("学校运动会"), T("灯塔看守人的生日"), T("市长的野餐")].randomElement() ?? T("大客户")
        s.orders.insert(MKOrder(items: [c.key + "\(t)"], stars: 10 + (t - 7) * 6, gems: 5 + (t - 7) * 3, meal: "🏆 " + who, made: Date(), big: true), at: 0)
        say(T("🏆 来了一张大订单：{0}。不着急，慢慢合。", MK.name(c.key + "\(t)")))
    }
    func refreshSignature() {
        let today = Wallet.day()
        if let k = s.orders.firstIndex(where: { $0.isSignature }), s.signatureDay != today { s.orders.remove(at: k) }
        guard s.signatureDay != today, !s.orders.contains(where: { $0.isSignature }), s.tut == nil || s.tut == 99 else { return }
        refreshFocus()
        guard let d = showcaseDishes().randomElement() ?? MK.recipes.filter({ MK.can($0, s.level) }).randomElement() else { return }
        let v = MK.value(d.id)
        s.orders.insert(MKOrder(items: [d.id], stars: MK.orderStars(v) + 3, gems: 3, meal: T("今日招牌 · ") + d.name, made: Date(), signature: true), at: 0)
        s.signatureDay = today
    }

    // 小紫自己的饭：只在饭点下单，一顿一单，吃过就不再要；过了饭点没做也不罚
    static func mealNow(_ d: Date = Date()) -> String? {
        switch Calendar.current.component(.hour, from: d) {
        case 7..<10: return T("早饭")
        case 11..<14: return T("午饭")
        case 15..<17: return T("下午茶")
        case 17..<20: return T("晚饭")
        case 21..<24: return T("夜宵")
        default: return nil
        }
    }
    func refreshPetOrder() {
        if MKDemo.on { return }
        guard tutStep >= 99 else { return }   // 新手引导时先不插它的饭，免得小手指错单
        let meal = Self.mealNow()
        if let k = s.orders.firstIndex(where: { $0.isPet }), s.orders[k].meal != meal { s.orders.remove(at: k) }
        guard let meal, !s.orders.contains(where: { $0.isPet }) else { return }
        let key = Wallet.day() + "|" + meal
        guard !(s.petMeals ?? []).contains(key) else { return }
        // 它挑：一样它爱吃的，等级比外卖高一点；饭点偶尔点一道菜
        let top = min(7, MK.orderTop(s.level) + 1)
        var items: [String] = []
        let dishes = focusDishes().filter { !MK.isDeep($0) }   // 它自己的饭不点深菜（饭点就两三个小时）
        if meal != T("下午茶"), let d = dishes.randomElement() { items.append(d.id) }   // 正餐一定是一道做出来的菜
        else if let c = (meal == T("下午茶") ? focus.filter { ["tea", "sweet", "fruit", "milk"].contains($0.key) } : focus).randomElement() ?? focus.first {
            items.append(c.key + "\(Int.random(in: max(2, top - 2)...top))")
        }
        if items.isEmpty { items = ["rice3"] }
        s.orders.insert(MKOrder(items: items, stars: 3, gems: 1, meal: meal, pet: true), at: 0)
    }

    /// 今天热卖：最多 3 条链（解锁少时全部），每天换
    var focus: [MK.Chain] {
        let f = unlocked.filter { (s.focus ?? []).contains($0.key) }
        return f.isEmpty ? unlocked : f
    }
    /// 每天换一次热卖；解锁了新链也重新挑（只在逻辑里调用，不在界面刷新时改状态）
    func refreshFocus() {
        let day = Wallet.day()
        let keys = s.focus ?? []
        if s.focusDay != day || keys.count < min(3, unlocked.count) || !keys.allSatisfy({ k in unlocked.contains { $0.key == k } }) {
            s.focusDay = day
            // 挑一道能做的菜，它的两条链一定在热卖里，再随机补一条
            var pick: [String] = []
            let keys = Set(unlocked.map(\.key))
            let can = MK.recipes.filter({ r in MK.can(r, s.level) && MK.baseChains(r).isSubset(of: keys) })
            let fresh = can.filter { !s.found.contains($0.id) }
            if let r = (fresh.isEmpty ? can : fresh).randomElement() {
                pick = Array(MK.baseChains(r)).shuffled()
            }
            // 本周主题链至少有一条在热卖里
            if let tk = MKWeek.current.chains.filter({ k in unlocked.contains { $0.key == k } && !pick.contains(k) }).randomElement(),
               !pick.contains(where: { MKWeek.current.chains.contains($0) }) { pick.append(tk) }
            for k in unlocked.map(\.key).shuffled() where pick.count < 3 && !pick.contains(k) { pick.append(k) }
            s.focus = pick
        }
    }
    /// 招牌和门单：12 级以后优先出深菜（三样料、半成品），后期的大菜主要在这里出现
    private func showcaseDishes() -> [MK.Recipe] {
        let fd = focusDishes()
        let deep = fd.filter(MK.isDeep)
        if s.level >= 12, !deep.isEmpty { return deep }
        if s.level >= 12, let any = MK.recipes.filter({ MK.can($0, s.level) && MK.isDeep($0) }).randomElement() { return [any] }
        return fd
    }
    private func otherDishes() -> [MK.Recipe] {
        let keys = Set(unlocked.map(\.key)), fd = Set(focusDishes().map(\.id))
        return MK.recipes.filter { r in !fd.contains(r.id) && MK.can(r, s.level) && MK.baseChains(r).isSubset(of: keys) }
    }
    private func focusDishes() -> [MK.Recipe] {
        let keys = Set(focus.map(\.key))
        return MK.recipes.filter { r in MK.can(r, s.level) && MK.baseChains(r).isSubset(of: keys) }
    }

    /// 外卖单太难：换一单。来了 2 小时以上免费，不然 1 宝石
    func swapCost(_ o: MKOrder) -> Int { (o.made.map { Date().timeIntervalSince($0) > 7200 } ?? true) ? 0 : 1 }
    func swap(_ o: MKOrder) {
        guard !o.isPet, !o.isEvent, !o.isSpecial, let k = s.orders.firstIndex(where: { $0.id == o.id }) else { return }
        let c = swapCost(o)
        guard s.gems >= c else { say(T("宝石不够。")); return }
        s.gems -= c
        s.orders[k] = newOrder(band: nextBand(except: o.id))
        react([T("那家不要了？行，换一家。"), T("这单太难，我替你推了。")])
    }

    private func usable(_ k: Int) -> Bool { k != opening && !s.board[k].boxed && s.board[k].bubbleUntil == nil }

    func canServe(_ o: MKOrder) -> Bool {
        var b = s.board
        for it in o.items {
            guard let k = b.indices.first(where: { b[$0].item == it && !b[$0].boxed && b[$0].bubbleUntil == nil }) else { return false }
            b[k].item = nil
        }
        return true
    }

    func serve(_ o: MKOrder) -> (coins: Int, food: String, pet: Bool)? {
        guard canServe(o) else { return nil }
        let oi = s.orders.firstIndex { $0.id == o.id } ?? 0
        for it in o.items {
            if let k = s.board.indices.first(where: { s.board[$0].item == it && usable($0) }) {
                emit(MKFX(kind: .serve, from: k, to: oi, item: it))
                s.board[k] = MKSlot()
            }
        }
        if tutStep == 2 { s.tut = 3 }
        touch()
        MKSfx.play("coin")
        let v = o.items.map(MK.value).reduce(0, +)
        s.orders.removeAll { $0.id == o.id }
        if !o.isPet, !o.isEvent, !o.isSpecial, bandOf(o) == 0, (s.ticketsServed ?? 0) >= 6 { easyAt = Date().addingTimeInterval(20 * 60) }
        if o.isPet {
            s.petMeals = Array(((s.petMeals ?? []) + [Wallet.day() + "|" + o.meal]).suffix(20))
            track("pet")
        } else if o.isEvent {
            addEventPoints(o.stars * 2)
            refreshEvent()
        } else {
            if let r = MKStory.regular(o.regular) {
                let k = s.regulars?[r.key] ?? 0
                var reg = s.regulars ?? [:]; reg[r.key] = k + 1; s.regulars = reg
                if k < r.notes.count { say(r.icon + " " + r.place + T("：") + r.notes[k]) }
                if k < r.reply.count { react([r.reply[k]]) }
                if k + 1 >= r.notes.count {
                    s.gems += 10
                    s.postcards = (s.postcards ?? []) + [r.key]
                    postcard = r
                }
            }
            if let d = o.door {
                // 门单：嘟嘟星亮一个区
                s.doorLit = Array(Set((s.doorLit ?? []) + [d])).sorted()
                give("energy")   // 门那边回礼：一瓶体力
                wowUntil = Date().addingTimeInterval(4)
                flushSave()
                onDoor?(d)
            } else if !o.isSignature && !o.isBig { s.orders.append(newOrder()) } else { wowUntil = Date().addingTimeInterval(4) }
            track("ticket")
        }
        s.served += 1
        if !o.isPet { MKGameCenter.shared.addOrder() }
        if !o.isPet { addSeason(o.isBig ? 5 : 1) }
        if !o.isPet && !o.isEvent && !o.isSpecial {
            s.ticketsServed = (s.ticketsServed ?? 0) + 1
            // 满贯条：每 5 单开一个福袋，每 4 个满贯（20 单）再加一个宝箱
            let k = (s.streak ?? 0) + 1
            s.streak = k
            if k % 5 == 0 {
                let bag = k % 20 == 0 ? "chest2" : "luckybag"
                if place(bag, near: MK.cols * 4 + 3), let e = lastPlaced { emit(MKFX(kind: .burst, from: e, to: nil, item: nil, tier: 8)) }
                else { s.bag.append(bag) }
                MKSfx.play("discover")
                say(k % 20 == 0 ? T("🎉 满贯 ×4！送一个宝箱。") : T("🎁 满 5 单！送一个惊喜福袋。"))
            }
        }
        s.stars += o.stars * (lucky ? 2 : 1)
        // 每周主题：用到主题链的单多给 1★
        if !o.isPet, !o.isEvent, MKWeek.matches(o.items) {
            s.stars += 1
            if Int.random(in: 0..<4) == 0 { say(MKWeek.current.icon + " " + T("{0}加成 +1★", MKWeek.current.name)) }
        }
        var tip = 0
        if o.isPet && !MKDemo.on { Intimacy.update { $0.shopMeal() } }
        if o.isSignature { givePacks(1, T("今日招牌卖出去了")) }
        if o.isBig {
            s.bigDay = Wallet.day()
            givePacks(1, T("大订单交掉了"))
            if o.items.contains(where: { MK.tier($0) >= 10 }) { give("chest3") }
            MKSfx.play("renovate"); shake += 1
            wowUntil = Date().addingTimeInterval(4)
            react([T("这么大一单……我们做到了？"), T("今天可以早点躺了。")], happy: true)
        }
        else if !o.isPet && !o.isEvent {
            // 一局里的小好运：偶尔多给小费、偶尔门缝里塞进来一包拍立得
            // 1/20 → 1/60（自测：16 天开了 100 包、第 10 天卡就集得差不多）
            if Int.random(in: 0..<60) == 0 { givePacks(1, T("门缝里塞进来一包，不知道谁放的")) }
            else if Int.random(in: 0..<9) == 0 { tip = MK.orderCoins(v) + 2; say(T("💰 小费 +{0}：客人说是给躺着的店员的。", tip)) }
        }
        earnGems(o.gems)
        gainXP(max(1, v / 3))
        haptic(.heavy)
        let main = o.items.max { MK.value($0) < MK.value($1) } ?? o.items[0]
        let food = MK.chain(main)?.food ?? MK.recipe(main)?.food ?? "riceball"
        selected = nil
        // 2026-10-21：20 级以后交单拿的币少两成（前期钱紧不动，后期币太多）
        let late = s.level >= 20 ? 0.8 : 1.0
        return (Int((Double(MK.orderCoins(v) * (o.isPet || o.isSpecial ? 2 : 1)) * late).rounded()) + tip, food, o.isPet)
    }

    // 空格
    private func empty(near i: Int) -> Int? {
        let r0 = i / MK.cols, c0 = i % MK.cols
        func dist(_ k: Int) -> Int { abs(k / MK.cols - r0) + abs(k % MK.cols - c0) }
        return s.board.indices.filter { s.board[$0].item == nil && !s.board[$0].boxed }.min { dist($0) < dist($1) }
    }
    @discardableResult
    private func place(_ id: String, near i: Int) -> Bool {
        // 体力瓶不占台面：掉出来直接加到体力上（6 级时台面上一堆瓶子用不上）
        if id == "energy" {
            s.energy += 20
            lastPlaced = s.board.indices.contains(i) ? i : nil
            say(T("⚡ 体力 +20"))
            return true
        }
        guard let e = empty(near: i) else { boardFull = true; say(T("台子满了。用不上的可以一键收进背包。")); return false }
        s.board[e] = MKSlot(item: id)
        if MK.isGen(id) { s.board[e].charges = MK.genCharges[1] }
        discover(id)
        lastPlaced = e
        return true
    }
    private func discover(_ id: String) {
        guard MK.chain(id) != nil || MK.recipe(id) != nil, !s.found.contains(id) else { return }
        s.found.append(id)
        let t = MK.tier(id)
        if let r = MK.recipe(id) {
            // 第一次做出这道菜：它先尝一口
            earnGems(3); newFind = id
            wowUntil = Date().addingTimeInterval(4.5)
            react([T("新菜！我先尝一口……"), T("{0}？……可以开店了。", r.name), T("这个，明天还要。")], happy: true)
        } else if t >= 3 { earnGems(t >= 8 ? 5 : 1); newFind = id }
    }

    // 点
    func tap(_ i: Int) {
        let slot = s.board[i]
        guard !slot.boxed else { say(T("纸箱。在旁边合成一次，它就打开了。")); return }
        guard let id = slot.item else { selected = nil; return }
        if slot.bubbleUntil != nil { selected = i; return }
        let wasSelected = selected == i
        selected = i
        if MK.isGen(id) { useGen(i); return }
        if let c = MK.chests[id] { if wasSelected || id == "gift" { useChest(i, c) }; return }
        switch id {
        case "luckybag": openLuckyBag(i); selected = nil
        case "energy": s.board[i] = MKSlot(); s.energy += 20; haptic(.medium); say(T("体力 +20")); selected = nil
        case "gem": s.board[i] = MKSlot(); s.gems += 1; haptic(.medium); say(T("宝石 +1")); selected = nil
        case "star": s.board[i] = MKSlot(); s.stars += 1; haptic(.medium); say(T("星星 +1")); selected = nil
        case "coins": s.board[i] = MKSlot(); coinsEarned += 5; haptic(.medium); say(T("币 +5")); selected = nil
        default:
            if MK.isAppliance(id) { useAppliance(i) }
        }
    }

    /// ⚡×2：点一下花 2 体力（和 2 次产出器次数），掉的东西高一级。5 级开放
    @Published var double = UserDefaults.standard.bool(forKey: "mk.x2") { didSet { UserDefaults.standard.set(double, forKey: "mk.x2") } }
    static let doubleLevel = 5
    func toggleDouble() {
        guard s.level >= Self.doubleLevel else { say(T("{0} 级开放 ⚡×2。", Self.doubleLevel)); return }
        double.toggle()
        haptic(.medium)
        MKSfx.play(double ? "merge_big" : "tap", volume: 0.5)
        say(double ? T("⚡×2 开了：点一下花 2 体力，掉的东西高一级。") : T("⚡×2 关了。"))
        if double { react([T("加倍？……行，我也加倍躺。"), T("火力全开。我在旁边鼓掌。")], happy: true) }
    }
    /// 惊喜福袋：点开随机给一样
    private func openLuckyBag(_ i: Int) {
        s.board[i] = MKSlot()
        let r = Int.random(in: 0..<100)
        let top = MK.orderTop(s.level)
        let pool = focus.isEmpty ? unlocked : focus
        let got: String
        if r < 50, let c = pool.randomElement() { got = c.key + "\(Int.random(in: max(2, top - 2)...max(2, top - 1)))" }
        else if r < 62, let c = pool.randomElement() { got = c.key + "\(min(MK.maxTier, top + 1))" }   // 大奖：比订单要的还高一级
        else if r < 75 { got = "energy" }
        else if r < 85 { got = "chest2" }
        else if r < 93 { got = "wildcard" }
        else { got = "gem" }
        s.board[i] = MKSlot(item: got)
        if got == "energy" { s.board[i] = MKSlot(); s.energy += 20 }
        discover(got)
        let big = r >= 50 && r < 62
        emit(MKFX(kind: .burst, from: i, to: nil, item: got, tier: big ? 8 : 6))
        MKSfx.play(big ? "discover" : "merge_big")
        haptic(.heavy)
        pulse = i
        say(T("🎁 福袋里是：{0}", MK.name(got)) + (big ? T("！大的！") : ""))
        if big { shake += 1; react([T("这个……我能先摸一下吗。"), T("好家伙，手气不错。")], happy: true) }
    }

    private func useGen(_ i: Int) {
        guard let id = s.board[i].item, let c = MK.chains.first(where: { $0.gen == id }) else { return }
        refillEnergy()
        if s.board[i].charges <= 0, boosting {
            // 新手畅玩：产出器空了马上装满，不让人卡在等待上
            s.board[i].charges = MK.genCharges[s.board[i].glv]
            s.board[i].refillAt = nil
            say(T("⚡ 无限体力中：{0}马上装满了。", c.genName))
        }
        if s.board[i].charges <= 0 {
            let left = Int((s.board[i].refillAt ?? Date()).timeIntervalSinceNow / 60) + 1
            deny(i, T("{0}空了，{1} 分钟后装满。", c.genName, left))
            react([T("{0}空了，跟我一样，歇会儿。", c.genName), T("它也累了，让它躺会儿。")])
            return
        }
        let free = boosting
        // ⚡×2：要 2 体力、产出器还剩 2 次；不够就按普通的来
        let dbl = double && s.level >= Self.doubleLevel && s.board[i].charges >= 2 && (free || s.energy >= 2)
        guard free || s.energy > 0 else {
            deny(i, T("体力没了。出去走走吧，我替你数步数：每 1000 步 +10。"))
            if !noSave, Date().timeIntervalSince(outOfEnergyAt) > 600 { outOfEnergyAt = Date(); outOfEnergy = true }
            react([T("体力没了？出去走走，我替你数步数。"), T("那我们一起躺会儿。合成和交单不花体力，接着来。")])
            return
        }
        guard empty(near: i) != nil else { boardFull = true; say(T("台子满了。用不上的可以一键收进背包。")); return }
        if !free {
            if s.energy == MK.maxEnergy { s.energyAt = Date() }
            s.energy -= dbl ? 2 : 1
        }
        let lv = s.board[i].glv
        let r = Int.random(in: 0..<100)
        let t: Int
        switch lv {
        case 3: t = r < 55 ? 1 : (r < 85 ? 2 : 3)
        case 2: t = r < 70 ? 1 : (r < 95 ? 2 : 3)
        default: t = r < 90 ? 1 : 2
        }
        // 亲密度爆率：有 luck 的机会掉高一级
        let lucky = Double.random(in: 0..<1) < luck
        let tt = min(MK.maxTier, t + (dbl ? 1 : 0) + (lucky ? 1 : 0))
        if place(c.key + "\(tt)", near: i), let to = lastPlaced { emit(MKFX(kind: .fly, from: i, to: to, item: c.key + "\(tt)")); MKSfx.play("tap", volume: 0.5) }
        if tutStep == 0 { s.tut = 1 }
        pulse = i
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { if self.pulse == i { self.pulse = nil } }
        touch()
        // 偶尔多掉一样
        if Double.random(in: 0..<1) < (1.0 / 40) * (1 + luck) { place(["energy", "gem", "star", "gift"].randomElement() ?? "gem", near: i) }
        // 惊喜福袋：每点一下都可能掉（×2 时机会也翻倍）
        else if s.level >= 2, Double.random(in: 0..<1) < (1.0 / (dbl ? 20 : 40)) * (1 + luck), place("luckybag", near: i), let e = lastPlaced {
            emit(MKFX(kind: .burst, from: e, to: nil, item: nil, tier: 6)); MKSfx.play("discover", volume: 0.5)
        }
        s.board[i].charges -= dbl ? 2 : 1
        if s.board[i].charges == 0 { s.board[i].refillAt = Date().addingTimeInterval(MK.genRefill[lv] * 60) }
        haptic(.light)
        track("gen")
    }
    /// 产出器升级：花宝石（2 级 12、3 级 30），次数更多、掉更高级
    func genUpgradeCost(_ lv: Int) -> Int { lv == 1 ? 12 : 30 }
    func upgradeGen(_ i: Int) {
        guard let id = s.board[i].item, MK.isGen(id), s.board[i].glv < 3 else { return }
        let c = genUpgradeCost(s.board[i].glv)
        guard s.gems >= c else { say(T("宝石不够（要 {0}）。交特别订单、做小目标、开宝箱都给宝石。", c)); return }
        s.gems -= c
        s.board[i].glv += 1
        s.board[i].charges = MK.genCharges[s.board[i].glv]; s.board[i].refillAt = nil
        emit(MKFX(kind: .burst, from: i, to: nil, item: id, tier: 8)); haptic(.heavy)
        say(T("{0}升到 {1} 级：次数更多，掉的更高级。", MK.name(id), s.board[i].glv))
        react([T("升级了？那我可以更放心地躺着了。")], happy: true)
    }
    func refillGen(_ i: Int) {
        guard s.gems >= 2, let id = s.board[i].item, MK.isGen(id) else { say(T("宝石不够。")); return }
        s.gems -= 2
        s.board[i].charges = MK.genCharges[s.board[i].glv]
        s.board[i].refillAt = nil
        haptic(.medium)
    }

    private func useChest(_ i: Int, _ c: (minutes: Double, drops: Int)) {
        if let at = s.board[i].openAt {
            guard Date() >= at else { say(T("还要 {0} 分钟。下面可以用宝石马上开。", Int(at.timeIntervalSinceNow / 60) + 1)); return }
            openChest(i, drops: c.drops)
        } else if c.minutes == 0 {
            openChest(i, drops: c.drops)
        } else {
            s.board[i].openAt = Date().addingTimeInterval(c.minutes * 60)
            say(T("开始开箱，{0} 分钟。", Int(c.minutes)))
        }
    }
    func rushChest(_ i: Int) {
        guard let at = s.board[i].openAt, let id = s.board[i].item, let c = MK.chests[id] else { return }
        let cost = rushCost(at)
        guard s.gems >= cost, opening == nil else { say(T("宝石不够。")); return }
        s.gems -= cost
        openChest(i, drops: c.drops)
    }
    func rushCost(_ at: Date) -> Int { max(1, Int(at.timeIntervalSinceNow / 300) + 1) }
    /// 开箱：先抖几下（咔哒咔哒），再「砰」地弹开，东西一样一样飞出来
    @Published var opening: Int? = nil
    private func openChest(_ i: Int, drops d0: Int) {
        guard opening == nil else { return }
        // 亲密度「贴心」以上（爆率 +15% 起）宝箱多掉一样
        let drops = d0 + (luck >= 0.15 ? 1 : 0)
        selected = nil
        let chestID = s.board[i].item
        var items: [String] = []
        for k in 0..<drops {
            let roll = Int.random(in: 0..<10)
            if k == 0 && drops >= 5 { items.append(["wildcard", "scissors", "gem", "energy"].randomElement() ?? "gem") }
            else if roll < 7, let c = unlocked.randomElement() { items.append(c.key + "\(Int.random(in: 1...min(4, 1 + drops / 2)))") }
            else { items.append(["energy", "gem", "star", "coins"].randomElement() ?? "coins") }
        }
        // 自测机器人（不存档、同步一口气玩）：马上开，不等动画
        if noSave {
            s.board[i] = MKSlot()
            for it in items where !place(it, near: i) { s.bag.append(it) }
            track("chest")
            return
        }
        opening = i
        MKSfx.play("rattle")
        haptic(.light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { self.haptic(.light) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { self.haptic(.medium) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.opening = nil
            guard self.s.board[i].item == chestID else { return }
            self.s.board[i] = MKSlot()
            self.emit(MKFX(kind: .burst, from: i, to: nil, item: nil, tier: 9))
            self.haptic(.heavy)
            MKSfx.play("discover")
            self.say(T("开箱！"))
            self.track("chest")
            for (k, it) in items.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09 * Double(k)) {
                    // 台子满了：剩下的进背包，不丢
                    guard self.place(it, near: i), let e = self.lastPlaced else { self.s.bag.append(it); return }
                    self.emit(MKFX(kind: .fly, from: i, to: e, item: it))
                    MKSfx.play("tap", volume: 0.35)
                }
            }
        }
    }

    private func useAppliance(_ i: Int) {
        guard let id = s.board[i].item else { return }
        let c = s.cooks[id] ?? MKCook()
        // 放错了 / 不想做了：点一下把放进去的食材拿出来
        if c.dish == nil, !c.putIn.isEmpty {
            var left: [String] = []
            for it in c.putIn { if !place(it, near: i) { left.append(it) } }
            s.cooks[id] = MKCook(putIn: left, dish: nil, doneAt: nil)
            say(left.isEmpty ? T("食材拿出来了。") : T("台面满了，还有 {0} 样在锅里。", left.count))
            return
        }
        guard let d = c.dish, let at = c.doneAt else { return }
        if Date() >= at {
            if place(d, near: i) { s.cooks[id] = MKCook(); haptic(.heavy); MKSfx.play("cookdone"); if let e = lastPlaced { emit(MKFX(kind: .burst, from: e, to: nil, item: nil, tier: 6)) }; say(T("出锅！闻着好香……它醒了。")); react([T("这个我能先尝一口吗？"), T("香！整个柜台都是这个味。"), T("你做菜的样子好厉害。")], happy: true); track("dish") }
        } else {
            say(T("还要 {0} 分钟。下面可以用宝石加速。", Int(at.timeIntervalSinceNow / 60) + 1))
        }
    }
    func rushCook(_ id: String) {
        guard let at = s.cooks[id]?.doneAt else { return }
        let cost = max(1, Int(at.timeIntervalSinceNow / 120) + 1)
        guard s.gems >= cost else { say(T("宝石不够。")); return }
        s.gems -= cost
        s.cooks[id]?.doneAt = Date()
        say(T("好了，点一下出锅。"))
    }

    // 拖
    func drop(from a: Int, to b: Int) {
        guard a != b, b >= 0, b < s.board.count, let ia = s.board[a].item, usable(a) else { return }
        if b == opening { deny(b); return }
        let tb = s.board[b]
        if tb.boxed { deny(b, T("纸箱。在旁边合成一次，它就打开了。")); return }
        if let ib = tb.item, MK.isAppliance(ib) { putIn(a, appliance: ib); return }
        if ia == "wildcard", let ib = tb.item, MK.chain(ib) != nil, MK.tier(ib) < MK.maxTier, tb.bubbleUntil == nil {
            s.board[a] = MKSlot(); upgrade(b); return
        }
        if ia == "scissors", let ib = tb.item, let c = MK.chain(ib), MK.tier(ib) >= 2, tb.bubbleUntil == nil {
            s.board[a] = MKSlot()
            guard let e = empty(near: b) else { s.board[a] = MKSlot(item: "scissors"); say(T("没地方放剪开的那半。")); return }
            let low = c.key + "\(MK.tier(ib) - 1)"
            s.board[b] = MKSlot(item: low); s.board[e] = MKSlot(item: low)
            haptic(.medium); return
        }
        if let ib = tb.item {
            if ib == ia, tb.bubbleUntil == nil, MK.chain(ia) != nil, MK.tier(ia) < MK.maxTier {
                s.board[a] = MKSlot(); upgrade(b); return
            }
            if ib == ia, MK.isGen(ia), s.board[a].glv == tb.glv, tb.glv < 3 {
                let lv = tb.glv + 1
                s.board[a] = MKSlot()
                s.board[b] = MKSlot(item: ia, glv: lv, charges: MK.genCharges[lv])
                pulse = b; haptic(.heavy)
                say(T("{0}升到 {1} 级：次数更多，掉的更高级。", MK.name(ia), lv))
                openBoxes(around: b)
                return
            }
            if tb.bubbleUntil != nil { deny(b); return }
            if ib == ia, MK.chain(ia) != nil, MK.tier(ia) >= MK.maxTier { deny(b, T("已经是最高级了，合不了了。")); return }
            let sa = s.board[a]; s.board[a] = tb; s.board[b] = sa      // 换位置
            MKSfx.play("button", volume: 0.4)
        } else {
            s.board[b] = s.board[a]; s.board[a] = MKSlot()
        }
        selected = b
    }

    /// 连击：2 秒内接着合，音一级一级往上走，3 连以上飘「连击 ×n」
    private var combo = 0
    private var lastMergeAt = Date.distantPast
    private func upgrade(_ b: Int) {
        guard let id = s.board[b].item, let c = MK.chain(id) else { return }
        let next = c.key + "\(MK.tier(id) + 1)"
        s.board[b] = MKSlot(item: next)
        pulse = b; selected = b
        combo = Date().timeIntervalSince(lastMergeAt) < 2.0 ? combo + 1 : 0
        lastMergeAt = Date()
        let fresh = !s.found.contains(next)
        let nt = MK.tier(next)
        haptic(nt >= 6 || combo >= 4 ? .heavy : (combo >= 2 ? .medium : .light))
        if fresh && nt >= 3 { MKSfx.play("discover") }
        else if nt >= 6 { MKSfx.play("merge_big") }
        else { MKSfx.play("merge\(min(combo, 9))") }
        discover(next)
        if MK.tier(next) >= 4 { gainXP(1) }     // 前期别升太快：只有合出 3 级以上才给经验
        track("merge")
        emit(MKFX(kind: .burst, from: b, to: nil, item: next, tier: max(nt, min(7, 2 + combo))))
        if combo >= 2 { emit(MKFX(kind: .combo, from: b, to: nil, item: nil, tier: combo + 1)) }
        emit(MKFX(kind: .merge, from: b, to: nil, item: id))
        if tutStep == 1 { s.tut = 2 }
        touch()
        let t = MK.tier(next)
        mergeTimes = mergeTimes.filter { $0.timeIntervalSinceNow > -20 } + [Date()]
        if t >= 8 { shake += 1; react([T("哇……{0}！", MK.name(next)), T("这个……能给我看一眼吗。就一眼。")], happy: true); wowUntil = Date().addingTimeInterval(5) }
        else if t >= 6, Int.random(in: 0..<3) == 0 { react([T("这个看着就好吃。"), T("留一口给我。就一口。"), T("闻到了，香。")], happy: true) }
        else if mergeTimes.count >= 12 { mergeTimes = []; react([T("你手好快，看得我都累了，我先躺会儿。"), T("慢点慢点，我眼睛跟不上。"), T("你忙，我替你歇着，分工明确。")]) }
        openBoxes(around: b)
        if MK.tier(next) == MK.maxTier { say(T("哇……{0}！", MK.name(next))) }
        // 合到 4 级以上，偶尔冒出一个泡泡：60 秒内用宝石拿下，不然变成币
        if MK.tier(next) >= 4, Int.random(in: 0..<100) < 6, let e = empty(near: b) {
            s.board[e] = MKSlot(item: next, bubbleUntil: Date().addingTimeInterval(60))
        }
    }

    private func openBoxes(around b: Int) {
        let r = b / MK.cols, c = b % MK.cols
        for d in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            let rr = r + d.0, cc = c + d.1
            guard rr >= 0, rr < MK.rows, cc >= 0, cc < MK.cols else { continue }
            let k = rr * MK.cols + cc
            if s.board[k].boxed {
                s.board[k].boxed = false
                MKSfx.play("box", volume: 0.6)
                if let it = s.board[k].item { discover(it) }
                emit(MKFX(kind: .burst, from: k, to: nil, item: nil, tier: 2))
                if tutStep == 3 { s.tut = 99; react([T("纸箱开了！里面有啥……又是米。"), T("地方变大了，我可以躺得更开了。")], happy: true) }
                else if Int.random(in: 0..<5) == 0 { react([T("纸箱里有啥？"), T("又多一块地方。")]) }
            }
        }
    }

    func bubbleCost(_ id: String) -> Int { max(1, MK.tier(id) - 2) }
    func buyBubble(_ i: Int) {
        guard let id = s.board[i].item, s.board[i].bubbleUntil != nil else { return }
        let cost = bubbleCost(id)
        guard s.gems >= cost else { say(T("宝石不够。")); return }
        s.gems -= cost
        s.board[i].bubbleUntil = nil
        haptic(.medium)
        say(T("拿下了！"))
    }

    private func putIn(_ a: Int, appliance: String) {
        guard let id = s.board[a].item else { return }
        var c = s.cooks[appliance] ?? MKCook()
        guard c.dish == nil else { deny(s.board.firstIndex { $0.item == appliance }, T("{0}在忙。", MK.name(appliance))); return }
        let avail = MK.recipes.filter { $0.at == appliance && MK.can($0, s.level) }
        let next = c.putIn + [id]
        let fits = avail.contains { r in Set(next).count == next.count && next.allSatisfy { r.needs.contains($0) } }
        guard fits else { deny(s.board.firstIndex { $0.item == appliance }, T("这个不放{0}里。", MK.name(appliance))); return }
        s.board[a] = MKSlot()
        c.putIn = next
        MKSfx.play("cook", volume: 0.6)
        if let r = avail.first(where: { Set($0.needs) == Set(next) }) {
            c = MKCook(putIn: [], dish: r.id, doneAt: Date().addingTimeInterval(r.minutes * 60))
            say(T("开始做「{0}」，{1} 分钟。", r.name, Int(r.minutes)))
            haptic(.heavy)
        } else {
            haptic(.light)
        }
        s.cooks[appliance] = c
    }

    // 出售 / 撤销
    func sellPrice(_ id: String) -> Int { max(1, MK.value(id) / 8) }
    /// 做好的菜装进饭盒带回家（主 App 背包里多一份，首页喂它）
    @discardableResult
    func takeHome(_ i: Int) -> Bool {
        guard let id = s.board[i].item, MK.recipe(id) != nil else { return false }
        s.board[i] = MKSlot()
        selected = nil
        say(T("🍱 {0} 装进饭盒了。回首页点「喂食」就能喂它。", MK.name(id)))
        react([T("带回家？……那我先不偷吃了。"), T("饭盒我替你看着。")], happy: true)
        haptic(.medium)
        return true
    }

    func sell(_ i: Int) {
        guard let id = s.board[i].item, usable(i), !MK.isGen(id), !MK.isAppliance(id) else { return }
        lastSold = MKSold(index: i, slot: s.board[i])
        coinsEarned += sellPrice(id)
        s.board[i] = MKSlot()
        selected = nil
        say(T("卖了 {0} 币。", sellPrice(id)))
    }
    func undoSell() {
        guard let ls = lastSold, s.board[ls.index].item == nil, let id = ls.slot.item else { return }
        coinsEarned -= sellPrice(id)
        s.board[ls.index] = ls.slot
        lastSold = nil
    }

    // 背包
    func stash(_ i: Int) {
        guard let id = s.board[i].item, usable(i) else { return }
        if MK.isAppliance(id), let c = s.cooks[id], c.dish != nil || !c.putIn.isEmpty { say(T("{0}里还有东西。", MK.name(id))); return }
        guard s.bag.count < s.bagSlots else { say(T("背包满了。")); return }
        s.bag.append(MK.isGen(id) ? id + "@\(s.board[i].glv)" : id)
        s.board[i] = MKSlot()
        selected = nil
        haptic(.light)
    }
    /// 单子要的东西 + 单子里那些菜的原料（半成品也拆开）
    var neededIDs: Set<String> { Set(s.orders.flatMap(\.items) + s.orders.flatMap { $0.items.flatMap(MK.allNeeds) }) }
    /// 一键收纳：台面上眼下没单子要、也没有能配对合成的东西，收进背包（高级的先收，背包满了就停）
    @discardableResult
    func stowIdle() -> Int {
        let need = neededIDs
        var count: [String: Int] = [:]
        for sl in s.board { if let id = sl.item, !sl.boxed { count[id, default: 0] += 1 } }
        let cand = s.board.indices.filter { i in
            guard let id = s.board[i].item, usable(i), !MK.isGen(id), !MK.isAppliance(id), MK.chests[id] == nil,
                  MK.chain(id) != nil || MK.recipe(id) != nil else { return false }
            if need.contains(id) { return false }
            if MK.chain(id) != nil, (count[id] ?? 0) >= 2, MK.tier(id) < MK.maxTier { return false }   // 还能合的留着
            return true
        }.sorted { MK.value(s.board[$0].item ?? "") > MK.value(s.board[$1].item ?? "") }
        var moved = 0
        for i in cand where s.bag.count < s.bagSlots {
            s.bag.append(s.board[i].item ?? ""); s.board[i] = MKSlot(); moved += 1
        }
        if moved > 0 { boardFull = false; haptic(.medium); say(T("收好了 {0} 样，背包 {1}/{2}。", moved, s.bag.count, s.bagSlots)) }
        else if s.bag.count >= s.bagSlots { say(T("背包也满了。卖掉几样，或者多开一个格子。")) }
        else { say(T("台面上的东西都用得上，先合一合吧。")) }
        return moved
    }
    func unstash(_ k: Int) {
        guard k < s.bag.count else { return }
        let parts = s.bag[k].split(separator: "@")
        let id = String(parts[0])
        guard place(id, near: MK.cols * 6 + 3), let e = lastPlaced else { return }
        if MK.isGen(id) {
            // 收起来的产出器拿出来不会白给满次数：等冷却
            let lv = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
            s.board[e].glv = lv; s.board[e].charges = 0
            s.board[e].refillAt = Date().addingTimeInterval(MK.genRefill[lv] * 60)
        }
        s.bag.remove(at: k)
    }
    /// 背包：30 格以内用宝石买；2026-10-21 起 31–50 格用金币买（后期台面挤，也给金币一个出口）
    static let bagMax = 50
    static let bagGemMax = 30
    var bagSlotCost: Int { 5 + max(0, s.bagSlots - 6) * 5 }
    var bagCoinCost: Int { 200 + max(0, s.bagSlots - Self.bagGemMax) * 40 }
    func buyBagSlot() {
        guard s.bagSlots < Self.bagGemMax else { say(T("背包已经最大了。")); return }
        guard s.gems >= bagSlotCost else { say(T("宝石不够。")); return }
        s.gems -= bagSlotCost
        s.bagSlots += 1
    }

    // 小铺（每天刷新）
    func refreshDeals() {
        let day = Wallet.day()
        guard s.dealsDay != day || s.deals.isEmpty else { return }
        s.dealsDay = day
        var d: [MKDeal] = []
        for _ in 0..<3 {
            guard let c = unlocked.randomElement() else { continue }
            let t = Int.random(in: 3...max(3, min(6, 3 + s.level / 2)))
            let id = c.key + "\(t)"
            d.append(MKDeal(item: id, price: max(5, MK.value(id)), gem: false))
        }
        d.append(MKDeal(item: "chest2", price: 6, gem: true))
        d.append(MKDeal(item: "wildcard", price: 4, gem: true))
        d.append(MKDeal(item: "scissors", price: 2, gem: true))
        s.deals = d
    }
    /// 买小铺的东西；返回要扣的币（宝石在这里直接扣），失败返回 nil
    func buyDeal(_ deal: MKDeal, coins: Int) -> Int? {
        guard let k = s.deals.firstIndex(where: { $0.id == deal.id }), !s.deals[k].sold else { return nil }
        if deal.gem {
            guard s.gems >= deal.price else { say(T("宝石不够。")); return nil }
        } else {
            guard coins >= deal.price else { say(T("币不够。")); return nil }
        }
        guard place(deal.item, near: MK.cols * 6 + 3) else { return nil }
        if deal.gem { s.gems -= deal.price }
        s.deals[k].sold = true
        return deal.gem ? 0 : deal.price
    }
    /// 宝石买体力：同一天越买越贵（5、10、20、40），第二天回到 5。
    /// 自测：60 天攒了 1000 多宝石，一直 5 宝石 50 体力的话，宝石就等于无限体力，「等它回满」没了盼头
    /// 平常玩送的宝石：20 级以后减半（2026-10-21 开内购：后期攒 1000 多颗就没人买了；新手期照样给足）
    func earnGems(_ n: Int) {
        guard n > 0 else { return }
        s.gems += s.level >= 20 ? max(1, (n + 1) / 2) : n
    }
    var energyCost: Int {
        let n = s.energyBuyDay == Wallet.day() ? (s.energyBuys ?? 0) : 0
        return [5, 10, 20, 40][min(3, n)]
    }
    func buyEnergy() {
        let c = energyCost
        guard s.gems >= c else { say(T("宝石不够。")); return }
        let today = Wallet.day()
        s.energyBuys = s.energyBuyDay == today ? (s.energyBuys ?? 0) + 1 : 1
        s.energyBuyDay = today
        s.gems -= c
        s.energy += 50
        say(T("体力 +50"))
    }

    // 回来时：睡了一觉体力满；它帮你看了店（偷吃一半）
    /// 老存档补发：新加的产出器/厨具只在升到那一级时发，已经过了那一级的玩家要补一个
    func backfillUnlocks() {
        guard !MKDemo.on else { return }
        let have = Set(s.board.compactMap(\.item) + s.bag.map { String($0.split(separator: "@")[0]) })
        var got: [String] = []
        let d = UserDefaults.standard
        // 每样只补一次（卖掉了不会再补）
        func once(_ id: String, _ name: String, _ near: Int) {
            let k = "mk.bf." + id
            guard !d.bool(forKey: k) else { return }
            d.set(true, forKey: k)
            if !have.contains(id) { give(id, near: near); got.append(name) }
        }
        for c in MK.chains where c.unlock <= s.level && c.unlock >= 16 { once(c.gen, c.genName, MK.cols * 8 + 3) }
        for a in MK.appliances where a.unlock <= s.level && a.unlock >= 16 { once(a.id, a.name, MK.cols * 7 + 3) }
        if !got.isEmpty { say(T("新到货：") + got.joined(separator: T("、"))) }
    }

    func welcomeBack() {
        backfillUnlocks()
        guard !MKDemo.on else { return }
        defer { s.lastSeen = Date() }
        guard let last = s.lastSeen else { return }
        let gap = Date().timeIntervalSince(last)
        if gap > 7200, tutStep >= 99 { easeOnReturn() }
        guard gap > 3600 else { return }
        var lines: [String] = []
        let cal = Calendar.current
        let h0 = cal.component(.hour, from: last), h1 = cal.component(.hour, from: Date())
        let slept = gap > 8 * 3600 || (gap > 4 * 3600 && (h0 >= 21 || h0 < 4) && (5...12).contains(h1))
        if slept, s.energy < MK.maxEnergy {
            s.energy = MK.maxEnergy; s.energyAt = Date()
            lines.append(T("你睡觉的时候它也睡了，醒来体力满了。"))
        }
        let n = min(5, Int(gap / 3600))
        if n > 0 {
            let earned = n * (3 + s.level / 3)
            let keep = max(1, earned / 2)
            coinsEarned += keep
            s.stars += n / 2
            lines.append(T("你不在的时候，它趴在柜台后面顺手接了 {0} 单，赚了 {1} 币……然后偷吃掉一半。给你 {2} 币", n, earned, keep) + (n / 2 > 0 ? T("、{0} 颗星。", n / 2) : T("。")))
        }
        if !lines.isEmpty { welcome = lines.joined(separator: "\n\n") }
    }

    /// 走路换体力：每 1000 步 10 体力，一天最多 100
    func applySteps(_ steps: Int) {
        guard steps > 0 else { return }
        let day = Wallet.day()
        if s.stepDay != day { s.stepDay = day; s.stepEnergy = 0 }
        let should = min(100, steps / 1000 * 10)
        let got = s.stepEnergy ?? 0
        guard should > got else { return }
        s.energy += should - got
        s.stepEnergy = should
        say(T("今天走了 {0} 步，它躺着替你数的：体力 +{1}", steps, should - got))
    }

    /// 离开小店时告诉灵动岛：下一件「好了」的事
    func nextReady() -> MKPing? {
        var c: [MKPing] = []
        let now = Date()
        // 门那边的单还没做：离开小店，灵动岛马上亮着这张小票（嘟嘟星哪个地方在等）
        let door = s.orders.first(where: { $0.isDoor })?.door
        for (id, k) in s.cooks { if let d = k.dish, let at = k.doneAt, at > now { c.append(MKPing(at: at, icon: "🍲", line: T("{0}好了～", MK.name(d)))); _ = id } }
        for slot in s.board {
            if let at = slot.openAt, at > now { c.append(MKPing(at: at, icon: "🎁", line: T("宝箱能开了"))) }
            if let at = slot.refillAt, at > now, let id = slot.item { c.append(MKPing(at: at, icon: "🧺", line: T("{0}装满了", MK.name(id)))) }
        }
        if s.energy < MK.maxEnergy {
            let full = s.energyAt.addingTimeInterval(Double(MK.maxEnergy - s.energy) * MK.regenSeconds)
            c.append(MKPing(at: full, icon: "⚡️", line: T("体力满了，来开店吧")))
        }
        // 下一个饭点
        let cal = Calendar.current
        for (h, meal) in [(7, T("早饭")), (11, T("午饭")), (15, T("下午茶")), (17, T("晚饭")), (21, T("夜宵"))] {
            if let t = cal.date(bySettingHour: h, minute: 0, second: 0, of: now), t > now,
               !(s.petMeals ?? []).contains(Wallet.day() + "|" + meal) {
                c.append(MKPing(at: t, icon: "🍙", line: T("{0}时间到，我饿了", meal))); break
            }
        }
        let best = c.min { $0.at < $1.at }
        // 门那边的单还没做：岛台常亮这张小票；推送用最近的那个计时
        if let d = door, d >= 1, d <= MKStory.doors.count {
            return MKPing(at: now.addingTimeInterval(1), icon: "🌙", line: T("门那边来单了：{0}", MKStory.doors[d - 1].name),
                          pushAt: best?.at, pushIcon: best?.icon, pushLine: best?.line)
        }
        return best
    }

    // 手感：特效、它的反应、新手引导
    var tutStep: Int { (MKDemo.on && !MKDemo.fresh) ? 99 : (s.tut ?? 99) }
    func emit(_ f: MKFX) {
        fx.append(f)
        let id = f.id
        DispatchQueue.main.asyncAfter(deadline: .now() + (f.kind == .combo ? 1.0 : 0.75)) { self.fx.removeAll { $0.id == id } }
    }
    func float(_ text: String, x: CGFloat) {
        let f = MKFloat(text: text, x: x)
        floaters.append(f)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.floaters.removeAll { $0.id == f.id } }
    }
    func react(_ lines: [String], happy: Bool = false) {
        guard let l = lines.randomElement() else { return }
        let say = MKSay(text: l)
        withAnimation(.spring(response: 0.3)) { petSay = say }
        if happy { petHappyUntil = Date().addingTimeInterval(3) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { if self.petSay?.id == say.id { withAnimation { self.petSay = nil } } }
    }
    func touch() { lastAction = Date(); idleSpoke = false }


    /// 停下来不知道干嘛时：嘟嘟告诉你下一步（能交的单 → 能合的 → 能装修 → 目标奖励 → 能点的产出器 → 都在歇）
    func nextStep() -> String {
        if let o = s.orders.first(where: { canServe($0) }) {
            return T("「{0}」那单，东西齐了，点「交」。", o.isPet ? T("我的") + o.meal : o.meal)
        }
        var seen: [String: Int] = [:]
        for sl in s.board where !sl.boxed && sl.bubbleUntil == nil {
            guard let id = sl.item, MK.chain(id) != nil, MK.tier(id) < MK.maxTier else { continue }
            if seen[id] != nil { return T("台面上有两个「{0}」，拖到一起能合。", MK.name(id)) }
            seen[id] = 1
        }
        if let t = nextTask, s.stars >= t.stars { return T("星星够了。点右下角「装修」：{0}。", t.title) }
        if dailyClaimable { return T("「目标」里有奖励没领。") }
        let gens = s.board.indices.filter { MK.isGen(s.board[$0].item ?? "") }
        let canTap = boosting || s.energy > 0
        let room = s.board.contains { $0.item == nil && !$0.boxed }
        if !room { return T("台子满了。点一个用不上的，卖掉或者收进背包。") }
        if !canTap { return T("体力没了。出去走走（每 1000 步 +10），或者先合一合、交交单。") }
        if let g = gens.first(where: { s.board[$0].charges > 0 || boosting }), let c = MK.chains.first(where: { $0.gen == s.board[g].item }) {
            return T("点一下「{0}」，出点新东西。", c.genName)
        }
        if let soon = gens.compactMap({ s.board[$0].refillAt }).min() {
            let m = max(1, Int(soon.timeIntervalSinceNow / 60) + 1)
            return T("产出器都在歇，最快 {0} 分钟后装满。选中它，可以用宝石马上装满。", m)
        }
        return T("台面上的东西能卖钱，点一下看看。")
    }

    // 每日任务 + 签到
    func refreshDaily() {
        let today = Wallet.day()
        if s.loginDay != today {
            let yesterday = Wallet.day(Date().addingTimeInterval(-86400))
            let streak = s.loginDay == yesterday ? (s.loginStreak ?? 0) + 1 : 1
            s.loginDay = today; s.loginStreak = streak
            if !MKDemo.on { giveLogin(streak) }
        }
        guard s.daily?.day != today else { return }
        var pool: [MKGoal] = [MKGoal(kind: "merge", target: [20, 30, 40][min(2, s.level / 6)]),
                              MKGoal(kind: "ticket", target: [3, 5, 7][min(2, s.level / 6)]),
                              MKGoal(kind: "gen", target: [30, 45, 60][min(2, s.level / 6)]),
                              MKGoal(kind: "chest", target: 1),
                              MKGoal(kind: "pet", target: 2)]
        if s.level >= 4 { pool.append(MKGoal(kind: "dish", target: s.level >= 10 ? 3 : 2)) }
        s.daily = MKDaily(day: today, goals: Array(pool.shuffled().prefix(3)))
    }
    private static let loginRewards: [(item: String?, gems: Int, energy: Int, text: String)] = [
        (nil, 0, 30, T("体力 +30")), (nil, 3, 0, T("宝石 +3")), ("wildcard", 0, 0, T("万能星 ×1")), ("chest2", 0, 0, T("宝箱 ×1")),
        ("scissors", 2, 0, T("小剪刀 + 宝石 2")), (nil, 5, 0, T("宝石 +5")), ("chest3", 5, 0, T("大宝箱 + 宝石 5")),
    ]
    func giveLogin(_ streak: Int) {
        let d = (streak - 1) % 7
        let r = Self.loginRewards[d]
        earnGems(r.gems); s.energy += r.energy
        if let it = r.item { give(it) }
        loginGift = (d + 1, r.text)
        MKSfx.play("reward")
    }
    /// 放到台面上；台面满了就塞进背包（不占格子上限也行，奖励不能丢）
    func give(_ id: String, near: Int = MK.cols * 6 + 3) {
        if empty(near: near) != nil { place(id, near: near) } else { s.bag.append(id); say(T("台面满了，{0}先放进背包。", MK.name(id))) }
    }
    /// 上一轮周榜的奖：第 1 名 / 前 10% / 参加了
    func vsReward(rank: Int, total: Int) {
        if rank == 1 { s.gems += 30; give("chest3"); say(T("🏆 上周交单榜第 1 名！宝石 +30，大宝箱一个。")) }
        else if rank <= max(1, total / 10) { s.gems += 15; give("chest2"); say(T("🏆 上周交单榜第 {0} 名（前 10%）：宝石 +15，宝箱一个。", rank)) }
        else { s.gems += 5; give("luckybag"); say(T("🏆 上周交单榜第 {0} 名：宝石 +5，福袋一个。这周再冲一把？", rank)) }
        MKSfx.play("reward")
    }

    // MARK: 限时冲刺
    func refreshSprint() {
        guard s.level >= 3, tutStep >= 99, !MKDemo.on || MKDemo.args.contains("-selfTestHuman") else { return }
        let now = Date()
        if let sp = s.sprint, now > sp.ends, !(sp.done && !sp.claimed) {
            s.sprint = nil; s.sprintNext = now.addingTimeInterval(20 * 60)
        }
        guard s.sprint == nil, now >= (s.sprintNext ?? .distantPast) else { return }
        var kinds: [(String, Int)] = [("merge", 30 + s.level), ("gen", 25 + s.level), ("ticket", 4 + s.level / 6)]
        if s.level >= 6 { kinds.append(("dish", 2 + s.level / 12)) }
        if s.level >= 8 { kinds.append(("chest", 2)) }
        let k = kinds.randomElement() ?? ("merge", 30)
        let reward = ["energy", "energy", "luckybag", "gems", "chest2"].randomElement() ?? "energy"
        s.sprint = MKSprint(kind: k.0, target: k.1, ends: now.addingTimeInterval(3 * 3600), reward: reward)
    }
    func claimSprint() {
        guard var sp = s.sprint, sp.done, !sp.claimed else { return }
        sp.claimed = true
        switch sp.reward {
        case "energy": s.energy += 50
        case "gems": earnGems(6)
        case "luckybag": give("luckybag")
        default: give("chest2")
        }
        s.sprint = nil
        s.sprintNext = Date().addingTimeInterval(Double(Int.random(in: 20...40)) * 60)
        addSeason(5)
        haptic(.heavy); MKSfx.play("reward")
        say(T("⚡ 冲刺完成：{0}", sp.rewardText))
    }

    func track(_ kind: String, _ n: Int = 1) {
        if var sp = s.sprint, sp.kind == kind, !sp.done, Date() <= sp.ends { sp.progress = min(sp.target, sp.progress + n); s.sprint = sp }
        guard var d = s.daily, d.day == Wallet.day(), let k = d.goals.firstIndex(where: { $0.kind == kind }) else { return }
        d.goals[k].progress = min(d.goals[k].target, d.goals[k].progress + n)
        s.daily = d
    }
    var dailyClaimable: Bool {
        guard let d = s.daily else { return false }
        return d.goals.contains { $0.done && !$0.claimed } || (!d.bonus && d.goals.allSatisfy(\.claimed))
    }
    func claimGoal(_ g: MKGoal) {
        guard var d = s.daily, let k = d.goals.firstIndex(where: { $0.id == g.id }), d.goals[k].done, !d.goals[k].claimed else { return }
        d.goals[k].claimed = true; s.daily = d
        addSeason(3)
        earnGems(3); s.energy += 10; haptic(.medium); MKSfx.play("reward"); say(T("宝石 +3 体力 +10"))
    }
    func claimDailyBonus() {
        guard var d = s.daily, !d.bonus, d.goals.allSatisfy(\.claimed) else { return }
        d.bonus = true; s.daily = d
        give("chest_daily"); haptic(.heavy); MKSfx.play("renovate"); s.packs = (s.packs ?? 0) + 1
        say(T("今天的小目标全做完了！每日宝箱放在台面上，拍立得 +1。"))
    }

    // 周末活动
    func refreshEvent() {
        guard let cur = MKEvent.current(), tutStep >= 99 else {
            if s.orders.contains(where: { $0.isEvent }) { s.orders.removeAll { $0.isEvent } }
            return
        }
        if s.event?.week != cur.week { s.event = MKEventState(week: cur.week) }
        let have = s.orders.filter { $0.isEvent }.count
        // 最后一档拿到了：活动单不再补（不然刷不完）
        if (s.event?.points ?? 0) >= MKEvent.goal { return }
        guard have < 2 else { return }
        let cs = unlocked.filter { cur.def.chains.contains($0.key) }
        let pick = cs.isEmpty ? unlocked : cs
        let top = MK.orderTop(s.level)
        for _ in have..<2 {
            var items: [String] = []
            for _ in 0..<(s.level < 5 ? 1 : 2) {
                if let c = pick.randomElement() { items.append(c.key + "\(Int.random(in: max(2, top - 3)...top))") }
            }
            if items.isEmpty { items = ["rice3"] }
            let v = items.map(MK.value).reduce(0, +)
            s.orders.append(MKOrder(items: items, stars: MK.orderStars(v), meal: cur.def.name, event: true))
        }
    }
    private func addEventPoints(_ n: Int) {
        guard var e = s.event else { return }
        e.points += n
        for (k, m) in MKEvent.milestones.enumerated() where e.points >= m.points && !e.claimed.contains(k) {
            e.claimed.append(k); earnGems(m.gems); give(m.item)
            MKSfx.play(k == MKEvent.milestones.count - 1 ? "renovate" : "reward")
            if k == MKEvent.milestones.count - 1 {
                s.packs = (s.packs ?? 0) + 2
                say(T("活动全部完成！{0} + 宝石 {1} + 拍立得 2 包", MK.name(m.item), m.gems))
            } else {
                say(T("活动奖励：{0} + 宝石 {1}", MK.name(m.item), m.gems))
            }
        }
        s.event = e
    }

    // 装修
    var nextTask: MKStory.Task? {
        MKStory.all.first { !s.done.contains($0.id) } ?? MKStory.wish(s.done.filter { $0.hasPrefix("w") }.count + 1)
    }
    func doTask(_ t: MKStory.Task) {
        guard s.stars >= t.stars, !s.done.contains(t.id) else { say(T("星星不够，交订单攒星星。")); return }
        s.stars -= t.stars
        s.done.append(t.id)
        haptic(.heavy)
        if let a = MKStory.area(of: t.id) {
            // 装修看得见：全屏切到这个地方，新家具落下来
            let ch = MKStory.chapterEnds.contains(t.id) ? (MKStory.chapters.firstIndex { $0.tasks.last?.id == t.id }).map { $0 + 1 } : nil
            let areaIds = a.chapters.flatMap { $0.tasks.map(\.id) }
            let areaDone = areaIds.allSatisfy { s.done.contains($0) }
            let allDone = MKStory.all.allSatisfy { s.done.contains($0.id) }
            if areaDone, let k = NestItem.awardKey(for: a.key) { accEarned.append(k) }
            if allDone, let k = NestItem.awardKey(for: "all") { accEarned.append(k) }
            renovated = MKRenovation(area: a, task: t, done: s.done, chapter: ch, areaDone: areaDone, allDone: allDone, bagUp: ch != nil && s.bagSlots < Self.bagMax)
        } else {
            storyLine = MKStoryShow(title: t.title, line: t.line)
        }
        if let m = MKStory.mystery(answeredBy: t.id) { reveal = m } else if let m = MKStory.mystery(halfBy: t.id) { reveal = m }
        gainXP(t.stars * 2)
        s.energy += 10   // 2026-10-27：每件装修 +10 体力，做完马上能接着玩
        if let g = MKCards.goldAt[t.id] { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.giveGold(g) } }
        if MKStory.chapterEnds.contains(t.id) {
            s.gems += 10; give("chest3")
            s.packs = (s.packs ?? 0) + 2
            if let k = MKStory.chapters.firstIndex(where: { $0.tasks.last?.id == t.id }) {
                flushSave()
                onChapter?(k + 1)
                ReviewAsk.happyMoment()   // 装修完一章：心情好的时候问一句打分
                if s.bagSlots < Self.bagMax { s.bagSlots += 1; say(T("背包多了一格：{0} 格。", s.bagSlots)) }
                grantBoost(30, T("第 {0} 章装修完", k + 1))
                if let b = MKStory.scenes[k + 1] { scene = MKScene(title: MKStory.chapters[k].title, beats: b) }
                refreshDoor()
            }
        }
        if t.id.hasPrefix("w") { earnGems(15); give("chest3") }
    }

    // MARK: 测试面板用（连点等级 7 下）
    func debugJump(chapter n: Int) {
        let chs = MKStory.chapters
        let k = max(1, min(chs.count, n))
        s.done = chs.prefix(k - 1).flatMap { $0.tasks.map(\.id) }
        s.doorLit = k > 1 ? Array(1...(k - 1)) : []
        s.orders.removeAll { $0.isDoor }
        if (s.ticketsServed ?? 0) < 3 { s.ticketsServed = 3 }
        s.tut = 99
        refreshDoor()
        say(T("测试：跳到第 {0} 章开头", k))
    }
    func debugScene(_ k: Int) {
        guard let b = MKStory.scenes[k] else { return }
        scene = MKScene(title: k == 0 ? T("门缝里的小票") : MKStory.chapters[k - 1].title, beats: b)
    }
    func debugRush() {
        guard let k = s.orders.firstIndex(where: { !$0.isPet && !$0.isEvent && !$0.isSpecial }) else { return }
        var o = s.orders[k]; o.rushUntil = Date().addingTimeInterval(5 * 60); o.meal = T("⏱ 急单 · 测试")
        s.orders[k] = o
    }
    func debugLevelUp() { gainXP(MK.xpNeed(s.level) - s.xp) }
    func skipTutorial() {
        s.tut = 99
        // 引导里那个纸箱步骤跳过了：顺手把上面两行纸箱打开
        for k in 0..<(MK.cols * 2) where s.board[k].boxed { s.board[k].boxed = false }
        say(T("好，你是老手。有不会的，发呆一会儿我会提示。"))
    }
    /// 刚开放小锅：保证马上有一张要做菜的单，配合做菜小教学
    private func ensureFirstDish() {
        guard !s.found.contains(where: { $0.hasPrefix("dish_") }),
              !s.orders.contains(where: { $0.items.contains { MK.recipe($0) != nil } }),
              let r = MK.recipe("dish_bento"), MK.can(r, s.level),
              let k = s.orders.firstIndex(where: { !$0.isPet && !$0.isEvent && !$0.isSpecial && !$0.isRush && $0.regular == nil && !canServe($0) }) else { return }
        let v = MK.value(r.id)
        s.orders[k] = MKOrder(items: [r.id], stars: MK.orderStars(v) + 2, gems: 2, meal: T("外卖 · ") + T("蘑菇小区"), made: Date(), band: 1)
    }

    private func gainXP(_ n: Int) {
        s.xp += n
        while s.xp >= MK.xpNeed(s.level) {
            s.xp -= MK.xpNeed(s.level)
            s.level += 1
            levelUp = s.level; MKSfx.play("renovate"); MKSfx.notify(.success)
            if s.level == 4 { DispatchQueue.main.async { self.ensureFirstDish() } }
            UserDefaults.standard.set(s.level, forKey: "merge.level")
            earnGems(3)
            s.energy += 20   // 升级：体力 +20（2026-10-20 不再直接加满，体力更有分量）
            // 台面满了就放进背包，升级奖励绝不能丢
            for c in MK.chains where c.unlock == s.level { give(c.gen, near: MK.cols * 8 + 3); UserDefaults.standard.set(true, forKey: "mk.bf." + c.gen) }
            for a in MK.appliances where a.unlock == s.level { give(a.id, near: MK.cols * 7 + 3); UserDefaults.standard.set(true, forKey: "mk.bf." + a.id) }
            give(s.level % 3 == 0 ? "chest2" : "gift")
        }
    }

    func say(_ t: String) {
        withAnimation { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { if self.toast == t { withAnimation { self.toast = nil } } }
    }
    private func haptic(_ st: UIImpactFeedbackGenerator.FeedbackStyle) { MKSfx.impact(st) }
    /// 不行的操作：低低一声「啵」+ 警告震动 + 那一格抖一下
    @Published var denied: Int? = nil
    /// 交单飞过去的位置：第几张卡、卡宽（界面告诉它）
    var orderSlot: (k: Int, w: CGFloat) = (0, 84)
    @Published var deniedTick = 0
    func deny(_ i: Int?, _ line: String? = nil) {
        MKSfx.play("boop", volume: 0.6)
        MKSfx.notify(.warning)
        denied = i
        deniedTick += 1
        let t = deniedTick
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { if self.deniedTick == t { self.denied = nil } }
        if let line { say(line) }
    }
}

// MARK: - 界面
struct MergeKitchenView: View {
    let pet: String
    @ObservedObject var profile: ProfileStore
    var steps: Int = 0
    var embedded = false             // 放在底部导航栏里：不显示右上角的关闭
    var onServe: (Int, String) -> Void = { _, _ in }
    var onTakeHome: (String) -> Void = { _ in }   // 做好的菜带回家喂它
    var onLeave: (MKPing?) -> Void = { _ in }
    var onChapter: (Int) -> Void = { _ in }
    var onDoor: (Int) -> Void = { _ in }
    @StateObject private var store = MKStore()
    @ObservedObject private var gc = MKGameCenter.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var dragFrom: Int? = nil
    @State private var dragAt: CGPoint = .zero
    @State private var lastTarget: Int? = nil   // 拖到一个能合的格子上时轻震一下
    @State private var eating: String? = nil
    @State private var now = Date()
    @State private var sheet: MKSheet? = nil
    @State private var showMap = Shot.map
    @State private var showDebug = false
    @State private var orderW: CGFloat = 84
    @State private var gw: CGFloat = 393
    @State private var onScreen = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let gemColor = Color(hex: "#A8E6FF")
    private static let starColor = Color(hex: "#FFD166")
    private static let doorColor = Color(hex: "#C9A7FF")
    private static let rushColor = Color(hex: "#FF9F6B")

    var body: some View {
        GeometryReader { g in
            // 小屏（SE）别把底栏挤出去：格子同时受高度限制（上面顶栏+目标条+订单+信息栏+底栏约 300pt）
            let side = floor(min((g.size.width - 32) / CGFloat(MK.cols), (g.size.height - 300) / CGFloat(MK.rows)))
            VStack(spacing: 6) {
                topBar
                HStack(spacing: 6) { goalStrip; streakMeter }
                petAndOrders
                board(side: side)
                infoBar.frame(height: 50)
                bottomBar
            }
            .onAppear { gw = g.size.width }
            .onChange(of: g.size.width) { _, w in gw = w }
            .padding(.horizontal, 12)
        }
        .background {
            // 你装修的店就是背景：它躺在你亲手布置的店里
            ZStack {
                Theme.ground
                // 背景糊得更开：地板缝不会在台面周围变成一条条黑线
                MKAreaScene(area: MKStory.shown(done: store.s.done), done: store.s.done, fill: true)
                    .blur(radius: 10)
                Color.black.opacity(0.58)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if let t = store.toast {
                Text(t).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text).multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.surface2, in: Capsule()).padding(.top, 150).padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity)).allowsHitTesting(false)
            }
        }
        .overlay { popups }
        .onChange(of: store.outOfEnergy) { _, v in if v { store.outOfEnergy = false; if sheet == nil { sheet = .energy } } }
        .sheet(item: $sheet) { s in
            switch s {
            case .bag: MKBagView(store: store, profile: profile)
            case .gems: MKGemShop(store: store)
            case .energy: MKEnergyCard(store: store) {
                sheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { sheet = .gems }
            }
            case .shop: MKShopView(store: store, profile: profile)
            case .book: MKBookView(store: store)
            case .deco: MKDecoView(store: store)
            case .tasks: MKTasksView(store: store)
            case .album: MKAlbumView(store: store)
            case .season: MKSeasonView(store: store)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(tick) { t in
            now = t
            store.tick()
            store.claimIAP()
            flushCoins()
        }
        .onDisappear { onScreen = false; store.flushSave(); flushCoins(); onLeave(store.nextReady()); MKMusic.stop() }
        .onChange(of: phase) { _, p in
            if p == .background || p == .inactive { store.flushSave() }
            if p == .background { flushCoins(); onLeave(store.nextReady()); MKMusic.stop() }
            // 小店是一个标签页：别的页回到前台时不放店里的音乐、不算「回店」
            if p == .active, onScreen { onLeave(nil); store.welcomeBack(); store.applySteps(steps); store.maybeLucky(); MKMusic.start() }
        }
        .onChange(of: steps) { _, n in store.applySteps(n) }
        .onAppear {
            store.onChapter = onChapter
            store.onDoor = onDoor
            MKGameCenter.shared.onReward = { [weak st = store] r, t in st?.vsReward(rank: r, total: t) }
            MKGameCenter.shared.start(prompt: false)
            onScreen = true
            MKMusic.start()
            onLeave(nil)
            store.welcomeBack()
            store.applySteps(steps)
            store.maybeLucky()
            if let sh = MKDemo.sheet { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { sheet = MKSheet(rawValue: sh) } }
            if MKDemo.args.contains("-demoRenovate"), let t = MKStory.all.first(where: { $0.id == "a4" }), let a = MKStory.area(of: "a4") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { sheet = .deco }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { store.renovated = MKRenovation(area: a, task: t, done: store.s.done, chapter: nil) }
            }
            if MKDemo.select { store.selected = MK.cols * 3 + 2; store.react([T("这个看着就好吃。")], happy: true) }
        }
    }

    private func flushCoins() {
        if !store.accEarned.isEmpty { store.accEarned.forEach { profile.grant($0) }; store.accEarned = [] }
        let n = store.coinsEarned
        guard n != 0 else { return }
        store.coinsEarned = 0
        if n > 0 { profile.earn(n, T("小厨房")) } else { _ = profile.spend(-n, T("小厨房 · 撤销出售")) }
    }

    // 大目标：把嘟嘟星 14 个地方点亮；这一章做到哪了。点开看地图和线索本
    private var goalStrip: some View {
        let lit = store.s.doorLit?.count ?? 0
        let chs = MKStory.chapters
        let k = chs.firstIndex { !$0.tasks.allSatisfy { store.s.done.contains($0.id) } }
        let chText: String = {
            guard let k else { return T("主线做完了 · 心愿进行中") }
            let done = chs[k].tasks.filter { store.s.done.contains($0.id) }.count
            return T("第 {0} 章 {1}/{2}", k + 1, done, chs[k].tasks.count)
        }()
        return Button { showMap = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill").font(.system(size: 11)).foregroundStyle(Self.doorColor)
                Text(T("嘟嘟星亮了 {0}/{1}", lit, MKStory.doors.count)).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text)
                ProgressView(value: Double(lit), total: Double(MKStory.doors.count)).tint(Self.doorColor).frame(maxWidth: 70)
                Text("·  " + chText).font(.system(size: 11)).foregroundStyle(Theme.text2).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.text3)
            }
            .padding(.horizontal, 10).frame(height: 24)
            .background(Color(hex: "#2E2350").opacity(0.85), in: Capsule())
        }
        .buttonStyle(.press)
        .sheet(isPresented: $showMap) { MKCluesView(store: store) }
        .sheet(isPresented: $showDebug) { MKDebugView(store: store) }
    }

    /// 满贯条：5 格，交一单亮一格，满了掉福袋。永远「就差几单」
    private var streakMeter: some View {
        let k = (store.s.streak ?? 0) % 5
        return HStack(spacing: 2) {
            MKIcon(id: "luckybag").frame(width: 16, height: 16)
            ForEach(0..<5, id: \.self) { j in
                Capsule().fill(j < k ? Theme.coin : Color.white.opacity(0.15)).frame(width: 7, height: 10)
            }
        }
        .padding(.horizontal, 7).frame(height: 24)
        .background(Color(hex: "#2E2350").opacity(0.85), in: Capsule())
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: k)
    }

    // 顶栏：等级、体力、宝石、星星、币
    private var topBar: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(T("{0} 级", store.s.level)).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accent)
                    #if DEBUG
                    .onTapGesture(count: 7) { showDebug = true }   // 测试面板，只在开发版
                    #endif
                ProgressView(value: Double(store.s.xp), total: Double(MK.xpNeed(store.s.level))).tint(Theme.accent).frame(width: 44)
            }
            Spacer(minLength: 0)
            if store.boosting {
                pill("bolt.fill", "∞", Theme.coin, sub: T("无限 ") + mmss(store.boostLeft))
            } else {
                pill("bolt.fill", "\(store.s.energy)", Theme.coin, sub: store.nextEnergyIn > 0 ? mmss(Double(store.nextEnergyIn)) : nil)
            }
            if store.s.level >= MKStore.doubleLevel {
                Button { store.toggleDouble() } label: {
                    HStack(spacing: 1) {
                        Image("mk_x2").resizable().scaledToFit().frame(width: 20, height: 20)
                            .saturation(store.double ? 1 : 0.2).opacity(store.double ? 1 : 0.7)
                        Text("×2").font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(store.double ? Color.black : Theme.text2)
                    }
                        .frame(width: 48, height: 32)
                        .background(store.double ? Theme.coin : Theme.surface, in: Capsule())
                        .overlay(Capsule().stroke(Theme.coin.opacity(store.double ? 0 : 0.5), lineWidth: 1))
                        .shadow(color: store.double ? Theme.coin.opacity(0.7) : .clear, radius: 6)
                }
                .buttonStyle(.press)
            }
            Button { sheet = .gems } label: { pill("diamond.fill", "\(store.s.gems)", Self.gemColor) }.buttonStyle(.press)
            pill("star.fill", "\(store.s.stars)", Self.starColor)
            pill("circle.circle.fill", Self.short(profile.profile.coins), Theme.coin)
            Menu {
                Toggle(T("背景音乐"), isOn: Binding(get: { MKMusic.on }, set: { MKMusic.on = $0 }))
                Toggle(T("音效"), isOn: Binding(get: { MKSfx.on }, set: { MKSfx.on = $0 }))
                Toggle(T("震动"), isOn: Binding(get: { MKSfx.hapticsOn }, set: { MKSfx.hapticsOn = $0 }))
                Toggle(T("静音模式也出声"), isOn: Binding(get: { MKSfx.ignoreSilent }, set: { MKSfx.ignoreSilent = $0; MKMusic.start() }))
                Button(T("试听音效")) { MKSfx.play("discover") }
                Divider()
                Button(T("重看开场故事")) { store.introPage = 0; store.intro = true }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text2)
                    .frame(width: 30, height: 32).background(Theme.surface, in: Circle())
            }
            if !embedded {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                        .frame(width: 32, height: 32).background(Theme.surface, in: Circle())
                }
                .buttonStyle(.press)
            }
        }
        .padding(.top, 6)
    }
    /// 1 万以上写成 12.3k（顶栏放不下五位数）
    static func short(_ n: Int) -> String {
        guard n >= 10000 else { return "\(n)" }
        let k = Double(n) / 1000
        return k >= 100 ? "\(Int(k))k" : String(format: "%.1fk", k)
    }
    private func pill(_ sym: String, _ v: String, _ c: Color, sub: String? = nil) -> some View {
        HStack(spacing: 3) {
            Image(systemName: sym).font(.system(size: 11)).foregroundStyle(c)
            VStack(alignment: .leading, spacing: 0) {
                // 自测发现：20 级时顶栏挤，金币「1280」被折成两行。只许一行，挤了就缩小一点
                Text(v).font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundStyle(Theme.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.numericText()).animation(.snappy, value: v)
                if let sub { Text(sub).font(.system(size: 8)).monospacedDigit().foregroundStyle(Theme.text3) }
            }
        }
        .padding(.horizontal, 8).frame(height: 32).background(Theme.surface, in: Capsule())
    }

    // 它 + 订单（左右滑）
    private var petAndOrders: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 16).fill(Color.black)
                VideoPetView(pet: pet, pose: .stand, frame: petFrame, size: 84, clip: petClip, fitShell: true)
                    .id(petClip ?? petFrame)
            }
            .frame(width: 88, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomLeading) {
                if let say = store.petSay {
                    Text(say.text).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.black)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 220, alignment: .leading)
                        // 挂在头像正下方（盖在台面最上面那排纸箱上），不再压住右边的订单卡
                        .offset(x: 4, y: 40)
                        .transition(.scale(scale: 0.6, anchor: .topLeading).combined(with: .opacity))
                        .id(say.id)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(2)
            // 卡宽 = 可见区刚好放下 3 张：一页一页停，左边永远是一整张卡，不会半张缩在头像旁边
            GeometryReader { geo in
            let cw = max(76, floor((geo.size.width - 12) / 3))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(shownOrders) { o in
                        orderCard(o, width: cw)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .scale(scale: 1.25).combined(with: .opacity)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: shownOrders.map(\.id))
                .scrollTargetLayout()
            }
            .onAppear { orderW = cw }
            .onChange(of: cw) { _, w in orderW = w }
            // 一张一张对齐停，不会停在半张卡上、被它的头像挡住一半
            .scrollTargetBehavior(.viewAligned)
            .clipShape(Rectangle())
            }
        }
        .frame(height: 104)
        .overlay(alignment: .topLeading) {
            ForEach(store.floaters) { f in MKFloatView(text: f.text).position(x: f.x, y: 52) }
        }
    }

    /// 能交的单排到最前（其余保持原来的顺序）
    private var shownOrders: [MKOrder] {
        let os = store.s.orders
        let ready = os.filter { store.canServe($0) }
        return ready + os.filter { o in !ready.contains { $0.id == o.id } }
    }

    private var waiting: Bool { store.s.orders.contains { $0.isPet } }
    private var happy: Bool { (store.petHappyUntil ?? .distantPast) > now }
    /// 优先级：在吃 > 开心 > 饿着等饭 > 躺壳里睡
    private var petClip: String? {
        if let e = eating { return "eat_" + e }
        if let w = store.wowUntil, w > now, MKClips.has("shopx_wow") { return "shopx_wow" }
        if let c = store.cashUntil, c > now, MKClips.has("shopx_cashier") { return "shopx_cashier" }
        if happy { return "happy" }
        if waiting { return nil }
        // 平时：在柜台后面轮着来——打瞌睡、看小票打哈欠、偷吃样品、躺壳里睡
        let idle = ["shell_sleep", "shop_apron", "shop_ticket", "shopx_taste"].filter { $0 == "shell_sleep" || MKClips.has($0) }
        return idle[Int(now.timeIntervalSince1970 / 20) % idle.count]
    }
    private var petFrame: String { eating == nil && !happy && waiting ? "hungry" : "" }

    private func orderCard(_ o: MKOrder, width: CGFloat = 84) -> some View {
        let ok = store.canServe(o)
        let small = o.items.count > 1
        let total: Int = o.items.map { MK.value($0) }.reduce(0, +)
        return VStack(spacing: 3) {
            Text(o.isPet ? T("{0}的{1}", Voice.petName, o.meal) : (o.rushUntil.map { "⏱ " + mmss($0.timeIntervalSince(now)) + T(" 急单") } ?? o.meal)).font(.system(size: 9, weight: .semibold)).lineLimit(1)
                .foregroundStyle(o.isRush ? Self.rushColor : o.isDoor ? Self.doorColor : o.isPet || o.isSignature || o.isBig ? Theme.coin : (o.isEvent ? Theme.joy : (o.regular != nil ? Theme.accent : (o.gems > 0 ? Self.gemColor : Theme.text3))))
            HStack(spacing: 2) {
                ForEach(Array(o.items.enumerated()), id: \.offset) { pair in
                    MKIcon(id: pair.element).frame(width: small ? 24 : 40, height: small ? 24 : 40)
                        .overlay(alignment: .topLeading) {
                            // 菜：左上角挂一个小厨具图标，点卡片看配方
                            if let r = MK.recipe(pair.element) {
                                MKIcon(id: r.at).frame(width: small ? 11 : 15, height: small ? 11 : 15)
                                    .padding(1).background(Color.black.opacity(0.55), in: Circle()).offset(x: -3, y: -3)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            // 要几级：和台面上的数字一样，看得出「还得再合几次」
                            if MK.chain(pair.element) != nil {
                                Text("\(MK.tier(pair.element))").font(.system(size: 8, weight: .heavy)).foregroundStyle(Color.black)
                                    .frame(width: 13, height: 13).background(Theme.coin, in: Circle())
                                    .offset(x: 3, y: 2)
                            }
                        }
                }
            }
            .frame(height: 40)
            HStack(spacing: 4) {
                Label("\(o.stars)", systemImage: "star.fill").foregroundStyle(Self.starColor)
                if o.gems > 0 { Label("\(o.gems)", systemImage: "diamond.fill").foregroundStyle(Self.gemColor) }
            }
            .font(.system(size: 9, weight: .bold))
            Button { serve(o) } label: {
                Text(ok ? T("交") : T("+{0} 币", MK.orderCoins(total) * (o.isPet || o.isSpecial ? 2 : 1)))
                    .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity, minHeight: 22)
                    .background(ok ? Theme.coin : Theme.surface2, in: Capsule())
                    .foregroundStyle(ok ? Color.black : Theme.text3)
            }
            .buttonStyle(.press).disabled(!ok)
        }
        .padding(5)
        .contentShape(Rectangle())
        .onTapGesture {
            if let d = o.items.first(where: { MK.recipe($0) != nil }) { withAnimation(.easeOut(duration: 0.2)) { store.recipeShow = d } }
            if let d = o.door, d <= MKStory.doors.count {
                store.say(T("🌙 嘟嘟星 · ") + MKStory.doors[d - 1].name + T("：") + MKStory.doors[d - 1].note)
            }
            if let r = MKStory.regular(o.regular) {
                let k = min(r.notes.count - 1, store.s.regulars?[r.key] ?? 0)
                store.say(r.icon + " " + r.who + T("：") + r.notes[k])
            }
        }
        .overlay(alignment: .topTrailing) {
            if !o.isPet, !o.isEvent, !o.isSpecial, !ok {
                Button { store.swap(o) } label: {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(store.swapCost(o) == 0 ? Theme.text2 : Self.gemColor)
                        .frame(width: 18, height: 18).background(Theme.surface2, in: Circle())
                }
                .buttonStyle(.press).padding(2)
            }
        }
        .frame(width: width, height: 104)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(o.isDoor ? Color(hex: "#2E1F4F") : o.isPet ? Color(hex: "#3A2F1C") : (o.isSignature ? Color(hex: "#3D2A18") : Theme.surface))
                if !o.isPet, UIImage(named: "ui_ticket") != nil {
                    Image("ui_ticket").resizable().opacity(0.16).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(o.isRush ? Self.rushColor : o.isDoor ? Self.doorColor : o.isPet || o.isSignature || o.isBig ? Theme.coin : (o.isEvent ? Theme.joy : (ok ? Theme.coin.opacity(0.7) : (o.gems > 0 ? Self.gemColor.opacity(0.6) : Color.clear))), lineWidth: o.isPet || o.isSpecial ? 2.5 : 2))
        .modifier(MKReadyBounce(on: ok))
    }

    private func serve(_ o: MKOrder) {
        let idx = CGFloat(shownOrders.firstIndex { $0.id == o.id } ?? 0)
        store.orderSlot = (Int(idx), orderW)
        guard let r = store.serve(o) else { return }
        store.coinsEarned += r.coins
        store.float(T("+{0}币  +{1}★", r.coins, o.stars * (store.lucky ? 2 : 1)), x: 94 + orderW / 2 + idx * (orderW + 6))
        MKSfx.notify(.success)
        if let d = o.door, d <= MKStory.doors.count {
            let door = MKStory.doors[d - 1]
            store.react([MKStory.doorLit[d - 1]], happy: true)
            store.storyLine = MKStoryShow(title: T("嘟嘟星 · {0}亮了", door.name), line: T("「{0}」\n\n门缝里的光，亮了一点。\n嘟嘟星已经亮了 {1} / {2} 个地方。", door.note, store.s.doorLit?.count ?? 1, MKStory.doors.count))
            return
        }
        if o.isSignature {
            store.react([T("招牌菜！整条街都闻到了。"), T("今天的招牌，卖完了。明天再来。"), T("这道……我也想要一份。")], happy: true)
            return
        }
        guard r.pet else {
            store.cashUntil = Date().addingTimeInterval(4.5)
            switch store.s.ticketsServed ?? 0 {
            case 1:
                store.say(T("📮 楼上：好香……明天还要。"))
                store.react([T("钱！……再做一个。"), T("不，十个。")], happy: true); return
            case 2:
                store.say(T("📮 楼上：隔壁闻到了，也要一份。"))
                store.react([T("隔壁也要？……那得多做点。我负责数钱。")], happy: true); return
            case 3:
                store.storyLine = MKStoryShow(title: T("嘟嘟小店，开张了"), line: MKStory.signLine); return
            default: break
            }
            let lazy = [T("这单我替你记着。"), T("又是{0}？他们真能吃。", o.meal.replacingOccurrences(of: T("外卖 · "), with: "")), T("钱放我肚子上就行。"), T("送完了？我刚睡醒，正好。"), T("我负责收钱，你负责别的，分工明确。")]
            // 外卖客人有名字、会回一句话：每个地址住着固定的人
            let dest = o.meal.replacingOccurrences(of: T("外卖 · "), with: "").replacingOccurrences(of: T("⏱ 急单 · "), with: "")
            if Int.random(in: 0..<2) == 0, let who = MKStory.takeoutFolks[dest], let line = who.lines.randomElement() {
                store.say("📮 " + who.name + T("：") + line)
            }
            store.react(lazy)
            store.cashUntil = Date().addingTimeInterval(4.5)
            return
        }
        onServe(r.coins, r.food)
        withAnimation { eating = r.food }
        store.react([T("好吃！"), T("就是这个味。"), T("你做的，最好吃。")])

        let food = r.food
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) { if eating == food { withAnimation { eating = nil } } }
    }

    // 棋盘
    private func board(side: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Color(hex: "#221C35"))
                // 不再铺木板纹理：木板缝在格子之间看着像几条黑线
                // 柜台台面：上亮下暗一层光，像木头台面被灯照着
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.07), .clear, Color.black.opacity(0.18)], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(colors: [Color(hex: "#CDBAF5").opacity(0.45), Color(hex: "#5B4B86").opacity(0.4)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
            }
            .frame(width: side * CGFloat(MK.cols) + 8, height: side * CGFloat(MK.rows) + 8)
            .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: 0), count: MK.cols), spacing: 0) {
                // 每次刷新只算一次（以前每一格都各自扫一遍棋盘和订单）
                let ctx = BoardCtx(target: dragTarget(side), hint: hintPair,
                                   dragID: dragFrom.flatMap { store.s.board[$0].item },
                                   need: Set(store.s.orders.flatMap(\.items)),
                                   ingr: Set(store.s.orders.flatMap { $0.items.flatMap(MK.allNeeds) }))
                ForEach(0..<(MK.cols * MK.rows), id: \.self) { i in cell(i, side: side, ctx: ctx) }
            }
            .padding(4)
            if let f = dragFrom, let id = store.s.board[f].item {
                // 拿起来的东西：放大、带影子、微微歪一点，浮在手指上方
                MKIcon(id: id).frame(width: side * 1.35, height: side * 1.35)
                    .shadow(color: .black.opacity(0.55), radius: 10, y: 8)
                    .rotationEffect(.degrees(-6))
                    .position(x: dragAt.x, y: dragAt.y - side * 0.45)
                    .allowsHitTesting(false)
            }
            ForEach(store.fx) { f in fxView(f, side: side) }
            tutorial(side: side)
            cookCoach(side: side)
            earlyCoach(side: side)
        }
        .frame(width: side * CGFloat(MK.cols) + 8, height: side * CGFloat(MK.rows) + 8)
        .coordinateSpace(name: "board")
        .modifier(MKShake(amount: CGFloat(store.shake)))
        .animation(.linear(duration: 0.35), value: store.shake)
        .frame(maxWidth: .infinity)
    }

    /// 拖动时手指下面那一格；一样的东西就发光（能合）
    private func dragTarget(_ side: CGFloat) -> Int? {
        guard let f = dragFrom, let id = store.s.board[f].item else { return nil }
        let c = Int(floor((dragAt.x - 4) / side)), r = Int(floor((dragAt.y - 4 - side * 0.45) / side))
        guard c >= 0, c < MK.cols, r >= 0, r < MK.rows else { return nil }
        let k = r * MK.cols + c
        guard k != f, let t = store.s.board[k].item, !store.s.board[k].boxed else { return nil }
        return (t == id || MK.isAppliance(t) || id == "wildcard") ? k : nil
    }
    /// 发呆 8 秒：两个能合的轻轻闪（同类游戏都有这个提示）
    private var hintPair: (Int, Int)? {
        // 前 5 级：发呆 3 秒就提示（新手不知道下一步干嘛）；之后 8 秒
        guard store.idleSeconds > (store.s.level <= 5 ? 3 : 8), dragFrom == nil, store.tutStep >= 99 else { return nil }
        _ = now
        return mergePair()
    }
    private func center(_ i: Int, _ side: CGFloat) -> CGPoint {
        CGPoint(x: 4 + CGFloat(i % MK.cols) * side + side / 2, y: 4 + CGFloat(i / MK.cols) * side + side / 2)
    }
    @ViewBuilder private func fxView(_ f: MKFX, side: CGFloat) -> some View {
        switch f.kind {
        case .burst:
            MKBurst(tier: f.tier, color: MK.chain(f.item ?? "").map { MKBurst.tint($0.key) }).frame(width: side, height: side).position(center(f.from, side))
        case .combo:
            MKComboText(n: f.tier).position(center(f.from, side)).offset(y: -side * 0.55)
        case .merge:
            if let it = f.item { MKMergeIn(item: it, size: side * 0.86).position(center(f.from, side)) }
        case .fly:
            if let to = f.to, let it = f.item {
                MKFlight(item: it, from: center(f.from, side), to: center(to, side), size: side * 0.8)
            }
        case .serve:
            if let it = f.item {
                // 飞向上面的订单卡（订单行在棋盘上方约 60pt）
                // 订单行从 x=94 开始（行坐标）；棋盘居中，换算到棋盘坐标要减去棋盘左边的空白
                let x = 94 + store.orderSlot.w / 2 + CGFloat(store.orderSlot.k) * (store.orderSlot.w + 6) - ((gw - 24) - (side * CGFloat(MK.cols) + 8)) / 2
                MKFlight(item: it, from: center(f.from, side), to: CGPoint(x: x, y: -60), size: side * 0.9, shrink: true)
            }
        }
    }

    /// 前 5 级的接力引导（2026-10-22，教学做完以后）：发呆 3 秒——
    /// 有单能交 → 小手指向上面的订单；没东西能合 → 订单要的那条链的产出器在格子里闪，小手点它
    @ViewBuilder private func earlyCoach(side: CGFloat) -> some View {
        if store.tutStep >= 99, store.s.level <= 5, store.idleSeconds > 3, dragFrom == nil, store.levelUp == nil, store.welcome == nil, !store.intro,
           mergePair() == nil {
            let _ = now
            if store.s.orders.contains(where: { store.canServe($0) }) {
                MKHand(from: CGPoint(x: 130, y: -24), to: nil)
            } else if store.s.energy > 0 || store.boosting {
                let chains = Set(store.s.orders.flatMap(\.items).compactMap { MK.chain($0)?.key })
                let gens = store.s.board.indices.filter { k in
                    guard let id = store.s.board[k].item, MK.isGen(id), !store.s.board[k].boxed, store.s.board[k].charges > 0 else { return false }
                    return chains.isEmpty || chains.contains(String(id.dropFirst(4)))
                }
                if let g = gens.first {
                    MKRing(side: side).position(center(g, side))
                    MKHand(from: center(g, side), to: nil)
                }
            }
        }
    }

    /// 新手引导：一只小手 + 一句话，不挡操作
    /// 第一次做菜的小教学：订单要一道菜、还没做过菜时，圈出厨具和台面上的食材，手指从食材拖到厨具
    @ViewBuilder private func cookCoach(side: CGFloat) -> some View {
        if store.tutStep >= 99, store.levelUp == nil, store.welcome == nil, !store.intro, dragFrom == nil,
           !store.s.found.contains(where: { $0.hasPrefix("dish_") }),
           let r = store.s.orders.lazy.flatMap(\.items).compactMap(MK.recipe).first(where: { MK.can($0, store.s.level) }),
           store.s.cooks[r.at]?.dish == nil,
           let ap = store.s.board.firstIndex(where: { $0.item == r.at }) {
            let w = side * CGFloat(MK.cols) + 8
            let put = store.s.cooks[r.at]?.putIn ?? []
            let have = r.needs.filter { !put.contains($0) }.compactMap { n in store.s.board.firstIndex { $0.item == n && !$0.boxed } }
            ZStack(alignment: .topLeading) {
                HStack(spacing: 10) {
                    Text("🍲").font(.system(size: 20)).frame(width: 34, height: 34).background(Color.black.opacity(0.85), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("第一次做菜")).font(.system(size: 10, weight: .bold)).foregroundStyle(Color.black.opacity(0.55))
                        Text(T("订单要「{0}」：把 {1} 拖进{2}，等它做好", r.name, r.needs.map(MK.name).joined(separator: T(" 和 ")), MK.name(r.at)))
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(Color.black).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(width: min(w - 24, 330))
                .background(Theme.coin, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .position(x: w / 2, y: side * (ap / MK.cols >= 5 ? 1.2 : 7.6))
                MKRing(side: side).position(center(ap, side))
                ForEach(have, id: \.self) { k in MKRing(side: side).position(center(k, side)) }
                if let f = have.first { MKHand(from: center(f, side), to: center(ap, side)) }
            }
            .allowsHitTesting(false)
        }
    }
    @ViewBuilder private func tutorial(side: CGFloat) -> some View {
        let step = store.tutStep
        if step < 99, store.welcome == nil, !store.intro, store.loginGift == nil, store.levelUp == nil {
            let text: String = {
                switch step {
                case 0: return store.boosting ? T("点一下米袋，掉出一粒米（无限体力中，不花体力）") : T("点一下米袋，掉出一粒米（花 1 点体力）")
                case 1: return T("两个一样的拖到一起，合成更高级的")
                case 2: return T("合出订单上要的东西，点上面黄色的「交」")
                default: return T("在纸箱旁边合成一次，纸箱就会打开")
                }
            }()
            let w = side * CGFloat(MK.cols) + 8
            ZStack(alignment: .topLeading) {
                // 教学卡：大一点、带步数，放在台面中间偏下，不挡要点的格子
                HStack(spacing: 10) {
                    Text("\(min(step, 3) + 1)/4").font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.coin)
                        .frame(width: 34, height: 34).background(Color.black.opacity(0.85), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("新手教学")).font(.system(size: 10, weight: .bold)).foregroundStyle(Color.black.opacity(0.55))
                        Text(text).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.black)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(width: min(w - 24, 330))
                .background(Theme.coin, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .position(x: w / 2, y: side * 4.6)
                if step == 0, let g = store.s.board.firstIndex(where: { $0.item == "gen_rice" }) {
                    MKRing(side: side).position(center(g, side))
                    MKHand(from: center(g, side), to: nil)
                } else if step == 1, let pair = mergePair() {
                    MKRing(side: side).position(center(pair.0, side))
                    MKRing(side: side).position(center(pair.1, side))
                    MKHand(from: center(pair.0, side), to: center(pair.1, side))
                } else if step == 2 {
                    MKHand(from: CGPoint(x: 130, y: -24), to: nil)
                }
            }
            .allowsHitTesting(false)
            .overlay(alignment: .topTrailing) {
                // 玩过这类游戏的人可以跳过（放在最上面纸箱那一行，不挡要点的格子）
                Button { store.skipTutorial() } label: {
                    Text(T("跳过教学")).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text2)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.black.opacity(0.7), in: Capsule())
                }
                .buttonStyle(.press)
                .padding(6)
            }
        }
    }
    private func mergePair() -> (Int, Int)? {
        var seen: [String: Int] = [:]
        for (i, sl) in store.s.board.enumerated() where !sl.boxed && sl.bubbleUntil == nil {
            guard let id = sl.item, MK.chain(id) != nil else { continue }
            if let j = seen[id] { return (j, i) }
            seen[id] = i
        }
        return nil
    }

    struct BoardCtx { let target: Int?; let hint: (Int, Int)?; let dragID: String?; let need: Set<String>; let ingr: Set<String> }
    @ViewBuilder private func cell(_ i: Int, side: CGFloat, ctx: BoardCtx) -> some View {
        let slot = store.s.board[i]
        let target = ctx.target == i
        let hint = ctx.hint?.0 == i || ctx.hint?.1 == i
        // 拖着东西时：台面上所有一样的（能合的）都亮一圈，一眼看到往哪放
        let dragID = ctx.dragID
        let match = dragID != nil && dragFrom != i && !slot.boxed && slot.bubbleUntil == nil && slot.item == dragID
        ZStack {
            // 凹进去的小格子（不再用棋盘格）
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Color.black.opacity(0.34), Color.black.opacity(0.16)], startPoint: .top, endPoint: .bottom))
                // 凹槽：上沿暗、下沿一道亮边
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                    LinearGradient(colors: [Color.black.opacity(0.35), Color.white.opacity(0.10)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.selected == i ? Theme.coin : (target ? Color.white : Color.clear), lineWidth: target ? 2.5 : 2))
                .shadow(color: target ? Theme.coin.opacity(0.8) : .clear, radius: 8)
                .padding(2)
            if hint {
                RoundedRectangle(cornerRadius: 10).fill(Theme.coin.opacity(store.s.level <= 5 ? 0.34 : 0.18)).padding(2)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.coin.opacity(store.s.level <= 5 ? 0.9 : 0), lineWidth: 2.5).padding(2))
                    .modifier(MKPulse())
            }
            if match && !target {
                RoundedRectangle(cornerRadius: 10).stroke(Theme.coin.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [5, 3])).padding(2)
            }
            if target {
                RoundedRectangle(cornerRadius: 10).fill(Theme.coin.opacity(0.28)).padding(2)
            }
            if slot.boxed {
                MKIcon(id: "box").padding(side * 0.04)
            } else if let id = slot.item, dragFrom != i {
                itemView(i, slot, id, side: side, need: ctx.need.contains(id), ingr: ctx.ingr.contains(id))
                    .id(id)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            } else if let id = slot.item {
                // 被拿起来的那一格：留个淡淡的影子，知道是从哪拿的
                MKIcon(id: id).padding(side * 0.12).opacity(0.22)
            }
        }
        .scaleEffect(target ? 1.1 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: target)
        .animation(.spring(response: 0.32, dampingFraction: 0.55), value: slot.item)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .onTapGesture { store.tap(i) }
        .gesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("board"))
            .onChanged { v in
                guard store.s.board[i].item != nil, !store.s.board[i].boxed, store.s.board[i].bubbleUntil == nil else { return }
                if dragFrom == nil { MKSfx.impact(.light) }
                dragFrom = i
                dragAt = v.location
                let t = dragTarget(side)
                if t != lastTarget { if t != nil { UISelectionFeedbackGenerator().selectionChanged() }; lastTarget = t }
            }
            .onEnded { v in
                guard dragFrom != nil else { return }
                let c = Int(floor((v.location.x - 4) / side))
                let r = Int(floor((v.location.y - 4 - side * 0.45) / side))
                if c >= 0, c < MK.cols, r >= 0, r < MK.rows { store.drop(from: i, to: r * MK.cols + c) }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragFrom = nil }
                lastTarget = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { store.pulse = nil }
            })
    }

    private func itemView(_ i: Int, _ slot: MKSlot, _ id: String, side: CGFloat, need: Bool, ingr: Bool) -> some View {
        let bubble = slot.bubbleUntil != nil
        let tier = MK.chain(id) != nil ? MK.tier(id) : 0
        return ZStack {
            if MK.isGen(id) && !bubble {
                // 产出器脚下一圈暖光：一眼看出「东西从这里出来」
                Ellipse().fill(RadialGradient(colors: [Theme.coin.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: side * 0.42))
                    .frame(width: side * 0.86, height: side * 0.36).offset(y: side * 0.28)
            }
            if tier >= 8 && !bubble {
                Circle().fill(RadialGradient(colors: [(tier == MK.maxTier ? Theme.coin : Color(hex: "#CDBAF5")).opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: side * 0.5))
                    .modifier(MKPulse())
            }
            MKIcon(id: id).padding(side * (bubble ? 0.2 : 0.07)).opacity(bubble ? 0.85 : 1)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            if bubble { MKIcon(id: "bubble").modifier(MKWobble()) }
        }
        .overlay(alignment: .bottomTrailing) { badge(slot, id) }
        .overlay(alignment: .topTrailing) {
            if !bubble, need {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.clean).padding(2)
            } else if !bubble, !slot.boxed, ingr {
                // 单子里那道菜要用到它：浅一点的勾
                Image(systemName: "checkmark.circle").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.clean.opacity(0.75)).padding(2)
            }
        }
        .overlay(alignment: .topLeading) {
            if MK.isGen(id), slot.glv > 1 {
                Text("Lv\(slot.glv)").font(.system(size: 7, weight: .heavy)).foregroundStyle(Self.gemColor).padding(3)
            }
        }
        .scaleEffect(store.pulse == i ? 1.26 : (store.opening == i ? 1.12 : 1))
        // 抖三下 = amount 走过 1 个整数；每格都跟着 deniedTick 走，只有被拒的那格带动画（其他格整数跳变不偏移）
        .modifier(MKDenyShake(amount: CGFloat(store.deniedTick) + (store.opening == i ? 1 : 0)))
        .animation(store.denied == i || store.opening == i ? .linear(duration: store.opening == i ? 0.5 : 0.35) : nil,
                   value: store.deniedTick + (store.opening == i ? 100_000 : 0))
        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: store.pulse)
    }

    @ViewBuilder private func badge(_ slot: MKSlot, _ id: String) -> some View {
        if MK.isGen(id) {
            if slot.charges > 0 { tag("\(slot.charges)", Theme.coin, dark: true) }
            else if let at = slot.refillAt { tag("⏳" + mmss(at.timeIntervalSince(now)), Theme.surface2, dark: false) }
            else { tag("⏳", Theme.surface2, dark: false) }
        } else if MK.isAppliance(id), let c = store.s.cooks[id], let at = c.doneAt {
            tag(now >= at ? T("好了") : mmss(at.timeIntervalSince(now)), now >= at ? Theme.coin : Theme.surface2, dark: now >= at)
        } else if MK.isAppliance(id), let c = store.s.cooks[id], !c.putIn.isEmpty {
            tag("\(c.putIn.count)/\(putInNeed(id, c))", Theme.surface2, dark: false)
        } else if let at = slot.openAt {
            tag(now >= at ? T("开") : mmss(at.timeIntervalSince(now)), now >= at ? Theme.coin : Theme.surface2, dark: now >= at)
        } else if let b = slot.bubbleUntil {
            tag("\(max(0, Int(b.timeIntervalSince(now))))s", Self.gemColor, dark: true)
        } else if MK.chain(id) != nil {
            let t = MK.tier(id)
            // 等级越高底色越亮：1–3 灰、4–6 薄荷、7–9 薰衣草、10 金
            let c: Color = t >= MK.maxTier ? Theme.coin : (t >= 7 ? Color(hex: "#B9A6E8") : (t >= 4 ? Theme.clean : Color.black.opacity(0.45)))
            Text("\(t)").font(.system(size: 8, weight: .heavy)).foregroundStyle(t >= 4 ? Color.black : Color.white.opacity(0.92))
                .frame(width: 13, height: 13).background(c, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
        }
    }
    /// 厨具里正在拼的那道菜一共要几样（三样料的菜显示 x/3）
    private func putInNeed(_ id: String, _ c: MKCook) -> Int {
        let fits = MK.recipes.filter { r in r.at == id && MK.can(r, store.s.level) && c.putIn.allSatisfy { p in r.needs.contains(p) } }
        return fits.map { $0.needs.count }.min() ?? 2
    }
    private func tag(_ t: String, _ bg: Color, dark: Bool) -> some View {
        Text(t).font(.system(size: 8, weight: .bold)).padding(.horizontal, 3).frame(minWidth: 14, minHeight: 13)
            .background(bg, in: Capsule()).foregroundStyle(dark ? Color.black : Theme.text)
    }
    private func mmss(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return s >= 60 ? "\(s / 60):\(String(format: "%02d", s % 60))" : "\(s)s"
    }

    // 选中东西时的信息栏
    @ViewBuilder private var infoBar: some View {
        if let i = store.selected, i < store.s.board.count, let id = store.s.board[i].item, !store.s.board[i].boxed {
            selectedBar(i, id, store.s.board[i])
        } else if store.boardFull && !store.s.board.contains(where: { $0.item == nil && !$0.boxed }) {
            HStack(spacing: 8) {
                Text(T("台子满了")).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                Text(T("背包 {0}/{1}", store.s.bag.count, store.s.bagSlots)).font(.system(size: 11)).foregroundStyle(Theme.text3)
                Spacer()
                smallBtn(T("一键收纳")) { store.stowIdle() }
                smallBtn(T("打开背包")) { sheet = .bag }
            }
            .padding(.horizontal, 12).frame(maxHeight: .infinity).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        } else if store.lastSold != nil {
            HStack {
                Text(T("刚卖了一样东西")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                Spacer()
                smallBtn(T("撤销")) { store.undoSell() }
            }
            .padding(.horizontal, 12).frame(maxHeight: .infinity).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        } else {
            // 计时卡一排（学同类上面那一排）：冲刺、今日目标、周榜、活动……长短倒计时叠在一起，什么时候打开都有一个快结束了
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if let sp = store.s.sprint {
                        if sp.done && !sp.claimed {
                            tcard("⚡", T("冲刺完成"), T("领 {0}", sp.rewardText), hot: true) { store.claimSprint() }
                        } else {
                            tcard("⚡", sp.title, "\(sp.progress)/\(sp.target) · " + left(sp.ends.timeIntervalSince(now)), progress: Double(sp.progress) / Double(max(1, sp.target))) {
                                store.say(T("限时冲刺：{0}，做完领{1}。", sp.title, sp.rewardText))
                            }
                        }
                    } else if store.s.level >= 3, let nx = store.s.sprintNext, nx > now {
                        tcard("⚡", T("下一个冲刺"), left(nx.timeIntervalSince(now))) { store.say(T("歇一会儿，下一个限时冲刺马上来。")) }
                    }
                    if let d = store.s.daily {
                        let got = d.goals.filter(\.claimed).count
                        tcard("🎯", T("今日目标"), "\(got)/\(d.goals.count) · " + left(Self.untilMidnight(now)), hot: store.dailyClaimable, progress: Double(d.goals.filter(\.done).count) / Double(max(1, d.goals.count))) { sheet = .tasks }
                    }
                    if !MKDemo.on {
                        tcard("🏆", T("周榜"), gc.authed ? ((gc.rank.map { T("第 {0} 名", $0) } ?? T("{0} 单", gc.score)) + (gc.ends.map { " · " + left($0.timeIntervalSince(now)) } ?? "")) : T("点我上榜")) { gc.show() }
                    }
                    if store.s.level >= 3 {
                        let lv = store.seasonLv, pts = store.seasonPts
                        tcard("🌟", T("季卡 {0} 级", lv), lv >= MKSeason.tiers ? T("满级") : "\(pts - lv * MKSeason.tierCost)/\(MKSeason.tierCost) · " + left(MKSeason.ends().timeIntervalSince(now)),
                              progress: lv >= MKSeason.tiers ? 1 : Double(pts - lv * MKSeason.tierCost) / Double(MKSeason.tierCost)) { sheet = .season }
                    }
                    if let e = MKEvent.current() {
                        tcard("🧺", e.def.name, (MKEvent.endDate().map { MKEvent.left($0) } ?? ""), hot: (store.s.event?.points ?? 0) < MKEvent.goal, progress: Double(store.s.event?.points ?? 0) / Double(MKEvent.goal)) { sheet = .tasks }
                    }
                    if store.lucky, let u = store.s.luckyUntil {
                        tcard("✨", T("好运"), T("星星翻倍 ") + mmss(u.timeIntervalSince(now)), hot: true) { }
                    }
                    if let sig = store.s.orders.first(where: { $0.isSignature }) {
                        tcard("🍲", T("今日招牌"), MK.name(sig.items[0]), hot: store.canServe(sig)) { }
                    } else if store.s.signatureDay == Wallet.day() {
                        tcard("🍲", T("今日招牌"), T("卖完了 ✓")) { }
                    }
                    if !MKDemo.on {
                        let im = Intimacy.load()
                        tcard("❤️", T("亲密度 · {0}", im.tier.name), im.bonus > 0 ? T("爆率 +{0}%", Int(im.bonus * 100)) : T("还没加成"), progress: im.value / 100) {
                            store.say(T("亲密度 {0}（{1}/100）：它饿了渴了脏了闷了，你及时管它就涨；让它饿到底就掉。越亲密，小店里掉好东西越多。", im.tier.name, Int(im.value))
                                      + (im.next.map { T(" 到 {0} 爆率 +{1}%。", $0.name, Int($0.bonus * 100)) } ?? ""))
                        }
                    }
                    tcard("🎞️", T("拍立得"), (store.s.packs ?? 0) > 0 ? T("{0} 包没开", store.s.packs ?? 0) : "\(store.cardsOwned)/\(MKCards.all.count)", hot: (store.s.packs ?? 0) > 0) { sheet = .album }
                    tcard(MKWeek.current.icon, T("本周 · {0}", MKWeek.current.name), T("相关的单 +1★")) {
                        store.say(MKWeek.current.icon + " " + MKWeek.current.name + T("：") + MKWeek.current.line + T(" 用到这些的单多给 1★：") + MKWeek.current.chains.compactMap { k in MK.chains.first { $0.key == k }?.genName }.joined(separator: T("、")) + T("。每周一换。"))
                    }
                    tcard("🔥", T("今天热卖"), store.focus.map(\.genName).joined(separator: T("、"))) {
                        store.say(T("今天热卖：") + store.focus.map(\.genName).joined(separator: T("、")) + (store.nextTask.map { T(" · 下一个装修 {0}★", $0.stars) } ?? ""))
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 计时卡：图标 + 标题 + 一行进度/倒计时，底下一条细进度
    private func tcard(_ icon: String, _ title: String, _ sub: String, hot: Bool = false, progress: Double? = nil, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 6) {
                Text(icon).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 11, weight: .bold)).lineLimit(1)
                    Text(sub).font(.system(size: 10, weight: .medium)).monospacedDigit().lineLimit(1).opacity(0.85)
                }
            }
            .padding(.horizontal, 8).frame(height: 44)
            .frame(minWidth: 96, alignment: .leading)
            .background(hot ? Theme.coin.opacity(0.92) : Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottom) {
                if let p = progress {
                    GeometryReader { g in
                        Capsule().fill(hot ? Color.black.opacity(0.35) : Theme.accent.opacity(0.8))
                            .frame(width: max(0, g.size.width * min(1, p)), height: 3)
                    }
                    .frame(height: 3).padding(.horizontal, 8).padding(.bottom, 3)
                }
            }
            .foregroundStyle(hot ? Color.black : Theme.text)
        }
        .buttonStyle(.press)
    }
    /// 倒计时：一小时以上写「2时41分」，以内写「12:05」
    private func left(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        if s >= 86400 { return T("{0}天{1}时", s / 86400, (s % 86400) / 3600) }
        if s >= 3600 { return T("{0}时{1}分", s / 3600, (s % 3600) / 60) }
        return mmss(t)
    }
    static func untilMidnight(_ now: Date) -> TimeInterval {
        let cal = Calendar.current
        let next = cal.startOfDay(for: now).addingTimeInterval(86400)
        return next.timeIntervalSince(now)
    }

    private func chip(_ icon: String, _ text: String, hot: Bool = false, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 3) { Text(icon); Text(text).lineLimit(1) }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8).frame(height: 24)
                .background(hot ? Theme.coin.opacity(0.9) : Theme.surface2, in: Capsule())
                .foregroundStyle(hot ? Color.black : Theme.text2)
        }
        .buttonStyle(.press)
    }

    private func selectedBar(_ i: Int, _ id: String, _ slot: MKSlot) -> some View {
        Group {
            if MK.isAppliance(id), store.s.cooks[id]?.dish == nil, (store.s.cooks[id]?.putIn ?? []).isEmpty,
               !MK.recipes.filter({ $0.at == id && MK.can($0, store.s.level) }).isEmpty {
                applianceBar(i, id)
            } else {
                plainSelectedBar(i, id, slot)
            }
        }
    }
    /// 选中厨具：横排图示配方（订单要的排前面、金边），点一个看详细
    private func applianceBar(_ i: Int, _ id: String) -> some View {
        let need = Set(store.s.orders.flatMap(\.items) + store.s.orders.flatMap { $0.items.flatMap(MK.allNeeds) })
        let rs = MK.recipes.filter { $0.at == id && MK.can($0, store.s.level) }.sorted { (need.contains($0.id) ? 0 : 1) < (need.contains($1.id) ? 0 : 1) }
        return HStack(spacing: 6) {
            MKIcon(id: id).frame(width: 30, height: 30)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(rs, id: \.id) { r in
                        Button { withAnimation(.easeOut(duration: 0.2)) { store.recipeShow = r.id } } label: {
                            MKRecipeRow(r: r, have: { x in store.s.board.contains { $0.item == x && !$0.boxed } }, size: 22, compact: true)
                                .padding(.horizontal, 6).frame(height: 38)
                                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(need.contains(r.id) ? Theme.coin : Color.clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.press)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
    private func plainSelectedBar(_ i: Int, _ id: String, _ slot: MKSlot) -> some View {
        HStack(spacing: 8) {
            MKIcon(id: id).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(MK.name(id) + (MK.isGen(id) ? T(" · {0} 级", slot.glv) : "")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                Text(hint(id, slot)).font(.system(size: 10)).foregroundStyle(Theme.text3).lineLimit(2)
            }
            Spacer(minLength: 0)
            actions(i, id, slot)
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private func actions(_ i: Int, _ id: String, _ slot: MKSlot) -> some View {
        if slot.bubbleUntil != nil {
            smallBtn(T("{0} 宝石拿下", store.bubbleCost(id))) { store.buyBubble(i) }
        } else if MK.isGen(id) {
            if slot.charges == 0 { smallBtn(T("2 宝石装满")) { store.refillGen(i) } }
            else if slot.glv < 3 { smallBtn(T("升级 {0}◆", store.genUpgradeCost(slot.glv))) { store.upgradeGen(i) } }
            smallBtn(T("收起")) { store.stash(i) }
        } else if let at = slot.openAt, now < at {
            smallBtn(T("{0} 宝石马上开", store.rushCost(at))) { store.rushChest(i) }
        } else if MK.chests[id] != nil {
            smallBtn(T("开箱")) { store.tap(i) }
        } else if MK.isAppliance(id) {
            if let at = store.s.cooks[id]?.doneAt, now < at { smallBtn(T("宝石加速")) { store.rushCook(id) } }
        } else if MK.recipe(id) != nil {
            smallBtn(T("🍱 带回家给它吃")) { if store.takeHome(i) { onTakeHome(id) } }
            smallBtn(T("卖 {0}", store.sellPrice(id))) { store.sell(i) }
        } else {
            smallBtn(T("收进包")) { store.stash(i) }
            smallBtn(T("卖 {0}", store.sellPrice(id))) { store.sell(i) }
        }
    }

    private func hint(_ id: String, _ slot: MKSlot) -> String {
        if let c = MK.chain(id) {
            let t = MK.tier(id)
            let use = MK.recipes.filter { $0.needs.contains(id) && MK.can($0, store.s.level) }.map(\.name)
            var s = t < MK.maxTier ? T("两个合成「{0}」", c.names[t]) : T("最高级了")
            if !use.isEmpty { s += T(" · 能做") + use.joined(separator: T("、")) }
            return s
        }
        if MK.isGen(id) {
            if slot.charges > 0 { return T("点一下花 1 体力，还能点 {0} 次；两个同级的合成升级", slot.charges) }
            return T("空了，{0} 分钟后装满", Int(((slot.refillAt ?? Date()).timeIntervalSinceNow) / 60) + 1)
        }
        if MK.isAppliance(id) {
            let rs = MK.recipes.filter { $0.at == id && MK.can($0, store.s.level) }
            if rs.isEmpty { return T("还没有能做的菜") }
            if let c = store.s.cooks[id], c.dish == nil, !c.putIn.isEmpty { return T("已经放了 ") + c.putIn.map(MK.name).joined(separator: T("、")) + T("。点一下拿出来") }
            return T("把食材拖进来：") + rs.map { "\($0.name)=" + $0.needs.map(MK.name).joined(separator: "+") }.joined(separator: T("；"))
        }
        if MK.recipe(id) != nil {
            let more = MK.recipes.filter { $0.needs.contains(id) && MK.can($0, store.s.level) }
            if let m = more.first { return T("做好的菜。还能拿去做「{0}」= ", m.name) + m.needs.map(MK.name).joined(separator: " + ") }
            return T("做好的菜，等它下单")
        }
        switch id {
        case "luckybag": return T("点开看看，里面随机一样，可能是大的")
        case "wildcard": return T("拖到任何食材上，直接升一级")
        case "scissors": return T("拖到食材上，剪成两个低一级的")
        case "gift": return T("点一下打开")
        case "chest2", "chest3": return T("点「开箱」开始计时")
        default: return T("点一下收下")
        }
    }
    private func smallBtn(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.system(size: 12, weight: .bold)).padding(.horizontal, 10).frame(height: 30)
                .background(Theme.accent, in: Capsule()).foregroundStyle(Color.black)
        }
        .buttonStyle(.press)
    }

    private var bottomBar: some View {
        let hot = store.nextTask.map { store.s.stars >= $0.stars } ?? false
        return HStack(spacing: 8) {
            barBtn("bag.fill", T("背包 {0}/{1}", store.s.bag.count, store.s.bagSlots), gate: .bag) { sheet = .bag }
            barBtn("storefront.fill", T("小铺"), gate: .shop) { sheet = .shop }
            barBtn("checklist", T("目标"), hot: store.dailyClaimable, gate: .tasks) { sheet = .tasks }
            barBtn("book.closed.fill", T("图鉴"), gate: .book) { sheet = .book }
            barBtn("paintbrush.fill", T("装修"), hot: hot) { sheet = .deco }
        }
        .padding(.bottom, 6)
    }
    /// 底栏入口按等级一个一个开（新手第一眼只看到「装修」），刚开的带「新」角标，点开过就消失
    static let gateLevel: [MKSheet: Int] = [.bag: 2, .tasks: 2, .shop: 3, .book: 3]
    private func barBtn(_ sym: String, _ t: String, hot: Bool = false, gate: MKSheet? = nil, _ a: @escaping () -> Void) -> some View {
        let need = gate.flatMap { Self.gateLevel[$0] } ?? 0
        // 老玩家（交过 40 单以上）不锁，免得更新后入口突然没了
        let locked = store.s.level < need && store.s.served < 40
        let fresh = gate != nil && !locked && need > 1 && store.s.served < 40 && !UserDefaults.standard.bool(forKey: "mk.seen." + (gate?.rawValue ?? ""))
        return Button {
            if locked { MKSfx.play("boop", volume: 0.5); store.say(T("{0} 级开放「{1}」。", need, t)); return }
            if let g = gate { UserDefaults.standard.set(true, forKey: "mk.seen." + g.rawValue) }
            MKSfx.play("button", volume: 0.5)
            a()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: locked ? "lock.fill" : sym).font(.system(size: 16))
                Text(locked ? T("{0} 级", need) : t).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(hot ? Color.black : (locked ? Theme.text3 : Theme.text))
            .background(hot ? Theme.coin : Theme.surface.opacity(locked ? 0.5 : 1), in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topTrailing) {
                if fresh {
                    Text(T("新")).font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2).background(Color(hex: "#FF5A7A"), in: Capsule())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.press)
    }

    @ViewBuilder private var popups: some View {
        if let id = store.recipeShow, let r = MK.recipe(id) {
            MKRecipePopup(recipe: r, store: store) { withAnimation { store.recipeShow = nil } }
                .transition(.opacity)
        }
        if let w = store.welcome {
            popup(title: T("欢迎回来"), text: w, image: nil) { store.welcome = nil }
        } else if store.intro {
            let pg = MKStory.introPages[min(store.introPage, MKStory.introPages.count - 1)]
            popup(title: pg.0, text: pg.1, image: nil) {
                if store.introPage < MKStory.introPages.count - 1 { withAnimation { store.introPage += 1 } } else { store.intro = false }
            }
        } else if let g = store.loginGift {
            popup(title: T("签到第 {0} 天", g.day), text: g.text + (g.day == 7 ? T("\n连续 7 天！") : T("\n明天再来，第 {0} 天更好。", g.day + 1)), image: "calendar") { store.loginGift = nil }
        } else if let l = store.levelUp {
            ZStack {
                MKRays().frame(width: 520, height: 520).allowsHitTesting(false)
                popup(title: T("小店 {0} 级", l), text: unlockText(l), image: nil) { store.levelUp = nil }
                MKConfetti().ignoresSafeArea()
            }
        } else if let sl = store.storyLine {
            ZStack {
                popup(title: sl.title, text: sl.line, image: nil) { store.storyLine = nil }
                MKConfetti().ignoresSafeArea()
            }
        } else if let m = store.reveal {
            ZStack {
                MKRays().frame(width: 520, height: 520).allowsHitTesting(false)
                VStack(spacing: 0) {
                    popup(title: m.id.hasSuffix("h") ? T("谜底揭了一角") : T("谜底揭晓"), text: m.q + "\n\n" + m.answer, image: nil, art: MKStory.revealImage[m.id]) { store.reveal = nil }
                }
                MKConfetti().ignoresSafeArea()
            }
        } else if let sc = store.scene {
            scenePopup(sc)
        } else if let r = store.postcard {
            popup(title: T("{0} {1}的明信片", r.icon, r.place), text: r.postcard + T("\n\n熟客的故事讲完了。宝石 +10，收进线索本。"), image: nil) { store.postcard = nil }
        } else if let g = store.goldCard {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { store.goldCard = nil }
                MKRays().frame(width: 520, height: 520).allowsHitTesting(false)
                VStack(spacing: 14) {
                    Text(T("金色拍立得")).font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: "#FFD166"))
                    MKPolaroid(card: g, width: 220)
                    Text(T("「{0}」", g.line)).font(.system(size: 15)).foregroundStyle(.white)
                    Text(T("故事里的一刻，收进相册了。")).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.6))
                    HStack(spacing: 10) {
                        MKShareButton(card: MKShareCard(title: T("金色拍立得 · {0}", g.name), line: g.line, card: g)).frame(width: 130)
                        Button(T("好")) { store.goldCard = nil }.buttonStyle(.borderedProminent).tint(Theme.accent)
                    }
                }
            }
        } else if let set = store.setComplete {
            ZStack {
                MKRays().frame(width: 520, height: 520).allowsHitTesting(false)
                popup(title: T("集齐「{0}」", set.name), text: T("九张都在相册里了。\n宝石 +15，大宝箱放在台面上。"), image: nil) { store.setComplete = nil }
                MKConfetti().ignoresSafeArea().allowsHitTesting(false)
                VStack {
                    Spacer()
                    MKShareButton(card: MKShareCard(title: T("集齐了「{0}」", set.name), line: T("九张拍立得，一张不少。"), card: MKCards.all.first { $0.set == set.id && $0.gold } ?? MKCards.all.first { $0.set == set.id }), label: T("分享这一套"))
                        .frame(width: 200).padding(.bottom, 60)
                }
            }
        } else if let f = store.newFind {
            if MK.recipe(f) != nil {
                ZStack {
                    MKRays().frame(width: 520, height: 520).allowsHitTesting(false)
                    popup(title: T("新菜：{0}", MK.name(f)), text: T("它先尝了一口，眼睛亮了：「……可以。」\n记进菜谱了，宝石 +3。"), image: f) { store.newFind = nil }
                }
            } else {
                popup(title: T("新发现：{0}", MK.name(f)), text: T("记进图鉴了，送你宝石。"), image: f) { store.newFind = nil }
            }
        }
    }
    /// 章末小戏：它摆着那句话的样子，一句一句点下去
    private func scenePopup(_ sc: MKScene) -> some View {
        let b = sc.beats[min(sc.page, sc.beats.count - 1)]
        let last = sc.page >= sc.beats.count - 1
        let next: () -> Void = {
            if last { store.scene = nil } else { withAnimation(.easeInOut(duration: 0.25)) { store.scene?.page += 1 } }
        }
        return ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: next)
            VStack(spacing: 12) {
                Text(sc.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Self.doorColor)
                Group {
                    if let im = b.img, UIImage(named: im) != nil {
                        MKStoryArt(name: im)
                    } else {
                        VideoPetView(pet: "purple", pose: .stand, frame: b.frame, size: 120)
                    }
                }
                .id(sc.page)
                .transition(.opacity)
                Text(b.line).font(.system(size: 16)).foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center).frame(minHeight: 66)
                    .id("t\(sc.page)").transition(.opacity)
                HStack(spacing: 5) {
                    ForEach(0..<sc.beats.count, id: \.self) { i in
                        Circle().fill(i <= sc.page ? Self.doorColor : Theme.surface2).frame(width: 6, height: 6)
                    }
                }
                Button(last ? T("好") : T("接着看"), action: next).buttonStyle(.borderedProminent).tint(Theme.accent)
            }
            .padding(24).frame(maxWidth: 340)
            .background(LinearGradient(colors: [Color(hex: "#2E2350"), Theme.surface], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 24))
            .padding(28)
        }
    }

    private func popup(title: String, text: String, image: String?, art: String? = nil, close: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 10) {
                if let art, UIImage(named: art) != nil { MKStoryArt(name: art, size: 200) }
                if let image { MKIcon(id: image).frame(width: 90, height: 90) }
                Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
                Text(text).font(.system(size: 14)).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
                Button(T("好"), action: close).buttonStyle(.borderedProminent).tint(Theme.accent)
            }
            .padding(24).background(Theme.surface, in: RoundedRectangle(cornerRadius: 24)).padding(36)
        }
    }
    private func unlockText(_ l: Int) -> String {
        var s: [String] = [T("宝石 +3，体力 +20")]
        for c in MK.chains where c.unlock == l { s.append(T("新产出器：{0}", c.genName)) }
        for a in MK.appliances where a.unlock == l { s.append(T("新厨具：{0}", a.name)) }
        for r in MK.recipes where r.unlock == l && r.book == nil { s.append(T("新菜：{0} = ", r.name) + r.needs.map(MK.name).joined(separator: " + ")) }
        for b in MK.books where b.level == l && !MK.hasBook(b.id) { s.append(T("📖 商城的「{0}」现在用得上了（4 道新菜）", b.name)) }
        return s.joined(separator: "\n")
    }
}

enum MKSheet: String, Identifiable { case bag, shop, book, deco, tasks, album, season, gems, energy; var id: String { rawValue } }

struct MKIcon: View {
    let id: String
    @MainActor private static var has: [String: Bool] = [:]
    @MainActor static func exists(_ id: String) -> Bool {
        if let h = has[id] { return h }
        let h = UIImage(named: "mk_" + id) != nil
        has[id] = h
        return h
    }
    var body: some View {
        if Self.exists(id) {
            Image("mk_" + id).resizable().scaledToFit()
        } else {
            Text(String(MK.name(id).prefix(2))).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
        }
    }
}

// MARK: 背包
private struct MKBagView: View {
    @ObservedObject var store: MKStore
    @ObservedObject var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(0..<max(store.s.bagSlots, store.s.bag.count), id: \.self) { k in
                        Button { store.unstash(k) } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(Theme.surface)
                                if k < store.s.bag.count { MKIcon(id: String(store.s.bag[k].split(separator: "@")[0])).padding(8) }
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.press)
                    }
                }
                }
                Text(T("台面上选中东西，点「收进包」放进来；点包里的东西拿回台面。每装修完一章，背包多一格；30 格以后可以用金币加格子，最多 50 格。")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                HStack {
                    Button(T("一键收纳")) { store.stowIdle() }.buttonStyle(.borderedProminent).tint(Theme.accent)
                    if store.s.bagSlots < MKStore.bagGemMax {
                        Button(T("多一个格子 · {0} 宝石", store.bagSlotCost)) { store.buyBagSlot() }.buttonStyle(.bordered)
                    } else if store.s.bagSlots < MKStore.bagMax {
                        Button(T("多一个格子 · {0} 币", store.bagCoinCost)) {
                            if profile.spend(store.bagCoinCost, T("小店 · 背包多一格")) { store.s.bagSlots += 1; MKSfx.play("coin") }
                        }
                        .buttonStyle(.bordered).disabled(profile.profile.coins < store.bagCoinCost)
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("背包")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }
}

// MARK: 小铺
private struct MKShopView: View {
    @ObservedObject var store: MKStore
    @ObservedObject var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text(T("每天刷新")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(store.s.deals) { d in dealButton(d) }
                    }
                    Button { store.buyEnergy() } label: {
                        HStack {
                            Image(systemName: "bolt.fill").foregroundStyle(Theme.coin)
                            Text(T("体力 +50"))
                            Spacer()
                            Label("\(store.energyCost)", systemImage: "diamond.fill").foregroundStyle(Color(hex: "#A8E6FF"))
                        }
                        .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Theme.text)
                    }
                    .buttonStyle(.press)
                    Text(T("同一天越买越贵，明天回到 5 宝石。")).font(.system(size: 11)).foregroundStyle(Theme.text3)
                    Text(T("宝石从特别订单、升级、宝箱、新发现里来，不卖真钱。")).font(.system(size: 11)).foregroundStyle(Theme.text3)
                }
                .padding(20)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("小铺")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
    private func dealButton(_ d: MKDeal) -> some View {
        Button {
            if let c = store.buyDeal(d, coins: profile.profile.coins), c > 0 { _ = profile.spend(c, T("小厨房小铺")) }
        } label: {
            VStack(spacing: 6) {
                MKIcon(id: d.item).frame(height: 56)
                Text(MK.name(d.item)).font(.system(size: 11)).foregroundStyle(Theme.text).lineLimit(1)
                Label("\(d.price)", systemImage: d.gem ? "diamond.fill" : "circle.circle.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(d.gem ? Color(hex: "#A8E6FF") : Theme.coin)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .opacity(d.sold ? 0.35 : 1)
        }
        .buttonStyle(.press).disabled(d.sold)
    }
}

// MARK: 图鉴
private struct MKBookView: View {
    @ObservedObject var store: MKStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(MK.chains, id: \.key) { c in chainRow(c) }
                    Text(T("菜")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                    let missing = MK.books.filter { !MK.hasBook($0.id) }
                    if !missing.isEmpty {
                        Text(T("📖 还有 {0} 道菜在商城的「菜谱」里：", missing.count * 4) + missing.map(\.name).joined(separator: T("、")) + T("。用店里赚的币去换。"))
                            .font(.system(size: 11)).foregroundStyle(Theme.coin)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                        ForEach(MK.recipes, id: \.id) { r in
                            entry(r.id, have: store.s.found.contains(r.id), label: store.s.found.contains(r.id) ? r.name : (r.book != nil && !MK.hasBook(r.book) ? T("📖 菜谱") : T("{0} 级", r.unlock)))
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("图鉴 {0}", store.s.found.count)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
    private func chainRow(_ c: MK.Chain) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(c.genName + (c.unlock > store.s.level ? T("（{0} 级解锁）", c.unlock) : "")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...MK.maxTier, id: \.self) { t in
                        let id = c.key + "\(t)"
                        let have = store.s.found.contains(id)
                        entry(id, have: have, label: have ? c.names[t - 1] : T("{0} 级", t)).frame(width: 58)
                    }
                }
            }
        }
    }
    private func entry(_ id: String, have: Bool, label: String) -> some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.surface)
                if have { MKIcon(id: id).padding(6) } else { Text("?").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.text3) }
            }
            .aspectRatio(1, contentMode: .fit)
            Text(label).font(.system(size: 9)).foregroundStyle(have ? Theme.text2 : Theme.text3).lineLimit(1)
        }
    }
}

// MARK: 装修（6 个地方，左右切换；任务一个一个解锁）
private struct MKDecoView: View {
    @ObservedObject var store: MKStore
    @Environment(\.dismiss) private var dismiss
    @State private var areaIdx: Int = -1
    @State private var clues = false
    @State private var soon = false
    private var allDone: Bool { store.s.done.filter { !$0.hasPrefix("w") }.count >= MKStory.all.count }
    /// 下一片地方：还在做。门缝里透出一点光（和主线对上：嘟嘟星上还有好多暗着的角落）
    private var comingSoon: some View {
        VStack(spacing: 8) {
            Image(systemName: "door.left.hand.open").font(.system(size: 30)).foregroundStyle(Color(hex: "#FFD166"))
            Text(T("下一站：正在装修")).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
            Text(T("嘟嘟星上还有好多暗着的角落。下一片地方我们正在一点一点收拾，更新了第一时间告诉你。\n在那之前：周末活动、大订单、今日招牌照常开，它的心愿也一个接一个。"))
                .font(.system(size: 12)).foregroundStyle(Theme.text3).multilineTextAlignment(.center)
        }
        .padding(16).frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#FFD166").opacity(0.35), lineWidth: 1))
    }
    private var current: Int {
        guard let t = store.nextTask, let a = MKStory.area(of: t.id) else { return MKStory.areas.count - 1 }
        return MKStory.areas.firstIndex { $0.key == a.key } ?? 0
    }
    var body: some View {
        let idx = areaIdx < 0 ? current : areaIdx
        let area = MKStory.areas[idx]
        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(MKStory.areas.enumerated()), id: \.offset) { pair in
                                chip(pair.offset, pair.element, selected: pair.offset == idx, locked: pair.offset > current)
                            }
                            // 最后一格：下一片地方（还在做）。让人知道玩到头不是结束，后面还有更新
                            Button { soon = true } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "hammer.fill").font(.system(size: 10))
                                    Text(T("下一站")).font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, 12).frame(height: 32)
                                .background(Theme.surface, in: Capsule())
                                .overlay(Capsule().stroke(Theme.text3.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                                .foregroundStyle(Theme.text3)
                            }
                            .buttonStyle(.press)
                        }
                    }
                    if allDone { comingSoon }
                    if idx > current {
                        lockedScene(area)
                    } else {
                        MKAreaScene(area: area, done: store.s.done).padding(.horizontal, 4)
                    }
                    HStack {
                        Label(T("{0} 颗星星", store.s.stars), systemImage: "star.fill").foregroundStyle(Color(hex: "#FFD166"))
                        Spacer()
                        Text(T("交订单攒星星")).foregroundStyle(Theme.text3)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    ForEach(area.chapters, id: \.title) { ch in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ch.title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                            ForEach(ch.tasks, id: \.id) { t in taskRow(t) }
                        }
                    }
                    if store.s.done.filter({ !$0.hasPrefix("w") }).count >= MKStory.all.count, let w = store.nextTask {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(T("{0}的心愿", Voice.petName)).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                            Text(T("下一片地方正在装修，好了第一时间告诉你。在那之前，它还有好多小心愿，一个一个来。")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                            taskRow(w)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("装修 · {0}", area.name)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { clues = true } label: { Label(T("线索本"), systemImage: "book.pages") } }
                ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } }
            }
            .sheet(isPresented: $clues) { MKCluesView(store: store) }
            .alert(T("下一站：正在装修"), isPresented: $soon) { Button(T("好")) {} } message: {
                Text(allDone ? T("下一片地方我们正在收拾，更新了第一时间告诉你。") : T("先把这几个地方装修好。后面还有新地方，我们正在做。"))
            }
            .fullScreenCover(item: $store.renovated) { r in MKRenovateView(r: r) { store.renovated = nil } }
        }
        .preferredColorScheme(.dark)
    }
    private func chip(_ i: Int, _ a: MKStory.Area, selected: Bool, locked: Bool) -> some View {
        Button { areaIdx = i } label: {
            HStack(spacing: 4) {
                if locked { Image(systemName: "lock.fill").font(.system(size: 10)) }
                Text(a.name).font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12).frame(height: 32)
            .background(selected ? Theme.accent : Theme.surface, in: Capsule())
            .foregroundStyle(selected ? Color.black : (locked ? Theme.text3 : Theme.text))
        }
        .buttonStyle(.press)
    }
    private func lockedScene(_ a: MKStory.Area) -> some View {
        ZStack {
            MKAreaScene(area: a, done: []).blur(radius: 14).opacity(0.5)
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 26))
                Text(T("装修完上一个地方才能来这儿")).font(.system(size: 13))
            }
            .foregroundStyle(Theme.text2)
        }
    }
    private func taskRow(_ t: MKStory.Task) -> some View {
        let done = store.s.done.contains(t.id)
        let isNext = store.nextTask?.id == t.id
        let enough = store.s.stars >= t.stars
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(done ? Theme.text3 : Theme.text)
                if done { Text(t.line).font(.system(size: 11)).foregroundStyle(Theme.text3) }
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            } else if isNext {
                Button { store.doTask(t) } label: {
                    Label("\(t.stars)", systemImage: "star.fill").font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12).frame(height: 32)
                        .background(enough ? Theme.coin : Theme.surface2, in: Capsule())
                        .foregroundStyle(enough ? Color.black : Theme.text3)
                }
                .buttonStyle(.press)
                .disabled(!enough)
            } else {
                Label("\(t.stars)", systemImage: "lock.fill").font(.system(size: 12)).foregroundStyle(Theme.text3)
            }
        }
        .padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// 装修好一件：全屏看这个地方，新家具从上面落下来、发一下光，小紫在角落拍手，下面一段话
struct MKRenovateView: View {
    let r: MKRenovation
    let close: () -> Void
    @State private var shown = false
    @State private var glow = false
    @State private var caption = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Text(r.area.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white.opacity(0.6))
                MKAreaScene(area: r.area, done: r.done, highlight: r.task.deco, shown: shown, glow: glow)
                    .overlay(alignment: .bottomTrailing) {
                        VideoPetView(pet: "purple", pose: .stand, frame: "happy", size: 92, clip: MKClips.has("shopx_wow") ? "shopx_wow" : nil)
                            .frame(width: 96, height: 96)
                            .background(Color.black.opacity(0.001))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(10)
                            .opacity(caption ? 1 : 0)
                    }
                    .padding(.horizontal, 12)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            VStack(spacing: 10) {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text(r.task.title).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
                    Text(r.task.line).font(.system(size: 15)).lineSpacing(3).foregroundStyle(Theme.text2)
                    Label(T("体力 +10"), systemImage: "bolt.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.coin)
                    if let c = r.chapter {
                        Label(T("第 {0} 章完成：宝石 +10 · 大宝箱 · 拍立得 2 包 · 无限体力 30 分钟", c) + (r.bagUp ? T(" · 背包 +1 格") : ""), systemImage: "sparkles")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.coin)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach([r.areaDone ? r.area.key : nil, r.allDone ? "all" : nil].compactMap { $0 }, id: \.self) { key in
                        if let e = NestItem.awards.first(where: { $0.area == key }) {
                            HStack(spacing: 10) {
                                Image("nest_\(e.item.rawValue)_v3").resizable().scaledToFit().frame(width: 52, height: 52)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key == "all" ? T("全部装修完成！") : T("「{0}」整片装修完成！", r.area.name))
                                        .font(.system(size: 14, weight: .bold)).foregroundStyle(Color.pink)
                                    Text(T("窝里送你一件纪念款：{0}（已经摆上了）", e.name))
                                        .font(.system(size: 12)).foregroundStyle(Theme.text2)
                                }
                            }
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    HStack(spacing: 10) {
                        if caption {
                            MKShareButton(card: MKShareCard(title: r.area.name + " · " + r.task.title, line: r.task.line, area: r.area, done: r.done))
                        }
                        Button(action: close) {
                            Text(T("好")).font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 48)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black)
                        }
                        .buttonStyle(.press)
                    }
                    .padding(.top, 4)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 12).padding(.bottom, 12)
                .offset(y: caption ? 0 : 420)
            }
            if caption && r.chapter != nil { MKConfetti().ignoresSafeArea().allowsHitTesting(false) }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { shown = true; glow = true }
                MKSfx.impact(.heavy)
                MKSfx.play("renovate")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation(.easeOut(duration: 0.8)) { glow = false } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { caption = true }
            }
        }
    }
}

// MARK: - 演示（只在模拟器截图时用：启动参数 -demoKitchen [-demoSheet deco|book|shop|bag] [-demoSelect]）
extension MKState {
    /// 首页小店卡片上那一句：为什么现在要去店里
    static func homeHint() -> String? {
        let s = MKState.load()
        guard s.introSeen == true else { return nil }
        UserDefaults.standard.set(s.level, forKey: "merge.level")
        let name = Voice.petName
        if let p = s.orders.first(where: { $0.isPet }) { return T("{0}的{1}在店里等你做 ›", name, p.meal) }
        if let d = s.orders.first(where: { $0.isDoor })?.door, d <= MKStory.doors.count { return T("🌙 门那边来单了：嘟嘟星 · {0}", MKStory.doors[d - 1].name) }
        if let g = s.orders.first(where: { $0.isSignature }), let it = g.items.first { return T("今日招牌「{0}」还没做", MK.name(it)) }
        if let r = MKStory.regulars.first(where: { reg in s.orders.contains { $0.regular == reg.key } }) { return T("{0} {1}来了一张新小票", r.icon, r.place) }
        if (s.packs ?? 0) > 0 { return T("还有 {0} 包拍立得没开", s.packs ?? 0) }
        return nil
    }
    /// 给灵动岛的店面快照：几单在等、什么招牌
    static func islandScene() -> LiveActivityManager.ShopScene? {
        let s = MKState.load()
        guard s.introSeen == true else { return nil }
        // 「几单能交」：台面上东西已经齐了的外卖单（总有 4 张单在等，数总数没意义）
        var have: [String: Int] = [:]
        for slot in s.board where !slot.boxed && slot.bubbleUntil == nil { if let id = slot.item { have[id, default: 0] += 1 } }
        let ready = s.orders.filter { o in
            guard !o.isPet else { return false }
            var need: [String: Int] = [:]
            for it in o.items { need[it, default: 0] += 1 }
            return need.allSatisfy { (have[$0.key] ?? 0) >= $0.value }
        }.count
        return .init(open: true, tickets: ready, sign: s.done.contains("a1") ? 1 : 0)
    }
}

enum MKDemo {
    /// 自测、截图用的启动参数，只在开发版生效；正式包一律当没有
    #if DEBUG
    static var args: [String] { ProcessInfo.processInfo.arguments }
    #else
    static var args: [String] { [] }
    #endif
    static var on: Bool { args.contains("-demoKitchen") }
    static var select: Bool { args.contains("-demoSelect") }
    static var allDone: Bool { args.contains("-demoAllDone") }
    static var fresh: Bool { args.contains("-demoFresh") }
    static var late: Bool { args.contains("-demoLate") }
    static var sheet: String? {
        guard let i = args.firstIndex(of: "-demoSheet"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

struct MKDemoRoot: View {
    @StateObject private var profile = ProfileStore()
    var body: some View {
        if MKDemo.args.contains("-selfTest") { MKBotView() } else { MergeKitchenView(pet: "purple", profile: profile) }
    }
}

extension MKState {
    /// 自测用：玩到 20 级的样子（高级货、大订单、深菜、新食材都摆出来看一眼）
    static func late() -> MKState {
        var s = demo()
        s.level = 20; s.gems = 80; s.stars = 40
        let rows: [[String?]] = [
            ["rice10", "rice11", "veg10", "veg11", "tea10", "tea11", "sweet10", "sweet11"],
            ["fruit10", "fruit11", "snack9", "snack10", "snack11", "milk10", "milk11", "egg10"],
            ["egg11", "coffee10", "coffee11", "honey9", "honey10", "honey11", "rice12", "tea12"],
            ["tea1", "tea3", "tea5", "tea7", "rice4", "rice5", "rice6", "egg5"],
            ["sweet1", "sweet2", "luckybag", nil, "dish_onigiriset", "dish_hotpot", "dish_mooncake", "dish_bun"],
            ["dish_teacake", "dish_honeytea", "dish_curryomu", "dish_starbox", nil, "chest3", "wildcard", nil],
            ["pot", "oven", "juicer", "icecream", "steamer", "coffeemaker", nil, nil],
            ["tea9", "tea9", "sweet9", "sweet9", nil, nil, nil, nil],
            ["gen_rice", "gen_veg", "gen_tea", "gen_sweet", "gen_fruit", "gen_snack", "gen_milk", "gen_egg"],
        ]
        s.board = Array(repeating: MKSlot(), count: MK.cols * MK.rows)
        for (r, row) in rows.enumerated() {
            for (c, it) in row.enumerated() where c < MK.cols {
                guard let it else { continue }
                let i = r * MK.cols + c
                s.board[i] = MKSlot(item: it)
                if MK.isGen(it) { s.board[i].charges = 20; s.board[i].glv = c % 3 + 1 }
            }
        }
        s.cooks = [:]
        s.orders = [MKOrder(items: ["sweet11"], stars: 34, gems: 17, meal: "🏆 " + T("婚礼派对"), made: Date(), big: true),
                    MKOrder(items: ["dish_curryomu"], stars: 6, meal: T("外卖 · 3 号楼"), band: 2),
                    MKOrder(items: ["tea5"], stars: 2, meal: T("外卖 · 河边公寓"), band: 0),
                    MKOrder(items: ["rice6", "egg5"], stars: 5, meal: T("外卖 · 灯塔"), band: 1),
                    MKOrder(items: ["dish_bun"], stars: 4, meal: T("外卖 · 图书馆"), band: 1)]
        s.found = MK.chains.flatMap { c in (1...MK.maxTier).map { c.key + "\($0)" } } + MK.recipes.map(\.id)
        s.bigDay = Wallet.day()
        return s
    }
    /// 玩到 9 级左右的样子
    static func demo() -> MKState {
        var s = MKState()
        s.level = 9; s.xp = 61; s.gems = 23; s.stars = 9; s.energy = 86; s.energyAt = Date()
        let rows: [[String?]] = [
            ["B", "B", "B", "B", "B", "B", "B"],
            ["B", "B", "B", "B", "B", "B", "B"],
            ["rice2", "veg3", nil, "tea3", "fruit2", nil, "snack1"],
            ["rice4", "rice4", "veg5", nil, "sweet3", "tea4", nil],
            ["gift", nil, "fruit3", "fruit3", nil, "sweet5", "wildcard"],
            ["veg4", nil, "rice6", "snack2", "chest2", "tea2", nil],
            ["pot", "oven", "juicer", nil, "veg2", "rice1", "fruit1"],
            ["dish_bento", nil, "sweet2", nil, "scissors", nil, "energy"],
            ["gen_rice", "gen_veg", "gen_tea", "gen_sweet", "gen_fruit", "gen_snack", "veg1"],
        ]
        for (r, row) in rows.enumerated() {
            for (c, it) in row.enumerated() {
                let i = r * MK.cols + c
                if it == "B" {
                    // 纸箱只在新开局有（9 级时早开完了），演示存档也不摆纸箱，免得看着像会再补
                    s.board[i] = (r + c) % 3 == 0 ? MKSlot(item: ["rice2", "veg1", "tea2"][c % 3]) : MKSlot()
                } else if let it {
                    s.board[i] = MKSlot(item: it)
                    if MK.isGen(it) { s.board[i].charges = [8, 5, 12, 3, 8, 6][c % 6] }
                }
            }
        }
        s.board[8 * MK.cols + 0].glv = 2; s.board[8 * MK.cols + 0].charges = 9
        s.board[8 * MK.cols + 3].charges = 0; s.board[8 * MK.cols + 3].refillAt = Date().addingTimeInterval(9 * 60)
        s.board[5 * MK.cols + 2].bubbleUntil = Date().addingTimeInterval(48)
        s.board[5 * MK.cols + 4].openAt = Date().addingTimeInterval(6 * 60 + 20)
        s.cooks = ["pot": MKCook(putIn: [], dish: "dish_curry", doneAt: Date().addingTimeInterval(3 * 60 + 12)),
                   "oven": MKCook(putIn: ["sweet3"], dish: nil, doneAt: nil),
                   "juicer": MKCook(putIn: [], dish: "dish_juiceset", doneAt: Date().addingTimeInterval(-5))]
        s.orders = [MKOrder(items: ["dish_curry"], stars: 3, gems: 1, meal: T("晚饭"), pet: true),
                    MKOrder(items: ["rice4", "veg3"], stars: 2, meal: T("外卖 · 3 号楼")),
                    MKOrder(items: ["fruit4", "tea4"], stars: 2, meal: T("外卖 · 河边公寓")),
                    MKOrder(items: ["sweet6"], stars: 2, gems: 4, meal: T("外卖 · 灯塔")),
                    MKOrder(items: ["snack3"], stars: 1, meal: T("外卖 · 图书馆"))]
        s.orders.append(MKOrder(items: ["tea5", "fruit4"], stars: 3, meal: T("周末野餐"), event: true))
        s.event = MKEventState(week: MKEvent.current()?.week ?? "demo", points: 18, claimed: [0])
        s.daily = MKDaily(day: Wallet.day(), goals: [MKGoal(kind: "merge", target: 30, progress: 30, claimed: true),
                                                     MKGoal(kind: "ticket", target: 5, progress: 5),
                                                     MKGoal(kind: "pet", target: 2, progress: 1)])
        s.loginDay = Wallet.day(); s.loginStreak = 4
        s.bag = ["fruit5", "snack4"]
        s.done = ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8", "t9", "t10", "t11", "t12", "a1", "a2", "a3", "a4"]
        s.cards = ["hatch": 1, "riceball": 3, "apron": 1, "ticket": 2, "cashier": 1, "wow": 1, "shellnap": 1]
        s.packs = 3; s.stardust = 12
        s.signatureDay = Wallet.day()
        s.luckyUntil = Date().addingTimeInterval(11 * 60 + 20)
        if MKDemo.allDone { s.done = MKStory.all.map(\.id) }
        var f: [String] = []
        for c in MK.chains where c.unlock <= 9 { for t in 1...6 { f.append(c.key + "\(t)") } }
        s.found = f + ["rice7", "dish_bento", "dish_curry", "dish_teacake", "dish_juiceset"]
        s.dealsDay = ""
        return s
    }
}


// MARK: 任务（每日任务 + 签到 + 周末活动）
private struct MKTasksView: View {
    @ObservedObject var store: MKStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let cur = MKEvent.current() { eventCard(cur.def) }
                    Text(T("今天的小目标")).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                    if let d = store.s.daily {
                        ForEach(d.goals) { g in goalRow(g) }
                        bonusRow(d)
                    }
                    Text(T("签到")).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text).padding(.top, 6)
                    loginRow
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("今日目标")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
    private func goalRow(_ g: MKGoal) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(g.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(g.claimed ? Theme.text3 : Theme.text)
                ProgressView(value: Double(g.progress), total: Double(g.target)).tint(Theme.accent)
                Text(T("{0}/{1} · 宝石 3 + 体力 10", g.progress, g.target)).font(.system(size: 10)).foregroundStyle(Theme.text3)
            }
            Spacer()
            if g.claimed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            } else {
                Button { store.claimGoal(g) } label: {
                    Text(T("领取")).font(.system(size: 13, weight: .bold)).padding(.horizontal, 14).frame(height: 32)
                        .background(g.done ? Theme.coin : Theme.surface2, in: Capsule())
                        .foregroundStyle(g.done ? Color.black : Theme.text3)
                }
                .buttonStyle(.press).disabled(!g.done)
            }
        }
        .padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
    private func bonusRow(_ d: MKDaily) -> some View {
        let ready = !d.bonus && d.goals.allSatisfy(\.claimed)
        return HStack(spacing: 10) {
            MKIcon(id: "chest_daily").frame(width: 40, height: 40)
            Text(T("三个都做完：每日宝箱")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
            Spacer()
            if d.bonus { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
            else {
                Button { store.claimDailyBonus() } label: {
                    Text(T("开")).font(.system(size: 13, weight: .bold)).padding(.horizontal, 14).frame(height: 32)
                        .background(ready ? Theme.coin : Theme.surface2, in: Capsule())
                        .foregroundStyle(ready ? Color.black : Theme.text3)
                }
                .buttonStyle(.press).disabled(!ready)
            }
        }
        .padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
    private var loginRow: some View {
        let streak = store.s.loginStreak ?? 1
        let today = (streak - 1) % 7
        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { k in
                VStack(spacing: 2) {
                    Image(systemName: k <= today ? "checkmark.seal.fill" : (k == 6 ? "gift.fill" : "seal"))
                        .font(.system(size: 18)).foregroundStyle(k <= today ? Theme.coin : Theme.text3)
                    Text("\(k + 1)").font(.system(size: 10)).foregroundStyle(Theme.text3)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
    private func eventCard(_ def: MKEvent.Def) -> some View {
        let pts = store.s.event?.points ?? 0
        let claimed = store.s.event?.claimed ?? []
        let goal = MKEvent.goal
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                MKIcon(id: "event_basket").frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text((MKEvent.season(Date()) != nil ? T("限时活动 · {0}", def.name) : T("周末活动 · {0}", def.name))).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                    if let end = MKEvent.endDate() {
                        Text(T("还剩 {0}", MKEvent.left(end))).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.joy)
                    }
                    Text(def.line).font(.system(size: 11)).foregroundStyle(Theme.text2)
                }
            }
            ProgressView(value: Double(min(pts, goal)), total: Double(goal)).tint(Theme.joy)
            HStack {
                ForEach(Array(MKEvent.milestones.enumerated()), id: \.offset) { pair in
                    VStack(spacing: 2) {
                        MKIcon(id: pair.element.item).frame(width: 22, height: 22)
                            .opacity(claimed.contains(pair.offset) ? 0.45 : 1)
                        Text("\(pair.element.points)").font(.system(size: 10, weight: .bold))
                            .foregroundStyle(claimed.contains(pair.offset) ? Theme.coin : Theme.text3)
                    }
                    if pair.offset < MKEvent.milestones.count - 1 { Spacer(minLength: 0) }
                }
            }
            Text(T("交粉色的活动单攒活动分：{0}", pts)).font(.system(size: 11)).foregroundStyle(Theme.text3)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.joy.opacity(0.6), lineWidth: 1.5))
    }
}


// MARK: 灵动岛 / 通知提醒
/// 测试面板只在开发版（Debug）里编译；TestFlight 和 App Store 的包里没有
enum MKDebug {
    #if DEBUG
    static let allowed = true
    #else
    static let allowed = false
    #endif
}
struct MKPing: Equatable {
    let at: Date; let icon: String; let line: String
    /// 推送用的那条（门单只给岛台常亮；推送照样排出锅/宝箱/体力，不被门单盖掉）
    var pushAt: Date? = nil; var pushIcon: String? = nil; var pushLine: String? = nil
    var forPush: MKPing? { pushAt.map { MKPing(at: $0, icon: pushIcon ?? "", line: pushLine ?? "") } ?? (icon == "🌙" ? nil : self) }
}

@MainActor
enum ShopPing {
    /// 第二个谜揭晓以后：每晚 9:41，灵动岛那道门亮一下（安静时段、提醒「少」不发）
    static func scheduleNightDoor() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["door.941"])
        guard MKState.load().done.contains("b12"), Quiet.level != .low, !Quiet.isQuiet(hour: 21) else { return }
        let c = UNMutableNotificationContent()
        c.title = ChatStore.petName
        c.body = [T("门……刚刚亮了一下。"), T("9 点 41 分。门那边，有人在看我们。"), T("门缝里掉进来一点光。我替你收着了。")].randomElement() ?? T("门亮了一下。")
        c.sound = nil
        var dc = DateComponents(); dc.hour = 21; dc.minute = 41
        center.add(UNNotificationRequest(identifier: "door.941", content: c, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
    }
    /// 离开小店时预约一条静音通知（安静时段不发、提醒档「少」不发）；回到小店就取消
    static func schedule(_ p: MKPing?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["shop.ready"])
        guard let p, p.at.timeIntervalSinceNow > 60, !Quiet.isQuiet(p.at), Quiet.level != .low else { return }
        let c = UNMutableNotificationContent()
        c.title = ChatStore.petName
        c.body = p.icon + " " + p.line
        c.sound = nil
        c.userInfo = ["url": "islandme://shop"]
        center.add(UNNotificationRequest(identifier: "shop.ready", content: c,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: p.at.timeIntervalSinceNow, repeats: false)))
    }
}


// MARK: 特效 / 它说的话
struct MKFX: Identifiable, Equatable {
    enum Kind { case burst, fly, serve, combo, merge }
    let id = UUID()
    let kind: Kind
    let from: Int
    let to: Int?
    let item: String?
    var tier: Int = 1
}
struct MKSay: Identifiable, Equatable { let id = UUID(); let text: String }

/// 合成那一下：一圈光 + 星星迸开（高级的更大更亮）
struct MKBurst: View {
    let tier: Int
    var color: Color? = nil
    @State private var go = false
    /// 每条链一个颜色：米白、胡萝卜橙、茶绿……星星跟着食材变色
    static func tint(_ key: String) -> Color {
        switch key {
        case "rice": return Color(hex: "#FFF4D6")
        case "veg": return Color(hex: "#FF9F5A")
        case "tea": return Color(hex: "#9BE08A")
        case "sweet": return Color(hex: "#FFC2D6")
        case "fruit": return Color(hex: "#FF6F8E")
        case "snack": return Color(hex: "#FFE066")
        case "milk": return Color(hex: "#E8F4FF")
        case "egg": return Color(hex: "#FFD166")
        case "coffee": return Color(hex: "#C89B7B")
        case "honey": return Color(hex: "#FFC233")
        default: return Color(hex: "#B9A6E8")
        }
    }
    var body: some View {
        let big = tier >= 6
        let n = tier >= 6 ? 12 : (tier >= 4 ? 9 : 6)
        let r: CGFloat = big ? 44 : (tier >= 4 ? 34 : 26)
        let c2 = color ?? Color(hex: "#B9A6E8")
        ZStack {
            // 一下白光：东西「啵」地变出来
            Circle().fill(RadialGradient(colors: [.white.opacity(0.95), c2.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 30))
                .frame(width: 60, height: 60)
                .scaleEffect(go ? 1.35 : 0.4).opacity(go ? 0 : 1)
            Circle().stroke(big ? Color(hex: "#FFD166") : Color.white.opacity(0.85), lineWidth: big ? 4 : 2.5)
                .scaleEffect(go ? (big ? 2.1 : 1.6) : 0.4).opacity(go ? 0 : 1)
            ForEach(0..<n, id: \.self) { k in
                let a = Double(k) / Double(n) * 2 * .pi + (k % 2 == 0 ? 0 : 0.3)
                let rr = r * (k % 2 == 0 ? 1 : 0.72)
                Image(systemName: k % 3 == 2 ? "circle.fill" : "star.fill").font(.system(size: big ? 11 : (k % 3 == 2 ? 5 : 8)))
                    .foregroundStyle(k % 2 == 0 ? Color(hex: "#FFD166") : c2)
                    .offset(x: go ? cos(a) * rr : 0, y: go ? sin(a) * rr + (go ? 6 : 0) : 0)
                    .scaleEffect(go ? 0.4 : 1.1)
                    .opacity(go ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: big ? 0.7 : 0.55)) { go = true } }
    }
}

/// 合成那一下：两个旧的从左右「吸」到一起、缩小消失（新的同时从中间弹出来）
struct MKMergeIn: View {
    let item: String
    let size: CGFloat
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                MKIcon(id: item).frame(width: size, height: size)
                    .scaleEffect(go ? 0.55 : 0.95, anchor: .center)
                    .scaleEffect(x: go ? 1.15 : 1, y: go ? 0.85 : 1)     // 挤一下
                    .offset(x: go ? 0 : side * size * 0.32)
                    .opacity(go ? 0 : 0.9)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeIn(duration: 0.16)) { go = true } }
    }
}

/// 3 连以上：格子上方飘「连击 ×n」
struct MKComboText: View {
    let n: Int
    @State private var pop = false
    @State private var go = false
    var body: some View {
        Text(T("连击 ×{0}", n))
            .font(.system(size: n >= 5 ? 17 : 14, weight: .heavy, design: .rounded))
            .foregroundStyle(n >= 5 ? Color(hex: "#FFD166") : .white)
            .shadow(color: Color(hex: "#7B5CC4"), radius: 0, x: 1.5, y: 1.5)
            .shadow(color: .black.opacity(0.5), radius: 3)
            .scaleEffect(pop ? 1.0 : 0.4)
            .offset(y: go ? -26 : 0)
            .opacity(go ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { pop = true }
                withAnimation(.easeIn(duration: 0.4).delay(0.5)) { go = true }
            }
    }
}

/// 东西从 a 飞到 b（产出器掉东西 / 交单飞进订单）
struct MKFlight: View {
    let item: String
    let from: CGPoint
    let to: CGPoint
    let size: CGFloat
    var shrink = false
    @State private var go = false
    var body: some View {
        MKIcon(id: item).frame(width: size, height: size)
            .scaleEffect(go ? (shrink ? 0.4 : 1) : (shrink ? 1 : 0.5))
            .opacity(go && shrink ? 0 : 1)
            .position(go ? to : from)
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeInOut(duration: shrink ? 0.5 : 0.3)) { go = true } }
    }
}

/// 升级 / 章节完成的彩带
struct MKConfetti: View {
    @State private var go = false
    private let bits: [(x: CGFloat, d: Double, c: Color, r: Double)] = (0..<36).map { _ in
        (CGFloat.random(in: 0...1), Double.random(in: 0...0.5),
         [Color(hex: "#FFD166"), Color(hex: "#B9A6E8"), Color(hex: "#F7A8C4"), Color(hex: "#A8E6FF")].randomElement() ?? .white,
         Double.random(in: 0...360))
    }
    var body: some View {
        GeometryReader { g in
            ForEach(0..<bits.count, id: \.self) { k in
                let b = bits[k]
                RoundedRectangle(cornerRadius: 2).fill(b.c).frame(width: 7, height: 12)
                    .rotationEffect(.degrees(go ? b.r + 360 : b.r))
                    .position(x: g.size.width * b.x, y: go ? g.size.height + 20 : -20)
                    .animation(.easeIn(duration: 1.8).delay(b.d), value: go)
            }
        }
        .allowsHitTesting(false)
        .onAppear { go = true }
    }
}


/// 引导用的小手：点（原地按一下）或拖（从 a 滑到 b）
struct MKHand: View {
    let from: CGPoint
    let to: CGPoint?
    @State private var go = false
    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 34)).foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 4)
            .scaleEffect(to == nil && go ? 0.85 : 1)
            .position(x: (go ? (to ?? from) : from).x + 14, y: (go ? (to ?? from) : from).y + 22)
            .onAppear {
                withAnimation(.easeInOut(duration: to == nil ? 0.6 : 1.1).repeatForever(autoreverses: to == nil)) { go = true }
            }
    }
}


// MARK: 更讲究的动效
struct MKFloat: Identifiable, Equatable { let id = UUID(); let text: String; let x: CGFloat }
/// 交单后飘起来的「+12币 +2★」
struct MKFloatView: View {
    let text: String
    @State private var go = false
    var body: some View {
        Text(text).font(.system(size: 14, weight: .heavy)).foregroundStyle(Color(hex: "#FFD166"))
            .shadow(color: .black.opacity(0.6), radius: 3)
            .offset(y: go ? -46 : 0).opacity(go ? 0 : 1).scaleEffect(go ? 1.15 : 0.8)
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { go = true } }
    }
}
/// 合出 8 级以上：棋盘抖一下
struct MKShake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 5 * sin(amount * .pi * 6), y: 0))
    }
}
/// 提示格子轻轻呼吸
/// 新手教学时套在要点的格子上的一圈呼吸光
struct MKRing: View {
    let side: CGFloat
    @State private var on = false
    var body: some View {
        ZStack {
            // 2026-10-22：闪光放在格子里面（填满、一呼一吸），不只是一圈线——新手一眼看到该点哪一格
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.coin.opacity(on ? 0.42 : 0.16))
                .frame(width: side - 6, height: side - 6)
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.coin, lineWidth: 3)
                .frame(width: side - 2, height: side - 2)
                .scaleEffect(on ? 1.10 : 0.97)
                .opacity(on ? 0.5 : 1)
                .shadow(color: Theme.coin.opacity(0.9), radius: on ? 12 : 5)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) { on = true } }
        .allowsHitTesting(false)
    }
}

/// 能交的订单卡：轻轻一跳一跳 + 金光，一眼看到「这张能交了」
struct MKReadyBounce: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        content.phaseAnimator([false, true]) { c, p in
            c.scaleEffect(on && p ? 1.05 : 1, anchor: .bottom)
                .shadow(color: on ? Theme.coin.opacity(p ? 0.55 : 0.2) : .clear, radius: on ? 8 : 0)
        } animation: { _ in .easeInOut(duration: 0.55) }
    }
}
/// 不行的那一格：左右抖三下
struct MKDenyShake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 5 * sin(amount * .pi * 6), y: 0))
    }
}
struct MKPulse: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content.opacity(on ? 1 : 0.2)
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { on = true } }
    }
}
/// 泡泡轻轻晃
struct MKWobble: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content.scaleEffect(x: on ? 1.04 : 0.97, y: on ? 0.97 : 1.04)
            .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { on = true } }
    }
}
/// 升级时背后转的光
struct MKRays: View {
    @State private var spin = false
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { k in
                Capsule().fill(LinearGradient(colors: [Color(hex: "#FFD166").opacity(0.45), .clear], startPoint: .bottom, endPoint: .top))
                    .frame(width: 26, height: 250).offset(y: -125)
                    .rotationEffect(.degrees(Double(k) * 30))
            }
        }
        .rotationEffect(.degrees(spin ? 360 : 0))
        .onAppear { withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { spin = true } }
    }
}
/// 店里的专门片段在不在包里（可灵出的，没出完也不影响）
enum MKClips {
    static func has(_ name: String) -> Bool { Bundle.main.url(forResource: "purple_" + name, withExtension: "mp4") != nil }
}


// MARK: 线索本：五个小谜（找到的线索、揭晓的谜底）+ 熟客的故事 + 那个不揭晓的大谜
struct MKCluesView: View {
    @ObservedObject var store: MKStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(T("最大的谜")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                        let bq = MKStory.bigQuestion(done: store.s.done)
                        Text(bq.q).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                        Text(bq.a).font(.system(size: 12)).foregroundStyle(Theme.text3)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [Color(hex: "#2E2350"), Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
                    MKPlanetMap(lit: Set(store.s.doorLit ?? []))
                    ForEach(MKStory.mysteries) { m in mysteryCard(m) }
                    Text(T("熟客")).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text).padding(.top, 6)
                    ForEach(MKStory.regulars, id: \.key) { r in regularRow(r) }
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("线索本")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
    private func mysteryCard(_ m: MKStory.Mystery) -> some View {
        let done = store.s.done
        let solved = done.contains(m.answerAt)
        let found = m.clues.filter { done.contains($0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(solved ? "✓" : T("？")).font(.system(size: 14, weight: .heavy)).foregroundStyle(solved ? Theme.coin : Theme.text3)
                Text(m.q).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(found.count)/\(m.clues.count)").font(.system(size: 11)).foregroundStyle(Theme.text3)
            }
            ForEach(m.clues, id: \.self) { c in
                if let t = MKStory.all.first(where: { $0.id == c }), done.contains(c) {
                    Text("· " + t.line).font(.system(size: 12)).foregroundStyle(Theme.text2)
                } else {
                    Text(T("· 还没找到的线索")).font(.system(size: 12)).foregroundStyle(Theme.text3.opacity(0.6))
                }
            }
            if !solved, let h = m.halfAt, let half = m.half, done.contains(h) {
                Text(half).font(.system(size: 13)).foregroundStyle(Theme.text2)
                    .padding(10).background(Color(hex: "#FFD166").opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
            if solved {
                Text(m.answer).font(.system(size: 13)).foregroundStyle(Color(hex: "#FFD166"))
                    .padding(10).background(Color(hex: "#FFD166").opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
    private func regularRow(_ r: MKStory.Regular) -> some View {
        let k = store.s.regulars?[r.key] ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(r.icon + " " + r.place).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                Text(k > 0 ? r.who : T("还没来过")).font(.system(size: 11)).foregroundStyle(Theme.text3)
                Spacer()
                HStack(spacing: 3) { ForEach(0..<r.notes.count, id: \.self) { i in Circle().fill(i < k ? Theme.accent : Theme.surface2).frame(width: 7, height: 7) } }
            }
            ForEach(0..<min(k, r.notes.count), id: \.self) { i in
                Text(T("「") + r.notes[i] + T("」")).font(.system(size: 12)).foregroundStyle(Theme.text2)
            }
            if k >= r.notes.count { Text(r.postcard).font(.system(size: 12)).foregroundStyle(Theme.coin) }
        }
        .padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}


// MARK: 嘟嘟星地图：14 个区围着正中的总店，门单做完一个亮一个
struct MKPlanetMap: View {
    let lit: Set<Int>
    @State private var picked: Int? = nil
    private static let glow = Color(hex: "#FFD98A")
    /// 第 12 区（总店）在正中，其余 13 个绕两圈
    private func pos(_ r: Int, in w: CGFloat) -> CGPoint {
        let c = CGPoint(x: w / 2, y: w / 2)
        if r == 12 { return c }
        let others = (1...14).filter { $0 != 12 }
        let k = others.firstIndex(of: r) ?? 0
        let inner = k < 5
        let n = inner ? 5 : 8
        let i = inner ? k : k - 5
        let rad = w * (inner ? 0.2 : 0.38)
        let ang = Double(i) / Double(n) * 2 * .pi - .pi / 2 + (inner ? 0.3 : 0)
        return CGPoint(x: c.x + rad * cos(ang), y: c.y + rad * sin(ang))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(T("嘟嘟星")).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                Text(T("亮了 {0} / {1}", lit.count, MKStory.doors.count)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Self.glow)
            }
            GeometryReader { g in
                let w = g.size.width
                ZStack {
                    Circle().fill(RadialGradient(colors: [Color(hex: "#3B2D63"), Color(hex: "#15102A")], center: .center, startRadius: 4, endRadius: w / 2))
                    Circle().fill(Self.glow.opacity(Double(lit.count) / Double(MKStory.doors.count) * 0.25)).blur(radius: 20)
                    ForEach(1...MKStory.doors.count, id: \.self) { r in
                        let on = lit.contains(r)
                        let p = pos(r, in: w)
                        Circle()
                            .fill(on ? Self.glow : Color(hex: "#4A4166"))
                            .frame(width: r == 12 ? 26 : 16, height: r == 12 ? 26 : 16)
                            .shadow(color: on ? Self.glow.opacity(0.9) : .clear, radius: on ? 8 : 0)
                            .overlay(Circle().stroke(picked == r ? Color.white : Color.clear, lineWidth: 2))
                            .position(p)
                            .onTapGesture { picked = r }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 260).frame(maxWidth: .infinity)
            if let r = picked, r <= MKStory.doors.count {
                let d = MKStory.doors[r - 1]
                Text(lit.contains(r) ? T("{0}：「{1}」", d.name, d.note) : T("{0}：还暗着。门那边的单做完，就会亮。", d.name))
                    .font(.system(size: 12)).foregroundStyle(Theme.text2)
            } else {
                Text(T("每章会有一张从灵动岛门缝掉进来的门单。做完一张，这里亮一块。点一个地方看看。"))
                    .font(.system(size: 12)).foregroundStyle(Theme.text3)
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}


/// 剧情插图：圆角卡片，一圈淡紫描边
struct MKStoryArt: View {
    let name: String
    var size: CGFloat = 230
    var body: some View {
        Image(name).resizable().scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "#C9A7FF").opacity(0.5), lineWidth: 1.5))
            .shadow(color: Color(hex: "#C9A7FF").opacity(0.35), radius: 14)
    }
}


/// 测试面板：跳章节、看小戏和谜底、加星星体力、测急单和 9:41 通知。只有连点等级 7 下才打开
struct MKDebugView: View {
    @ObservedObject var store: MKStore
    @Environment(\.dismiss) private var dismiss
    @State private var chapter = 2
    var body: some View {
        NavigationStack {
            List {
                Section(T("资源")) {
                    Button(T("星星 +500")) { store.s.stars += 500 }
                    Button(T("宝石 +100")) { store.s.gems += 100 }
                    Button(T("体力加满")) { store.s.energy = MK.maxEnergy }
                    Button(T("无限体力 30 分钟")) { store.grantBoost(30, T("测试")) }
                    Button(T("升 1 级（现在 {0} 级）", store.s.level)) { store.debugLevelUp() }
                }
                Section(T("剧情")) {
                    Stepper(T("跳到第 {0} 章开头", chapter), value: $chapter, in: 1...MKStory.chapters.count)
                    Button(T("跳过去")) { store.debugJump(chapter: chapter); dismiss() }
                    ForEach(0...MKStory.chapters.count, id: \.self) { k in
                        Button(k == 0 ? T("看小戏：门缝里的小票") : T("看小戏：第 {0} 章章末", k)) { store.debugScene(k); dismiss() }
                    }
                    ForEach(MKStory.mysteries) { m in
                        Button(T("看谜底：") + m.q) { store.reveal = m; dismiss() }
                    }
                }
                Section(T("订单")) {
                    Button(T("把一张单变成急单（5 分钟）")) { store.debugRush(); dismiss() }
                    Button(T("现在来一张门单")) { store.refreshDoor(); dismiss() }
                }
                Section(T("通知")) {
                    Button(T("10 秒后发一条 9:41 门亮了（先退到后台）")) {
                        let c = UNMutableNotificationContent()
                        c.title = ChatStore.petName; c.body = T("门……刚刚亮了一下。"); c.sound = nil
                        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "door.test", content: c,
                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)))
                    }
                }
            }
            .navigationTitle(T("测试面板")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
