import SwiftUI

/// “我”：宠物名字、我的昵称、它怎么称呼我、作息、角色外观入口
struct MeView: View {
    @State private var cloudTick = 0
    private var cloudText: String {
        guard let d = CloudSave.lastBackup else { return T("还没存过") }
        return T("上次 {0}", d.formatted(date: .abbreviated, time: .shortened))
    }
    @ObservedObject var profile: ProfileStore
    @ObservedObject var live: LiveActivityManager
    @ObservedObject var routine: RoutineStore
    @ObservedObject var companion: CompanionStore
    @Binding var character: Character
    var shownPose: Pose
    var lastLine: String
    var need: Need?
    @State private var hasBirthday = false
    @AppStorage("onboarded.v1") private var onboarded = true
    @ObservedObject private var bond = BondStore.shared
    @State private var quietStart = Quiet.start
    @State private var quietEnd = Quiet.end
    @State private var level = Quiet.level
    private enum Field: Hashable { case pet, myName, callMe }
    @FocusState private var focus: Field?
    @State private var savedTip = false
    @State private var replayStory = false

    /// 收起键盘，提示一下已经存好了（输入是边打边存的）
    private func done() {
        focus = nil
        let n = profile.profile.petName.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { profile.profile.petName = T("嘟嘟") }
        Voice.petName = profile.profile.petName
        withAnimation { savedTip = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { withAnimation { savedTip = false } }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(T("宠物")) {
                    TextField(T("名字"), text: $profile.profile.petName)
                        .focused($focus, equals: .pet).submitLabel(.done)
                        .onSubmit { done() }
                }
                if bond.hatched {
                    Section {
                        NavigationLink { MemoriesView(bond: bond, petName: profile.profile.petName) } label: {
                            HStack { Text(T("回忆")); Spacer(); Text(T("一起 {0} 天 · {1}", bond.daysTogether, bond.stageName)).foregroundStyle(.secondary) }
                        }
                    }
                }
                Section(T("我")) {
                    TextField(T("我的昵称"), text: $profile.profile.myName)
                        .focused($focus, equals: .myName).submitLabel(.next)
                        .onSubmit { focus = .callMe }
                    TextField(T("它叫我（留空就用昵称）"), text: $profile.profile.callMe)
                        .focused($focus, equals: .callMe).submitLabel(.done)
                        .onSubmit { done() }
                    Picker(T("性别"), selection: $profile.profile.gender) {
                        Text(T("不说")).tag("")
                        Text(T("男")).tag(T("男"))
                        Text(T("女")).tag(T("女"))
                        if !["", T("男"), T("女")].contains(profile.profile.gender) {
                            Text(profile.profile.gender).tag(profile.profile.gender)
                        }
                    }
                    Toggle(T("生日"), isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker(T("日期"), selection: Binding(
                            get: { profile.profile.birthday ?? Date() },
                            set: { profile.profile.birthday = $0 }), displayedComponents: .date)
                    }
                }
                Section(T("作息时间线")) {
                    Picker(T("几点起床"), selection: $profile.profile.wakeHour) {
                        ForEach(4...12, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                    Picker(T("几点睡觉"), selection: $profile.profile.sleepHour) {
                        ForEach(19...23, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                    NavigationLink {
                        RoutineEditor(routine: routine)
                    } label: {
                        HStack { Text(T("每天的安排")); Spacer(); Text(T("{0} 项", routine.routine.items.count)).foregroundStyle(.secondary) }
                    }
                    if let c = routine.current { Text(T("现在：{0} {1}", c.timeText, c.title)).font(.footnote).foregroundStyle(.secondary) }
                }
                Section {
                    NavigationLink { CompanionPicker(store: companion, wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour) } label: {
                        HStack { Text(T("想让它陪你做的事")); Spacer(); Text(T("{0} 件", companion.chosen.count)).foregroundStyle(.secondary) }
                    }
                }
                Section(T("它什么时候找你")) {
                    Toggle(T("醒着时偶尔打个招呼（约两小时一次）"), isOn: Binding(
                        get: { Greeter.enabled },
                        set: { Greeter.enabled = $0; Greeter.schedule(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour, routine: routine.routine) }))
                    Toggle(T("{0}自己的安排（午睡、喝奶茶…）", profile.profile.petName), isOn: Binding(
                        get: { PetLife.enabled },
                        set: { PetLife.enabled = $0
                               PetLife.schedule(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour, enabled: $0)
                               Greeter.schedule(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour, routine: routine.routine) }))
                    Toggle(T("到饭点喊你吃饭（早饭·午饭 12:10·晚饭 18:20）"), isOn: Binding(
                        get: { Meals.enabled },
                        set: { Meals.enabled = $0; Meals.schedule(wakeHour: profile.profile.wakeHour) }))
                    Toggle(T("作息到点提醒"), isOn: Binding(
                        get: { Greeter.routineEnabled },
                        set: { Greeter.routineEnabled = $0; routine.scheduleNotifications() }))
                    Picker(T("提醒多少"), selection: $level) {
                        ForEach(NotifyLevel.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(level.detail).font(.footnote).foregroundStyle(.secondary)
                    Picker(T("安静时段开始"), selection: $quietStart) {
                        ForEach(18...23, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                    Picker(T("安静时段结束"), selection: $quietEnd) {
                        ForEach(5...11, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                    Text(T("安静时段里不发任何通知、不弹灵动岛，到点后再补。")).font(.footnote).foregroundStyle(.secondary)
                    Text(T("饿了、渴了、脏了各提醒一次；它每天早上报备自己的安排，去做事时说一声。全部静音。")).font(.footnote).foregroundStyle(.secondary)
                    let plan = PetLife.today(wakeHour: profile.profile.wakeHour, sleepHour: profile.profile.sleepHour)
                    if PetLife.enabled && !plan.isEmpty {
                        Text(T("今天它要：") + plan.map { "\($0.timeText) \($0.activity.pose.label)" }.joined(separator: " · ")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle(T("对视（用前置摄像头）"), isOn: Binding(
                        get: { GazeWatcher.enabled },
                        set: { GazeWatcher.enabled = $0; NotificationCenter.default.post(name: Notification.Name("gazeChanged"), object: nil) }))
                } footer: {
                    Text(T("App 开着时，你看它，它会回看你；盯久了它会害羞。只在手机上算，不拍照、不录像、不上传。"))
                }
                Section {
                    Toggle(T("小店音效"), isOn: Binding(get: { MKSfx.on }, set: { MKSfx.on = $0 }))
                    Button(T("重看开场故事")) { replayStory = true }
                } footer: {
                    Text(T("合成、交单的小声音，不会打断你在听的歌。静音模式下要不要出声，在小店右上角的齿轮里改。"))
                }
                .fullScreenCover(isPresented: $replayStory) { StoryIntroView { replayStory = false } }
                Section {
                    AgeSettings()
                } header: { Text(T("按年龄陪你")) }
                Section {
                    HStack {
                        Label(T("iCloud 存档"), systemImage: "icloud")
                        Spacer()
                        Text(cloudText).font(.system(size: 13)).foregroundStyle(Theme.text3)
                    }
                    Button(T("现在存一次")) { CloudSave.backup(); cloudTick += 1 }
                } header: { Text(T("存档")) } footer: {
                    Text(T("进度会自动存进你的 iCloud（同一个 Apple ID），换手机或删了重装，打开 App 会问你要不要恢复。需要在系统设置里登录 iCloud。"))
                }
                .id(cloudTick)

                Section(T("岛台")) {
                    Toggle(T("显示在灵动岛"), isOn: Binding(
                        get: { live.isRunning },
                        set: { on in on ? live.start(pose: shownPose, character: character, lastLine: lastLine, need: need) : live.end(byUser: true) }))
                    if !live.isEnabled {
                        Text(T("请在 设置 → 本 App 中打开“实时活动”")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    NavigationLink { LedgerView(profile: profile) } label: {
                        HStack { Text(T("金币与背包")); Spacer(); Text("\(profile.profile.coins)").foregroundStyle(.secondary) }
                    }
                }
                Section {
                    Button(T("重看新手引导")) { onboarded = false }
                } footer: {
                    Text(T("它睡觉的时段（睡觉→起床）需求只按 30% 消耗。"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle(T("我"))
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(T("完成")) { done() }.fontWeight(.semibold)
                }
            }
            .overlay(alignment: .bottom) {
                if savedTip {
                    Label(T("已保存"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .tint(Theme.accent)
        }
        .onAppear { hasBirthday = profile.profile.birthday != nil }
        .onChange(of: quietStart) { _, v in Quiet.start = v; reschedule() }
        .onChange(of: quietEnd) { _, v in Quiet.end = v; reschedule() }
        .onChange(of: level) { _, v in Quiet.level = v; reschedule() }
        .onChange(of: hasBirthday) { _, on in if !on { profile.profile.birthday = nil } }
    }

    private func reschedule() {
        let p = profile.profile
        Greeter.schedule(wakeHour: p.wakeHour, sleepHour: p.sleepHour, routine: routine.routine)
        PetLife.schedule(wakeHour: p.wakeHour, sleepHour: p.sleepHour, enabled: PetLife.enabled)
        routine.scheduleNotifications()
        HealthStore.scheduleNags(routine: routine.routine)
        NotificationCenter.default.post(name: Notification.Name("quietChanged"), object: nil)
    }
}


/// 「我」里的年龄段 + 吃药时间
struct AgeSettings: View {
    @State private var age: String? = AgeGroup.current?.rawValue
    @State private var meds: [Int] = AgeCare.medTimes
    @State private var newMed = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!

    var body: some View {
        AgePicker(selection: Binding(get: { age }, set: { age = $0; AgeGroup.current = $0.flatMap(AgeGroup.init(rawValue:)) }))
            .listRowBackground(Color.clear)
        if age == AgeGroup.senior.rawValue {
            ForEach(meds, id: \.self) { t in
                HStack {
                    Image(systemName: "pills.fill").foregroundStyle(Theme.accent)
                    Text(String(format: T("%02d:%02d 吃药"), t / 60, t % 60))
                    Spacer()
                    Button(role: .destructive) { meds.removeAll { $0 == t }; save() } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                }
            }
            HStack {
                DatePicker(T("添加吃药时间"), selection: $newMed, displayedComponents: .hourAndMinute)
                Button(T("加")) {
                    let c = Calendar.current.dateComponents([.hour, .minute], from: newMed)
                    let m = (c.hour ?? 8) * 60 + (c.minute ?? 0)
                    if !meds.contains(m) { meds.append(m); save() }
                }
                .buttonStyle(.borderless)
            }
            Text(T("吃药提醒会响一声，安静时段也会提醒。")).font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func save() { meds.sort(); AgeCare.medTimes = meds; AgeCare.schedule() }
}
