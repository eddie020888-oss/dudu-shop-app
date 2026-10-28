import SwiftUI

// MARK: - 自测机器人（只在模拟器跑：-demoKitchen -demoFresh -selfTest）
// 用真代码从新开局一路玩：每「天」补满体力和产出器、让计时的东西到点，然后按玩家的思路操作，
// 一直玩到 72 件装修全做完或到 120 天，记录每天的进度和任何卡住的地方。
@MainActor
enum MKBot {
    struct Day { let day: Int; let level: Int; let served: Int; let stars: Int; let done: Int; let actions: Int; let stuck: Bool }
    struct Report { var days: [Day] = []; var notes: [String] = []; var dishes = Set<String>(); var maxTier: [String: Int] = [:]; var bagOverflow = 0; var mixes: [String] = []; var ordered = Set<String>();
        // 真人模式（-selfTestHuman）：钱包、买过什么、每天的账
        var coins = 0; var coinsTotal = 0; var buys: [String] = []; var ledger: [String] = []; var goals = 0; var bonusDays = 0; var packs = 0
        var idleEnergy = 0; var firstSeen: [String: Int] = [:]; var kinds: [String: Int] = [:]; var total: [String: Int] = [:] }

    static func run(_ st: MKStore, maxDays: Int = 120, energyPerDay: Int = 400, human: Bool = false) -> Report {
        st.noSave = true
        var rep = Report()
        st.s.tut = 99
        if human { UserDefaults.standard.removeObject(forKey: "mk.books"); st.double = false }
        for d in 1...maxDays {
            // 真人：早上睡醒体力满 100 + 每天第一次开店 30 分钟无限体力（按 150 算）+ 走路 5000 步（50）
            newDay(st, energy: human ? MK.maxEnergy + 200 : energyPerDay)
            if human { humanDayStart(st, &rep, d) }
            let served0 = st.s.served
            var actions = 0, idle = 0
            for session in 0..<(human ? 4 : 3) {
            if session > 0 {
                refillGens(st); idle = 0
                // 真人：一天开 4 次，中间隔 4 小时左右，体力回满 100（不会超过 100）
                if human { st.s.energy = max(st.s.energy, MK.maxEnergy) }
            }
            if human, st.s.level >= MKStore.doubleLevel { st.double = st.s.energy >= 60 }
            while actions < 4000 {
                if human, st.double, st.s.energy < 10 { st.double = false }
                actions += 1
                let before = (st.s.board, st.s.served, st.s.energy, st.s.cooks, st.s.bag)
                for o in st.s.orders { for it in o.items where MK.recipe(it) != nil { rep.ordered.insert(it) } }
                let did = step(st, &rep)
                let changed = before.0 != st.s.board || before.1 != st.s.served || before.2 != st.s.energy || before.3 != st.s.cooks || before.4 != st.s.bag
                if did && changed { idle = 0 } else { idle += 1; if did { rep.kinds["noop", default: 0] += 1 } }
                if idle > 2 { break }
            }
            if human {
                if st.s.energy >= 20 { rep.idleEnergy += 1 }
                humanSessionEnd(st, &rep, d)
            }
            }
            while let t = st.nextTask, st.s.stars >= t.stars { st.doTask(t) }
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? "day \(d) level \(st.s.level) served \(st.s.served) done \(st.s.done.count) board \(st.s.board.filter { $0.item != nil }.count) bag \(st.s.bag.count) coins \(rep.coins) gems \(st.s.gems)\n"
                    .appendLine(to: dir.appendingPathComponent("selftest_progress.txt"))
            }
            if human {
                rep.ledger.append(String(format: "%3d %3d %4d %3d/%d %6d %5d %4d %4d %3d/%d", d, st.s.level, st.s.served - served0, st.s.done.count, MKStory.all.count,
                                         rep.coins, st.s.gems, st.s.stars, st.s.packs ?? 0, st.cardsOwned, MKCards.all.count))
            }
            let stuck = st.s.served == served0
            rep.days.append(Day(day: d, level: st.s.level, served: st.s.served - served0, stars: st.s.stars, done: st.s.done.count, actions: actions, stuck: stuck))
            if st.s.served - served0 <= 3, rep.mixes.count < 4 { rep.mixes.append(T("第 {0} 天（{1} 级，交了 {2} 单）", d, st.s.level, st.s.served - served0) + boardMix(st)) }
            if stuck, rep.notes.count < 6 {
                let ords = st.s.orders.map { $0.items.map(MK.name).joined(separator: "+") }.joined(separator: " | ")
                rep.notes.append(T("第 {0} 天一单都没交成（台面 {1}/{2}，体力 {3}）订单：{4}；动作：{5}", d, st.s.board.filter { $0.item != nil }.count, MK.cols * MK.rows, st.s.energy, ords, rep.kinds.sorted { $0.key < $1.key }.map { "\($0.key)\($0.value)" }.joined(separator: " ")))
            }
            for (k, v) in rep.kinds { rep.total[k, default: 0] += v }
            if st.s.orders.contains(where: { $0.isSignature }) { rep.total[T("招牌没交"), default: 0] += 1 }
            rep.kinds = [:]
            if st.s.done.count >= MKStory.all.count { rep.notes.append(T("第 {0} 天：{1} 件装修全部完成 ✅", d, MKStory.all.count)); break }
        }
        for slot in st.s.board { if let id = slot.item, let c = MK.chain(id) { rep.maxTier[c.key] = max(rep.maxTier[c.key] ?? 0, MK.tier(id)) } }
        for id in st.s.found { if let c = MK.chain(id) { rep.maxTier[c.key] = max(rep.maxTier[c.key] ?? 0, MK.tier(id)) } }
        rep.dishes = Set(st.s.found.filter { MK.recipe($0) != nil })
        rep.bagOverflow = max(0, st.s.bag.count - st.s.bagSlots)
        return rep
    }

    static func refillGens(_ st: MKStore) {
        for i in st.s.board.indices { if let id = st.s.board[i].item, MK.isGen(id) { st.s.board[i].charges = MK.genCharges[st.s.board[i].glv]; st.s.board[i].refillAt = nil } }
        let past = Date().addingTimeInterval(-1)
        for k in st.s.cooks.keys where st.s.cooks[k]?.doneAt != nil { st.s.cooks[k]?.doneAt = past }
    }
    /// 新的一天：体力、产出器、计时的厨具 / 宝箱都到点
    static func newDay(_ st: MKStore, energy: Int) {
        // 交不了的老单换掉（真人也会这么做）
        for o in st.s.orders where !o.isPet && !o.isEvent && !st.canServe(o) && st.swapCost(o) == 0 && Int.random(in: 0..<3) == 0 { st.swap(o) }
        for k in st.s.orders.indices where st.s.orders[k].made != nil { st.s.orders[k].made = Date().addingTimeInterval(-8000) }
        st.s.energy = max(st.s.energy, energy)
        st.s.focusDay = nil; st.refreshFocus()           // 模拟的新一天：换今天热卖
        st.s.signatureDay = nil; st.refreshSignature()   // 和今日招牌
        st.s.bigDay = nil; st.refreshBig()                // 和大订单（交掉了第二天再来）
        let past = Date().addingTimeInterval(-1)
        for i in st.s.board.indices {
            if let id = st.s.board[i].item, MK.isGen(id) { st.s.board[i].charges = MK.genCharges[st.s.board[i].glv]; st.s.board[i].refillAt = nil }
            if st.s.board[i].openAt != nil { st.s.board[i].openAt = past }
            if st.s.board[i].bubbleUntil != nil { st.s.board[i] = MKSlot(item: "coins") }
        }
        for k in st.s.cooks.keys where st.s.cooks[k]?.doneAt != nil { st.s.cooks[k]?.doneAt = past }
        // 背包里的东西拿回台面（产出器、厨具优先）
        let need = needed(st)
        for k in st.s.bag.indices.reversed() {
            let id = String(st.s.bag[k].split(separator: "@")[0])
            if (MK.isGen(id) && need.chains.contains(String(id.dropFirst(4)))) || (MK.isAppliance(id) && MK.recipes.contains { $0.at == id && need.dishes.contains($0.id) }) { st.unstash(k) }
        }
    }

    /// 走一步；返回这一步有没有做成事
    static func step(_ st: MKStore, _ rep: inout Report) -> Bool {
        let b = st.s.board
        // 1. 能交的单先交（它的饭优先）
        if let o = st.s.orders.sorted(by: { ($0.isPet ? 0 : 1) < ($1.isPet ? 0 : 1) }).first(where: { st.canServe($0) }) {
            if o.isSignature { rep.kinds[T("招牌交了"), default: 0] += 1 }
            if o.isBig { rep.kinds["大订单交了" + "\(MK.tier(o.items[0]))级", default: 0] += 1 }
            if o.items.contains(where: { MK.recipe($0).map(MK.isDeep) ?? false }) { rep.kinds["深菜单交了", default: 0] += 1 }
            let kind = o.isPet ? "单·嘟嘟的饭" : o.isBig ? "单·大订单" : o.isSignature ? "单·招牌" : o.isDoor ? "单·门口" : o.isEvent ? "单·活动" : o.isRush ? "单·急单" : o.regular != nil ? "单·熟客" : "单·外卖"
            rep.kinds[kind, default: 0] += 1
            if o.items.contains(where: { MK.recipe($0) != nil }) { rep.kinds["单里有菜", default: 0] += 1 }
            _ = st.serve(o); rep.kinds["serve", default: 0] += 1; return true
        }
        // 2. 收菜、开箱、收小东西
        for (i, sl) in b.enumerated() where !sl.boxed && sl.bubbleUntil == nil {
            guard let id = sl.item else { continue }
            if MK.isAppliance(id), let c = st.s.cooks[id], c.dish != nil, let at = c.doneAt, at <= Date() {
                let n = st.s.found.count; st.tap(i); if st.s.cooks[id]?.dish == nil { _ = n; return true }
            }
            if MK.chests[id] != nil, freeCells(st) >= 3, sl.openAt.map({ $0 <= Date() }) ?? true { st.selected = i; st.tap(i); rep.kinds["chest", default: 0] += 1; return true }
            if ["energy", "gem", "star", "coins", "wildcard"].contains(id) == false, MK.chain(id) == nil, MK.recipe(id) == nil, !MK.isGen(id), !MK.isAppliance(id), id != "scissors" {
                st.tap(i); if st.s.board[i].item != id { return true }
            }
            if ["energy", "gem", "star", "coins"].contains(id) { st.tap(i); return true }
        }
        let need = needed(st)
        // 3. 订单要菜：每台厨具认准一道菜，把食材放进去
        for ap in MK.appliances {
            guard let ai = b.firstIndex(where: { $0.item == ap.id }), st.s.cooks[ap.id]?.dish == nil else { continue }
            // 只做还缺的菜（之前会一直做同一道，台面上堆了二十几份便当）
            let wantRs = MK.recipes.filter { $0.at == ap.id && MK.can($0, st.s.level) && need.dishes.contains($0.id) && countOf(st, $0.id) + cookingCount(st, $0.id) < max(1, need.count($0.id)) }
            let have = st.s.cooks[ap.id]?.putIn ?? []
            let target: MK.Recipe?
            if !have.isEmpty {
                target = wantRs.first { r in have.allSatisfy { r.needs.contains($0) } }
                if target == nil { st.tap(ai); rep.kinds["eject", default: 0] += 1; return true }
            } else {
                target = wantRs.first { r in r.needs.allSatisfy { n in b.contains { $0.item == n && !$0.boxed } } }
            }
            guard let r = target else { continue }
            for n in r.needs where !have.contains(n) {
                if let k = b.firstIndex(where: { $0.item == n && !$0.boxed && $0.bubbleUntil == nil }) {
                    st.drop(from: k, to: ai); rep.kinds["cook", default: 0] += 1; return true
                }
            }
        }
        // 4. 合成：两个一样的（只合到订单 / 菜谱用得上的级别，图鉴收集允许到 10 级）
        var seen: [String: Int] = [:]
        for (i, sl) in b.enumerated() where !sl.boxed && sl.bubbleUntil == nil {
            guard let id = sl.item else { continue }
            let cap = freeCells(st) > 14 ? MK.maxTier : MK.orderTop(st.s.level) + 1
            if MK.chain(id) != nil, MK.tier(id) < cap, !need.items.contains(id) || countOf(st, id) > need.count(id) + 1 {
                if let j = seen[id] { st.drop(from: j, to: i); rep.kinds["merge", default: 0] += 1; return true }
                seen[id] = i
            }
            if MK.isGen(id), sl.glv < 3, let j = seen["G" + id + "\(sl.glv)"] { st.drop(from: j, to: i); return true }
            if MK.isGen(id) { seen["G" + id + "\(sl.glv)"] = i }
        }
        // 5. 万能星用在订单要的东西差一级的地方
        if let w = b.firstIndex(where: { $0.item == "wildcard" }) {
            if let k = b.indices.first(where: { k in guard !b[k].boxed, b[k].bubbleUntil == nil, let id = b[k].item, MK.chain(id) != nil else { return false }; let up = MK.chain(id)!.key + "\(MK.tier(id) + 1)"; return need.items.contains(up) }) {
                st.drop(from: w, to: k); return true
            }
        }
        // 5b. 小剪刀：订单要 k 级、台面上只有用不上的 k+1 级 → 剪成两个 k 级（真人会这么用）
        if let sc = b.firstIndex(where: { $0.item == "scissors" && !$0.boxed }) {
            for it in Set(need.items) where MK.chain(it) != nil && countOf(st, it) < need.count(it) {
                let up = MK.chain(it)!.key + "\(MK.tier(it) + 1)"
                if !need.items.contains(up), let k = b.indices.first(where: { b[$0].item == up && !b[$0].boxed && b[$0].bubbleUntil == nil }) {
                    st.drop(from: sc, to: k); rep.kinds["scissors", default: 0] += 1; return true
                }
            }
        }
        // 6. 点产出器（挑订单要的链）
        guard st.s.energy > 0 else { return false }
        let free = freeCells(st)
        // 订单换了要的链：背包里对应的产出器 / 厨具拿回来（真人也会）
        if free >= 4, let k = st.s.bag.indices.first(where: { k in
            let id = String(st.s.bag[k].split(separator: "@")[0])
            return (MK.isGen(id) && need.chains.contains(String(id.dropFirst(4)))) || (MK.isAppliance(id) && MK.recipes.contains { $0.at == id && need.dishes.contains($0.id) })
        }) { st.unstash(k); rep.kinds["unstash", default: 0] += 1; return true }
        // 背包里有订单要的货：台面宽裕时拿出来
        if free >= 8, let k = st.s.bag.indices.first(where: { k in
            let id = String(st.s.bag[k].split(separator: "@")[0])
            return need.items.contains(id) || (MK.chests[id] != nil) || id == "luckybag"
        }) { st.unstash(k); rep.kinds["unstash", default: 0] += 1; return true }
        // 腾地方：先卖真正没用的（不在订单链上的 → 比订单要的还高的 → 没人要的菜），绝不卖订单链上正在往上合的低级货
        if free < 4, let k = junk(st, need) {
            if MK.recipe(b[k].item ?? "") != nil, st.s.bag.count < st.s.bagSlots { st.stash(k) } else { st.sell(k) }
            rep.kinds["clear", default: 0] += 1; return true
        }
        // 台面紧：不在热卖里的产出器、用不上的厨具先收进背包
        if free < 6, st.s.bag.count < st.s.bagSlots, let k = b.indices.first(where: { k in
            guard let id = b[k].item, !b[k].boxed else { return false }
            if MK.isGen(id) { return !need.chains.contains(String(id.dropFirst(4))) }
            if MK.isAppliance(id) { return st.s.cooks[id]?.dish == nil && (st.s.cooks[id]?.putIn ?? []).isEmpty && !MK.recipes.contains { $0.at == id && need.dishes.contains($0.id) } }
            return false
        }) { st.stash(k); rep.kinds["stash", default: 0] += 1; return true }
        if free == 0 {
            // 实在没东西可腾：多出来的同级货（比需要的多 2 个以上）卖一个
            var cnt: [String: Int] = [:]
            for sl in b where !sl.boxed { if let id = sl.item, MK.chain(id) != nil { cnt[id, default: 0] += 1 } }
            if let e = cnt.filter({ $0.value > need.count($0.key) + 2 }).min(by: { MK.value($0.key) < MK.value($1.key) }),
               let k = b.indices.first(where: { b[$0].item == e.key && !b[$0].boxed && b[$0].bubbleUntil == nil }) {
                st.sell(k); rep.kinds["sell", default: 0] += 1; return true
            }
            rep.kinds[T("台面满到没东西可腾"), default: 0] += 1
            // 真人这时会狠心卖一个：最便宜的低级货（哪怕订单链上的），先腾出一格再说（之前机器人在这儿连卡 3 天）
            if let k = b.indices.filter({ k in guard let id = b[k].item, !b[k].boxed, b[k].bubbleUntil == nil else { return false }; return MK.chain(id) != nil }).min(by: { MK.value(b[$0].item!) < MK.value(b[$1].item!) }) {
                st.sell(k); rep.kinds["sell", default: 0] += 1; return true
            }
            return false
        }
        // 宝石够就给要用的产出器升级
        if let k = b.indices.first(where: { k in guard let id = b[k].item, MK.isGen(id), b[k].glv < 3 else { return false }
            return need.chains.contains(String(id.dropFirst(4))) && st.s.gems >= st.genUpgradeCost(b[k].glv) + 4 }) {
            st.upgradeGen(k); rep.kinds["genup", default: 0] += 1; return true
        }
        // 台面紧：先卖不在今天订单里的链的东西
        if free < 8, let k = junk(st, need, chainsOnly: true) {
            st.sell(k); rep.kinds["selloff", default: 0] += 1; return true
        }
        let gens = b.indices.filter { k in guard let id = b[k].item else { return false }; return MK.isGen(id) && b[k].charges > 0 }
        let wanted = gens.filter { k in let key = String(b[k].item!.dropFirst(4)); return need.chains.contains(key) }
        if let g = wanted.randomElement() ?? (free > 20 ? gens.randomElement() : nil) { st.tap(g); rep.kinds["gen", default: 0] += 1; return true }
        return false
    }

    struct Need { var items: [String] = []; var dishes: Set<String> = []; var chains: Set<String> = []
        func count(_ id: String) -> Int { items.filter { $0 == id }.count } }
    static func needed(_ st: MKStore) -> Need {
        var n = Need()
        for o in st.s.orders { for it in o.items {
            n.items.append(it)
            if let r = MK.recipe(it) {
                n.dishes.insert(r.id)
                for x in MK.allNeeds(r.id) { n.items.append(x); if let c = MK.chain(x) { n.chains.insert(c.key) }; if MK.recipe(x) != nil { n.dishes.insert(x) } }
            }
            if let c = MK.chain(it) { n.chains.insert(c.key) }
        } }
        return n
    }
    /// 台面上最该清掉的一格：不在订单链上的货 < 比订单要的最高级还高的货 < 订单不要的菜；同类里先清便宜的
    static func junk(_ st: MKStore, _ need: Need, chainsOnly: Bool = false) -> Int? {
        let b = st.s.board
        var top: [String: Int] = [:]
        for it in need.items { if let c = MK.chain(it) { top[c.key] = max(top[c.key] ?? 0, MK.tier(it)) } }
        func rank(_ k: Int) -> Int? {
            guard let id = b[k].item, !b[k].boxed, b[k].bubbleUntil == nil else { return nil }
            // 做多了的菜（比订单要的多）也可以清
            if !chainsOnly, MK.recipe(id) != nil, need.items.contains(id), countOf(st, id) > need.count(id) { return 2 }
            guard !need.items.contains(id) else { return nil }
            if let c = MK.chain(id) {
                guard let t = top[c.key] else { return 0 }
                return MK.tier(id) > t ? 1 : nil
            }
            if !chainsOnly, MK.recipe(id) != nil, !need.dishes.contains(id) { return 2 }
            // 小剪刀留 2 把够用，多的卖掉（之前机器人攒了 20 多把，占掉台面三分之一）
            if !chainsOnly, id == "scissors", b.filter({ $0.item == "scissors" }).count > 2 { return 1 }
            return nil
        }
        return b.indices.compactMap { k in rank(k).map { (k, $0) } }
            .min { ($0.1, MK.value(b[$0.0].item!)) < ($1.1, MK.value(b[$1.0].item!)) }?.0
    }
    // MARK: 真人模式
    static func humanDayStart(_ st: MKStore, _ rep: inout Report, _ d: Int) {
        // 新的一天：签到（连续）、每日小目标、小铺换货
        let today = Wallet.day(), yesterday = Wallet.day(Date().addingTimeInterval(-86400))
        st.s.loginDay = d == 1 ? "" : yesterday
        st.s.daily = nil
        st.refreshDaily()
        if st.s.loginDay == today { st.giveLogin(st.s.loginStreak ?? 1) }
        st.s.dealsDay = ""; st.refreshDeals()
        st.s.energyBuys = 0
        for (k, v) in [("double", st.s.level >= MKStore.doubleLevel), ("big", st.s.orders.contains { $0.isBig }),
                       ("door", st.s.orders.contains { $0.isDoor }), ("sign", st.s.orders.contains { $0.isSignature })] where v && rep.firstSeen[k] == nil {
            rep.firstSeen[k] = d
        }
    }
    static func humanSessionEnd(_ st: MKStore, _ rep: inout Report, _ d: Int) {
        // 每日小目标：做完的领掉；三个都领了再领每日宝箱
        for g in st.s.daily?.goals ?? [] where g.done && !g.claimed { st.claimGoal(g); rep.goals += 1 }
        if let dl = st.s.daily, !dl.bonus, dl.goals.allSatisfy(\.claimed) { st.claimDailyBonus(); rep.bonusDays += 1 }
        // 拍立得：有包就开；星光够就换大宝箱
        while (st.s.packs ?? 0) > 0, st.openPack() != nil { rep.packs += 1 }
        while (st.s.stardust ?? 0) >= MKCards.exchangeCost { st.exchangeDust(); rep.buys.append(T("第 {0} 天 星光换大宝箱", d)) }
        // 钱包
        rep.coins += st.coinsEarned; rep.coinsTotal += st.coinsEarned; st.coinsEarned = 0
        // 菜谱书：等级到了、钱够就买（真人看到「新菜谱用得上了」会去买）
        for b in MK.books where !MK.hasBook(b.id) && st.s.level >= b.level && rep.coins >= b.price {
            rep.coins -= b.price; MK.addBook(b.id); rep.buys.append(T("第 {0} 天（{1} 级）买「{2}」{3} 币", d, st.s.level, b.name, b.price))
        }
        let reserve = MK.books.filter { !MK.hasBook($0.id) && st.s.level + 2 >= $0.level }.map(\.price).min() ?? 0
        // 小铺：订单要的货有卖就买（留着买书的钱）；宝石多了买宝箱
        let need = needed(st)
        for deal in st.s.deals where !deal.sold {
            if !deal.gem, need.items.contains(deal.item), rep.coins - deal.price >= reserve, let c = st.buyDeal(deal, coins: rep.coins) {
                rep.coins -= c; rep.kinds["买小铺货", default: 0] += 1
            } else if deal.gem, deal.item == "chest2", st.s.gems >= 40, st.buyDeal(deal, coins: rep.coins) != nil {
                rep.kinds["宝石买宝箱", default: 0] += 1
            }
        }
        // 体力见底、宝石富余：买体力（越买越贵，真人一天最多买一两次）
        if st.s.energy < 20, st.energyCost <= 10, st.s.gems >= st.energyCost + 20 { st.buyEnergy(); rep.kinds["宝石买体力", default: 0] += 1 }
        // 背包满了、宝石富余：多开一格
        if st.s.bag.count >= st.s.bagSlots, st.s.gems >= st.bagSlotCost + 10 { st.buyBagSlot(); rep.kinds["买背包格", default: 0] += 1 }
        // 装修：星星够就做
        while let t = st.nextTask, st.s.stars >= t.stars { st.doTask(t) }
    }

    /// 卡住时台面上都是什么（找「台面不够用」的根因）
    static func boardMix(_ st: MKStore) -> String {
        let need = needed(st)
        var top: [String: Int] = [:]
        for it in need.items { if let c = MK.chain(it) { top[c.key] = max(top[c.key] ?? 0, MK.tier(it)) } }
        var m: [String: Int] = [:]
        var lows: [String: Int] = [:]
        for sl in st.s.board {
            guard let id = sl.item else { m["空"] = (m["空"] ?? 0) + 1; continue }
            let k: String
            if sl.boxed { k = "纸箱" }
            else if MK.isGen(id) { k = "产出器" }
            else if MK.isAppliance(id) { k = "厨具" }
            else if MK.chests[id] != nil || id == "luckybag" { k = "宝箱福袋" }
            else if MK.recipe(id) != nil { k = need.dishes.contains(id) ? "订单要的菜" : "没人要的菜" }
            else if let c = MK.chain(id) {
                if need.items.contains(id) { k = "订单要的货" }
                else if let t = top[c.key], MK.tier(id) < t { k = "往上合的低级货"; lows[id, default: 0] += 1 }
                else { k = "其他货" }
            } else { k = "道具(" + id + ")" }
            m[k, default: 0] += 1
        }
        let single = lows.filter { $0.value == 1 }.count
        return "  台面：" + m.sorted { $0.value > $1.value }.map { "\($0.key)\($0.value)" }.joined(separator: " ")
            + "；低级货里落单（没有同伴可合）的 \(single) 种；背包 \(st.s.bag.count)/\(st.s.bagSlots)"
    }
    static func cookingCount(_ st: MKStore, _ id: String) -> Int { st.s.cooks.values.filter { $0.dish == id }.count }
    static func freeCells(_ st: MKStore) -> Int { st.s.board.filter { $0.item == nil && !$0.boxed }.count }
    static func countOf(_ st: MKStore, _ id: String) -> Int { st.s.board.filter { $0.item == id && !$0.boxed }.count }
}

