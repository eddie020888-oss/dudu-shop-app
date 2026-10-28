import SwiftUI
import UserNotifications
import AVFoundation

extension Notification.Name {
    static let openChat = Notification.Name("openChat")
    static let petSpoke = Notification.Name("petSpoke")   // 系统通知到点，App 在前台时同步进聊天
    static let deviceShaken = Notification.Name("deviceShaken")
    static let userChatted = Notification.Name("userChatted")
    static let userTyping = Notification.Name("userTyping")     // object: Bool
    static let openShop = Notification.Name("openShop")
}

/// 处理通知点击：点通知横幅 → 直接进聊天页；App 在前台时通知也弹横幅
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        IslandRefresh.register()          // 后台刷新：App 不开时岛台也能隔一阵换个样子
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.notification.request.identifier == "shop.ready" {
            NotificationCenter.default.post(name: .openShop, object: nil)
        } else {
            NotificationCenter.default.post(name: .openChat, object: nil)
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        // 问候 / 作息由系统按时发；App 开着时把这句同步进聊天（需求那条 onChange 已经写过，跳过）
        if id.hasPrefix("greet.") || id.hasPrefix("routine.") || id.hasPrefix("meal.") {
            NotificationCenter.default.post(name: .petSpoke, object: notification.request.content.body)
        }
        return id.hasPrefix("need.") ? [.banner, .sound] : [.banner]
    }
}

@main
struct IslandMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    init() {
        GroupMigration.run()     // 一定要最先：开通 App Group 后把旧存档搬进共享容器
        Shot.seed()
        // 老用户（已经有存档）不再走新手开场
        let d = UserDefaults.standard
        if d.object(forKey: "onboarded.v1") == nil,
           UserDefaults(suiteName: Character.appGroup)?.data(forKey: "petneeds.v1") != nil {
            d.set(true, forKey: "onboarded.v1")
        }
    }
    var body: some Scene {
        WindowGroup {
            if MKDemo.on { MKDemoRoot() } else { CloudRoot() }
        }
    }
}

struct ContentView: View {
    @StateObject private var detector = ActivityDetector()
    @StateObject private var live = LiveActivityManager()
    @StateObject private var chat = ChatStore()
    @StateObject private var needs = NeedsStore()
    @StateObject private var profile = ProfileStore()
    @StateObject private var routine = RoutineStore()
    @StateObject private var health = HealthStore()
    @StateObject private var companion = CompanionStore()
    @StateObject private var letters = LetterStore()
    @StateObject private var gaze = GazeWatcher()
    @State private var lastGazeReact = Date.distantPast
    @State private var openLetter: DuduLetter? = nil
    @ObservedObject private var bond = BondStore.shared
    @State private var character = Character.load()
    @State private var manualPose: Pose? = nil          // nil = 跟随传感器
    @State private var showChat = false
    @Namespace private var zoom

    private var shownPose: Pose { manualPose ?? detector.pose }

    @State private var poseSince = Date()
    @State private var showFood = false
    @State private var tab = Shot.on ? Shot.tab : 0   // 0 首页 1 窝 2 商城 3 我 4 小店
    @State private var nestRoom: NestRoom = Shot.room.flatMap { NestRoom(rawValue: $0) } ?? .bedroom
    @State private var showKitchen = false
    @State private var shopHint: String? = nil      // 首页小店卡片上那一句：它的饭在店里、今日招牌还没做……
    @State private var lowBatterySaid = false
    @AppStorage("onboarded.v1") private var onboarded = false
    @AppStorage(StoryIntroView.seenKey) private var storySeen = false
    @State private var toast: ProfileStore.Reward? = nil
    @State private var careFlash: Pose? = nil        // 照顾后舞台上演几秒的动作视频（eat/coffee/wash）
    @State private var reaction: String? = nil       // 戳它/自发小动作时的表情帧
    @State private var stageClip: String? = nil      // 专门片段：happy（开心晃）/ shell（窝在蛋壳里）
    @State private var clipToken = ""
    @State private var eatingUntil = Date.distantPast   // 吃喝动画播完前不让别的动作打断
    @State private var pokeCount = 0
    @State private var pokeTimes: [Date] = []         // 连着摸 3 下 = 摸肚子
    @State private var flourishTimer: Timer? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var intimacy = Intimacy.load()
    @State private var showIntimacy = false
    @State private var rescueShow: Rescue? = nil
    @State private var pickGame = Shot.pickGame
    @State private var homeGame: GameKind? = Shot.game
    // 2026-10-28 新手第一个小任务：回到桌面看一眼灵动岛上的它（我们最特别的地方，新手要第一时间看到）
    @AppStorage("quest.islandPeek") private var peekQuest = ""   // "" 没开始 / "on" 进行中 / "done"
    @State private var leftAt: Date? = nil

    // body 拆成三段，避免一条链太长编译器算不过来
    var body: some View {
        withCompanion
    }

