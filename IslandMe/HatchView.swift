import SwiftUI

/// 开蛋：蛋 → 点/摇出裂纹 → 看两条路线的预览 → 选（不可更改，二次确认）→ 破壳"嘟？" → 起名
struct HatchView: View {
    @ObservedObject var bond: BondStore
    @ObservedObject var profile: ProfileStore
    var pet: String
    var finish: () -> Void

    enum Phase { case egg, choose, lang, hatching, name }
    @State private var phase: Phase = .egg
    @State private var cracks = 0          // 0–3
    @State private var taps = 0
    @State private var wobble = false
    @State private var answer = false       // 蛋里回敲一下
    @State private var picked: LangRoute? = nil
    @State private var confirm = false
    @State private var shellOpen = false
    @State private var petIn = false
    @State private var hatchVideo: URL? = Bundle.main.url(forResource: "purple_x_hatch", withExtension: "mp4")
    @State private var duduShown = false
    @State private var arrived = false      // 开场：灵动岛亮一下，一团光掉下来变成蛋
    @State private var fall = false
    @State private var handLine = false
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            switch phase {
            case .egg:      eggStage
            case .choose:   chooseStage
            case .lang:     langStage
            case .hatching: hatchingStage
            case .name:     nameStage
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(duration: 0.45), value: phase)
        .onReceive(NotificationCenter.default.publisher(for: .deviceShaken)) { _ in if phase == .egg { knock(strong: true) } }
        .onAppear { Analytics.log("hatch_start") }
        .alert(T("选定后不能更改哦"), isPresented: $confirm) {
            Button(T("再想想"), role: .cancel) { }
            Button(T("就这样")) { startHatching() }
        } message: {
            Text(picked == .dudu ? T("它会一直说嘟语，但会越来越懂你。") : T("它会从嘟嘟开始，慢慢学会说{0}。", picked == .en ? T("英文") : T("中文")))
        }
    }

    // MARK: 蛋

    private var eggStage: some View {
        ZStack(alignment: .top) {
            // 灵动岛那里亮一下紫光，一小团光掉下来
            Capsule().fill(Theme.accent).frame(width: 126, height: 37)
                .blur(radius: arrived ? 0 : 14).opacity(arrived ? 0 : 0.9)
                .padding(.top, 11).ignoresSafeArea()
                .animation(.easeOut(duration: 1.2).delay(0.3), value: arrived)
            Circle().fill(Theme.accent).frame(width: 18, height: 18).blur(radius: 3)
                .shadow(color: Theme.accent, radius: 12)
                .offset(y: fall ? 330 : 20).opacity(fall && !arrived ? 1 : 0)
                .animation(.easeIn(duration: 0.9), value: fall)
            eggColumn.opacity(arrived ? 1 : 0).animation(.easeOut(duration: 0.6), value: arrived)
        }
        .onAppear {
            guard !arrived else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { fall = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                arrived = true
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
    }

    private var eggColumn: some View {
        VStack(spacing: 28) {
            Spacer()
            Text(cracks == 0 ? T("昨晚 9 点 41 分，有什么东西从灵动岛掉了进来。\n它一直在等你把手机拿起来。")
                 : (cracks == 1 ? T("它在里面回敲了一下。") : (cracks < 3 ? T("它在里面动了一下……") : T("它要出来了！"))))
                .font(.system(size: 17)).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            EggView(cracks: cracks, glow: answer)
                .frame(width: 200, height: 250)
                .rotationEffect(.degrees(wobble ? 6 : -6), anchor: .bottom)
                .animation(.easeInOut(duration: 0.12).repeatCount(answer ? 5 : 1, autoreverses: true), value: wobble)
                .onTapGesture { knock(strong: false) }
            Text(T("点点它，或者摇一摇手机")).font(.system(size: 13)).foregroundStyle(Theme.text3)
            Spacer()
        }
    }

    private func knock(strong: Bool) {
        taps += strong ? 3 : 1
        wobble.toggle()
        UIImpactFeedbackGenerator(style: strong ? .medium : .light).impactOccurred()
        // 蛋里的小家伙轻轻回应
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            answer = true; wobble.toggle()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { answer = false }
        }
        let c = min(3, taps / 3)
        if c != cracks { withAnimation { cracks = c } }
        if c >= 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { phase = .choose }
        }
    }

    // MARK: 选路线（先看两段预览）

    private var chooseStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(T("破壳前，决定一件事")).font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.text)
                Text(T("你希望它以后学会人类语言吗？\n选定后**永远不能更改**，两种它都会长大、都会越来越懂你。"))
                    .font(.system(size: 15)).foregroundStyle(Theme.text2).lineSpacing(4)
                RoutePreview(title: T("学会说话"), subtitle: T("从嘟嘟开始，慢慢学单词、说短句，最后能和你聊天"),
                             lines: [T("嘟？"), T("饿…嘟"), T("还……要。"), T("你坐这儿，我也不想动。")],
                             selected: picked != nil && picked != .dudu) { picked = .zh }
                RoutePreview(title: T("保留嘟语"), subtitle: T("永远说嘟语，但会听懂你的话，用动作回应你"),
                             lines: [T("嘟？"), T("嘟嘟！🍰"), T("（你说晚安，它去找毯子）"), T("嘟嘟·嘟♡")],
                             selected: picked == .dudu) { picked = .dudu }
                Button {
                    if picked == .dudu { confirm = true } else { phase = .lang }
                } label: {
                    Text(picked == nil ? T("先选一个") : T("下一步")).font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(picked == nil ? Theme.surface2 : Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(picked == nil ? Theme.text3 : .black)
                }
                .disabled(picked == nil)
                .padding(.top, 6)
            }
            .padding(24)
        }
    }

    private var langStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text(T("它要学哪种语言？")).font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.text)
            Text(T("也是选定后不能更改。")).font(.system(size: 15)).foregroundStyle(Theme.text2)
            ForEach([LangRoute.zh, .en], id: \.self) { r in
                Button { picked = r } label: {
                    HStack {
                        Text(r == .zh ? T("中文") : "English").font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Image(systemName: picked == r ? "checkmark.circle.fill" : "circle")
                    }
                    .padding(18)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(picked == r ? Theme.accent : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.text)
            }
            Spacer()
            HStack(spacing: 12) {
                Button(T("返回")) { picked = nil; phase = .choose }
                    .frame(maxWidth: .infinity, minHeight: 52).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(Theme.text)
                Button(T("确定")) { confirm = true }
                    .frame(maxWidth: .infinity, minHeight: 52).background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.black).font(.system(size: 17, weight: .semibold))
                    .disabled(picked != .zh && picked != .en)
            }
        }
        .padding(24)
    }

    // MARK: 破壳

    private func startHatching() {
        guard let r = picked else { return }
        Analytics.log("hatch_route", ["route": r.rawValue])
        phase = .hatching
        if hatchVideo != nil {
            // 破壳视频：蛋晃 → 裂开 → 上半壳掉到后面 → 它窝在下半壳里眨眼
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); withAnimation { handLine = true } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { withAnimation { duduShown = true; handLine = false } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.9) { phase = .name; name = profile.profile.petName }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(duration: 0.6)) { shellOpen = true }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { withAnimation(.spring(duration: 0.7)) { petIn = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { phase = .name; name = profile.profile.petName }
    }

    @ViewBuilder private var hatchingStage: some View {
        if let url = hatchVideo {
            VStack(spacing: 24) {
                Spacer()
                ZStack { Color.black; LoopingVideoView(url: url) }
                    .frame(width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 36))
                ZStack {
                    Text(T("一只短短的手，先伸了出来……")).font(.system(size: 15)).foregroundStyle(Theme.text2)
                        .opacity(handLine ? 1 : 0)
                    Text(T("嘟？")).font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.accent)
                        .opacity(duduShown ? 1 : 0).scaleEffect(duduShown ? 1 : 0.6)
                }
                Spacer()
            }
        } else {
            classicHatching
        }
    }

    private var classicHatching: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                if petIn {
                    VideoPetView(pet: pet, pose: .stand, size: 180)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
                EggHalf(top: true).fill(EggView.shellFill)
                    .frame(width: 200, height: 250)
                    .offset(x: shellOpen ? -70 : 0, y: shellOpen ? -90 : 0)
                    .rotationEffect(.degrees(shellOpen ? -35 : 0))
                    .opacity(shellOpen ? 0 : 1)
                EggHalf(top: false).fill(EggView.shellFill)
                    .frame(width: 200, height: 250)
                    .offset(y: shellOpen ? 80 : 0)
                    .opacity(petIn ? 0 : 1)
            }
            .frame(height: 280)
            if petIn {
                Text(T("嘟？")).font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.accent)
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer()
        }
    }

    // MARK: 起名

    private var nameStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            ZStack { Color.black; VideoPetView(pet: pet, pose: .stand, frame: nameFocused ? "shy" : "", size: 150) }
                .frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 30))
            Text(T("给它起个名字")).font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.text)
            Text(T("破壳日、名字和第一声“嘟？”，是你们的第一份回忆。")).font(.system(size: 14)).foregroundStyle(Theme.text2)
            TextField(T("嘟嘟"), text: $name)
                .font(.system(size: 20, weight: .semibold))
                .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .focused($nameFocused).submitLabel(.done)
            Spacer()
            Button {
                let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                profile.profile.petName = n.isEmpty ? T("嘟嘟") : String(n.prefix(8))
                Voice.petName = profile.profile.petName
                bond.hatch(route: picked ?? .zh)
                finish()
            } label: {
                Text(T("就叫它这个")).font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.black)
            }
        }
        .padding(24)
    }
}

