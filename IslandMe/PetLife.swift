import Foundation
import UserNotifications

/// 小紫自己的生活：它不只是镜子，每天也有自己的安排——全部是懒的事（设定 3.1：不跑、不打球、不健身）。
/// - 每天 1–2 件事，各 1 小时，按日期固定随机（同一天打开多少次都一样）。
/// - 早上（起床后半小时）主动说一句今天的安排；每件事开始时说一句，结束时嘀咕一句。
/// - 进行中：首页舞台和岛台都换成它在做的事。
struct PetPlanItem: Equatable, Identifiable {
    let activity: PetActivity
    let start: Date
    var end: Date { start.addingTimeInterval(3600) }
    var id: String { "\(activity.rawValue)-\(Int(start.timeIntervalSince1970))" }
    var timeText: String {
        let h = Calendar.current.component(.hour, from: start)
        let ap = h < 12 ? T("上午") : (h < 18 ? T("下午") : T("晚上"))
        let h12 = h > 12 ? h - 12 : h
        return T("{0}{1}点", ap, h12)
    }
}

enum PetActivity: String, CaseIterable {
    case nap, snack, boba, read, uke, sunbath, stargaze

    /// 首页舞台的专门片段（有就播，没有就用 pose 的通用动作）
    var clip: String? {
        switch self {
        case .nap: return "x_hug_shell"; case .snack: return "x_snack"; case .boba: return "x_boba"
        case .sunbath: return "x_sunbath"; case .stargaze: return "x_stargaze"; default: return nil
        }
    }

    /// 进行中舞台和岛台用哪段动作（新小紫视频到了以后换成专门的片段）
    var pose: Pose {
        switch self {
        case .nap:   return .sleep
        case .snack: return .eat
        case .boba:  return .coffee
        case .read:  return .read
        case .uke:   return .uke
        case .sunbath, .stargaze: return .sleep
        }
    }
    var doing: String {
        switch self {
        case .nap:   return T("睡一小时午觉💤")
        case .snack: return T("吃一小时零食🍪")
        case .boba:  return T("慢慢喝一杯奶茶🧋")
        case .read:  return T("躺着看会儿书📖")
        case .uke:   return T("坐着弹会儿尤克里里🎵")
        case .sunbath: return T("躺着晒一小时太阳☀️")
        case .stargaze: return T("躺着看会儿星星✨")
        }
    }
    var startLines: [String] {
        switch self {
        case .nap:   return [T("困了，我先睡一会儿。"), T("午觉时间，别叫我。")]
        case .snack: return [T("零食时间到🍪"), T("我去拆包薯片。")]
        case .boba:  return [T("奶茶来了，我要慢慢喝🧋"), T("喝奶茶，不许抢。")]
        case .read:  return [T("我躺着看会儿书📖"), T("看书去了，躺着看。")]
        case .uke:   return [T("弹会儿琴，坐着弹🎵"), T("尤克里里放肚子上，开弹。")]
        case .sunbath: return [T("晒太阳去了，补钙。"), T("太阳正好，我躺一会儿☀️")]
        case .stargaze: return [T("我去看星星了✨"), T("看看嘟嘟星在哪边。")]
        }
    }
    var endLines: [String] {
        switch self {
        case .nap:   return [T("睡醒了……还想睡。"), T("醒了。刚刚梦到吃的。")]
        case .snack: return [T("吃完了，嘴巴好咸。"), T("零食没了。还……要。")]
        case .boba:  return [T("喝完了，珍珠一颗没剩。"), T("奶茶没了，好可惜。")]
        case .read:  return [T("看了两页，睡着了一会儿。"), T("书盖在脸上了。")]
        case .uke:   return [T("弹完了，手指头有点累。"), T("学会半首新曲子。")]
        case .sunbath: return [T("晒好了，肚子暖暖的。"), T("翻个面……算了，不翻了。")]
        case .stargaze: return [T("看完了。有一颗一直在眨眼。"), T("没找到嘟嘟星，下次再找。")]
        }
    }
    /// 它在忙的时候你找它聊天
    var busyLines: [String] {
        switch self {
        case .nap:   return [T("……呼……嗯？你说。"), T("在睡觉……小声点。")]
        case .snack: return [T("嚼嚼……你说。"), T("嘴里有东西，等一下。")]
        case .boba:  return [T("在喝奶茶，吸管还在嘴里。"), T("嗯？珍珠卡住了，你说。")]
        case .read:  return [T("在看书……其实快睡着了。"), T("嗯？我在看书，你说。")]
        case .uke:   return [T("♪～ 在弹琴，你说。"), T("弹着呢，给你弹一首？")]
        case .sunbath: return [T("在晒太阳……别挡光。"), T("暖暖的，你说。")]
        case .stargaze: return [T("嘘，在数星星。"), T("你看，那颗在眨眼。")]
        }
    }
}

