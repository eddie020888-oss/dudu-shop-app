import SwiftUI

// MARK: - 小紫拍立得：集卡。卡上只有小紫（画面里永远只有它一个），背面是它说的一句话。
// 卡包从交招牌菜、章末、每日目标、偶尔的惊喜里来；不卖钱。重复卡换成星光，星光换宝箱。
// 金卡是故事里的关键时刻：不靠抽，到了那一章自然得到。

struct MKCard: Identifiable {
    let id: String
    let set: Int
    let name: String
    let stars: Int        // 1–3；金卡 = 0
    let line: String
    var gold: Bool { stars == 0 }
    var image: String { "card_" + id }
}

enum MKCards {
    struct CardSet { let id: Int; let name: String; let unlockTask: String?; let unlockText: String }
    static let sets: [CardSet] = [
        CardSet(id: 1, name: T("小店的日子"), unlockTask: nil, unlockText: ""),
        CardSet(id: 2, name: T("懒洋洋的一天"), unlockTask: "a12", unlockText: T("装修完小店门面（第四章）解锁")),
        CardSet(id: 3, name: T("门那边的星星"), unlockTask: "c12", unlockText: T("装修完茶室（第八章）解锁")),
    ]
    static let all: [MKCard] = [
        MKCard(id: "hatch", set: 1, name: T("破壳那天"), stars: 0, line: T("嘟？……这是哪儿。哦，是你。")),
        MKCard(id: "riceball", set: 1, name: T("第一个饭团"), stars: 1, line: T("还有吗？")),
        MKCard(id: "apron", set: 1, name: T("小围裙"), stars: 1, line: T("系上了，就算上班了。……我先眯会儿。")),
        MKCard(id: "ticket", set: 1, name: T("看小票"), stars: 1, line: T("这单……好长。你做，我看。")),
        MKCard(id: "shellnap", set: 1, name: T("壳里看店"), stars: 1, line: T("我闭着眼也在看店。")),
        MKCard(id: "cashier", set: 1, name: T("肚子当钱箱"), stars: 2, line: T("钱放这儿最安全。")),
        MKCard(id: "taste", set: 1, name: T("偷吃样品"), stars: 2, line: T("我这是试吃。是工作。")),
        MKCard(id: "wow", set: 1, name: T("新菜出锅"), stars: 3, line: T("这个！明天还要！")),
        MKCard(id: "lastbite", set: 1, name: T("最后一口"), stars: 3, line: T("最后一口……舍不得吃。")),

        MKCard(id: "hugshell", set: 2, name: T("抱着蛋壳"), stars: 0, line: T("这是我唯一的一块嘟嘟星。")),
        MKCard(id: "wake", set: 2, name: T("刚睡醒"), stars: 1, line: T("几点了？……不重要。")),
        MKCard(id: "sunbath", set: 2, name: T("晒太阳"), stars: 1, line: T("嘟嘟星时间，晒一下午。")),
        MKCard(id: "oneeye", set: 2, name: T("睁一只眼"), stars: 1, line: T("我没睡，我在省电。")),
        MKCard(id: "cupnap", set: 2, name: T("抱着杯子睡着"), stars: 2, line: T("茶凉了，梦是热的。")),
        MKCard(id: "bellyup", set: 2, name: T("翻肚皮"), stars: 2, line: T("摸这里。只准摸这里。")),
        MKCard(id: "sulk", set: 2, name: T("闹别扭"), stars: 2, line: T("哼。……再给块饼干就不哼了。")),
        MKCard(id: "boba", set: 2, name: T("喝奶茶"), stars: 3, line: T("珍珠要一颗一颗吃。")),
        MKCard(id: "share", set: 2, name: T("分你一口"), stars: 3, line: T("给你……就一口。")),

        MKCard(id: "stargaze", set: 3, name: T("看星星"), stars: 0, line: T("那颗，是我家。")),
        MKCard(id: "music", set: 3, name: T("听歌"), stars: 1, line: T("这首，像嘟嘟星的风。")),
        MKCard(id: "read", set: 3, name: T("看书"), stars: 1, line: T("看到第二页就睡着了。")),
        MKCard(id: "straw", set: 3, name: T("小草帽"), stars: 1, line: T("夏天要有帽子。冬天也要。")),
        MKCard(id: "blanket", set: 3, name: T("拖来毯子"), stars: 2, line: T("你冷吗？我拖过来的，可累了。")),
        MKCard(id: "uke", set: 3, name: T("弹琴"), stars: 2, line: T("只会一个和弦，够了。")),
        MKCard(id: "scarf", set: 3, name: T("奶奶的围巾"), stars: 2, line: T("刚好围一圈。")),
        MKCard(id: "party", set: 3, name: T("跳一支舞"), stars: 3, line: T("门开了要办派对，先练练。")),
        MKCard(id: "happy", set: 3, name: T("今天也好"), stars: 3, line: T("今天也是好日子。")),
    ]
    static func card(_ id: String) -> MKCard? { all.first { $0.id == id } }
    static func cards(in set: Int) -> [MKCard] { all.filter { $0.set == set } }
    /// 金卡：故事走到这里就送
    static let goldAt: [String: String] = ["b12": "hugshell", "d12": "stargaze"]
    static let dustFor = [0, 1, 4, 9]          // 重复卡换星光
    static let exchangeCost = 60               // 星光换一个大宝箱
}

