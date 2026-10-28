import SwiftUI

/// 投喂：它张着嘴瘫在远处，你用手指把零食往上一弹，进嘴算一口。12 样零食。
/// 它懒：一开始一动不动；喂进去越多，它越得意，开始慢慢左右晃（难度来自它的懒得意）。
struct FlingGame: View {
    let pet: String
    let accessories: [String]
    let done: (GameResult) -> Void

    private static let total = 12
    /// 小店里的真货（3D 图），不用 emoji
    private static let foods = ["veg2", "rice3", "sweet6", "snack3", "milk3", "coffee3", "rice3", "veg2", "sweet3"]
    private static let gravity: CGFloat = 1100

    struct Shot { var p: CGPoint; var v: CGVector; let food: String; var bounced = false }

    @State private var started = false
    @State private var size: CGSize = .zero
    @State private var shot: Shot? = nil
    @State private var dragAt: CGPoint? = nil
    @State private var queue: [String] = []
    @State private var hits = 0
    @State private var thrown = 0
    @State private var streak = 0
    @State private var face = "gape"
    @State private var bubble: String? = nil
    @State private var t0 = Date()
    @State private var last = Date()
    @State private var petX: CGFloat = 0.5
    @State private var finished = false
    @State private var crumbs: [Crumb] = []
    private let tick = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    struct Crumb: Identifiable { let id = UUID(); var p: CGPoint; var v: CGVector; let food: String; var life: Double }

    private var petSize: CGFloat { min(size.width * 0.46, 190) }
    private var petCenter: CGPoint { CGPoint(x: petX * size.width, y: size.height * 0.30) }
    /// 嘴：张嘴帧（purple_gape，打哈欠那一下）里嘴在图的 (0.49, 0.42)
    private var mouth: CGPoint { CGPoint(x: petCenter.x - petSize * 0.01, y: petCenter.y - petSize * 0.5 + petSize * 0.42) }
    private var pad: CGPoint { CGPoint(x: size.width * 0.5, y: size.height - 96) }