enum PetLife {
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "life.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "life.enabled") }
    }
    /// 某天的安排：工作日午后睡一觉 + 下午/晚上一件懒爱好；周末两件。按日期固定。
    static func plan(for day: Date, wakeHour: Int, sleepHour: Int) -> [PetPlanItem] {
        let cal = Calendar.current
        let d0 = cal.startOfDay(for: day)
        var rng = SeededRNG(seed: UInt64(d0.timeIntervalSince1970 / 86400))
        let weekday = cal.component(.weekday, from: d0)          // 1 = 周日
        let weekend = weekday == 1 || weekday == 7
        let hobbies: [PetActivity] = [.snack, .boba, .read, .uke, .sunbath].shuffled(using: &rng)
        let lastStart = max(wakeHour + 2, sleepHour - 2)
        func at(_ h: Int) -> Date { cal.date(bySettingHour: min(max(h, wakeHour + 1), lastStart), minute: 0, second: 0, of: d0)! }

        var items: [PetPlanItem] = []
        if weekend {
            items.append(PetPlanItem(activity: hobbies[0], start: at(Int.random(in: 10...11, using: &rng))))
            items.append(PetPlanItem(activity: hobbies[1], start: at(Int.random(in: 15...17, using: &rng))))
            if Int.random(in: 0..<2, using: &rng) == 0 { items.append(PetPlanItem(activity: .stargaze, start: at(20))) }
        } else {
            items.append(PetPlanItem(activity: .nap, start: at(Int.random(in: 13...14, using: &rng))))
            let h = [16, 19, 20].randomElement(using: &rng)!
            // 晚上那件：三分之一是躺着看星星；晒太阳只在白天
            var a = hobbies.first { h < 18 || $0 != .sunbath }!
            if h >= 19 && Int.random(in: 0..<3, using: &rng) == 0 { a = .stargaze }
            items.append(PetPlanItem(activity: a, start: at(h)))
        }
        return items.sorted { $0.start < $1.start }
    }

    static func today(wakeHour: Int, sleepHour: Int) -> [PetPlanItem] { plan(for: Date(), wakeHour: wakeHour, sleepHour: sleepHour) }

    /// 现在正在做的事
    static func current(wakeHour: Int, sleepHour: Int, at now: Date = Date()) -> PetPlanItem? {
        today(wakeHour: wakeHour, sleepHour: sleepHour).first { $0.start <= now && now < $0.end }
    }

    /// 早上那句："今天上午9点我去上学，下午4点去打一小时篮球🏀。"
    static func announcement(_ items: [PetPlanItem]) -> String {
        let parts = items.map { "\($0.timeText)\($0.activity.doing)" }
        let opener = [T("今天我的安排："), T("跟你报备一下，"), T("今天有点忙哦，")].randomElement()!
        return opener + parts.joined(separator: T("，")) + T("。其他时间都陪你～")
    }

    /// 预约今明两天的通知：早上报备 + 每件事开始时一句（都静音，不亮屏）
    static func schedule(wakeHour: Int, sleepHour: Int, enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix("life.") })
            guard enabled, Quiet.level != .low else { return }
            let cal = Calendar.current
            for offset in 0...1 {
                guard let day = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
                let items = plan(for: day, wakeHour: wakeHour, sleepHour: sleepHour)
                var notes: [(String, Date, String)] = []
                if let morning = cal.date(bySettingHour: wakeHour, minute: 30, second: 0, of: day) {
                    notes.append(("life.am.\(Wallet.day(day))", morning, announcement(items)))
                }
                for it in items { notes.append(("life.\(it.id)", it.start, it.activity.startLines.randomElement()!)) }
                for (id, when, body) in notes where when > Date() && !Quiet.isQuiet(when) {
                    let c = UNMutableNotificationContent()
                    c.title = ChatStore.petName
                    c.body = body
                    c.interruptionLevel = .passive
                    let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: when)
                    center.add(UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
                }
            }
        }
    }

    /// 今天已经被小紫安排占用的小时（问候避开）
    static func busyHours(for day: Date, wakeHour: Int, sleepHour: Int) -> Set<Int> {
        var s = Set(plan(for: day, wakeHour: wakeHour, sleepHour: sleepHour).map { Calendar.current.component(.hour, from: $0.start) })
        s.insert(wakeHour)   // 早上报备那一小时
        return s
    }
}

/// 可复现的随机数（按日期做种子）
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