struct MKPull: Identifiable { let id = UUID(); let card: MKCard; let isNew: Bool; let dust: Int }

extension MKStore {
    var cardCounts: [String: Int] { s.cards ?? [:] }
    var cardsOwned: Int { MKCards.all.filter { (cardCounts[$0.id] ?? 0) > 0 }.count }
    func setUnlocked(_ set: Int) -> Bool {
        guard let cs = MKCards.sets.first(where: { $0.id == set }) else { return false }
        return cs.unlockTask.map { s.done.contains($0) } ?? true
    }
    func setDone(_ set: Int) -> Bool { MKCards.cards(in: set).allSatisfy { (cardCounts[$0.id] ?? 0) > 0 } }

    func givePacks(_ n: Int, _ why: String) {
        s.packs = (s.packs ?? 0) + n
        say(T("🎞️ 拍立得 +{0}：{1}", n, why))
    }
    /// 第一次进店（老存档第一次打开）：送破壳那天的金卡 + 一包
    func ensureCardsStarted() {
        guard s.cards == nil else { return }
        s.cards = ["hatch": 1]
        s.packs = (s.packs ?? 0) + 1
    }
    func giveGold(_ id: String) {
        var c = cardCounts
        guard (c[id] ?? 0) == 0, let card = MKCards.card(id) else { return }
        c[id] = 1; s.cards = c
        goldCard = card
        checkSetDone(card.set)
    }
    /// 开一包：3 张，只从解锁了的套里抽，金卡不在包里
    func openPack() -> [MKPull]? {
        guard (s.packs ?? 0) > 0 else { return nil }
        let pool = MKCards.all.filter { !$0.gold && setUnlocked($0.set) }
        guard !pool.isEmpty else { return nil }
        s.packs = (s.packs ?? 0) - 1
        var c = cardCounts
        var out: [MKPull] = []
        let weight = [0, 6, 3, 1]
        // 保底（2026-10-27）：连续 3 包没出新卡，这包第 3 张一定是没有的卡。
        // 自测里机器人第 15 天到第 37 天一直卡在 25/27，开了几十包都是重复的
        let pity = (s.dryPacks ?? 0) >= 3
        for k in 0..<3 {
            let total = pool.map { weight[$0.stars] }.reduce(0, +)
            var r = Int.random(in: 0..<total)
            var pick = pool[0]
            for card in pool { r -= weight[card.stars]; if r < 0 { pick = card; break } }
            if pity, k == 2, !out.contains(where: \.isNew), let fresh = pool.filter({ (c[$0.id] ?? 0) == 0 }).randomElement() { pick = fresh }
            let had = c[pick.id] ?? 0
            // 重复的不攒（又不能卖）：每张只留一张，重复的直接变星光
            c[pick.id] = 1
            let dust = had > 0 ? MKCards.dustFor[pick.stars] : 0
            if dust > 0 { s.stardust = (s.stardust ?? 0) + dust }
            out.append(MKPull(card: pick, isNew: had == 0, dust: dust))
        }
        s.cards = c
        s.dryPacks = out.contains(where: \.isNew) ? 0 : (s.dryPacks ?? 0) + 1
        for set in Set(out.map(\.card.set)) { checkSetDone(set) }
        return out
    }
    private func checkSetDone(_ set: Int) {
        guard setDone(set), !(s.setsClaimed ?? []).contains(set) else { return }
        s.setsClaimed = (s.setsClaimed ?? []) + [set]
        s.gems += 15
        give("chest3")
        setComplete = MKCards.sets.first { $0.id == set }
    }
    func exchangeDust() {
        guard (s.stardust ?? 0) >= MKCards.exchangeCost else { say(T("星光不够。重复的卡会变成星光。")); return }
        s.stardust = (s.stardust ?? 0) - MKCards.exchangeCost
        give("chest3")
        say(T("✨ {0} 星光换了一个大宝箱，放在台面上了。", MKCards.exchangeCost))
    }
}