    private var core: some View {
        TabView(selection: $tab) {
            home.tabItem { Label(T("首页"), systemImage: "house.fill") }.tag(0)
            if shopUnlocked {
                kitchenView.tabItem { Label(T("小店"), systemImage: "storefront.fill") }.tag(4)
            }
            NestView(profile: profile, pet: character.pet, petName: profile.profile.petName, room: $nestRoom,
                     onBought: { i in chat.say(i.thanks, notify: false, frame: "happy") },
                     onGame: { gameDone($0) })
                .tabItem { Label(T("窝"), systemImage: "sofa.fill") }.tag(1)
            ShopView(profile: profile, character: character, pose: shownPose)
                .tabItem { Label(T("商城"), systemImage: "bag.fill") }.tag(2)
            MeView(profile: profile, live: live, routine: routine, companion: companion, character: $character, shownPose: shownPose, lastLine: chat.islandLine, need: needs.urgent)
                .tabItem { Label(T("我"), systemImage: "person.fill") }.tag(3)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showChat) {
            ChatView(chat: chat, needs: needs, pose: shownPose, character: character, onCare: care, profile: profile, onFeed: feed)
                .navigationTransition(.zoom(sourceID: "island", in: zoom))
        }
        .fullScreenCover(isPresented: Binding(get: { !onboarded || !bond.hatched }, set: { _ in })) {
          if !bond.hatched && !storySeen && !Shot.on {
            // 新玩家：开蛋之前先看 20 秒开场故事（嘟嘟星在变暗）
            StoryIntroView { storySeen = true }
          } else if !bond.hatched {
            // 第一次（老用户也补一次）：先开蛋、选语言路线、起名
            HatchView(bond: bond, profile: profile, pet: character.pet) {
                Analytics.log("hatch", ["route": bond.route.rawValue])
                // 刚出壳：舞台上先窝在蛋壳里，再开心晃一下
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showClip("shell", seconds: 4.0) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { showClip("shell_happy", seconds: 3.6) }
                if onboarded {
                    chat.say(Voice.line("kw.hello", mood: .happy), notify: false)
                }
            }
          } else {
            OnboardingView(profile: profile, pet: character.pet,
                           askNotifications: askNotifications,
                           askHealth: { done in health.start(then: done) },
                           askMotion: { detector.start() },
                           startIsland: { live.start(pose: shownPose, character: character, lastLine: chat.islandLine, need: needs.urgent) },
                           finish: {
                               if !live.isRunning { LiveActivityManager.userTurnedOff = true }   // 开场里选了"以后再说"
                               else if peekQuest.isEmpty { peekQuest = "on" }
                               onboarded = true
                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showFood = true }
                           },
                           startAt: .hello)
          }
        }
        // 灵动岛大岛上点了"喂一口/摸摸"：重新读存档、把熟悉度补上
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("islandCare"))) { _ in islandCareSync() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("quietChanged"))) { _ in needs.scheduleReminders() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("intimacyChanged"))) { _ in intimacy = Intimacy.load() }
        .sheet(isPresented: $pickGame) {
            GamePicker(profile: profile, pet: "purple") { k in
                pickGame = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { homeGame = k }
            }
        }
        .fullScreenCover(item: $homeGame) { k in
            GameShell(kind: k, pet: "purple", accessories: profile.profile.equipped, rewardAvailable: !profile.gameClaimed(k), onFinish: { gameDone($0) })
        }
        .overlay { if let r = rescueShow { RescueCard(r: r) { withAnimation { rescueShow = nil } }.transition(.scale.combined(with: .opacity)) } }
        .alert(T("亲密度：{0}（{1}/100）", intimacy.tier.name, Int(intimacy.value)), isPresented: $showIntimacy) {
            Button(T("好")) {}
        } message: {
            Text((intimacy.bonus > 0 ? T("小店爆率 +{0}%。", Int(intimacy.bonus * 100)) : T("还没有爆率加成。"))
                 + (intimacy.next.map { T("到「{0}」（{1}）爆率 +{2}%。", $0.name, $0.floor, Int($0.bonus * 100)) } ?? "")
                 + "\n\n" + T("它饿了、渴了、脏了、闷了的时候及时管它就涨，一整天没让它见底再加一点；让它饿到底、脏到底，管家会花你的金币代劳，亲密度会掉。"))
        }
        // 岛台点击 → islandme://chat
        .onReceive(NotificationCenter.default.publisher(for: .openShop)) { _ in if shopUnlocked { tab = 4 } }
        .onOpenURL { url in
            if url.host == "chat" { showChat = true }
            if url.host == "shop", shopUnlocked { tab = 4 }
        }
        // 点通知横幅 → 聊天页
        .onReceive(NotificationCenter.default.publisher(for: .openChat)) { _ in showChat = true }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in rescueIfBottom(); health.refresh(); ShopPing.scheduleNightDoor(); live.setShopScene(MKState.islandScene()); shopHint = MKState.homeHint() }
        .onReceive(NotificationCenter.default.publisher(for: .petSpoke)) { n in
            if let line = n.object as? String { chat.say(line, notify: false) }
        }
    }

    private var withLifecycle: some View {
        core
        .onAppear {
            detector.routinePose = { [weak routine] in routine?.current?.pose }
            detector.workoutPose = { [weak health] in health?.workoutPose }
            detector.lifePose = { [weak profile] in
                guard PetLife.enabled, let p = profile?.profile else { return nil }
                return PetLife.current(wakeHour: p.wakeHour, sleepHour: p.sleepHour)?.activity.pose
            }
            PetLife.schedule(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour, enabled: PetLife.enabled)
            lifeTick()
            detector.appActive = true
            detector.startSignals()                  // 耳机/音乐/电话/充电/横屏：不用权限
            if onboarded { detector.start() }
            startFlourish()
            gaze.start()
            companion.roll(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour)
            dailyRewards()
            welcomeBack()
            checkLetters()
            health.onWorkout = { w in
                profile.rewardWorkout()
                companion.record(.workout)
                needs.cheer(0.15)
                chat.say(HealthStore.praise(w), notify: true, frame: "happy")
                detector.reevaluate()
            }
            if onboarded && !Shot.on { health.start() }
            HealthStore.scheduleNags(routine: routine.routine)
            ChatStore.petName = profile.profile.petName; Voice.petName = profile.profile.petName
            PetNeeds.sleepStart = profile.profile.sleepHour; PetNeeds.sleepEnd = profile.profile.wakeHour
            routine.scheduleNotifications()
            AgeCare.schedule()
            Greeter.schedule(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour, routine: routine.routine)
            if chat.islandLine.isEmpty { chat.mutter(for: shownPose) }
            character.accessories = profile.profile.equipped
            if onboarded {
                live.ensureRunning(pose: shownPose, character: character, lastLine: chat.islandLine, need: needs.urgent)
                askNotifications {}
            }
        }
        // 作息到点：通知由系统按时发，前台时经 petSpoke 进聊天；这里不再重复说
        .onChange(of: routine.routine) { _, r in
            Greeter.schedule(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour, routine: r)
            HealthStore.scheduleNags(routine: r)
        }
        .onChange(of: profile.profile) { old, p in
            ChatStore.petName = p.petName; Voice.petName = p.petName
            if old.wakeHour != p.wakeHour || old.sleepHour != p.sleepHour {
                PetLife.schedule(wakeHour: p.wakeHour, sleepHour: p.sleepHour, enabled: PetLife.enabled)
                PetNeeds.sleepStart = p.sleepHour; PetNeeds.sleepEnd = p.wakeHour
                needs.scheduleReminders()
                Greeter.schedule(wakeHour: p.wakeHour, sleepHour: p.sleepHour, routine: routine.routine)
            }
            if character.accessories ?? [] != p.equipped { character.accessories = p.equipped }
        }
    }

    private var withEvents: some View {
        withLifecycle
        // 需求出现 / 消失 → 它说一句 + 岛台切换（需求优先于动作）
        .onChange(of: needs.urgent) { old, new in
            if let n = new, n != old { chat.say(Voice.line("need." + n.rawValue), notify: false) }
            if let n = new, n != old,
               live.alert(pose: shownPose, character: character, line: chat.islandLine, frame: n.frame, need: n, title: "\(profile.profile.petName)\(n.label)") {
                Analytics.log("island_alert", ["kind": "need", "need": n.rawValue])
            } else {
                live.update(pose: shownPose, character: character, lastLine: chat.islandLine, need: new)
            }
        }
        // 里程碑：聊天里说一句；不在前台时弹大岛
        .onChange(of: bond.justUnlocked) { _, m in
            guard let m else { return }
            if m != .hatch { showClip("happy", seconds: 3.6) }
            live.alert(pose: shownPose, character: character, line: m.title, frame: "happy", need: needs.urgent, title: "✨ " + m.title)
        }
        .onChange(of: character) { _, c in
            c.save()
            live.update(pose: shownPose, character: c, lastLine: chat.islandLine, need: needs.urgent)
        }
        .onChange(of: shownPose) { _, p in
            poseSince = Date()
            chat.mutter(for: p)
            publishWidget()                      // 动作变化只换岛台那句话，不弹消息
            live.update(pose: p, character: character, lastLine: chat.islandLine, need: needs.urgent)
        }
        .onChange(of: scenePhase) { _, p in
            detector.appActive = (p == .active)
            if p == .background { leftAt = Date() }
            if p == .active, peekQuest == "on", let t = leftAt, Date().timeIntervalSince(t) > 1.5, live.isRunning {
                peekQuest = "done"
                profile.earn(30, T("在灵动岛上看到它"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    react(frame: "party", line: T("看到我了吧！我一直住在那儿。锁屏、玩别的 App，我都在上面陪你。"), seconds: 3.5)
                }
            }
            if p == .active {
                companion.roll(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour)
                startFlourish(); dailyRewards(); welcomeBack(); lifeTick(); islandCareSync(); checkLetters(); gaze.start()
                bond.checkAnniversaries(); bond.add(.open); Analytics.dailyOpen()
                PetLife.schedule(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour, enabled: PetLife.enabled)
                Greeter.schedule(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour, routine: routine.routine)
                if onboarded { live.ensureRunning(pose: shownPose, character: character, lastLine: chat.islandLine, need: needs.urgent) }
            } else {
                flourishTimer?.invalidate(); flourishTimer = nil
                gaze.stop()
                if p == .background { profile.markAway(); IslandRefresh.schedule() }
            }
        }
    }

    private var withSignals: some View {
        withEvents
        .onChange(of: health.stepsToday) { _, n in profile.checkSteps(n); companion.record(.walk, amount: n, absolute: true) }
        .onReceive(NotificationCenter.default.publisher(for: .userChatted)) { _ in profile.claim(.chat); companion.record(.chat) }
        .onChange(of: profile.lastReward) { _, r in
            guard let r else { return }
            withAnimation(.spring) { toast = r }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { if toast == r { withAnimation { toast = nil } } }
        }
        // 小紫自己的安排：每 30 秒看一眼，开始/结束各说一句，早上报备一次
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in lifeTick() }
        .onReceive(NotificationCenter.default.publisher(for: .userTyping)) { n in
            detector.typing = (n.object as? Bool) ?? false
        }
        // 你截图 → 它比个耶
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            react(frame: "party", line: [T("咔嚓！我上镜吗？"), T("拍我？比个耶。"), T("截图发朋友圈记得带上我。")].randomElement()!, seconds: 2.5)
        }
        // 手机快没电 → 它也犯困（每次掉到 20% 以下说一次）
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            let lv = UIDevice.current.batteryLevel, st = UIDevice.current.batteryState
            if lv >= 0 && lv < 0.2 && st == .unplugged {
                if !lowBatterySaid { lowBatterySaid = true; react(frame: "yawn", line: [T("电量不多了，我也好困……"), T("快没电了，找个充电器？")].randomElement()!, seconds: 3) }
            } else if lv >= 0.3 { lowBatterySaid = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceShaken)) { _ in
            react(frame: "surprised", line: [T("晃晕了……"), T("别摇！"), T("地震了？")].randomElement()!, seconds: 2)
        }
        .onChange(of: chat.islandLine) { _, _ in
            live.update(pose: shownPose, character: character, lastLine: chat.islandLine, need: needs.urgent)
            publishWidget()
        }
    }

    private var withCompanion: some View {
        withSignals
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("calledName"))) { _ in companion.record(.callName) }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("gazeChanged"))) { _ in
            GazeWatcher.enabled ? gaze.start() : gaze.stop()
        }
        // 对视：你看它 → 它停下来看你、眨眼；盯久了 → 害羞；移开视线 → 东张西望
        .onChange(of: gaze.looking) { _, on in
            guard !showChat, careFlash == nil, stageClip == nil else { return }
            if on {
                guard Date().timeIntervalSince(lastGazeReact) > 40 else { return }
                lastGazeReact = Date()
                react(frame: "blink", line: nil, seconds: 0.5)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    guard gaze.looking else { return }
                    react(frame: "happy", line: [T("你在看我？"), T("嗯？看我干嘛。"), T("我也在看你。")].randomElement()!, seconds: 2.0)
                    bond.add(.pet)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
                    if let s = gaze.lookSince, Date().timeIntervalSince(s) > 6 {
                        react(frame: "shy", line: [T("一直盯着我……不好意思了。"), T("别看了，脸都红了。")].randomElement()!, seconds: 2.5)
                    }
                }
            } else if Date().timeIntervalSince(lastGazeReact) < 15 {
                react(frame: "think", line: nil, seconds: 1.2)
            }
        }
        // 今天陪你：做完一件 +3 币说一句；三件都做完嘟嘟星寄包裹（+5 币 + 一样吃的）
        .onChange(of: companion.justDone) { _, i in
            guard let i else { return }
            companion.justDone = nil
            profile.earn(3, T("陪你 · ") + i.title)
            chat.say(Voice.line("companion.done"), notify: false, frame: "happy")
            react(frame: "happy", line: nil, seconds: 1.8)
        }
        .onChange(of: companion.bonusReady) { _, ready in
            guard ready else { return }
            let f = [Food.carrot, Food.rice, Food.goji, Food.coffee].randomElement()!
            profile.wallet.bag[f.id, default: 0] += 1
            companion.takeBonus()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                profile.earn(5, T("嘟嘟星的包裹"))
                chat.say(Voice.line("companion.bonus", ["food": f.emoji + f.name]), notify: false, frame: "party")
                showClip("happy", seconds: 3.6)
            }
        }
    }

    private var home: some View {
        ScrollView {
                VStack(spacing: 0) {
                    // 顶部：名字 + 岛台开关
                    HStack {
                        Text(profile.profile.petName).font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.text)
                        Spacer()
                        Toggle(T("岛台"), isOn: Binding(
                            get: { live.isRunning },
                            set: { on in on ? live.start(pose: shownPose, character: character, lastLine: chat.islandLine, need: needs.urgent) : live.end(byUser: true) }))
                            .toggleStyle(.switch).tint(Theme.accent)
                            .font(.system(size: 13)).foregroundStyle(Theme.text2)
                            .fixedSize()
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)

                    // 舞台：和岛台同款的黑色圆角
                    Group {
                        ZStack(alignment: .top) {
                            Color.black
                            StageSky()                       // 它住的小胶囊：远处几颗很淡的星（嘟嘟星方向）
                            VStack {
                                Spacer()
                                VideoPetView(pet: character.pet, pose: careFlash ?? shownPose, frame: careFlash != nil ? "" : (reaction ?? needs.urgent?.frame ?? ""), accessories: (stageClip ?? "").hasPrefix("shell") ? [] : profile.profile.equipped, size: 210, clip: stageClip ?? lifeClip)
                                    .offset(x: gaze.looking ? -gaze.faceX * 6 : 0)          // 对视：你脸往哪偏，它往哪转一点
                                    .animation(.easeOut(duration: 0.4), value: gaze.faceX)
                                    .frame(height: 230).padding(.bottom, 86)
                            }
                            if needs.urgent == nil, let r = bond.request, !r.expired {   // 它的小愿望（需求优先）
                                WishChip(request: r) { fulfill(r) }
                                    .padding(.top, 16)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                            if let n = needs.urgent {     // 只在有需求时提示，不显示"正在站立"这类动作名
                                HStack(spacing: 6) {
                                    Image(systemName: n.symbol).font(.system(size: 11, weight: .semibold))
                                    Text(n.label)
                                }
                                .font(.system(size: 12)).foregroundStyle(Theme.alert)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Theme.surface, in: Capsule())
                                .padding(.top, 16)
                            }
                            Text(T("戳它玩 · 长按聊天")).font(.system(size: 11)).foregroundStyle(Theme.text3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(.top, 20).padding(.trailing, 20)
                            // 照顾按钮就在它脚下：喂食 / 喝水 / 清理 / 陪玩，外圈是还剩多少
                            HStack(spacing: 12) {
                                ForEach(Need.allCases, id: \.self) { n in
                                    CareBubble(need: n, level: needs.level(n)) {
                                        if n == .hungry { showFood = true } else if n == .happy { pickGame = true } else { care(n) }
                                    }
                                }
                                // 亲密度和照顾放一起：伺候得好就涨，涨了小店爆率高
                                IntimacyBubble(im: intimacy) { showIntimacy = true }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 14)
                            if bond.hatched, Wishes.blanketTime(sleepHour: profile.profile.sleepHour), !bond.didToday("blanket") {
                                Button { coverBlanket() } label: {
                                    Label([T("给它盖毯子"), T("它把毯子抱来了"), T("它躺好等你了")][bond.habitLevel("blanket")], systemImage: "moon.zzz.fill")
                                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Color(hex: "#E9DEFF"))
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Theme.surface, in: Capsule())
                                }
                                .buttonStyle(.press)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.top, 54).padding(.leading, 16)
                            }
                        }
                        .frame(height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 36))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 36))
                    .onTapGesture { poke() }
                    .onLongPressGesture(minimumDuration: 0.4) { showChat = true }
                    .matchedTransitionSource(id: "island", in: zoom)
                    .padding(.horizontal, 20)

                    // 它刚说的话
                    if !chat.islandLine.isEmpty {
                        Text("“\(chat.islandLine)”")
                            .font(.system(size: 15)).lineSpacing(4).foregroundStyle(Color(hex: "#E7E3F2"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 20).padding(.top, 14)
                    }


                    // 新手小任务：回桌面看一眼灵动岛
                    if peekQuest == "on" && live.isRunning {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.topthird.inset.filled").font(.system(size: 26)).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(T("试一下：回到桌面，看看屏幕最顶上")).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                                Text(T("从屏幕底部往上划回到桌面，或者锁屏。它就在那个黑色的「岛」上。看完回来领 30 币。")).font(.system(size: 12)).foregroundStyle(Theme.text2)
                            }
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                        .padding(.horizontal, 20).padding(.top, 14)
                    }

                    // 嘟嘟星来信（没拆的）
                    if let l = letters.firstUnread {
                        LetterBanner { letters.open(l); openLetter = l }
                            .padding(.horizontal, 20).padding(.top, 18)
                    }

                    // 和它聊聊（原来的聊天页挪到这儿）
                    HomeChatCard(chat: chat, needs: needs, pose: shownPose, character: character) { showChat = true }
                        .padding(.horizontal, 20).padding(.top, 18)

                    // 嘟嘟小店：喂完第一口（新手礼包的饭团）以后才出现——「冰箱空了……」
                    if !bond.s.firstFood.isEmpty || UserDefaults.standard.bool(forKey: "merge.opened") {
                    Button { tab = 4 } label: {
                        HStack(spacing: 12) {
                            Image("mk_rice4").resizable().scaledToFit().frame(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(T("嘟嘟小店")).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                                Text(shopHint ?? (UserDefaults.standard.bool(forKey: "merge.opened") ? T("做好吃的带回家喂它，接外卖给它赚零花钱") : T("冰箱空了……"))).font(.system(size: 12)).foregroundStyle(shopHint == nil ? Theme.text3 : Theme.coin).lineLimit(2)
                            }
                            Spacer()
                            Text(UserDefaults.standard.bool(forKey: "merge.opened") ? T("去开店 ›") : T("去看看 ›")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.coin)
                        }
                        .padding(14)
                        .background(LinearGradient(colors: [Color(hex: "#3A2A1E"), Theme.surface], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.press)
                    .padding(.horizontal, 20).padding(.top, 14)
                    }

                    // 「今天陪你」卡片：2026-10-19 发财哥定首页不再放（数据和逻辑先留着）

                    // 底部入口：陪它玩、它的窝
                    HStack(spacing: 10) {
                        Button { nestRoom = .bedroom; tab = 1 } label: {
                            HStack {
                                Text(T("它的窝"))
                                Spacer()
                                Text("›").foregroundStyle(Theme.text3)
                            }
                        }
                        Button { nestRoom = .play; tab = 1 } label: {
                            HStack {
                                Text(T("陪它玩"))
                                Spacer()
                                let left = NestItem.allCases.filter { $0.has(profile.profile.owned) && $0.game != nil && $0.game != .gacha && !profile.gameClaimed($0.game!) }.count
                                Text(left > 0 ? T("{0} 个能赚币 ›", left) : T("游戏 ›")).foregroundStyle(Theme.coin)
                            }
                        }
                    }
                    .font(.system(size: 14)).foregroundStyle(Theme.text)
                    .buttonStyle(EntryButtonStyle())
                    .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 30)
                }
        }
        .background(Theme.ground.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let t = toast { RewardToast(reward: t).padding(.top, 6).transition(.move(edge: .top).combined(with: .opacity)) }
        }
        .overlay {
            if let m = bond.justUnlocked, m != .hatch {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { withAnimation { bond.justUnlocked = nil } }
                    MilestoneCard(milestone: m, petName: profile.profile.petName, days: bond.daysTogether) {
                        withAnimation { bond.justUnlocked = nil }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .sheet(item: $openLetter) { l in
            LetterView(letter: l, route: bond.route, stage: bond.stage, petName: profile.profile.petName,
                       gifted: letters.gifted.contains(l.id), claim: { claimLetter(l) })
        }
        .sheet(isPresented: $showFood) { FoodPicker(profile: profile) { feed($0) } }
    }

    private var kitchenView: some View {
        MergeKitchenView(pet: character.pet, profile: profile, steps: health.stepsToday, embedded: true,
                         onServe: { _, foodID in shopMeal(foodID) },
                         onTakeHome: { id in takeHome(id) },
                         onLeave: { ping in shopLeft(ping) },
                         onChapter: { k in shopChapter(k) },
                         onDoor: { d in shopDoor(d) })
    }

    /// 店里交的小紫的饭 = 真的喂了它一顿（不花背包里的东西）
    private func shopMeal(_ foodID: String) {
        guard let f = Food.all.first(where: { $0.id == foodID }) else { needs.apply([.hungry: 0.3]); return }
        needs.apply(f.effects)
        _ = bond.fed(f)
        _ = bond.add(f.main == .thirsty ? .drink : .feed)
        if f.main != .thirsty { companion.record(.feed) }
    }
    private var shopUnlocked: Bool { !bond.s.firstFood.isEmpty || UserDefaults.standard.bool(forKey: "merge.opened") }
    /// 店里做好的菜带回家：进背包，首页喂它
    private func takeHome(_ id: String) {
        profile.addToBag(id)
        if let f = Food.by(id) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                chat.say(T("……{0}？给我的？回家再吃。", f.name), notify: false, frame: "happy")
            }
        }
    }
    private func shopLeft(_ ping: MKPing?) {
        shopHint = MKState.homeHint()
        ShopPing.schedule(ping?.forPush)
        let wp = ping?.forPush
        WidgetBridge.publishShop(icon: wp?.icon, line: wp?.line, at: wp?.at)
        live.setShop(at: ping?.at, icon: ping?.icon, line: ping?.line, scene: MKState.islandScene())
    }
    /// 每装修完一章：门那边寄来一封信；最后一章，它说起那道门
    private func shopChapter(_ k: Int) {
        if letters.deliverShop(chapter: k) != nil { Analytics.log("shop_chapter", ["k": "\(k)"]) }
        if k == 6 { ShopPing.scheduleNightDoor() }
        if k == 12 { chat.say(T("门开了。店开在哪儿都一样……我哪儿也不去。"), notify: false, frame: "happy") }
    }

    /// 门单做完：嘟嘟星亮了一个区，灵动岛那一句跟着换
    private func shopDoor(_ d: Int) {
        guard d >= 1, d <= MKStory.doors.count else { return }
        chat.say("🌙 " + MKStory.doors[d - 1].name + T("亮了。") + MKStory.doorLit[d - 1], notify: false, frame: "happy")
        Analytics.log("shop_door", ["d": "\(d)"])
    }

    /// 它自己的安排进行中：舞台播专门片段（晒太阳、看星星、吃零食、喝奶茶、抱着蛋壳午睡）
    private var lifeClip: String? {
        guard manualPose == nil, careFlash == nil, reaction == nil, needs.urgent == nil, PetLife.enabled,
              let it = PetLife.current(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour),
              shownPose == it.activity.pose else { return nil }
        return it.activity.clip
    }

    /// 桌面小组件：把它现在的样子和那句话同步过去
    private func publishWidget() {
        let p = shownPose
        let frame = [.stand, .study, .ball, .paint].contains(p) ? "idle" : p.rawValue
        let old = WidgetBridge.read()
        WidgetBridge.publish(WidgetState(frame: frame, line: chat.islandLine, need: needs.urgent?.rawValue ?? "",
                                         name: profile.profile.petName, at: Date(),
                                         shopIcon: old?.shopIcon, shopLine: old?.shopLine, shopAt: old?.shopAt))
    }

    /// 灵动岛上点过的"喂一口/摸摸"：重新读存档，熟悉度补记
    private func islandCareSync() {
        needs.reload()
        profile.reloadWallet()
        let d = UserDefaults.standard
        let q = d.stringArray(forKey: "island.pendingBond") ?? []
        guard !q.isEmpty else { return }
        d.removeObject(forKey: "island.pendingBond")
        for a in q {
            if let act = BondAction(rawValue: a) { _ = bond.add(act) }
            if a == "pet" { companion.record(.islandPet) }
            Analytics.log("island_care", ["action": a])
        }
    }

    /// 戳它：换个表情、嘀咕一句（不进聊天记录），连戳会不耐烦
    private func poke() {
        if stageClip != nil, Date() >= eatingUntil { clipToken = ""; withAnimation { stageClip = nil } }   // 戳一下就从片段里回来（吃东西时不打断）
        pokeCount += 1
        if pokeCount < 5 { needs.cheer(0.02) }
        // 3 秒内连着摸 3 下 = 摸肚子：先憋着，然后笑出声（设定第 10 节动作 5）
        let now = Date()
        pokeTimes = pokeTimes.filter { now.timeIntervalSince($0) < 3 } + [now]
        if pokeTimes.count >= 3 && pokeCount < 5 {
            pokeTimes = []
            bellyRub()
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { pokeCount = max(0, pokeCount - 1) }
            return
        }
        let pick: (String, String)
        if pokeCount >= 5 { pick = ("angry", Voice.line("poke.annoyed", mood: .sulky)) }
        else {
            let f = ["happy", "laugh", "surprised", "shy", "think"].randomElement()!
            pick = (f, Voice.line("poke"))
            bond.add(.pet)
        }
        react(frame: pick.0, line: pick.1, seconds: 1.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { pokeCount = max(0, pokeCount - 1) }
    }

    private func react(frame: String, line: String?, seconds: Double) {
        withAnimation { reaction = frame }
        if let line { chat.mutter(line) }
        live.update(pose: shownPose, character: character, lastLine: chat.islandLine, need: needs.urgent)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { withAnimation { reaction = nil } }
    }

    /// 摸肚子：先憋着（害羞），然后笑出声；第一次解锁里程碑；满足"想被摸肚子"
    private func bellyRub() {
        bond.add(.pet)
        chat.mutter(Voice.line("belly"))
        if Bundle.main.url(forResource: "purple_x_belly_rub", withExtension: "mp4") != nil {
            showClip("x_belly_rub", seconds: 4.4)          // 先憋着不笑，然后笑出声、小手护肚子
        } else {
            react(frame: "shy", line: nil, seconds: 0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { react(frame: "laugh", line: nil, seconds: 1.8) }
        }
        bond.unlock(.bellyLaugh)
        if bond.request?.kind == .belly { wishMet() }
    }

    /// 睡前盖毯子：+3 熟悉度、记习惯（7 天 3 次它会自己抱毯子来，累计 10 次它自己躺好等你）
    private func coverBlanket() {
        bond.add(.blanket)
        bond.habit("blanket")
        Analytics.log("blanket", ["lv": "\(bond.habitLevel("blanket"))"])
        if bond.request?.kind == .blanket { bond.requestMet() }
        chat.say(Voice.line("blanket"), notify: false, frame: "sleep")
        play(.sleep)
        showClip("x_hug_shell", seconds: 4.4)           // 盖好了：抱着蛋壳睡
    }

    /// 点小愿望气泡：吃的喝的背包里有就直接喂，没有打开背包；摸肚子；盖毯子
    private func fulfill(_ r: PetRequest) {
        switch r.kind {
        case .food, .drink:
            if let f = Food.by(r.item), f.dish, (profile.wallet.bag[f.id] ?? 0) == 0 {
                chat.say(T("{0}……店里能做。你去做，我在这儿等。", f.name), notify: false, frame: "hungry")
                if shopUnlocked { tab = 4 }
            } else if let f = Food.by(r.item), (f.price == 0 && !f.dish) || (profile.wallet.bag[f.id] ?? 0) > 0 { feed(f) } else { showFood = true }
        case .belly: bellyRub()
        case .blanket: coverBlanket()
        }
    }

    private func wishMet() {
        Intimacy.update { $0.wishMet() }
        bond.requestMet()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            chat.say(Voice.line("req.met", mood: .excited), notify: false, frame: "happy")
        }
    }

    /// 到日子的信寄到：它先发现（"门那边好像寄来了东西"），首页出现信封；顺便约好下一封的提醒
    private func checkLetters() {
        guard bond.hatched else { return }
        // 好几天没来：攒下的信一次寄到，只说一句（自测：每次打开都寄一封、同一句话在聊天里重复好几遍）
        var got = 0
        while letters.deliver(days: bond.daysTogether) != nil, got < 20 { got += 1 }
        let lastSaid = chat.messages.last?.text ?? ""
        if got > 0, !lastSaid.contains(T("信")) && !lastSaid.contains("letter") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                let line = Voice.route == .dudu || Voice.stage == 0 ? T("嘟？嘟嘟！（它指着门那边，有个信封掉了下来）")
                         : (Voice.route == .en ? "Something came through the door… a letter!" : T("门那边好像掉下来一封信……一起拆？"))
                chat.say(line, notify: false, frame: "surprised")
                react(frame: "surprised", line: nil, seconds: 2.0)
            }
        }
        letters.scheduleNext(hatchDate: bond.hatchDate)
    }

    private func claimLetter(_ l: DuduLetter) {
        guard letters.claim(l) else { return }
        if let id = l.food { profile.wallet.bag[id, default: 0] += 1 }
        if l.coins > 0 { profile.earn(l.coins, T("嘟嘟星来信")) }
        else if let f = l.food.flatMap(Food.by) { chat.mutter(T("信里夹着{0}{1}，放进背包了。", f.emoji, f.name)) }
        react(frame: "happy", line: nil, seconds: 1.8)
    }

    /// 有攒着的梦就讲（起床后、或离开很久回来时）
    private func tellDream() {
        guard let d = bond.takeDream() else { return }
        chat.say(Voice.line("dream"), notify: false, frame: "think")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            chat.say(Wishes.dreamLine(d), notify: false, frame: "think")
        }
    }

    /// 舞台播一段专门片段（不改岛台），到时间回到当前动作；后来的会顶掉先来的
    private func showClip(_ name: String, seconds: Double, force: Bool = false) {
        if !force && Date() < eatingUntil { return }      // 正在吃喝：让它吃完
        let token = UUID().uuidString
        clipToken = token
        withAnimation { stageClip = name }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if clipToken == token { withAnimation { stageClip = nil } }
        }
    }

    /// 你在看它的时候它自己会搞点小动作：每 20–40 秒一次，一半概率换表情说一句，否则换个待机视频
    private func startFlourish() {
        flourishTimer?.invalidate()
        flourishTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 20...40), repeats: false) { _ in
            Task { @MainActor in
                if careFlash == nil, reaction == nil, stageClip == nil, needs.urgent == nil, !showChat,
                   let w = Wishes.maybeAsk(bond: bond, bag: profile.wallet.bag, sleepHour: profile.profile.sleepHour, busy: false) {
                    bond.setRequest(w)
                    chat.say(Wishes.line(w), notify: false, frame: Wishes.frame(w))
                    react(frame: Wishes.frame(w), line: nil, seconds: 2.4)
                } else if careFlash == nil, reaction == nil, stageClip == nil, needs.urgent == nil, !showChat {
                    let r = Int.random(in: 0..<10)
                    if r < 4 {
                        let pick = [("think", T("在想晚饭吃什么。")), ("happy", T("你今天看起来不错。")), ("shy", T("一直盯着我干嘛。")),
                                    ("surprised", T("刚才是不是有声音？")), ("happy", T("要不要喂我一口。")), ("think", T("你忙吧，我在。"))].randomElement()!
                        react(frame: pick.0, line: pick.1, seconds: 2.2)
                    } else if r < 6, shownPose == .stand {
                        // 原地来一段别的动作（起床伸懒腰 / 走两步），4.5 秒后回来
                        withAnimation { careFlash = [.wake, .walk].randomElement() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { withAnimation { careFlash = nil } }
                    }
                }
                startFlourish()
            }
        }
    }

    /// 照顾一次：满足需求、它回一句、岛台立刻更新
    private func care(_ n: Need) {
        if n == .thirsty { feed(.water); return }
        let needed = needs.level(n) < 0.9
        if needs.level(n) < Need.threshold { Intimacy.update { $0.cared() } }
        needs.care(n)
        if needed {
            chat.say(Voice.line("cared." + n.rawValue), notify: false, frame: NeedsStore.caredFrame[n])
            if n == .happy { bond.add(.pet) }
        }
        else { chat.mutter(Voice.line("full." + n.rawValue)) }   // 已经满了：只嘀咕，不刷聊天
        // 陪玩：换个大笑表情 + 走两步；吃/喝/洗：舞台播对应视频（4.5 秒），岛台同步，之后回到当前动作
        if n == .happy { react(frame: "laugh", line: nil, seconds: 2.0); return }
        play(n == .hungry ? .eat : .wash)
    }

    /// 舞台播一段动作视频 4.5 秒，岛台同步，然后回到当前动作
    private func play(_ flash: Pose) {
        if Date() < eatingUntil { return }
        clipToken = ""
        withAnimation { stageClip = nil; careFlash = flash }
        live.update(pose: flash, character: character, lastLine: chat.islandLine, need: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation { careFlash = nil }
            live.update(pose: shownPose, character: character, lastLine: chat.islandLine, need: needs.urgent)
        }
    }

    /// 播这样吃的专属动画，整段播完（按视频实际时长）；没有专属片段时退回通用吃/喝动作。返回要占用的秒数
    @discardableResult
    private func eatFood(_ f: Food) -> Double {
        let clipName = f.clip ?? f.id
        guard let url = Bundle.main.url(forResource: "\(character.pet)_eat_\(clipName)", withExtension: "mp4") else {
            play(f.pose); return 4.5
        }
        let secs = max(2, CMTimeGetSeconds(AVURLAsset(url: url).duration) - 0.12)
        eatingUntil = Date().addingTimeInterval(secs)
        showClip("eat_\(clipName)", seconds: secs, force: true)
        live.update(pose: f.pose, character: character, lastLine: chat.islandLine, need: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + secs) {
            live.update(pose: shownPose, character: character, lastLine: chat.islandLine, need: needs.urgent)
        }
        return secs
    }

    /// 喂一样东西：吃不下就不扣；扣一个 → 按食物效果加减 → 说一句 → 播对应视频
    private func feed(_ f: Food) {
        if Date() < eatingUntil { chat.mutter(Voice.route == .en ? "Still chewing…" : T("嘴里还没咽下去呢…")); return }
        if needs.level(f.main) > 0.95 {
            chat.mutter(Voice.line("full." + f.main.rawValue))
            react(frame: "think", line: nil, seconds: 1.5); return
        }
        guard profile.consume(f) else { showFood = true; return }
        if needs.level(f.main) < Need.threshold { Intimacy.update { $0.cared(favorite: f.favorite) } }
        let firstBite = bond.s.firstFood.isEmpty && f.main != .thirsty
        var eff = f.effects
        if f.id == "popcorn" && shownPose == .movie { eff[.happy] = (eff[.happy] ?? 0) * 2 }
        if f.favorite { eff[.happy] = (eff[.happy] ?? 0) + 0.05 }
        needs.apply(eff)
        let firstFav = bond.fed(f)
        let wished = bond.request.map { ($0.kind == .food || $0.kind == .drink) && $0.item == f.id } ?? false
        bond.add(f.main == .thirsty ? .drink : .feed)
        if f.main != .thirsty { companion.record(.feed) }
        Analytics.log("feed", ["food": f.id])
        var line = firstFav ? Voice.line("fed.favorite", mood: .excited, ["food": f.name])
                            : Voice.line("fed." + f.id, ["food": f.name])
        if f.id == "popcorn" && shownPose == .movie && Voice.route.speaks && Voice.stage >= 2 { line = Voice.route == .en ? "Movie + popcorn. Perfect." : T("边看边吃，完美。") }
        if profile.profile.coins == 0 && !(profile.wallet.bag.values.contains { $0 > 0 }) { line = Voice.line("fed.lastbite") }
        // 熟悉度刚过 80：喂完这一口说出第一句话
        if bond.consumeFirstWord() { line = Voice.line("firstword") }
        chat.say(line, notify: false, frame: f.favorite ? "happy" : NeedsStore.caredFrame[f.main])
        // 每样吃的都有自己的一段（胡萝卜就啃胡萝卜、水就抱杯喝水），从头播到吃完，期间不被打断
        let dur = eatFood(f)
        // 吃完以后的小尾巴：吃到最爱（眯眼停一下再笑）、最后一口（舍不得）、困了还想吃（点头又醒）
        let h = Calendar.current.component(.hour, from: Date())
        let tail: String? = (firstFav || (bond.favoriteFood?.id == f.id)) ? "x_fav_eat"
            : (profile.profile.coins == 0 && !(profile.wallet.bag.values.contains { $0 > 0 })) ? "x_last_bite"
            : (f.main != .thirsty && (Wishes.blanketTime(sleepHour: profile.profile.sleepHour) || h < 6)) ? "x_sleepy_eat" : nil
        if let tail { DispatchQueue.main.asyncAfter(deadline: .now() + dur) { showClip(tail, seconds: 4.4) } }
        // 第一口（新手礼包的饭团）：吃完盯着空盘子——主页这时出现「嘟嘟小店 · 冰箱空了……」
        if firstBite, MKState.load().introSeen != true {
            DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.8) { chat.say(T("……还想吃。冰箱好像空了。"), notify: false, frame: "hungry") }
        }
        if wished { DispatchQueue.main.asyncAfter(deadline: .now() + dur) { wishMet() } }
        // 很熟以后（300+），喂它最爱的，有时它会舍不得地分你一点（动作 8）
        else if !firstFav, bond.familiarity >= 300, f.id == bond.favoriteFoodSecret, Double.random(in: 0..<1) < 0.25 {
            DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.3) {
                chat.say(Voice.line("share", mood: .shy), notify: false, frame: "shy")
                showClip("x_share_snack", seconds: 4.0)     // 舍不得地推一块给你
                bond.unlock(.shareSnack)
            }
        }
    }

    /// 小紫自己的生活进聊天：早上报备、每件事开始/结束各一句（每句只说一次，App 没开时补上）
    /// 饿到底 / 渴到底 / 脏到底 / 闷到底：管家自动用你的金币点最好的（豪华大餐、泡泡浴……），亲密度掉。
    /// 没钱请管家：它就一直饿着，亲密度掉得更多（一天一项只扣一次）
    private func rescueIfBottom() {
        guard bond.hatched, onboarded, !Shot.on, !MKDemo.on else { return }
        // 这个功能刚上线那一次：之前见底的不算（不然一更新就被扣好几百币），直接回到告急线上一点
        let d = UserDefaults.standard
        if !d.bool(forKey: "rescue.on") {
            d.set(true, forKey: "rescue.on")
            var eff: [Need: Double] = [:]
            for n in Need.allCases where needs.level(n) <= 0.001 { eff[n] = Need.threshold + 0.05 }
            if !eff.isEmpty { needs.apply(eff) }
            return
        }
        Intimacy.update { $0.rollDay() }
        for n in Need.allCases where needs.level(n) <= 0.001 {
            let r = Rescue.of(n)
            if profile.spend(r.price, T("管家代劳 · {0}{1}", r.emoji, r.name)) {
                var eff: [Need: Double] = [n: 1]
                if n != .happy { eff[.happy] = 0.1 }
                needs.apply(eff)
                Intimacy.update { $0.hitBottom() }
                chat.say(r.line, notify: false, frame: n == .happy ? "happy" : NeedsStore.caredFrame[n])
                withAnimation(.spring(response: 0.4)) { rescueShow = r }
                Analytics.log("rescue", ["need": n.rawValue])
            } else {
                var told = false
                Intimacy.update { told = $0.neglected(n.rawValue) }
                let w: [Need: String] = [.hungry: T("饿得不行了"), .thirsty: T("渴得不行了"), .dirty: T("脏得不行了"), .happy: T("闷得不行了")]
                if told { chat.say((w[n] ?? "") + T("……管家说你的金币不够，请不动。"), notify: false, frame: n.frame) }
            }
        }
    }

    private func lifeTick() {
        rescueIfBottom()
        guard PetLife.enabled, onboarded else { return }
        let p = profile.profile, now = Date()
        let items = PetLife.today(wakeHour: p.wakeHour, sleepHour: p.sleepHour)
        let d = UserDefaults.standard
        var said = Set(d.stringArray(forKey: "life.said") ?? [])
        let today = Wallet.day()
        said = said.filter { $0.hasPrefix(today) }
        func once(_ key: String, _ body: () -> Void) {
            let k = "\(today)|\(key)"
            guard !said.contains(k) else { return }
            said.insert(k); body()
        }
        if let am = Calendar.current.date(bySettingHour: p.wakeHour, minute: 30, second: 0, of: now), now >= am,
           items.contains(where: { $0.end > now }) {
            once("am") { chat.say(PetLife.announcement(items.filter { $0.end > now }), notify: false, frame: "happy") }
        }
        for it in items {
            if now >= it.start && now < it.end {
                once("start." + it.id) { chat.say(it.activity.startLines.randomElement()!, notify: false) }
            } else if now >= it.end && now.timeIntervalSince(it.end) < 3 * 3600 {
                once("start." + it.id) {}                      // 错过了开始就不补"我去了"
                once("end." + it.id) { chat.say(it.activity.endLines.randomElement()!, notify: false, frame: "happy") }
            }
        }
        // 小愿望 2 小时没满足：它算了，去睡会儿（不罚）
        if let r = bond.request, r.expired {
            bond.setRequest(nil)
            chat.say(Voice.line("req.giveup"), notify: false, frame: "sleep")
            if r.kind == .drink { showClip("x_cup_sleep", seconds: 4.4) }   // 抱着空杯子睡着了
        }
        // 盖毯子成了习惯：到点它自己抱毯子来 / 自己躺好露肚子等你（每天说一次）
        let lv = bond.habitLevel("blanket")
        if lv >= 1, Wishes.blanketTime(sleepHour: p.sleepHour), !bond.didToday("blanket") {
            once("blanket") {
                chat.say(Voice.line(lv >= 2 ? "blanket.2" : "blanket.1"), notify: false, frame: lv >= 2 ? "shy" : "yawn")
                showClip(lv >= 2 ? "x_belly_up" : "x_bring_blanket", seconds: 4.4)
            }
        }
        // 攒着的梦：起床后讲
        if bond.pendingDream != nil, Wishes.dreamTime(wakeHour: p.wakeHour) { tellDream() }
        d.set(Array(said), forKey: "life.said")
        detector.reevaluate()
    }

    /// 通知权限：答应了就排好需求提醒；不管答没答应都回调
    private func askNotifications(_ done: @escaping () -> Void) {
        if Shot.on { done(); return }   // 截图模式不弹权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            Task { @MainActor in
                if ok { needs.scheduleReminders() }
                done()
            }
        }
    }

    /// 小游戏结束：加快乐、按规则给币、说一句
    /// 游戏页一局结束：开心、熟悉度、币、可能掉贴纸；它在聊天里说一句
    private func gameDone(_ r: GameResult) -> Stickers.Sticker? {
        needs.care(.happy)
        let got = profile.rewardGame(r)
        bond.add(.play)
        companion.record(.play)
        Analytics.log("game", ["kind": r.kind.rawValue, "score": "\(r.score)"])
        var line = Voice.line(r.won ? "game.win" : "game.lose")
        if got > 0 && Voice.route.speaks && Voice.stage >= 2 { line += Voice.route == .en ? " +\(got) coins." : T(" 赚了 {0} 币。", got) }
        chat.say(line, notify: false, frame: r.won ? "laugh" : "shy")
        return r.won ? Stickers.drop() : nil
    }

    private func playDone(_ caught: Int) {
        needs.care(.happy)
        let got = profile.rewardPlay(caught: caught)
        bond.add(.play)
        companion.record(.play)
        Analytics.log("play", ["caught": "\(caught)"])
        var line = caught == 0 ? Voice.line("play.zero") : Voice.line("play.some", ["n": "\(caught)"])
        if got > 0 && Voice.route.speaks && Voice.stage >= 2 { line += Voice.route == .en ? " +\(got) coins." : T(" 赚了 {0} 币。", got) }
        chat.say(line, notify: false, frame: caught == 0 ? "shy" : "laugh")
        react(frame: caught == 0 ? "shy" : "laugh", line: nil, seconds: 2.0)
    }

    /// 回到前台：你不在时发生的事（最多 3 条）——离开太久的反应、自己从背包拿东西吃、捡到的金币
    private func welcomeBack() {
        let away = bond.lastActive.map { Date().timeIntervalSince($0) } ?? 0
        bond.markActive()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {      // 让签到提示先飘完
            var lines: [(String, String)] = []
            let day: TimeInterval = 86400
            if away >= 7 * day {
                lines.append((Voice.line("back.7d"), "sleep"))
                showClip("shell_sleep", seconds: 4.4)      // 缩在蛋壳里睡着了，舞台上直接看到
            }
            else if away >= 3 * day { lines.append((Voice.line("back.3d", mood: .sulky), "angry")); showClip("x_sulk", seconds: 4.4) }
            else if away >= day { lines.append((Voice.line("back.1d"), "yawn")); showClip("x_one_eye", seconds: 4.4) }   // 懒洋洋睁一只眼，看清是你才笑
            // 离开超过 12 小时又饿了：自己从背包里拿最便宜的吃一个
            if away >= 12 * 3600, needs.level(.hungry) < 0.5,
               let f = Food.shop.filter({ $0.effects[.hungry] ?? 0 > 0 }).sorted(by: { $0.price < $1.price }).first(where: { (profile.wallet.bag[$0.id] ?? 0) > 0 }),
               profile.consume(f) {
                needs.apply(f.effects)
                lines.append((Voice.line("selfate", ["food": f.name]), "eat"))
            }
            let n = profile.collectFound()
            if n > 0 { lines.append((Voice.line("found", ["n": "\(n)"]), "happy")) }
            guard !lines.isEmpty else { return }
            Analytics.log("welcome_back", ["hours": "\(Int(away / 3600))", "items": "\(lines.count)"])
            for (k, l) in lines.prefix(3).enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 1.2) {
                    chat.say(l.0, notify: false, frame: l.1)
                    if stageClip == nil { react(frame: l.1, line: nil, seconds: 2.0) }
                }
            }
            // 7 天以上：它在蛋壳里睡着了，过一会儿"被你叫醒"
            if away >= 7 * day {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                    chat.say(Voice.line("back.wake", mood: .excited), notify: false, frame: "happy")
                    showClip("shell_happy", seconds: 3.6)       // 被叫醒：壳晃起来，笑
                    if away >= 30 * day { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { tellDream() } }   // 一个月没见：叫醒后讲个梦
                }
            }
        }
    }

    /// 每天的签到 + 按时起床（起床时间后 1 小时内打开 App）
    private func dailyRewards() {
        profile.dailyCheckIn()
        let wake = routine.routine.items.first { $0.pose == .wake }.map { $0.hour * 60 + $0.minute } ?? profile.profile.wakeHour * 60
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let now = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if now >= wake && now <= wake + 60 { profile.claim(.wake); companion.record(.wakeOnTime) }
    }

    /// 只有一个角色：小紫（2026-10-16 决定，积分和动作全投在它身上）
    static let pets: [(String, String)] = [("purple", T("嘟嘟"))]

    static func petName(_ id: String) -> String { pets.first { $0.0 == id }?.1 ?? T("小怪") }
    static func minutes(since d: Date) -> String {
        let m = Int(Date().timeIntervalSince(d) / 60)
        return m < 1 ? T("刚刚") : (m < 60 ? T("{0} 分钟", m) : T("{0} 小时", m / 60))
    }
}

/// 舞台背景的星星：只在两边和顶上，慢慢一闪一闪
struct StageSky: View {
    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.06, 0.16, 2.2, 0.0), (0.09, 0.42, 1.4, 1.1), (0.05, 0.70, 1.6, 2.3), (0.93, 0.12, 2.0, 0.6),
        (0.95, 0.38, 1.3, 1.7), (0.91, 0.64, 1.8, 2.9), (0.30, 0.07, 1.2, 0.9), (0.70, 0.05, 1.5, 2.0),
    ]
    @State private var on = false
    var body: some View {
        GeometryReader { g in
            ForEach(stars.indices, id: \.self) { i in
                let s = stars[i]
                Circle().fill(Color(hex: "#E9DEFF"))
                    .frame(width: s.2, height: s.2)
                    .opacity(on ? 0.55 : 0.18)
                    .animation(.easeInOut(duration: 2.6).repeatForever().delay(s.3), value: on)
                    .position(x: g.size.width * s.0, y: g.size.height * s.1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { on = true }
    }
}

struct EntryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.surface.opacity(configuration.isPressed ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}
