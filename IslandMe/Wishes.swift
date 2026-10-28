import SwiftUI

/// 它主动的小心思（设定第 8、9、11、12 节）：小愿望、睡前盖毯子、讲梦的时间点。
/// 全部是"它想要"，不是"你必须"——没满足 2 小时后它自己算了，不罚。
@MainActor
enum Wishes {
    /// 该盖毯子的时间段：睡觉点前 2 小时到后 3 小时
    static func blanketTime(sleepHour: Int, now: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: now)
        let d = (h - sleepHour + 24) % 24
        return d >= 22 || d < 3
    }

    /// 你看着它的时候偶尔提一个小愿望：每天最多 2 个（加上饿/渴正好 3 次左右），两个之间至少隔 50 分钟
    static func maybeAsk(bond: BondStore, bag: [String: Int], sleepHour: Int, busy: Bool) -> PetRequest? {
        guard bond.hatched, bond.request?.expired ?? true, !busy, bond.requestsToday < 2, !Quiet.isQuiet(Date()) else { return nil }
        let d = UserDefaults.standard
        if let last = d.object(forKey: "wish.last") as? Date, Date().timeIntervalSince(last) < 50 * 60 { return nil }
        guard Int.random(in: 0..<3) == 0 else { return nil }
        var pool: [PetRequest] = [PetRequest(kind: .belly)]
        if blanketTime(sleepHour: sleepHour), !bond.didToday("blanket") {
            pool += [PetRequest(kind: .blanket), PetRequest(kind: .blanket)]
        }
        // 想喝上次喝过的那种（没喝过就要水）
        pool.append(PetRequest(kind: .drink, item: bond.lastDrink.isEmpty ? "water" : bond.lastDrink))
        // 想吃：背包里有的优先，没有就要便宜的（不让你破费）
        let foods = Food.shop.filter { $0.main != .thirsty }
        let owned = foods.filter { (bag[$0.id] ?? 0) > 0 }
        if let f = (owned.isEmpty ? foods.filter { $0.price <= 12 } : owned).randomElement() {
            pool.append(PetRequest(kind: .food, item: f.id))
        }
        // 开过店：有时想吃店里才有的菜（背包里有就直接喂，没有就提醒你去店里做）
        if d.bool(forKey: "merge.opened") {
            let lv = d.integer(forKey: "merge.level")
            let can = Food.dishes.filter { f in MK.recipe(f.id).map { MK.can($0, max(lv, 1)) } ?? false }
            if let f = can.randomElement() { pool += [PetRequest(kind: .food, item: f.id), PetRequest(kind: .food, item: f.id)] }
        }
        d.set(Date(), forKey: "wish.last")
        return pool.randomElement()
    }

    static func line(_ r: PetRequest) -> String {
        switch r.kind {
        case .food, .drink: return Voice.line("req." + r.kind.rawValue, ["food": Food.by(r.item)?.name ?? ""])
        case .belly:        return Voice.line("req.belly")
        case .blanket:      return Voice.line("req.blanket")
        }
    }

    static func frame(_ r: PetRequest) -> String {
        switch r.kind { case .food: return "hungry"; case .drink: return "thirsty"; case .belly: return "shy"; case .blanket: return "yawn" }
    }

    static func label(_ r: PetRequest) -> String {
        switch r.kind {
        case .food, .drink:
            let f = Food.by(r.item)
            return (r.kind == .food ? T("想吃 ") : T("想喝 ")) + (f.map { $0.emoji + $0.name } ?? "")
        case .belly:   return T("想被摸肚子")
        case .blanket: return T("困了，想盖毯子")
        }
    }

    /// 讲梦的时机：起床后 5 小时内（"醒来后"），安静时段不讲
    static func dreamTime(wakeHour: Int, now: Date = Date()) -> Bool {
        let h = Calendar.current.component(.hour, from: now)
        let d = (h - wakeHour + 24) % 24
        return d < 5 && !Quiet.isQuiet(now)
    }

    /// 梦的内容按它会说到哪：能说短句才自己讲，否则旁白描述它比划
    static func dreamLine(_ d: Dream) -> String {
        if Voice.route == .en && Voice.stage >= 2 { return d.textEn }
        if Voice.route == .zh && Voice.stage >= 2 { return d.text }
        let t = Voice.route == .en ? d.textEn : d.text
        return Voice.route == .en ? "(It mimes a dream for a while… \(t))" : T("（它比划了半天，好像是：{0}）", t)
    }
}

/// 舞台顶部的小愿望气泡：点一下就去满足
struct WishChip: View {
    let request: PetRequest
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle").font(.system(size: 10, weight: .semibold))
                Text(Wishes.label(request))
            }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color(hex: "#E9DEFF"))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.press)
    }
}
