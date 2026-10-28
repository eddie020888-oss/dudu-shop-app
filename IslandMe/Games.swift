import SwiftUI

// MARK: - 游戏页（底部导航「游戏」）
//
// 人设：它懒，游戏里永远是你动手、它瘫着看/张嘴等。
// 每个游戏每天第一局按成绩给币（最多 10），之后只加开心和熟悉度；赢了随机掉一张贴纸进贴纸册。

enum GameKind: String, CaseIterable, Identifiable {
    case fling, cups, dudu, match, coins, stars, gacha
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fling: return T("投喂")
        case .cups:  return T("猜杯子")
        case .dudu:  return T("猜嘟语")
        case .match: return T("翻牌配对")
        case .coins: return T("接爆米花")
        case .stars: return T("星星连线")
        case .gacha: return T("扭蛋")
        }
    }
    var blurb: String {
        switch self {
        case .fling: return T("它张着嘴瘫着，你把零食弹进去")
        case .cups:  return T("饭团藏在哪个杯子底下？")
        case .dudu:  return T("它嘟了一串，你猜它想说啥")
        case .match: return T("它的表情和配饰，翻两张一样的")
        case .coins: return T("它看电视，爆米花往外蹦，拖着它接")
        case .stars: return T("按顺序点星星，连出一个星座")
        case .gacha: return T("每天免费扭一次")
        }
    }
    /// 卡片上它摆的表情
    var frame: String {
        switch self {
        case .fling: return "hungry"
        case .cups:  return "think"
        case .dudu:  return "surprised"
        case .match: return "happy"
        case .coins: return "laugh"
        case .stars: return "think"
        case .gacha: return "surprised"
        }
    }
    var emoji: String {
        switch self { case .fling: return "🥕"; case .cups: return "🍙"; case .dudu: return "💬"; case .match: return "🃏"; case .coins: return "🍿"; case .stars: return "✦"; case .gacha: return "🎁" }
    }
    var tint: Color {
        switch self {
        case .fling: return Color(hex: "#F59E4B")
        case .cups:  return Color(hex: "#8FB8F0")
        case .dudu:  return Color(hex: "#F7A8C4")
        case .match: return Color(hex: "#9FDCC4")
        case .coins: return Color(hex: "#FFD166")
        case .stars: return Color(hex: "#A8E6FF")
        case .gacha: return Color(hex: "#F7A8C4")
        }
    }
}

/// 一局的结果：score 是给币依据（0…10），won 决定掉不掉贴纸
struct GameResult { let kind: GameKind; let score: Int; let won: Bool; let detail: String }

/// 贴纸册：赢了随机掉一张，24 张
enum Stickers {
    struct Sticker: Identifiable, Hashable { let id: String; let image: String?; let emoji: String?; let name: String }

    static let all: [Sticker] = {
        var s: [Sticker] = []
        for f in ["happy", "laugh", "shy", "surprised", "think", "yawn", "eat", "sleep", "thirsty", "cry", "angry", "coffee"] {
            s.append(Sticker(id: "face_" + f, image: "purple_face_" + f, emoji: nil, name: faceName[f] ?? f))
        }
        for a in Accessory.all { s.append(Sticker(id: "acc_" + a.id, image: "acc_" + a.id, emoji: nil, name: a.name)) }
        for (e, n) in [("🥕", T("胡萝卜")), ("🍙", T("饭团")), ("🍵", T("枸杞茶")), ("🍰", T("蛋糕")), ("✦", T("嘟嘟星"))] {
            s.append(Sticker(id: "e_" + n, image: nil, emoji: e, name: n))
        }
        return s
    }()
    private static let faceName = ["happy": T("开心"), "laugh": T("笑出声"), "shy": T("害羞"), "surprised": T("吓一跳"), "think": T("想事情"), "yawn": T("哈欠"),
                                   "eat": T("吃东西"), "sleep": T("睡着了"), "thirsty": T("渴了"), "cry": T("委屈"), "angry": T("鼓脸"), "coffee": T("咖啡时间")]

    static var owned: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "stickers.v1") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "stickers.v1") }
    }

    /// 掉一张：优先没有的
    static func drop() -> Sticker {
        let have = owned
        let pick = all.filter { !have.contains($0.id) }.randomElement() ?? all.randomElement()!
        owned = have.union([pick.id])
        return pick
    }
}

