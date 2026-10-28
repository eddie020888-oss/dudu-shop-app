import Foundation

/// 资料 + 金币 + 钱包（背包/流水/每日奖励）。所有进出账都走这里并记流水。
@MainActor
final class ProfileStore: ObservableObject {
    @Published var profile = Profile.load() { didSet { profile.save() } }
    @Published var wallet = Wallet.load() { didSet { wallet.save() } }
    /// 刚到账的一笔，首页弹一下 "+10 签到"
    @Published private(set) var lastReward: Reward? = nil

    struct Reward: Equatable { let id = UUID(); let amount: Int; let reason: String }

    // MARK: 进账

    func earn(_ n: Int, _ reason: String) {
        guard n != 0 else { return }
        profile.coins += n
        log(n, reason)
        lastReward = Reward(amount: n, reason: reason)
    }

    func isClaimed(_ r: EarnRule) -> Bool {
        switch r {
        case .checkin: return wallet.lastCheckIn == Wallet.day()
        case .found:   return foundToday >= EarnRule.foundCap
        default:       return wallet.claimed.contains("\(Wallet.day())|\(r.rawValue)")
        }
    }

    // MARK: 离线捡钱：你不在的时候它在外面溜达，每离开 1 小时捡 2 个，每天最多 15

    var foundToday: Int { wallet.foundDay == Wallet.day() ? (wallet.foundToday ?? 0) : 0 }

    /// App 退到后台时记一下
    /// 灵动岛按钮在 App 外动了背包 → 重新读
    func reloadWallet() { let w = Wallet.load(); if w != wallet { wallet = w } }

    func markAway() { wallet.lastSeen = Date() }

    /// 回到前台：算离开了多久，返回捡到几个（0 = 没有）
    @discardableResult
    func collectFound() -> Int {
        defer { wallet.lastSeen = nil }
        guard let t = wallet.lastSeen else { return 0 }
        let hours = Int(Date().timeIntervalSince(t) / 3600)
        let n = min(hours * 2, EarnRule.foundCap - foundToday)
        guard n > 0 else { return 0 }
        wallet.foundToday = foundToday + n
        wallet.foundDay = Wallet.day()
        earn(n, T("它捡到的"))
        return n
    }

    /// 小游戏结算：每天第一局按接到的数量给（最多 10），之后只开心不给钱
    @discardableResult
    func rewardPlay(caught: Int) -> Int {
        guard caught > 0, !isClaimed(.play) else { return 0 }
        let n = min(caught, EarnRule.playCap)
        markClaimed(.play)
        earn(n, T("陪它玩 · 接到 {0} 个", caught))
        return n
    }

    private func markClaimed(_ r: EarnRule) {
        wallet.claimed.append("\(Wallet.day())|\(r.rawValue)")
        let keep = Set([Wallet.day(), Wallet.day(Date().addingTimeInterval(-86400))])
        wallet.claimed.removeAll { !keep.contains(String($0.prefix(10))) }
    }

    /// 每天一次的奖励；已领过返回 false
    @discardableResult
    func claim(_ r: EarnRule) -> Bool {
        guard r != .checkin, r != .found, r != .play, !isClaimed(r) else { return false }
        markClaimed(r)
        earn(r.amount, r.short)
        return true
    }

    /// 每日签到：连续签到每天多 2 币，最多多 10
    func dailyCheckIn() {
        let today = Wallet.day()
        guard wallet.lastCheckIn != today else { return }
        let yesterday = Wallet.day(Date().addingTimeInterval(-86400))
        wallet.streak = wallet.lastCheckIn == yesterday ? wallet.streak + 1 : 1
        wallet.lastCheckIn = today
        let bonus = min(wallet.streak - 1, 5) * 2
        earn(EarnRule.checkin.amount + bonus, wallet.streak > 1 ? T("签到 · 连续 {0} 天", wallet.streak) : T("签到"))
    }

