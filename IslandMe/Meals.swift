import Foundation
import UserNotifications

/// 养生家：到饭点它要吃饭了，喊你一起吃（静音通知、安静时段不发、"少"档不发）。
enum Meals {
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "meals.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "meals.enabled") }
    }

    /// (key, 小时, 分钟)：早饭 = 起床后 40 分钟；午饭 12:10；晚饭 18:20
    static func times(wakeHour: Int) -> [(String, Int, Int)] {
        [("breakfast", wakeHour, 40), ("lunch", 12, 10), ("dinner", 18, 20)]
    }
    static func hours(wakeHour: Int) -> Set<Int> { Set(times(wakeHour: wakeHour).map { $0.1 }) }

    static func schedule(wakeHour: Int) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix("meal.") })
            guard enabled, Quiet.level != .low else { return }
            let cal = Calendar.current
            for offset in 0...1 {
                guard let day = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
                for (k, h, m) in times(wakeHour: wakeHour) where !Quiet.isQuiet(hour: h) {
                    var dc = cal.dateComponents([.year, .month, .day], from: day)
                    dc.hour = h; dc.minute = m
                    guard let when = cal.date(from: dc), when > Date() else { continue }
                    let c = UNMutableNotificationContent()
                    c.title = ChatStore.petName
                    c.body = Voice.line("meal." + k)
                    center.add(UNNotificationRequest(identifier: "meal.\(Wallet.day(day)).\(k)", content: c,
                                                     trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
                }
            }
        }
    }
}