struct MKBotView: View {
    @State private var text = T("机器人在玩……")
    var body: some View {
        ScrollView {
            Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading).padding(14).padding(.top, 50)
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            let a = MKDemo.args
            let days = a.firstIndex(of: "-selfTestDays").flatMap { Int(a[safe: $0 + 1] ?? "") } ?? 120
            let runs = a.firstIndex(of: "-selfTestRuns").flatMap { Int(a[safe: $0 + 1] ?? "") } ?? 1
            var lines: [String] = [T("自测：真代码从新开局一路玩（每天 400 体力），跑 {0} 局", runs), ""]
            var tail: [String] = []
            for run in 1...runs {
                let st = MKStore()
                let t0 = Date()
                let human = a.contains("-selfTestHuman")
                let r = MKBot.run(st, maxDays: days, human: human)
                let fin = r.days.first { $0.done >= MKStory.all.count }
                let slow = r.days.filter { $0.served <= 3 }
                lines.append(T("【第 {0} 局】用时 {1} 秒；", run, Int(Date().timeIntervalSince(t0))) + (fin.map { T("第 {0} 天装修全做完", $0.day) } ?? T("{0} 天装修 {1}/{2}", r.days.count, r.days.last?.done ?? 0, MKStory.all.count))
                    + T("；交单 ≤3 的天 {0} 个、一单没交 {1} 个；台面满到没东西可腾 {2} 次；背包超出 {3}", slow.count, r.days.filter(\.stuck).count, r.total[T("台面满到没东西可腾")] ?? 0, r.bagOverflow))
                lines.append(T("天  级  交单  星  装修  步数"))
                for d in r.days where d.day <= 3 || d.day % 5 == 0 || d.day == r.days.count {
                    lines.append(String(format: "%3d %3d %4d %4d %4d/%d %5d", d.day, d.level, d.served, d.stars, d.done, MKStory.all.count, d.actions))
                }
                lines.append(contentsOf: r.mixes)
                if human {
                    lines.append(T("真人模式：每天开 4 次店；钱包按小店赚的币算（商城里别的花销不算）"))
                    lines.append(T("天  级  交单  装修   剩币  宝石  星  卡包  拍立得"))
                    lines.append(contentsOf: r.ledger.enumerated().filter { $0.offset < 3 || ($0.offset + 1) % 5 == 0 || $0.offset == r.ledger.count - 1 }.map(\.element))
                    lines.append(T("一共赚 {0} 币；领每日小目标 {1} 个、每日宝箱 {2} 天；开卡包 {3} 包；体力还剩 20 以上就没事可做的场次 {4}", r.coinsTotal, r.goals, r.bonusDays, r.packs, r.idleEnergy))
                    lines.append(T("第一次出现：") + r.firstSeen.sorted { $0.value < $1.value }.map { "\($0.key) 第\($0.value)天" }.joined(separator: "，"))
                    lines.append(contentsOf: r.buys.prefix(12))
                }
                let never = MK.recipes.filter { !r.ordered.contains($0.id) }.map { "\($0.name)(\($0.unlock))" }
                let notMade = MK.recipes.filter { r.ordered.contains($0.id) && !r.dishes.contains($0.id) }.map(\.name)
                lines.append(T("从没上过单的菜 {0}：", never.count) + never.joined(separator: "、"))
                lines.append(T("上过单但没做成的菜 {0}：", notMade.count) + notMade.joined(separator: "、"))
                lines.append(T("做出过的菜 {0}/{1}", r.dishes.count, MK.recipes.count) + T("；各链最高：") + MK.chains.map { "\($0.genName)\(r.maxTier[$0.key] ?? 0)" }.joined(separator: " "))
                lines.append(T("累计动作：") + r.total.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: T("，")))
                lines.append("")
                tail.append(T("【第 {0} 局】全部天数：", run))
                for d in r.days { tail.append(String(format: "%3d %3d %4d %4d %4d/%d %5d%@", d.day, d.level, d.served, d.stars, d.done, MKStory.all.count, d.actions, d.stuck ? T(" 卡住") : "")) }
                tail.append(contentsOf: r.notes)
            }
            text = lines.joined(separator: "\n")
            print("SELFTEST\n" + text)
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? (lines + [""] + tail).joined(separator: "\n").write(to: dir.appendingPathComponent("selftest.txt"), atomically: true, encoding: .utf8)
            }
        }
    }
}

private extension String {
    func appendLine(to url: URL) throws {
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(utf8)); try? h.close() }
        else { try write(to: url, atomically: true, encoding: .utf8) }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
