import Foundation
import UserNotifications

/// 作息表运行时：每 30 秒看一眼当前项；变化时通知外部；为每项预约每日本地通知。
@MainActor
final class RoutineStore: ObservableObject {
    @Published var routine = Routine.load() { didSet { routine.save(); refresh(); scheduleNotifications() } }
    @Published private(set) var current: RoutineItem? = nil
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let c = routine.current()
        if c != current { current = c }
    }

    /// 每项一条每日重复的本地通知（到点提醒 + 点开进聊天）
    func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let old = reqs.map(\.identifier).filter { $0.hasPrefix("routine.") }
            center.removePendingNotificationRequests(withIdentifiers: old)
            guard Greeter.routineEnabled else { return }
            for it in self.routine.items where !Quiet.isQuiet(hour: it.hour) && Quiet.level != .low {
                let c = UNMutableNotificationContent()
                c.title = ChatStore.petName
                c.body = it.line.isEmpty ? it.title : it.line
                c.interruptionLevel = .passive
                var dc = DateComponents(); dc.hour = it.hour; dc.minute = it.minute
                center.add(UNNotificationRequest(identifier: "routine.\(it.id.uuidString)", content: c,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
            }
        }
    }
}
