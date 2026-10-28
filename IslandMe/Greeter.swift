import Foundation
import UserNotifications

/// 主动打招呼：醒着的每个整点一句（作息里已有安排的小时跳过），静音、不点亮屏幕。
/// 动作变化不再弹消息；需求（饿/渴/脏）到阈值各提醒一次；作息到点一次。
enum Greeter {
    static let enabledKey = "greet.enabled"
    static let routineEnabledKey = "routine.notify.enabled"

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
    static var routineEnabled: Bool {
        get { UserDefaults.standard.object(forKey: routineEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: routineEnabledKey) }
    }

    /// 整点问候：今明两天 wake..<sleep 之间；跳过作息、小紫自己安排占用的小时。
    /// 问候频率：每 2 小时一次（小紫自己也会主动报备安排，加起来不吵）
    static func schedule(wakeHour: Int, sleepHour: Int, routine: Routine) {
        Meals.schedule(wakeHour: wakeHour)
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix("greet.") })
            guard enabled, Quiet.level != .low else { return }
            let step = Quiet.level == .high ? 1 : 2
            let cal = Calendar.current
            let end = sleepHour > wakeHour ? sleepHour : 24
            for offset in 0...1 {
                guard let day = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
                var busy = Set(routine.items.map(\.hour)).union(Meals.enabled ? Meals.hours(wakeHour: wakeHour) : [])
                if PetLife.enabled { busy.formUnion(PetLife.busyHours(for: day, wakeHour: wakeHour, sleepHour: sleepHour)) }
                for h in stride(from: wakeHour + 1, to: end, by: step) where !busy.contains(h) && !Quiet.isQuiet(hour: h) {
                    var dc = cal.dateComponents([.year, .month, .day], from: day)
                    dc.hour = h; dc.minute = (h * 7) % 12 + 1         // 错开整点，别和别的 App 撞
                    guard let when = cal.date(from: dc), when > Date() else { continue }
                    let c = UNMutableNotificationContent()
                    c.title = ChatStore.petName
                    c.body = Voice.speaks ? line(for: h) : Mood.calm.dudu.randomElement()!
                    c.interruptionLevel = .passive        // 不响、不亮屏，只进通知中心和岛台
                    center.add(UNNotificationRequest(identifier: "greet.\(Wallet.day(day)).\(h)", content: c,
                                                     trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
                }
            }
        }
    }

    static func line(for hour: Int) -> String {
        let pool: [String]
        switch hour {
        case 5...8:   pool = [T("早。我醒了，你呢。"), T("新的一天，先喝口水。"), T("早上好，今天想干嘛？")]
        case 9...11:  pool = [T("上午过半了，顺利吗。"), T("我在，忙你的。"), T("坐太久的话，站起来一下。")]
        case 12...13: pool = [T("中午了，吃点好的。"), T("该吃饭了，别拖。"), T("午休一下，我也眯一会儿。")]
        case 14...17: pool = [T("下午好。还撑得住吗。"), T("喝口水，接着来。"), T("这会儿最容易困，走两步。")]
        case 18...20: pool = [T("晚上好。今天怎么样。"), T("下班了吗，吃了没。"), T("天黑了，我陪你。")]
        default:      pool = [T("夜深了，差不多该歇了。"), T("还在呢？我陪你一会儿。"), T("睡前把手机放远点。")]
        }
        return pool.randomElement()!
    }
}
