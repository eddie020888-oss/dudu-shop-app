import SwiftUI

/// 猜杯子：饭团扣在 3 个杯子里的一个，杯子换位，你猜在哪个底下。5 轮，越来越快。
/// 它在旁边瘫着看，换位的时候眼睛跟着转，转晕了打哈欠；猜中它分到饭团，猜错它也照吃（懒得生气）。
struct CupsGame: View {
    let pet: String
    let done: (GameResult) -> Void

    private static let rounds = 5
    enum Phase { case intro, show, shuffling, pick, reveal, over }

    @State private var phase: Phase = .intro
    @State private var slots = [0, 1, 2]         // slots[cup] = 杯子现在在第几个位置
    @State private var ball = 0                  // 饭团在哪个杯子底下
    @State private var lifted: Int? = nil
    @State private var round = 0
    @State private var right = 0
    @State private var face = "think"
    @State private var bubble: String? = nil
    @State private var picked: Int? = nil
    @State private var depth: [Int: CGFloat] = [:]   // 换位时的前后：+1 前面，-1 后面

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cupW = min(w * 0.26, 110)
            ZStack {
                Image("game_bg_sky").resizable().scaledToFill().frame(width: w, height: h).clipped()
                Color.black.opacity(0.45)

                // 它在上面瘫着看
                DressedPetView(pet: pet, pose: .stand, frame: face, accessories: [])
                    .frame(width: min(w * 0.42, 170), height: min(w * 0.42, 170))
                    .position(x: w * 0.5, y: h * 0.24)
                if let b = bubble { PetBubble(text: b).position(x: w * 0.74, y: h * 0.10) }

                // 桌面（3D 木桌）
                let tableH = (w - 8) * 293 / 900
                Image("game_table").resizable().scaledToFit()
                    .frame(width: w - 8)
                    .position(x: w * 0.5, y: h * 0.62 + cupW * 0.38 + tableH * 0.08)

                ForEach(0..<3, id: \.self) { c in
                    let x = w * (0.2 + 0.3 * CGFloat(slots[c]))
                    let up = lifted == c
                    let dz = depth[c] ?? 0          // 换位时一个从前面绕、一个从后面绕
                    ZStack {
                        // 桌上的影子：碗抬起来就变小变淡
                        Ellipse().fill(Color.black.opacity(up ? 0.18 : 0.38))
                            .frame(width: cupW * (up ? 0.62 : 0.9), height: cupW * 0.14)
                            .offset(y: cupW * 0.37)
                        if c == ball && (phase == .show || phase == .reveal || phase == .over || up) {
                            Image("game_onigiri").resizable().scaledToFit()
                                .frame(width: cupW * 0.58)
                                .scaleEffect(up ? 1 : 0.85)
                                .offset(y: cupW * 0.17)
                        }
                        Image("game_bowl").resizable().scaledToFit()
                            .frame(width: cupW)
                            .rotationEffect(.degrees(up ? -9 : 0), anchor: .bottomTrailing)
                            .offset(y: up ? -cupW * 0.62 : 0)
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
                    }
                    .frame(width: cupW, height: cupW * 1.4)
                    .scaleEffect(1 + dz * 0.1)
                    .offset(y: dz * cupW * 0.12)
                    .zIndex(Double(dz))
                    .overlay(alignment: .bottom) {
                        if phase == .reveal || phase == .over, picked == c {
                            Capsule().fill(c == ball ? Theme.clean : Theme.alert).frame(width: cupW * 0.5, height: 5).offset(y: 6)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { pick(c) }
                    .position(x: x, y: h * 0.62)
                }

                VStack {
                    HStack(spacing: 8) {
                        ForEach(0..<Self.rounds, id: \.self) { i in
                            Capsule().fill(results.indices.contains(i) ? (results[i] ? Theme.clean : Theme.alert.opacity(0.6)) : Theme.surface)
                                .frame(width: 26, height: 8)
                        }
                    }
                    .padding(.top, 14)
                    Spacer()
                    Text(hint).font(.system(size: 13)).foregroundStyle(Theme.text3).padding(.bottom, 22)
                }

                if phase == .intro {
                    StartCard(title: T("猜杯子"), lines: [T("饭团扣在一个杯子底下"), T("杯子换来换去，一轮比一轮快"), T("猜中它分到饭团，猜错它也照吃")]) { nextRound() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
    }

    @State private var results: [Bool] = []

    private var hint: String {
        switch phase {
        case .show: return T("看好饭团在哪")
        case .shuffling: return T("换位中……")
        case .pick: return T("在哪个底下？点一下")
        default: return ""
        }
    }

    private func nextRound() {
        picked = nil
        ball = Int.random(in: 0..<3)
        face = "surprised"
        phase = .show
        withAnimation(.spring(response: 0.35)) { lifted = ball }
        GFX.play("flip", .light, volume: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.35)) { lifted = nil }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shuffle() }
        }
    }

    private func shuffle() {
        phase = .shuffling
        face = "think"
        let n = 4 + round * 2
        let dur = max(0.2, 0.5 - Double(round) * 0.07)
        if round >= 3 { say(GameTalk.line(T("转晕了……"), "Dizzy…", dudu: T("嘟～～"))) }
        for i in 0..<n {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * (dur + 0.04)) {
                var a = Int.random(in: 0..<3), b = Int.random(in: 0..<3)
                while b == a { b = Int.random(in: 0..<3) }
                // 交换两个位置上的杯子
                let ca = slots.firstIndex(of: a)!, cb = slots.firstIndex(of: b)!
                // 一个从前面绕、一个从后面绕（不是两个碗平着穿过去）
                withAnimation(.easeOut(duration: dur / 2)) { depth[ca] = 1; depth[cb] = -1 }
                withAnimation(.easeInOut(duration: dur)) { slots[ca] = b; slots[cb] = a }
                MKSfx.play("flip", volume: 0.25)
                DispatchQueue.main.asyncAfter(deadline: .now() + dur / 2) { withAnimation(.easeIn(duration: dur / 2)) { depth[ca] = 0; depth[cb] = 0 } }
                if i == n / 2 && round >= 2 { face = "yawn" }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(n) * (dur + 0.04) + 0.15) {
            face = "think"
            phase = .pick
        }
    }

    private func pick(_ c: Int) {
        guard phase == .pick else { return }
        picked = c
        phase = .reveal
        let ok = c == ball
        results.append(ok)
        round += 1
        if ok { right += 1 }
        withAnimation(.spring(response: 0.35)) { lifted = c }
        if ok { GFX.good() } else { GFX.bad() }
        if !ok {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { withAnimation(.spring(response: 0.35)) { lifted = ball } }
        }
        face = ok ? "laugh" : "eat"
        say(ok ? GameTalk.line(T("猜对了！分我一口。"), "Right! Share a bite.", dudu: T("嘟嘟！✨"))
               : GameTalk.line(T("那我吃了啊。"), "I'll eat it then.", dudu: T("嘟…嘟嘟。")))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.spring(response: 0.35)) { lifted = nil }
            if round >= Self.rounds {
                phase = .over
                let score = right * 2
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    done(GameResult(kind: .cups, score: score, won: right >= 3, detail: T("猜中 {0}/{1} 次", right, Self.rounds)))
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { nextRound() }
            }
        }
    }

    private func say(_ s: String) {
        withAnimation { bubble = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if bubble == s { withAnimation { bubble = nil } } }
    }
}

/// 倒扣的杯子：上窄下宽
struct CupShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let top = r.width * 0.22
        p.move(to: CGPoint(x: r.minX + top, y: r.minY + r.height * 0.06))
        p.addQuadCurve(to: CGPoint(x: r.maxX - top, y: r.minY + r.height * 0.06), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.04))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.03, y: r.maxY - r.height * 0.1))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.03, y: r.maxY - r.height * 0.1), control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.06))
        p.closeSubpath()
        return p
    }
}
