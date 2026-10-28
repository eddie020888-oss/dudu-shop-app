import SwiftUI

/// 星星连线（观星台 · 小望远镜）：按顺序点星星，连出一个星座。连完揭开一条嘟嘟星的线索（按顺序，一个星座一条）。
/// 它躺在望远镜旁边看；越快连完分越高。
struct StarLinkGame: View {
    let pet: String
    let done: (GameResult) -> Void

    struct Constellation { let name: String; let points: [CGPoint]; let clue: String }

    static let all: [Constellation] = [
        .init(name: T("饭团座"), points: [p(0.5, 0.12), p(0.85, 0.78), p(0.15, 0.78), p(0.5, 0.12)],
              clue: T("嘟嘟星上有一种发光的草，煮熟了像米饭。它小时候天天吃。")),
        .init(name: T("杯子座"), points: [p(0.2, 0.2), p(0.3, 0.8), p(0.7, 0.8), p(0.8, 0.2), p(0.9, 0.4), p(0.8, 0.55)],
              clue: T("那边的人用星光泡茶，喝一口，整晚都暖暖的。")),
        .init(name: T("小角座"), points: [p(0.15, 0.85), p(0.3, 0.2), p(0.45, 0.6), p(0.55, 0.6), p(0.7, 0.2), p(0.85, 0.85)],
              clue: T("天上最亮的那颗星，最近悄悄换了位置。")),
        .init(name: T("卷毛座"), points: [p(0.5, 0.9), p(0.5, 0.5), p(0.75, 0.35), p(0.6, 0.12), p(0.3, 0.2), p(0.35, 0.45), p(0.55, 0.4)],
              clue: T("嘟嘟星的人头顶都有一撮卷毛，越卷的越懒。")),
        .init(name: T("门座"), points: [p(0.2, 0.9), p(0.2, 0.35), p(0.5, 0.1), p(0.8, 0.35), p(0.8, 0.9)],
              clue: T("灵动岛那道门的另一边，也有一道一模一样的门。")),
        .init(name: T("蛋座"), points: [p(0.5, 0.08), p(0.78, 0.3), p(0.85, 0.65), p(0.5, 0.92), p(0.15, 0.65), p(0.22, 0.3), p(0.5, 0.08)],
              clue: T("有一颗蛋也开始动了，花纹跟它那颗一样。")),
        .init(name: T("嘟嘟星座"), points: [p(0.5, 0.05), p(0.62, 0.38), p(0.95, 0.4), p(0.68, 0.6), p(0.78, 0.95), p(0.5, 0.75), p(0.22, 0.95), p(0.32, 0.6), p(0.05, 0.4), p(0.38, 0.38), p(0.5, 0.05)],
              clue: T("嘟嘟星就在这个方向。它每次看星星，都朝这边。")),
        .init(name: T("心座"), points: [p(0.5, 0.9), p(0.12, 0.45), p(0.25, 0.15), p(0.5, 0.32), p(0.75, 0.15), p(0.88, 0.45), p(0.5, 0.9)],
              clue: T("那边有人一直在嘟嘟地叫它的名字。很小声，但一直在叫。")),
    ]
    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    static var progress: Int {
        get { UserDefaults.standard.integer(forKey: "stars.next") }
        set { UserDefaults.standard.set(newValue, forKey: "stars.next") }
    }

    @State private var started = false
    @State private var c: Constellation = StarLinkGame.all[0]
    @State private var next = 0
    @State private var t0 = Date()
    @State private var elapsed: Double = 0
    @State private var shake = false
    @State private var finished = false
    @State private var face = "think"
    @State private var twinkle = false
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let bg: [(CGFloat, CGFloat, CGFloat)] = (0..<60).map { _ in (.random(in: 0...1), .random(in: 0...1), .random(in: 0.6...1.8)) }