// MARK: - 一张拍立得

struct MKPolaroid: View {
    let card: MKCard
    var owned = true
    var count = 0
    var width: CGFloat = 100
    var body: some View {
        VStack(spacing: width * 0.05) {
            ZStack {
                if owned {
                    Image(card.image).resizable().scaledToFill()
                } else {
                    Color(hex: "#2A2438")
                    Image(systemName: "questionmark").font(.system(size: width * 0.28, weight: .bold)).foregroundStyle(Color.white.opacity(0.25))
                }
            }
            .frame(width: width * 0.86, height: width * 0.86)
            .clipped()
            HStack(spacing: 2) {
                if card.gold {
                    Image(systemName: "star.circle.fill").foregroundStyle(Color(hex: "#E8B23A"))
                } else {
                    ForEach(0..<card.stars, id: \.self) { _ in Image(systemName: "star.fill").foregroundStyle(Color(hex: "#F2A93B")) }
                }
            }
            .font(.system(size: width * 0.07))
            Text(owned ? card.name : T("？？？")).font(.system(size: width * 0.1, weight: .semibold)).foregroundStyle(Color(hex: "#4A3B2A"))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.top, width * 0.07).padding(.bottom, width * 0.06)
        .frame(width: width)
        .background(card.gold && owned ? Color(hex: "#FFF4D6") : Color(hex: "#FBF8F2"), in: RoundedRectangle(cornerRadius: width * 0.04))
        .overlay(RoundedRectangle(cornerRadius: width * 0.04).stroke(card.gold && owned ? Color(hex: "#E8B23A") : Color.clear, lineWidth: 2))
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        .opacity(owned ? 1 : 0.55)
    }
}

// MARK: - 相册