/// 游戏里它说话：按语言路线和阶段，说不了话的就嘟
enum GameTalk {
    static func line(_ zh: String, _ en: String, dudu: String = T("嘟！")) -> String {
        if Voice.route == .dudu || Voice.stage == 0 { return dudu }
        if Voice.stage == 1 {
            // 单词期：只蹦关键词
            let s = Voice.route == .en ? en : zh
            let words = s.split(whereSeparator: { T("，。！？,.!? …").contains($0) }).prefix(2).map(String.init)
            return words.joined(separator: "…") + T("…嘟")
        }
        return Voice.route == .en ? en : zh
    }
}

extension ProfileStore {
    /// 某个游戏今天的币领了没
    func gameClaimed(_ k: GameKind) -> Bool {
        k == .coins ? isClaimed(.play) : wallet.claimed.contains("\(Wallet.day())|game.\(k.rawValue)")
    }

    /// 扭蛋：今天的免费那次用掉了
    func useFreeGacha() -> Bool {
        guard !gameClaimed(.gacha) else { return false }
        wallet.claimed.append("\(Wallet.day())|game.gacha")
        return true
    }

    /// 游戏结算：每个游戏每天第一局按成绩给（最多 10）
    @discardableResult
    func rewardGame(_ r: GameResult) -> Int {
        if r.kind == .coins { return rewardPlay(caught: r.score) }
        guard r.score > 0, !gameClaimed(r.kind) else { return 0 }
        let n = min(r.score, EarnRule.playCap)
        wallet.claimed.append("\(Wallet.day())|game.\(r.kind.rawValue)")
        earn(n, "\(r.kind.title) · \(r.detail)")
        return n
    }
}

/// 全屏玩一局：顶栏 + 游戏本体 + 结算卡（给币、掉贴纸）
struct GameShell: View {
    let kind: GameKind
    let pet: String
    let accessories: [String]
    let rewardAvailable: Bool
    let onFinish: (GameResult) -> Stickers.Sticker?
    @Environment(\.dismiss) private var dismiss
    @State private var result: GameResult? = nil
    @State private var sticker: Stickers.Sticker? = nil
    @State private var round = 0

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(kind.title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.text)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                            .frame(width: 40, height: 40).background(Theme.surface, in: Circle())
                    }
                    .buttonStyle(.press)
                }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
                game.id(round)
            }
            if let r = result {
                Color.black.opacity(0.55).ignoresSafeArea()
                ResultCard(result: r, pet: pet, rewardAvailable: rewardAvailable, sticker: sticker,
                           again: { result = nil; sticker = nil; round += 1 },
                           close: { dismiss() })
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var game: some View {
        switch kind {
        case .fling: FlingGame(pet: pet, accessories: accessories, done: finish)
        case .cups:  CupsGame(pet: pet, done: finish)
        case .dudu:  DuduQuiz(pet: pet, done: finish)
        case .match: MatchGame(pet: pet, done: finish)
        case .coins: CatchGame(pet: pet, accessories: accessories, rewardAvailable: rewardAvailable, embedded: true) { n in
                         finish(GameResult(kind: .coins, score: n, won: n >= 6, detail: T("接到 {0} 个", n)))
                     }
        case .stars: StarLinkGame(pet: pet, done: finish)
        case .gacha: EmptyView()
        }
    }

    private func finish(_ r: GameResult) {
        let s = onFinish(r)
        if r.won { MKSfx.play("discover", volume: 0.7); ReviewAsk.happyMoment() }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { sticker = s; result = r }
    }
}

