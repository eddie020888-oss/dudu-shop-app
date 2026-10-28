import SwiftUI

/// 陪它玩：接金币小游戏（20 秒）。左右拖动它接住掉下来的金币，别碰到臭袜子。
/// 每天第一局接到几个给几个币（最多 10），之后再玩只加开心。
struct CatchGame: View {
    var pet: String
    var accessories: [String]
    var rewardAvailable: Bool
    var embedded = false          // 在游戏页里玩：顶栏和结算交给外壳
    var onFinish: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    struct Drop: Identifiable { let id = UUID(); var x: CGFloat; var y: CGFloat; var speed: CGFloat; let bad: Bool; var vx: CGFloat = 0; var spin: Double = 0 }

    private static let duration: Double = 20
    @State private var drops: [Drop] = []
    @State private var petX: CGFloat = 0.5          // 0...1
    @State private var caught = 0
    @State private var started: Date? = nil
    @State private var last: Date = Date()
    @State private var nextSpawn: Double = 0
    @State private var done = false
    @State private var flash: String? = nil
    @State private var size: CGSize = .zero
    @State private var lean: CGFloat = 0
    private let tick = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    private var remaining: Int {
        guard let s = started else { return Int(Self.duration) }
        return max(0, Int(ceil(Self.duration - Date().timeIntervalSince(s))))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("\(caught)", systemImage: "circle.hexagongrid.circle.fill")
                    .font(.system(size: 18, weight: .bold)).monospacedDigit().foregroundStyle(Theme.coin)
                Spacer()
                Text(T("{0} 秒", remaining)).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.text2)
                if !embedded { Button(T("关闭")) { finish(early: true) }.padding(.leading, 12) }
            }
            .padding(.horizontal, 20).padding(.top, 16)

            GeometryReader { g in
                ZStack(alignment: .topLeading) {
                    Image("game_bg_room").resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
                    Color.black.opacity(0.4)
                    // 它在看的电视：爆米花和臭袜子从屏幕里蹦出来
                    Image("nest_tv_v2").resizable().scaledToFit()
                        .frame(width: min(g.size.width * 0.46, 190))
                        .position(x: g.size.width * 0.5, y: 70)
                    ForEach(drops) { d in
                        GameFood(id: d.bad ? "img:game_sock" : "snack3").frame(width: 44, height: 44)
                            .rotationEffect(.degrees(d.spin))
                            .position(x: d.x * g.size.width, y: d.y)
                    }
                    // 地面
                    Ellipse().fill(Theme.accent.opacity(0.12)).frame(width: 150, height: 22)
                        .position(x: petX * g.size.width, y: g.size.height - 14)
                    // 透明底的静帧（视频是黑底，放在夜空上会出一块黑框）；跑起来往移动方向歪一点、上下颠
                    DressedPetView(pet: pet, pose: .stand, frame: flash ?? (started == nil ? "idle" : "happy"), accessories: accessories)
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(Double(lean) * 10))
                        .offset(y: started == nil ? 0 : -abs(sin(Date().timeIntervalSinceReferenceDate * 9)) * 5)
                        .position(x: petX * g.size.width, y: g.size.height - 80)
                        .allowsHitTesting(false)

                    if started == nil && !done {
                        overlayCard(title: T("接爆米花"), lines: [T("电视里的爆米花蹦出来了，左右拖它接住爆米花，躲开臭袜子"), rewardAvailable ? T("今天第一局：接到几个给几个币（最多 {0}）", EarnRule.playCap) : T("今天的金币领过了，这局只为开心")], button: T("开始")) { start() }
                    }
                    if done && !embedded {
                        overlayCard(title: T("接到 {0} 个！", caught),
                                    lines: [rewardAvailable && caught > 0 ? T("+{0} 币", min(caught, EarnRule.playCap)) : T("它玩得很开心"), T("快乐值 +{0}%", Int(Need.happy.careAmount * 100))],
                                    button: T("好")) { dismiss() }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let nx = min(0.92, max(0.08, v.location.x / max(1, g.size.width)))
                    lean = max(-1, min(1, (nx - petX) * 40))
                    petX = nx
                }.onEnded { _ in withAnimation(.spring(response: 0.3)) { lean = 0 } })
                .onAppear { size = g.size }
                .onChange(of: g.size) { _, s in size = s }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .background(Theme.ground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(started != nil && !done)
        .onReceive(tick) { now in step(now) }
    }

    private func overlayCard(title: String, lines: [String], button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
            ForEach(lines, id: \.self) { Text($0).font(.system(size: 13)).foregroundStyle(Theme.text2).multilineTextAlignment(.center) }
            Button(button, action: action)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 36).padding(.vertical, 10)
                .background(Theme.accent, in: Capsule()).foregroundStyle(.black)
                .padding(.top, 4)
        }
        .padding(22)
        .background(Theme.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 22))
        .onAppear { if Shot.autoStart && title == T("接爆米花") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { action() } } }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func start() {
        caught = 0; drops = []; nextSpawn = 0.3
        started = Date(); last = Date()
    }

    private func step(_ now: Date) {
        guard let s = started, !done, size.height > 0 else { return }
        let dt = CGFloat(min(0.05, now.timeIntervalSince(last))); last = now
        let t = now.timeIntervalSince(s)
        if t >= Self.duration { finish(early: false); return }

        // 越往后掉得越快、越密
        nextSpawn -= Double(dt)
        if nextSpawn <= 0 {
                        // 从电视屏幕里往外蹦：先往上、往两边弹出去，再落下来
            drops.append(Drop(x: .random(in: 0.42...0.58), y: 70, speed: -CGFloat.random(in: 180...320), bad: Double.random(in: 0..<1) < 0.22,
                              vx: CGFloat.random(in: -0.42...0.42), spin: .random(in: -30...30)))
            nextSpawn = max(0.35, 0.75 - t * 0.02)
        }

        let catchY = size.height - 140
        var keep: [Drop] = []
        for var d in drops {
            // 抛物线：横着飘，竖着先上后下（越往后掉得越快）
            d.speed += CGFloat(520 + t * 14) * dt
            d.y += d.speed * dt
            d.x = min(0.95, max(0.05, d.x + d.vx * dt))
            if d.x <= 0.05 || d.x >= 0.95 { d.vx = -d.vx * 0.6 }
            d.spin += Double(d.vx) * 240 * Double(dt)
            if d.speed > 0, d.y >= catchY && d.y <= catchY + 45 && abs(d.x - petX) * size.width < 52 {
                if d.bad { caught = max(0, caught - 1); react("cry"); GFX.play("boop", .heavy, volume: 0.5) }
                else { caught += 1; react(caught % 5 == 0 ? "laugh" : "happy"); GFX.play(caught % 5 == 0 ? "reward" : "coin", .light, volume: 0.45) }
                continue
            }
            if d.y < size.height + 30 { keep.append(d) }
        }
        drops = keep
    }

    private func react(_ f: String) {
        flash = f
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if flash == f { flash = nil } }
    }

    private func finish(early: Bool) {
        guard !done else { dismiss(); return }
        if started == nil { dismiss(); return }      // 没开始就关：什么都不发生
        done = true
        drops = []
        onFinish(caught)
        if early { dismiss() }
    }
}
