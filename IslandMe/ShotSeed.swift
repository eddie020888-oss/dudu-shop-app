import Foundation

/// 商店截图模式（只在模拟器里用启动参数 -shot 打开，普通用户碰不到）：
/// 预先摆好一个玩了一个月的存档——孵好的嘟嘟、戴着贝雷帽、窝里家具齐全、小店到第 5 章、嘟嘟星亮了 4 块，
/// 不弹任何权限框。-shotTab N 首页0/窝1/商城2/我3/小店4，-shotShop N 商城分页，-shotRoom N 窝的房间，
/// -shotScene K 小店里直接演第 K 章章末小戏，-shotMap 打开嘟嘟星地图。
enum Shot {
    #if DEBUG
    static let args = ProcessInfo.processInfo.arguments
    #else
    static let args: [String] = []   // 正式包没有截图模式
    #endif
    static var on: Bool { args.contains("-shot") }
    private static func val(_ k: String) -> String? {
        guard let i = args.firstIndex(of: k), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    static var tab: Int { Int(val("-shotTab") ?? "") ?? 0 }
    static var shopTab: Int { Int(val("-shotShop") ?? "") ?? 0 }
    static var room: Int? { val("-shotRoom").flatMap { Int($0) } }
    static var scene: Int? { val("-shotScene").flatMap { Int($0) } }
    static var map: Bool { args.contains("-shotMap") }
    /// 截图：直接打开一个小游戏（-shotGame fling|cups|dudu|match|coins|stars）
    static var game: GameKind? { on ? val("-shotGame").flatMap { GameKind(rawValue: $0) } : nil }
    static var autoStart: Bool { on && args.contains("-shotAutoStart") }
    static var pickGame: Bool { on && args.contains("-shotPickGame") }

    static func seed() {
        guard on else { return }
        let d = UserDefaults.standard
        // 换语言重拍时清掉上一轮的聊天记录（不然英文图里是中文聊天）
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("chat.json"))
        d.set(true, forKey: "onboarded.v1")
        d.set(true, forKey: "merge.opened")
        var b = BondState()
        b.hatched = true; b.hatchDate = Date().addingTimeInterval(-36 * 86400)
        b.route = L10n.isEN ? .en : .zh; b.familiarity = 420
        b.favoriteFood = "boba"; b.favoriteFound = true; b.firstFood = "riceball"; b.firstDrink = "water"
        b.signature = "嘟嘟·嘟♡"; b.lastActive = Date()
        for m in Milestone.allCases { b.milestones[m.rawValue] = Date().addingTimeInterval(-86400) }   // 不弹里程碑卡
        if let data = try? JSONEncoder().encode(b) { d.set(data, forKey: "bond.v1") }
        var p = Profile()
        p.petName = T("嘟嘟"); p.coins = 1280; p.myName = ""
        p.owned = Accessory.all.map(\.id) + NestItem.allCases.map(\.ownedKey)
        p.equipped = ["hat_beret"]
        p.save()
        var s = MKState.demo()
        let chs = MKStory.chapters
        s.done = chs.prefix(4).flatMap { $0.tasks.map(\.id) }
        s.doorLit = [1, 2, 3, 4]
        s.stars = 64; s.tut = 99; s.introSeen = true; s.ticketsServed = 60; s.served = 80
        s.lastSeen = Date(); s.firstDay = Date().addingTimeInterval(-30 * 86400)
        s.boostDay = Wallet.day(); s.ordersDeduped = true; s.luckyDay = Wallet.day()
        s.orders.removeAll { $0.isEvent }
        s.orders.insert(MKOrder(items: ["rice5"], stars: 7, gems: 3, meal: "🌙 " + MKStory.doors[4].name, made: Date(), door: 5), at: 1)
        s.save()
    }
}