/// 一条路线的预览卡：几句台词轮流冒出来
private struct RoutePreview: View {
    var title: String
    var subtitle: String
    var lines: [String]
    var selected: Bool
    var pick: () -> Void
    @State private var i = 0
    private let tick = Timer.publish(every: 1.6, on: .main, in: .common).autoconnect()

    var body: some View {
        Button(action: pick) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Theme.accent : Theme.text3)
                }
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.text2)
                HStack(spacing: 8) {
                    ForEach(0..<lines.count, id: \.self) { k in
                        Circle().fill(k <= i ? Theme.accent : Theme.surface2).frame(width: 6, height: 6)
                    }
                    Spacer()
                }
                Text(lines[i])
                    .font(.system(size: 16)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
                    .id(i).transition(.opacity.combined(with: .move(edge: .bottom)))
                Text([T("第 1 天"), T("第 3 天"), T("第 2 周"), T("第 4 周")][min(i, 3)]).font(.system(size: 11)).foregroundStyle(Theme.text3)
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Theme.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain).foregroundStyle(Theme.text)
        .onReceive(tick) { _ in withAnimation { i = (i + 1) % lines.count } }
    }
}

/// 嘟嘟星的蛋：淡紫渐变 + 深紫斑点 + 符号；裂纹随 cracks 增加
struct EggView: View {
    var cracks: Int
    var glow: Bool = false