    var body: some View {
        GeometryReader { g in
            ZStack {
                Image("game_bg_sky").resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
                Color.black.opacity(0.4)
                // 地面微光
                Ellipse().fill(Theme.accent.opacity(0.10)).frame(width: petSize * 1.1, height: 26)
                    .position(x: petCenter.x, y: petCenter.y + petSize * 0.47)

                DressedPetView(pet: pet, pose: .stand, frame: face, accessories: accessories)
                    .frame(width: petSize, height: petSize)
                    .position(petCenter)

                if let b = bubble {
                    PetBubble(text: b).position(x: petCenter.x, y: petCenter.y - petSize * 0.62)
                }

                ForEach(crumbs) { c in
                    Text(c.food).font(.system(size: 22)).opacity(c.life).position(c.p)
                }

                // 飞着的零食（越远越小）
                if let s = shot {
                    let k = max(0.45, min(1, (s.p.y - petCenter.y) / max(1, pad.y - petCenter.y) * 0.55 + 0.45))
                    GameFood(id: s.food).frame(width: 52 * k, height: 52 * k).position(s.p)
                }

                // 发射台：手指按住拖动，往上一甩
                if started && !finished && shot == nil, let next = queue.first {
                    let at = dragAt ?? pad
                    Circle().stroke(Theme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                        .frame(width: 88, height: 88).position(pad)
                    GameFood(id: next).frame(width: 58, height: 58).position(at)
                }

                // 顶部计分
                VStack {
                    HStack(spacing: 6) {
                        ForEach(0..<Self.total, id: \.self) { i in
                            Circle().fill(i < hits ? Theme.alert : (i < thrown ? Theme.surface2 : Theme.surface))
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.top, 14)
                    Spacer()
                    if started && !finished {
                        Text(T("按住零食，往它嘴里一甩")).font(.system(size: 12)).foregroundStyle(Theme.text3).padding(.bottom, 18)
                    }
                }

                if !started {
                    StartCard(title: T("投喂"), lines: [T("它张着嘴等你喂，懒得动"), T("按住下面的零食往上甩，进嘴算一口"), T("喂进去越多它越得意，会开始晃")]) { start() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    guard started, !finished, shot == nil, hypot(v.startLocation.x - pad.x, v.startLocation.y - pad.y) < 90 else { return }
                    dragAt = v.location
                }
                .onEnded { v in
                    guard dragAt != nil else { return }
                    launch(from: v.location, velocity: v.velocity)
                })
            .onAppear { size = g.size }
            .onChange(of: g.size) { _, s in size = s }
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
        .onReceive(tick) { step($0) }
    }

    private func start() {
        queue = (0..<Self.total).map { _ in Self.foods.randomElement()! }
        hits = 0; thrown = 0; streak = 0; face = "gape"
        t0 = Date(); last = Date(); started = true
        say(GameTalk.line(T("啊——"), "Aaah—", dudu: T("嘟啊——")))
    }

    private func launch(from p: CGPoint, velocity: CGSize) {
        dragAt = nil
        guard let food = queue.first else { return }
        // 往上甩才算；太轻的当没甩
        var vx = velocity.width * 0.5, vy = velocity.height * 0.62
        guard vy < -250 else { return }
        let m = hypot(vx, vy), cap: CGFloat = 1650
        if m > cap { vx *= cap / m; vy *= cap / m }
        queue.removeFirst()
        thrown += 1
        shot = Shot(p: p, v: CGVector(dx: vx, dy: vy), food: food)
        GFX.play("tap", .light, volume: 0.4)
        face = "gape"
    }

    private func step(_ now: Date) {
        let dt = CGFloat(min(0.033, now.timeIntervalSince(last))); last = now
        guard started, size.width > 0 else { return }
        // 它的懒晃：喂进 3 口以后开始，越喂越晃
        let t = now.timeIntervalSince(t0)
        let amp = CGFloat(max(0, hits - 2)) * 0.035
        petX = 0.5 + min(0.3, amp) * CGFloat(sin(t * (0.9 + Double(hits) * 0.08)))

        crumbs = crumbs.compactMap { c in
            var c = c; c.life -= Double(dt) * 1.6; c.v.dy += Self.gravity * dt
            c.p.x += c.v.dx * dt; c.p.y += c.v.dy * dt
            return c.life > 0 ? c : nil
        }

        guard var s = shot else { return }
        s.v.dy += Self.gravity * dt
        s.p.x += s.v.dx * dt; s.p.y += s.v.dy * dt
        let toMouth = hypot(s.p.x - mouth.x, s.p.y - mouth.y)
        let toBody = hypot(s.p.x - petCenter.x, s.p.y - (petCenter.y + petSize * 0.12))
        if toMouth < petSize * 0.15 {
            shot = nil; scored(); return
        }
        if !s.bounced && toBody < petSize * 0.42 && s.v.dy > -200 {
            // 砸到身上弹开
            s.bounced = true
            s.v = CGVector(dx: (s.p.x - petCenter.x) * 4, dy: -180)
            missed(bonk: true)
        }
        if s.p.y > size.height + 40 || s.p.x < -40 || s.p.x > size.width + 40 {
            shot = nil
            if !s.bounced { missed(bonk: false) }
            checkEnd(); return
        }
        shot = s
    }

    private func scored() {
        hits += 1; streak += 1
        GFX.play(streak >= 3 ? "merge\(min(9, streak))" : "coin", .medium)
        face = "eat"
        for _ in 0..<5 {
            crumbs.append(Crumb(p: mouth, v: CGVector(dx: .random(in: -120...120), dy: .random(in: -260 ... -80)), food: "✨", life: 1))
        }
        if streak == 3 { say(GameTalk.line(T("还……要。"), "More…", dudu: T("嘟嘟嘟！"))) }
        else if streak == 5 { say(GameTalk.line(T("我是专业的。"), "I'm a professional.", dudu: T("嘟嘟嘟嘟！✨"))) }
        else if hits == 3 { say(GameTalk.line(T("嗯？我晃一下。"), "Hm? Let me wobble.", dudu: T("嘟～"))) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if face == "eat" { face = "happy" } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { if face == "happy" { face = "gape" } }
        checkEnd()
    }

    private func missed(bonk: Bool) {
        streak = 0
        if bonk { GFX.play("boop", .heavy, volume: 0.5) }
        face = bonk ? "shy" : "cry"
        if bonk { say(GameTalk.line(T("砸我脸了……"), "Hit my face…", dudu: T("嘟！？"))) }
        else if Bool.random() { say(GameTalk.line(T("够不着，不够了。"), "Can't reach. Not trying.", dudu: T("嘟…"))) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { if face == "shy" || face == "cry" { face = "gape" } }
    }

    private func checkEnd() {
        guard queue.isEmpty, shot == nil, !finished else { return }
        finished = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            done(GameResult(kind: .fling, score: min(hits, 10), won: hits >= 6, detail: T("喂进 {0}/{1} 口", hits, Self.total)))
        }
    }

    private func say(_ s: String) {
        withAnimation { bubble = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if bubble == s { withAnimation { bubble = nil } } }
    }
}

/// 游戏开场卡
struct StartCard: View {
    let title: String
    let lines: [String]
    var button = T("开始")
    let action: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
            ForEach(lines, id: \.self) { Text($0).font(.system(size: 13)).foregroundStyle(Theme.text2).multilineTextAlignment(.center) }
            Button(button, action: action)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 40).padding(.vertical, 11)
                .background(Theme.accent, in: Capsule()).foregroundStyle(.black)
                .padding(.top, 6)
        }
        .padding(22)
        .background(Theme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
        // 截图自测：开场卡自己点「开始」，好截到游戏中的画面
        .onAppear { if Shot.autoStart { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { action() } } }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
