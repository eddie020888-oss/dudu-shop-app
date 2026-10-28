import SwiftUI

/// 开完蛋以后：它决定住下 → 作息 → 逐个讲清楚再要权限 → 打开岛台 → 喂第一口（名字在开蛋时只起一次）。
/// 权限不一上来全弹：每一页先说好处，点"好"才弹系统框；点"以后再说"直接跳过。
struct OnboardingView: View {
    @ObservedObject var profile: ProfileStore
    var pet: String
    var askNotifications: (@escaping () -> Void) -> Void
    var askHealth: (@escaping () -> Void) -> Void
    var askMotion: () -> Void
    var startIsland: () -> Void
    var finish: () -> Void
    /// 开过蛋的用户（名字已经在开蛋时起好）从作息页开始
    var startAt: Step = .hello

    enum Step: Int, CaseIterable { case hello, name, schedule, motion, notify, health, island, feed }
    @State private var step: Step = .hello
    @State private var name = ""
    @State private var age: String? = AgeGroup.current?.rawValue
    @FocusState private var nameFocused: Bool

    var body: some View {
        page.onAppear { if step == .hello, startAt != .hello { step = startAt } }
    }

    private var page: some View {
        VStack(spacing: 0) {
            // 进度点
            HStack(spacing: 6) {
                ForEach(Step.allCases.filter { $0 != .name }, id: \.self) { s in
                    Capsule().fill(s.rawValue <= step.rawValue ? Theme.accent : Theme.surface2)
                        .frame(width: s == step ? 18 : 6, height: 6)
                }
            }
            .padding(.top, 14)

            // 舞台：每页它做不同的动作
            ZStack {
                Color.black
                VideoPetView(pet: pet, pose: stagePose, frame: stageFrame, size: 190)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 36))
            .padding(.horizontal, 20).padding(.top, 16)
            .animation(.easeInOut, value: step)

            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.text)
                Text(bodyText).font(.system(size: 15)).lineSpacing(4).foregroundStyle(Theme.text2)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.top, 22)
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

            Spacer()

            VStack(spacing: 10) {
                Button(action: primary) {
                    Text(primaryLabel).font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.black)
                }
                if let skip = skipLabel {
                    Button(skip) { next() }
                        .font(.system(size: 15)).foregroundStyle(Theme.text3)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
        .background(Theme.ground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { name = profile.profile.petName }
    }

    // MARK: 每页内容

    private var stagePose: Pose {
        switch step {
        case .hello: return .sleep
        case .name: return .stand
        case .schedule: return .sleep
        case .motion: return .walk
        case .notify: return .phone
        case .health: return .run
        case .island: return .stand
        case .feed: return .eat
        }
    }
    private var stageFrame: String { step == .name && nameFocused ? "shy" : "" }

    private var title: String {
        switch step {
        case .hello: return T("它决定住下了")
        case .name: return T("给我起个名字吧")
        case .schedule: return T("你一般几点起、几点睡？")
        case .motion: return T("你动，我就动")
        case .notify: return T("我饿了会叫你一声")
        case .health: return T("你走路，我有饭吃")
        case .island: return T("我住在灵动岛上")
        case .feed: return T("最后，喂我第一口")
        }
    }
    private var bodyText: String {
        switch step {
        case .hello: return T("它没去找别的地方，直接躺回了半个蛋壳里，翻了个身。\n看来它打算住在你的手机里了——就住在最顶上，那个会亮的地方。")
        case .name: return T("以后通知和聊天里都用这个名字。")
        case .schedule: return T("你睡的时候我也睡，睡着了饿得慢。你按时起床打开 App，我给你 10 个金币。")
        case .motion: return T("你走路我就走，你开车我就坐着。要「运动与健身」权限，看你在走、在跑还是在车上，数据只在手机上。")
        case .notify: return T("就一声，不响。饿了、渴了、脏了各叫你一次，平时一小时最多打个招呼。要通知权限。")
        case .health: return T("你走得多，我有饭吃。要读「健康」里的步数和运动：走到 4千/8千/1万2 步、每运动一次都给金币，给我买吃的。只读不写。")
        case .island: return T("打开后，锁屏和灵动岛上都能看到我。系统大约 8 小时会收起一次，你下次打开 App 我就回来。")
        case .feed: return T("新手礼包里有一个 🍙，还有 🥕×3、☕️×1。先喂我饭团。")
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .name:
            TextField(T("嘟嘟"), text: $name)
                .font(.system(size: 20, weight: .semibold))
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .focused($nameFocused)
                .submitLabel(.done)
                .padding(.top, 6)
        case .schedule:
            VStack(spacing: 8) {
                hourRow(T("起床"), value: Binding(get: { profile.profile.wakeHour }, set: { profile.profile.wakeHour = $0 }), range: 4...12)
                hourRow(T("睡觉"), value: Binding(get: { profile.profile.sleepHour }, set: { profile.profile.sleepHour = $0 }), range: 19...23)
                Text(T("你是？（它按这个陪你，以后在「我」里能改）")).font(.system(size: 13)).foregroundStyle(Theme.text3).padding(.top, 6)
                AgePicker(selection: Binding(get: { age }, set: { age = $0; AgeGroup.current = $0.flatMap(AgeGroup.init(rawValue:)) }))
            }
            .padding(.top, 6)
        default:
            EmptyView()
        }
    }

    private func hourRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.text)
            Spacer()
            Picker(label, selection: value) {
                ForEach(Array(range), id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
            }
            .tint(Theme.accent)
        }
        .padding(.horizontal, 14).frame(minHeight: 48)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var primaryLabel: String {
        switch step {
        case .hello: return T("欢迎住下")
        case .name, .schedule: return T("下一步")
        case .motion, .notify, .health: return T("好")
        case .island: return T("打开岛台")
        case .feed: return T("喂它")
        }
    }
    private var skipLabel: String? {
        switch step {
        case .motion, .notify, .health, .island: return T("以后再说")
        default: return nil
        }
    }

    private func primary() {
        switch step {
        case .name:
            let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.profile.petName = n.isEmpty ? T("嘟嘟") : String(n.prefix(8))
            nameFocused = false
            next()
        case .motion: askMotion(); next()
        case .notify: askNotifications { next() }
        case .health: askHealth { next() }
        case .island: startIsland(); next()
        case .feed: finish()
        default: next()
        }
    }

    private func next() {
        var r = step.rawValue + 1
        if Step(rawValue: r) == .name { r += 1 }   // 名字开蛋时已经起过
        guard let n = Step(rawValue: r) else { finish(); return }
        withAnimation(.spring(duration: 0.35)) { step = n }
    }
}