    /// 去掉首尾重复的点（闭合图形最后一笔回到起点）
    private var uniquePoints: [CGPoint] {
        var u: [CGPoint] = []
        for q in c.points where !u.contains(q) { u.append(q) }
        return u
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let box = CGRect(x: w * 0.1, y: h * 0.12, width: w * 0.8, height: min(h * 0.55, w * 0.8))
            ZStack {
                Image("game_bg_sky").resizable().scaledToFill().frame(width: w, height: h).clipped()
                ForEach(bg.indices, id: \.self) { i in   // 一闪一闪
                    Circle().fill(.white.opacity(twinkle ? 0.15 : 0.55)).frame(width: bg[i].2, height: bg[i].2).position(x: bg[i].0 * w, y: bg[i].1 * h)
                        .animation(.easeInOut(duration: 1.2 + Double(i % 5) * 0.3).repeatForever(autoreverses: true), value: twinkle)
                }

                // 已连的线
                Path { path in
                    guard next > 0 else { return }
                    path.move(to: pt(c.points[0], box))
                    for i in 1..<min(next, c.points.count) { path.addLine(to: pt(c.points[i], box)) }
                }
                .stroke(Color(hex: "#A8E6FF").opacity(finished ? 0.95 : 0.7), style: StrokeStyle(lineWidth: finished ? 3 : 2, lineCap: .round, lineJoin: .round))
                .shadow(color: Color(hex: "#A8E6FF"), radius: finished ? 8 : 3)

                // 星星（按钮）
                ForEach(uniquePoints.indices, id: \.self) { i in
                    let q = uniquePoints[i]
                    let isNext = !finished && next < c.points.count && c.points[next] == q
                    let lit = c.points.prefix(next).contains(q)
                    ZStack {
                        Circle().fill(Color.white.opacity(0.001)).frame(width: 54, height: 54)
                        Image(lit ? "game_star_lit" : "game_star_dim").resizable().scaledToFit()
                            .frame(width: lit ? 40 : 30, height: lit ? 40 : 30)
                            .shadow(color: Color(hex: "#A8E6FF").opacity(lit ? 0.9 : 0), radius: 8)
                            .scaleEffect(isNext ? (twinkle ? 1.35 : 1.15) : 1)
                            .animation(isNext ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .spring(response: 0.3), value: twinkle)
                        if isNext {
                            Circle().stroke(Color(hex: "#A8E6FF").opacity(0.6), lineWidth: 1.5).frame(width: 34, height: 34)
                        }
                    }
                    .position(pt(q, box))
                    .onTapGesture { tapStar(q) }
                }

                // 它躺在下面
                VStack {
                    Spacer()
                    if finished {
                        VStack(spacing: 6) {
                            Text(c.name).font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: "#A8E6FF"))
                            Text(c.clue).font(.system(size: 14)).foregroundStyle(Theme.text).multilineTextAlignment(.center)
                        }
                        .padding(14).background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                    }
                    HStack(alignment: .bottom) {
                        DressedPetView(pet: pet, pose: .stand, frame: face, accessories: []).frame(width: 96, height: 96)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(String(format: T("%.1f 秒"), elapsed)).font(.system(size: 18, weight: .bold)).monospacedDigit().foregroundStyle(Theme.text)
                            Text(started ? T("{0} · 点亮 {1}/{2}", c.name, min(next, c.points.count), c.points.count) : "").font(.system(size: 12)).foregroundStyle(Theme.text3)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
                .offset(x: shake ? 6 : 0)

                if !started {
                    StartCard(title: T("星星连线"), lines: [T("从最亮的那颗开始，按顺序点星星"), T("连出一个星座，就揭开一条嘟嘟星的线索"),
                                                       T("已揭开 {0}/{1} 条", min(Self.progress, Self.all.count), Self.all.count)]) { start() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
        .onReceive(tick) { _ in if started && !finished { elapsed = Date().timeIntervalSince(t0) } }
        .onAppear { DispatchQueue.main.async { twinkle = true } }
    }

    private func pt(_ q: CGPoint, _ box: CGRect) -> CGPoint { CGPoint(x: box.minX + q.x * box.width, y: box.minY + q.y * box.height) }

    private func start() {
        c = Self.all[Self.progress % Self.all.count]
        next = 0; elapsed = 0; finished = false; face = "think"
        t0 = Date(); started = true
    }

    private func tapStar(_ q: CGPoint) {
        guard started, !finished, next < c.points.count else { return }
        if c.points[next] == q {
            withAnimation(.easeOut(duration: 0.2)) { next += 1 }
            GFX.play("merge\(min(9, next))", .light)
            // 闭合图形：最后一笔回到起点自动连上
            if next == c.points.count - 1, c.points.last == c.points.first { withAnimation { next += 1 } }
            if next >= c.points.count { complete() }
        } else {
            t0 = t0.addingTimeInterval(-1)          // 点错罚 1 秒
            GFX.bad()
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) { shake.toggle() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shake = false }
        }
    }

    private func complete() {
        withAnimation(.easeInOut(duration: 0.4)) { finished = true }
        face = "surprised"
        let first = Self.progress < Self.all.count
        Self.progress += 1
        let score = max(2, 10 - Int(elapsed / 3))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            done(GameResult(kind: .stars, score: score, won: true,
                            detail: first ? T("揭开了「{0}」", c.name) : String(format: T("%.1f 秒连完「%@」"), elapsed, c.name)))
        }
    }
}