private struct ResultCard: View {
    let result: GameResult
    let pet: String
    let rewardAvailable: Bool
    let sticker: Stickers.Sticker?
    let again: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            DressedPetView(pet: pet, pose: .stand, frame: result.won ? "laugh" : "shy", accessories: [])
                .frame(width: 120, height: 120)
            Text(result.detail).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
            Text(result.won ? GameTalk.line(T("玩累了，我躺会儿。"), "Tired now. Lying down.", dudu: T("嘟嘟！✨"))
                            : GameTalk.line(T("没事，我也没赢过。"), "It's fine, I never win either.", dudu: T("嘟…嘟。")))
                .font(.system(size: 15)).foregroundStyle(Theme.text2)
            if rewardAvailable && result.score > 0 {
                Label(T("+{0} 币", min(result.score, EarnRule.playCap)), systemImage: "circle.hexagongrid.circle.fill")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.coin)
            } else {
                Text(T("开心 +，熟悉度 +")).font(.system(size: 13)).foregroundStyle(Theme.text3)
            }
            if let s = sticker {
                HStack(spacing: 10) {
                    StickerImage(sticker: s).frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("掉了一张贴纸")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                        Text(s.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                    }
                    Spacer()
                }
                .padding(10).background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
            }
            HStack(spacing: 10) {
                Button(action: close) {
                    Text(T("不玩了")).frame(maxWidth: .infinity, minHeight: 48).background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
                }
                Button(action: again) {
                    Text(T("再来一局")).fontWeight(.semibold).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 48).background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .font(.system(size: 15)).foregroundStyle(Theme.text).buttonStyle(.press)
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 26))
        .padding(.horizontal, 28)
    }
}

struct StickerImage: View {
    let sticker: Stickers.Sticker
    var body: some View {
        if let i = sticker.image { Image(i).resizable().scaledToFit() }
        else { Text(sticker.emoji ?? "✦").font(.system(size: 30)).minimumScaleFactor(0.3) }
    }
}

struct StickerAlbum: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let owned = Stickers.owned
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(Stickers.all) { s in
                        let have = owned.contains(s.id)
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(Theme.surface)
                                if have { StickerImage(sticker: s).padding(8) }
                                else { Text("?").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text3) }
                            }
                            .aspectRatio(1, contentMode: .fit)
                            Text(have ? s.name : T("还没有")).font(.system(size: 11)).foregroundStyle(have ? Theme.text2 : Theme.text3)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("贴纸册 {0}/{1}", owned.count, Stickers.all.count))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

/// 游戏里它的小气泡（说一句，2 秒后淡出）
struct PetBubble: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Theme.surface2, in: Capsule())
            .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}


/// 首页点「快乐」：直接挑一个小游戏陪它玩（不用再跑到窝里的游戏角）
struct GamePicker: View {
    @ObservedObject var profile: ProfileStore
    let pet: String
    let pick: (GameKind) -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(GameKind.allCases.filter { $0 != .gacha }) { k in
                        Button { pick(k) } label: {
                            VStack(spacing: 6) {
                                DressedPetView(pet: pet, pose: .stand, frame: k.frame, accessories: []).frame(width: 72, height: 72)
                                Text(k.title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                                Text(k.blurb).font(.system(size: 11)).foregroundStyle(Theme.text3).multilineTextAlignment(.center).lineLimit(2)
                                Text(profile.gameClaimed(k) ? T("今天领过币了") : T("今天第一局有币"))
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(profile.gameClaimed(k) ? Theme.text3 : Theme.coin)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.horizontal, 8)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(k.tint.opacity(0.5), lineWidth: 1.5))
                        }
                        .buttonStyle(.press)
                    }
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("陪它玩一局")).navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}


/// 小游戏里的东西：用小店的 3D 图（mk_<id>），或者直接给图名（img:xxx）；都没有才退回文字
struct GameFood: View {
    let id: String
    var body: some View {
        if id.hasPrefix("img:") { Image(String(id.dropFirst(4))).resizable().scaledToFit() }
        else if MKIcon.exists(id) { Image("mk_" + id).resizable().scaledToFit().shadow(color: .black.opacity(0.35), radius: 3, y: 2) }
        else { Text(id).font(.system(size: 40)).minimumScaleFactor(0.2) }
    }
}


/// 小游戏的手感：一个音效 + 一下震动（跟小店共用开关）
enum GFX {
    static func play(_ sfx: String, _ style: UIImpactFeedbackGenerator.FeedbackStyle? = .light, volume: Float = 0.6) {
        MKSfx.play(sfx, volume: volume)
        if let st = style, MKSfx.hapticsOn { UIImpactFeedbackGenerator(style: st).impactOccurred() }
    }
    static func good() { MKSfx.play("reward", volume: 0.6); if MKSfx.hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func bad() { MKSfx.play("boop", volume: 0.5); if MKSfx.hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
}