    /// 外星壳（2026-10-17 发财哥定）：深紫色壳 + 会发光的纹路；破壳后下半个就是它的第一张床
    static let shellFill = LinearGradient(colors: [Color(hex: "#6B4FB8"), Color(hex: "#2E1F5C")], startPoint: .top, endPoint: .bottom)
    static let veinColor = Color(hex: "#A8E6FF")

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                EggHalf(top: nil).fill(Self.shellFill)
                    .shadow(color: Theme.accent.opacity(glow ? 0.8 : 0.3), radius: glow ? 24 : 12)
                // 发光纹路（像叶脉，从中间的符号往外长）
                Path { p in
                    let veins: [[(CGFloat, CGFloat)]] = [
                        [(0.50, 0.45), (0.38, 0.38), (0.30, 0.26)],
                        [(0.50, 0.45), (0.63, 0.36), (0.68, 0.24)],
                        [(0.50, 0.45), (0.34, 0.58), (0.24, 0.62)],
                        [(0.50, 0.45), (0.66, 0.60), (0.77, 0.66)],
                        [(0.50, 0.45), (0.47, 0.66), (0.52, 0.84)],
                    ]
                    for v in veins {
                        p.move(to: CGPoint(x: w * v[0].0, y: h * v[0].1))
                        p.addQuadCurve(to: CGPoint(x: w * v[2].0, y: h * v[2].1), control: CGPoint(x: w * v[1].0, y: h * v[1].1))
                    }
                }
                .stroke(Self.veinColor.opacity(glow ? 0.95 : 0.55), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .shadow(color: Self.veinColor.opacity(glow ? 0.9 : 0.4), radius: glow ? 8 : 4)
                // 蛋底一个很小的厨师帽印记（谁画的？第四章揭晓：星星爷爷）
                ChefHatMark().fill(Self.veinColor.opacity(0.32))
                    .frame(width: w * 0.09, height: w * 0.08)
                    .position(x: w * 0.5, y: h * 0.885)
                // 嘟嘟星的星
                Image(systemName: "sparkle").font(.system(size: w * 0.14, weight: .bold))
                    .foregroundStyle(Self.veinColor.opacity(glow ? 1 : 0.75))
                    .position(x: w * 0.5, y: h * 0.45)
                // 裂纹
                if cracks > 0 {
                    Path { p in
                        let segs: [[(CGFloat, CGFloat)]] = [
                            [(0.42, 0.22), (0.48, 0.30), (0.43, 0.37), (0.50, 0.44)],
                            [(0.50, 0.44), (0.58, 0.40), (0.63, 0.48), (0.71, 0.44)],
                            [(0.50, 0.44), (0.40, 0.50), (0.33, 0.47), (0.26, 0.53)],
                        ]
                        for s in segs.prefix(cracks) {
                            p.move(to: CGPoint(x: w * s[0].0, y: h * s[0].1))
                            for q in s.dropFirst() { p.addLine(to: CGPoint(x: w * q.0, y: h * q.1)) }
                        }
                    }
                    .stroke(Color(hex: "#E9DEFF"), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

/// 蛋形；top=true 上半壳、false 下半壳（锯齿切口）、nil 整颗
struct EggHalf: Shape {
    var top: Bool?
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var egg = Path()
        egg.move(to: CGPoint(x: w * 0.5, y: 0))
        egg.addCurve(to: CGPoint(x: w, y: h * 0.62), control1: CGPoint(x: w * 0.86, y: 0), control2: CGPoint(x: w, y: h * 0.34))
        egg.addCurve(to: CGPoint(x: w * 0.5, y: h), control1: CGPoint(x: w, y: h * 0.86), control2: CGPoint(x: w * 0.78, y: h))
        egg.addCurve(to: CGPoint(x: 0, y: h * 0.62), control1: CGPoint(x: w * 0.22, y: h), control2: CGPoint(x: 0, y: h * 0.86))
        egg.addCurve(to: CGPoint(x: w * 0.5, y: 0), control1: CGPoint(x: 0, y: h * 0.34), control2: CGPoint(x: w * 0.14, y: 0))
        guard let top else { return egg }
        // 锯齿切口
        var zig = Path()
        let y = h * 0.5
        zig.move(to: CGPoint(x: -10, y: top ? -10 : h + 10))
        zig.addLine(to: CGPoint(x: -10, y: y))
        let n = 8
        for k in 0...n {
            let x = w * CGFloat(k) / CGFloat(n)
            zig.addLine(to: CGPoint(x: x, y: y + (k % 2 == 0 ? -12 : 12)))
        }
        zig.addLine(to: CGPoint(x: w + 10, y: y))
        zig.addLine(to: CGPoint(x: w + 10, y: top ? -10 : h + 10))
        zig.closeSubpath()
        return egg.intersection(zig)
    }
}


/// 小厨师帽：三团云朵 + 一条帽檐
struct ChefHatMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.addEllipse(in: CGRect(x: 0, y: h * 0.18, width: w * 0.46, height: h * 0.46))
        p.addEllipse(in: CGRect(x: w * 0.27, y: 0, width: w * 0.46, height: h * 0.5))
        p.addEllipse(in: CGRect(x: w * 0.54, y: h * 0.18, width: w * 0.46, height: h * 0.46))
        p.addRoundedRect(in: CGRect(x: w * 0.16, y: h * 0.48, width: w * 0.68, height: h * 0.34), cornerSize: CGSize(width: 1.5, height: 1.5))
        p.addRect(CGRect(x: w * 0.14, y: h * 0.84, width: w * 0.72, height: h * 0.16))
        return p
    }
}
