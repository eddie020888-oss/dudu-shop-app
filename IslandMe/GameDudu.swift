import SwiftUI

/// 猜嘟语：它嘟一串、摆个表情，你从 3 个意思里猜它想说啥。一局 5 题。
/// 猜对它会点头（嘟！），猜错它歪头再嘟一遍、比划给你看正确的意思。越熟题越难（选项越像）。
struct DuduQuiz: View {
    let pet: String
    let done: (GameResult) -> Void

    struct Q { let dudu: String; let frame: String; let answer: String; let wrong: [String]; let hint: String }

    /// 题库：意思都来自它的日常（吃、喝、睡、懒、养生、想你）
    static let bank: [Q] = [
        Q(dudu: T("嘟…🍔"), frame: "hungry", answer: T("饿了"), wrong: [T("想睡觉"), T("想出去玩")], hint: T("它盯着你手里的东西")),
        Q(dudu: T("嘟…🧋"), frame: "thirsty", answer: T("想喝点什么"), wrong: [T("想洗澡"), T("肚子疼")], hint: T("它抱着空杯子晃了晃")),
        Q(dudu: T("嘟……💤"), frame: "yawn", answer: T("困了"), wrong: [T("饿了"), T("生气了")], hint: T("眼皮在打架")),
        Q(dudu: T("嘟嘟！✨"), frame: "laugh", answer: T("好开心"), wrong: [T("好困"), T("好委屈")], hint: T("肚子笑得一颤一颤")),
        Q(dudu: T("嘟…///"), frame: "shy", answer: T("不好意思了"), wrong: [T("想吃蛋糕"), T("想睡觉")], hint: T("它把脸埋进小手里")),
        Q(dudu: T("嘟——。"), frame: "angry", answer: T("有点小脾气"), wrong: [T("好开心"), T("想喝水")], hint: T("脸鼓起来，扭过头去")),
        Q(dudu: T("嘟？？"), frame: "surprised", answer: T("没听懂"), wrong: [T("饿了"), T("想你了")], hint: T("歪着头看你")),
        Q(dudu: T("嘟…嘟。"), frame: "cry", answer: T("有点委屈"), wrong: [T("想玩游戏"), T("困了")], hint: T("眼睛湿湿的")),
        Q(dudu: T("嘟嘟·嘟♡"), frame: "happy", answer: T("想你了"), wrong: [T("想吃饭团"), T("要睡了")], hint: T("它朝你眨眨眼")),
        Q(dudu: T("嘟嘟嘟～🍵"), frame: "coffee", answer: T("喝口热茶，养生"), wrong: [T("想吃炸鸡"), T("想跑步")], hint: T("它捧着保温杯，一脸满足")),
        Q(dudu: T("嘟…嘟嘟…"), frame: "think", answer: T("在想晚饭吃什么"), wrong: [T("在想去健身"), T("在想写作业")], hint: T("它摸着肚子在算什么")),
        Q(dudu: T("嘟。嘟嘟。"), frame: "idle", answer: T("你坐这儿，我也不动"), wrong: [T("快起来运动"), T("去写作业")], hint: T("它拍拍旁边的位置")),
        Q(dudu: T("嘟！嘟嘟！"), frame: "hungry", answer: T("就一口"), wrong: [T("我不吃"), T("我吃饱了")], hint: T("伸出一根短手指")),
        Q(dudu: T("嘟～～"), frame: "sleep", answer: T("晚安"), wrong: [T("早上好"), T("开饭了")], hint: T("抱着蛋壳闭上眼")),
        Q(dudu: T("嘟嘟？🍙"), frame: "eat", answer: T("还有吗"), wrong: [T("太难吃了"), T("不要了")], hint: T("它舔舔嘴，看看空盘子")),
        Q(dudu: T("嘟…🛁"), frame: "dirty", answer: T("想洗个澡"), wrong: [T("想吃饭"), T("想出门")], hint: T("它闻了闻自己")),
    ]

    private static let count = 5
    @State private var started = false
    @State private var qs: [Q] = []
    @State private var i = 0
    @State private var options: [String] = []
    @State private var chosen: String? = nil
    @State private var right = 0
    @State private var face = "idle"
    @State private var showHint = false
    @State private var wobble = false

    var body: some View {
        GeometryReader { g in
            ZStack {
                Image("game_bg_room").resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                if started, i < qs.count {
                    let q = qs[i]
                    VStack(spacing: 14) {
                        Text(T("第 {0}/{1} 题", i + 1, Self.count)).font(.system(size: 12)).foregroundStyle(Theme.text3).padding(.top, 14)
                        DressedPetView(pet: pet, pose: .stand, frame: face, accessories: [])
                            .frame(width: min(g.size.width * 0.5, 200), height: min(g.size.width * 0.5, 200))
                            .rotationEffect(.degrees(wobble ? 4 : -4))
                            .animation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true), value: wobble)
                        Text(q.dudu).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: "#3A2A6E"))
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(Color(hex: "#FFF6E8"), in: RoundedRectangle(cornerRadius: 22))
                            .overlay(alignment: .top) {   // 气泡小尾巴，指向它
                                Triangle().fill(Color(hex: "#FFF6E8")).frame(width: 18, height: 10).offset(y: -9)
                            }
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                            .scaleEffect(wobble ? 1.04 : 1)
                        Group {
                            if showHint || chosen != nil {
                                Text(T("（{0}）", q.hint)).font(.system(size: 13)).foregroundStyle(Theme.text2)
                            } else {
                                Button(T("看看它在干嘛")) { withAnimation { showHint = true } }
                                    .font(.system(size: 13)).foregroundStyle(Theme.accent)
                            }
                        }
                        .frame(height: 20)
                        Spacer(minLength: 0)
                        VStack(spacing: 10) {
                            ForEach(options, id: \.self) { o in
                                Button { choose(o) } label: {
                                    Text(o).font(.system(size: 16, weight: .medium))
                                        .frame(maxWidth: .infinity, minHeight: 52)
                                        .background(color(o).opacity(chosen == nil ? 0.92 : 1), in: RoundedRectangle(cornerRadius: 16))
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
                                        .foregroundStyle(chosen != nil && o == q.answer ? Color.black : Theme.text)
                                }
                                .buttonStyle(.plain)
                                .disabled(chosen != nil)
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 20)
                    }
                }
                if !started {
                    StartCard(title: T("猜嘟语"), lines: [T("它嘟一串，配个表情"), T("你猜它想说什么，一局 5 题"), T("猜不出来可以看看它在干嘛")]) { start() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
    }

    private func color(_ o: String) -> Color {
        guard let c = chosen else { return Theme.surface }
        if o == qs[i].answer { return Theme.clean }
        if o == c { return Theme.alert.opacity(0.55) }
        return Theme.surface
    }

    private func start() {
        qs = Array(Self.bank.shuffled().prefix(Self.count))
        i = 0; right = 0; started = true
        load()
    }

    private func load() {
        let q = qs[i]
        options = ([q.answer] + q.wrong).shuffled()
        chosen = nil; showHint = false
        face = q.frame
        wobble.toggle()
    }

    private func choose(_ o: String) {
        let q = qs[i]
        withAnimation(.easeOut(duration: 0.2)) { chosen = o }
        if o == q.answer { right += 1; face = "laugh"; GFX.good() } else { face = "surprised"; GFX.bad() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if i + 1 < qs.count { i += 1; load() }
            else {
                done(GameResult(kind: .dudu, score: right * 2, won: right >= 3, detail: T("听懂 {0}/{1} 句", right, Self.count)))
            }
        }
    }
}


private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath(); return p
    }
}