struct MKAlbumView: View {
    @ObservedObject var store: MKStore
    @Environment(\.dismiss) private var dismiss
    @State private var pulls: [MKPull]? = nil
    @State private var looking: MKCard? = nil
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    ForEach(MKCards.sets, id: \.id) { set in setSection(set) }
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("{0}拍立得 {1}/{2}", Voice.petName, store.cardsOwned, MKCards.all.count)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
            .overlay { if let p = pulls { MKPackOpenView(pulls: p) { pulls = nil } } }
            .overlay { if let c = looking { cardDetail(c) } }
            .onAppear { if MKDemo.args.contains("-demoPack") { pulls = store.openPack() } }
        }
        .preferredColorScheme(.dark)
    }
    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("🎞️ 还有 {0} 包", store.s.packs ?? 0)).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                    Text(T("交招牌菜、每章装修完、每日目标全做完都会给")).font(.system(size: 11)).foregroundStyle(Theme.text3)
                }
                Spacer()
                Button {
                    if let p = store.openPack() { withAnimation { pulls = p } }
                } label: {
                    Text(T("开一包")).font(.system(size: 15, weight: .bold)).padding(.horizontal, 16).frame(height: 38)
                        .background((store.s.packs ?? 0) > 0 ? Theme.coin : Theme.surface2, in: Capsule())
                        .foregroundStyle((store.s.packs ?? 0) > 0 ? Color.black : Theme.text3)
                }
                .buttonStyle(.press).disabled((store.s.packs ?? 0) == 0)
            }
            HStack {
                Text(T("✨ 星光 {0}", store.s.stardust ?? 0)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "#FFD166"))
                Text(T("重复的不留，直接变成星光")).font(.system(size: 11)).foregroundStyle(Theme.text3)
                Spacer()
                Button(T("{0} 星光换大宝箱", MKCards.exchangeCost)) { store.exchangeDust() }
                    .font(.system(size: 12, weight: .semibold)).buttonStyle(.bordered).tint(Theme.accent)
                    .disabled((store.s.stardust ?? 0) < MKCards.exchangeCost)
            }
        }
        .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
    private func setSection(_ set: MKCards.CardSet) -> some View {
        let cards = MKCards.cards(in: set.id)
        let have = cards.filter { (store.cardCounts[$0.id] ?? 0) > 0 }.count
        let open = store.setUnlocked(set.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(set.name).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                Text("\(have)/\(cards.count)").font(.system(size: 12)).foregroundStyle(Theme.text3)
                Spacer()
                if store.setDone(set.id) {
                    Label(T("集齐了"), systemImage: "checkmark.seal.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.coin)
                } else {
                    Text(open ? T("集齐：宝石 15 + 大宝箱") : set.unlockText).font(.system(size: 11)).foregroundStyle(Theme.text3)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                ForEach(cards) { c in
                    let n = store.cardCounts[c.id] ?? 0
                    MKPolaroid(card: c, owned: n > 0, count: n, width: 100)
                        .onTapGesture { if n > 0 { withAnimation { looking = c } } }
                }
            }
            .opacity(open ? 1 : 0.5)
        }
    }
    private func cardDetail(_ c: MKCard) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { withAnimation { looking = nil } }
            VStack(spacing: 16) {
                MKPolaroid(card: c, width: 250)
                Text(T("「{0}」", c.line)).font(.system(size: 17, weight: .medium)).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - 开包：三张背面朝上，点一张翻一张

struct MKPackOpenView: View {
    let pulls: [MKPull]
    let close: () -> Void
    @State private var flipped: Set<Int> = []
    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 22) {
                Text(flipped.count < pulls.count ? T("点一下，翻开") : T("收进相册了")).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                HStack(spacing: 12) {
                    ForEach(Array(pulls.enumerated()), id: \.offset) { pair in
                        let open = flipped.contains(pair.offset)
                        ZStack {
                            if open {
                                MKPolaroid(card: pair.element.card, width: 104)
                                    .overlay(alignment: .top) {
                                        Text(pair.element.isNew ? T("新") : T("+{0} 星光", pair.element.dust))
                                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(pair.element.isNew ? .white : .black)
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(pair.element.isNew ? Color(hex: "#E5484D") : Color(hex: "#FFD166"), in: Capsule())
                                            .offset(y: -10)
                                    }
                                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            } else {
                                RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [Color(hex: "#6B4FB8"), Color(hex: "#2E1F5C")], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 104, height: 128)
                                    .overlay(Image(systemName: "sparkle").font(.system(size: 26)).foregroundStyle(Color(hex: "#A8E6FF").opacity(0.8)))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.5), lineWidth: 2))
                            }
                        }
                        .rotation3DEffect(.degrees(open ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                        .onTapGesture {
                            guard !open else { return }
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { _ = flipped.insert(pair.offset) }
                            MKSfx.impact(pair.element.card.stars >= 3 ? .heavy : .light)
                            MKSfx.play(pair.element.card.stars >= 3 ? "discover" : "flip")
                        }
                    }
                }
                if flipped.count == pulls.count {
                    Button(action: close) {
                        Text(T("好")).font(.system(size: 17, weight: .semibold)).frame(width: 180, height: 46)
                            .background(Theme.accent, in: Capsule()).foregroundStyle(.black)
                    }
                    .buttonStyle(.press)
                } else {
                    Button(T("全部翻开")) { withAnimation { flipped = Set(pulls.indices) } }
                        .font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.6))
                }
            }
        }
        .onAppear { if MKDemo.args.contains("-demoPack") { flipped = [0, 1] } }
    }
}
