import SwiftUI

/// 翻牌配对：4×4，8 对（它的表情 + 配饰）。翻两张一样的就留着。步数越少分越高。
/// 它在顶上瘫着看：翻对了它跟着笑，连错了它打哈欠"我先睡会儿，你慢慢翻"。
struct MatchGame: View {
    let pet: String
    let done: (GameResult) -> Void

    struct Card: Identifiable { let id = UUID(); let key: String; var up = false; var matched = false }
    private static let keys = ["purple_face_happy", "purple_face_laugh", "purple_face_shy", "purple_face_eat",
                               "acc_hat_straw", "acc_glasses_sun", "acc_bow_red", "acc_scarf_blue"]

    @State private var started = false
    @State private var cards: [Card] = []
    @State private var open: [Int] = []
    @State private var moves = 0
    @State private var misses = 0
    @State private var face = "happy"
    @State private var bubble: String? = nil
    @State private var busy = false

    var body: some View {
        GeometryReader { g in
            ZStack {
                Image("game_bg_room").resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
                Color.black.opacity(0.35)
                VStack(spacing: 10) {
                    HStack(alignment: .bottom) {
                        DressedPetView(pet: pet, pose: .stand, frame: face, accessories: [])
                            .frame(width: 92, height: 92)
                        if let b = bubble { PetBubble(text: b) }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(T("{0} 步", moves)).font(.system(size: 18, weight: .bold)).monospacedDigit().foregroundStyle(Theme.text)
                            Text(T("配上 {0}/8", cards.filter(\.matched).count / 2)).font(.system(size: 12)).foregroundStyle(Theme.text3)
                        }
                    }
                    .padding(.horizontal, 18).padding(.top, 12)

                    let side = min((g.size.width - 32 - 30) / 4, (g.size.height - 150) / 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: 10), count: 4), spacing: 10) {
                        ForEach(cards.indices, id: \.self) { i in
                            CardFace(card: cards[i]).frame(width: side, height: side)
                                .onTapGesture { flip(i) }
                        }
                    }
                    Spacer(minLength: 0)
                }
                if !started {
                    StartCard(title: T("翻牌配对"), lines: [T("翻两张一样的就配上"), T("它的表情和配饰，一共 8 对"), T("步数越少分越高")]) { start() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
    }

    private func start() {
        cards = (Self.keys + Self.keys).shuffled().map { Card(key: $0) }
        open = []; moves = 0; misses = 0; face = "happy"; started = true
        // 开局让你瞄一眼（它懒得帮你记）
        for i in cards.indices { cards[i].up = true }
        busy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.3)) { for i in cards.indices { cards[i].up = false } }
            busy = false
        }
    }

    private func flip(_ i: Int) {
        guard started, !busy, !cards[i].up, !cards[i].matched else { return }
        withAnimation(.easeInOut(duration: 0.25)) { cards[i].up = true }
        GFX.play("flip", .light, volume: 0.45)
        open.append(i)
        guard open.count == 2 else { return }
        moves += 1
        let a = open[0], b = open[1]
        open = []
        if cards[a].key == cards[b].key {
            cards[a].matched = true; cards[b].matched = true
            GFX.play("merge\(min(9, cards.filter(\.matched).count / 2 + 1))", .medium)
            misses = 0
            face = "laugh"
            if cards.allSatisfy(\.matched) { finish() }
            else if Int.random(in: 0..<3) == 0 { say(GameTalk.line(T("记性真好。"), "Good memory.", dudu: T("嘟！"))) }
        } else {
            misses += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { MKSfx.play("boop", volume: 0.35) }
            face = misses >= 3 ? "yawn" : "think"
            if misses == 3 { say(GameTalk.line(T("我先睡会儿，你慢慢翻。"), "I'll nap. Take your time.", dudu: T("嘟……💤"))) }
            busy = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.25)) { cards[a].up = false; cards[b].up = false }
                busy = false
            }
        }
    }

    private func finish() {
        // 最少 8 步；每多 2 步少 1 分
        let score = max(1, 10 - max(0, moves - 8) / 2)
        say(GameTalk.line(T("全配上了！"), "All matched!", dudu: T("嘟嘟嘟！✨")))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            done(GameResult(kind: .match, score: score, won: moves <= 16, detail: T("{0} 步配完", moves)))
        }
    }

    private func say(_ s: String) {
        withAnimation { bubble = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if bubble == s { withAnimation { bubble = nil } } }
    }
}

private struct CardFace: View {
    let card: MatchGame.Card
    var body: some View {
        ZStack {
            if card.up || card.matched {
                Image("game_card_front").resizable().scaledToFit()
                Image(card.key).resizable().scaledToFit().padding(10)
                if card.matched {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.clean)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(4)
                }
            } else {
                Image("game_card_back").resizable().scaledToFit()
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
        .rotation3DEffect(.degrees(card.up || card.matched ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        .scaleEffect(card.matched ? 0.94 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: card.up)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: card.matched)
    }
}