    /// 步数达标（按档位，各一次）
    func checkSteps(_ steps: Int) {
        if steps >= 4000 { claim(.steps4k) }
        if steps >= 8000 { claim(.steps8k) }
        if steps >= 12000 { claim(.steps12k) }
    }

    /// 运动记录（每天最多两次）
    func rewardWorkout() { if !claim(.workout1) { claim(.workout2) } }

    // MARK: 出账

    func spend(_ n: Int, _ reason: String) -> Bool {
        guard profile.coins >= n else { return false }
        profile.coins -= n
        log(-n, reason)
        return true
    }

    func buy(_ a: Accessory) -> Bool {
        guard !profile.owned.contains(a.id), a.onSale(), spend(a.price, T("买 {0}", a.name)) else { return false }
        profile.owned.append(a.id)
        equip(a)
        return true
    }

    /// 白送一件配饰（季卡满级奖励等）：放进衣柜，不自动穿
    func grant(_ id: String) {
        // 窝里的纪念款：直接摆上
        if id.hasPrefix("nest."), !profile.owned.contains(id) {
            profile.owned.append(id)
            let parts = id.split(separator: ".")
            if parts.count == 3, let it = NestItem(rawValue: String(parts[1])), let n = Int(parts[2].dropFirst()) { it.choose(n) }
            return
        }
        guard Accessory.by(id) != nil, !profile.owned.contains(id) else { return }
        profile.owned.append(id)
    }

    /// 给窝添一件（随便买，买了当场摆上）
    func buyNest(_ i: NestItem) -> Bool {
        guard !i.free, !profile.owned.contains(i.ownedKey), spend(i.price, T("窝 · {0}", i.name)) else { return false }
        profile.owned.append(i.ownedKey)
        Analytics.log("nest_buy", ["item": i.rawValue])
        return true
    }

    /// 买窝里某个位置的新款（原款没买也能直接买新款）
    func buyNest(_ st: NestStyle) -> Bool {
        if st.n == 0 { return buyNest(st.item) }
        guard !profile.owned.contains(st.ownedKey), spend(st.price, T("窝 · {0}", st.name)) else { return false }
        profile.owned.append(st.ownedKey)
        Analytics.log("nest_buy", ["item": st.id])
        return true
    }

    func count(_ f: Food) -> Int { f.price == 0 && !f.dish ? .max : (wallet.bag[f.id] ?? 0) }
    /// 店里做好的菜带回家：放进背包
    func addToBag(_ id: String, _ n: Int = 1) { wallet.bag[id, default: 0] += n }

    @discardableResult
    func buy(_ f: Food, qty: Int = 1) -> Bool {
        guard f.price > 0, !f.dish, spend(f.price * qty, T("买 {0}{1}{2}", f.emoji, f.name, qty > 1 ? "×\(qty)" : "")) else { return false }
        wallet.bag[f.id, default: 0] += qty
        return true
    }

    /// 用掉一个（水免费不扣）
    func consume(_ f: Food) -> Bool {
        if f.price == 0 && !f.dish { return true }
        guard (wallet.bag[f.id] ?? 0) > 0 else { return false }
        wallet.bag[f.id]! -= 1
        return true
    }

    // MARK: 配饰

    func equip(_ a: Accessory) {
        profile.equipped.removeAll()            // 一次戴一件：每件都是它真戴上的样子（专门出的视频/图），叠戴会穿帮
        profile.equipped.append(a.id)
    }
    func unequip(_ a: Accessory) { profile.equipped.removeAll { $0 == a.id } }
    func isEquipped(_ a: Accessory) -> Bool { profile.equipped.contains(a.id) }

    private func log(_ n: Int, _ reason: String) {
        wallet.ledger.insert(.init(at: Date(), amount: n, reason: reason), at: 0)
        if wallet.ledger.count > 200 { wallet.ledger.removeLast(wallet.ledger.count - 200) }
    }
}
