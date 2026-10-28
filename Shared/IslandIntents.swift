import AppIntents
import ActivityKit
import Foundation

/// 灵动岛大岛上的按钮：不用打开 App 就能喂一口、摸摸它。
/// LiveActivityIntent 由系统放在 App 进程里执行（App 没开会在后台拉起），所以可以直接改存档、更新岛台。
struct IslandCareIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "照顾它"
    static var description = IntentDescription("在灵动岛上直接喂它一口或摸摸它")
    static var openAppWhenRun = false

    @Parameter(title: "动作") var action: String

    init() { action = "pet" }
    init(action: String) { self.action = action }

    func perform() async throws -> some IntentResult {
        let result = IslandCare.apply(action)
        await IslandCare.show(frame: result.frame, line: result.line)
        // App 在前台时让它重新读一下存档、记熟悉度
        await MainActor.run {
            NotificationCenter.default.post(name: Notification.Name("islandCare"), object: action)
        }
        return .result()
    }
}

/// 灵动岛上它说的话：按语言路线和阶段（App 每次熟悉度变化时存一下）
enum IslandTalk {
    static func store(route: String, stage: Int) {
        UserDefaults.standard.set(route, forKey: "island.route")
        UserDefaults.standard.set(stage, forKey: "island.stage")
    }
    /// 嘟语路线或还没学会说话 → 嘟；单词期 → 短；之后 → 整句
    static func say(_ zh: [String], _ en: [String], dudu: [String]) -> String {
        let d = UserDefaults.standard
        let route = d.string(forKey: "island.route") ?? "zh"
        let stage = d.integer(forKey: "island.stage")
        if route == "dudu" || stage == 0 { return dudu.randomElement()! }
        let pool = route == "en" ? en : zh
        let s = pool.randomElement()!
        if stage == 1 { return String(s.prefix(4)) + T("…嘟") }
        return s
    }
}

enum IslandCare {
    /// 改存档：喂 → 背包里最便宜的吃的一个；喝 → 水（免费）；摸 → 开心 +5%
    static func apply(_ action: String) -> (frame: String, line: String) {
        var needs = PetNeeds.load()
        defer { needs.save() }
        switch action {
        case "feed":
            var w = Wallet.load()
            guard let f = Food.shop.filter({ $0.main != .thirsty }).sorted(by: { $0.price < $1.price }).first(where: { (w.bag[$0.id] ?? 0) > 0 }) else {
                return ("hungry", IslandTalk.say([T("背包空了……"), T("没吃的了，去商城？")], ["Bag's empty…"], dudu: [T("嘟…🍙？")]))
            }
            if needs.level(.hungry) > 0.95 {
                return ("think", IslandTalk.say([T("吃不下了…"), T("饱了，躺会儿。")], ["Too full…"], dudu: [T("嘟…撑。")]))
            }
            w.bag[f.id, default: 1] -= 1
            w.save()
            for (n, d) in f.effects { needs.add(n, d) }
            pendingBond("feed")
            return ("eat", "\(f.emoji) " + IslandTalk.say([T("好吃！"), T("就一口…再一口。"), T("嚼嚼嚼…")], ["Yum!", "One more bite…"], dudu: [T("嘟嘟！"), T("嘟～")]))
        case "drink":
            if needs.level(.thirsty) > 0.95 {
                return ("think", IslandTalk.say([T("喝饱了…"), T("肚子里在晃。")], ["Full of water…"], dudu: [T("嘟…咕。")]))
            }
            needs.add(.thirsty, 0.45)
            pendingBond("drink")
            return ("coffee", "💧 " + IslandTalk.say([T("咕咚…舒服。"), T("温的，养生。")], ["Gulp… nice."], dudu: [T("嘟咕咚～")]))
        default:
            needs.add(.happy, 0.05)
            pendingBond("pet")
            // 连着摸：先害羞，再笑出声
            let d = UserDefaults.standard
            let now = Date().timeIntervalSince1970
            let recent = (d.array(forKey: "island.pets") as? [Double] ?? []).filter { now - $0 < 10 } + [now]
            d.set(recent, forKey: "island.pets")
            if recent.count >= 3 {
                return ("laugh", "❤️ " + IslandTalk.say([T("哈哈痒！别摸了…再摸一下。"), T("痒痒痒！")], ["Ticklish!"], dudu: [T("嘟嘟嘟嘟！")]))
            }
            return ("shy", "❤️ " + IslandTalk.say([T("嘿嘿…"), T("再摸摸。")], ["Hehe…"], dudu: [T("嘟…///")]))
        }
    }

    /// 岛台立刻换成吃东西/笑的样子，3 秒后回到原来
    static func show(frame: String, line: String) async {
        guard let a = Activity<IslandMeAttributes>.activities.first else { return }
        var s = a.content.state
        let old = s
        s.frame = frame
        s.lastLine = line
        s.tick += 1
        await a.update(.init(state: s, staleDate: nil))
        try? await Task.sleep(for: .seconds(5))
        var back = old
        back.tick = s.tick + 1
        back.lastLine = line
        await a.update(.init(state: back, staleDate: nil))
    }

    /// 熟悉度要在 App 里算；先记下来，App 下次打开时补上
    private static func pendingBond(_ a: String) {
        let d = UserDefaults.standard
        var q = d.stringArray(forKey: "island.pendingBond") ?? []
        q.append(a)
        d.set(Array(q.suffix(20)), forKey: "island.pendingBond")
    }
}
