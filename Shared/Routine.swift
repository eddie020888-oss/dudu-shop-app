import Foundation

/// 作息时间线：一天里固定时间点做的事。宠物在没有传感器明确信号时按这个表演。
struct RoutineItem: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var hour: Int
    var minute: Int
    var title: String        // 显示名：喝咖啡
    var symbol: String       // SF Symbol：cup.and.saucer.fill
    var pose: Pose           // 对应动作（决定用哪张帧）
    var line: String = ""    // 到点时它说的话（空则用 title）

    var minutesOfDay: Int { hour * 60 + minute }
    var timeText: String { String(format: "%02d:%02d", hour, minute) }
}

struct Routine: Codable, Equatable {
    var items: [RoutineItem] = Routine.defaultItems

    var sorted: [RoutineItem] { items.sorted { $0.minutesOfDay < $1.minutesOfDay } }

    /// 现在该做什么：最近一个已到点的项目，到点后 1 小时内有效（睡觉一直持续到下一项）。
    /// 一天刚开始还没到第一项时，如果昨天最后一项是睡觉就还在睡。其余时间返回 nil，交给传感器/时段判断。
    func current(at now: Date = Date()) -> RoutineItem? {
        let m = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        let s = sorted
        if let it = s.last(where: { $0.minutesOfDay <= m }) {
            return (it.pose == .sleep || m - it.minutesOfDay < 60) ? it : nil
        }
        if let last = s.last, last.pose == .sleep { return last }
        return nil
    }
    func next(at now: Date = Date()) -> RoutineItem? {
        let m = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        let s = sorted
        return s.first { $0.minutesOfDay > m } ?? s.first
    }

    /// 默认只放起床和睡觉，其余自己加
    static let defaultItems: [RoutineItem] = [
        .init(hour: 7,  minute: 0,  title: T("起床"), symbol: "sunrise.fill",  pose: .wake,  line: T("早。起来了。")),
        .init(hour: 23, minute: 0,  title: T("睡觉"), symbol: "moon.zzz.fill", pose: .sleep, line: T("睡了。")),
    ]

    /// 可添加的安排
    static let presets: [(title: String, symbol: String, pose: Pose, line: String)] = [
        (T("起床"), "sunrise.fill", .wake, T("早。起来了。")), (T("洗漱"), "drop.fill", .wash, T("刷牙，别偷懒。")),
        (T("喝咖啡"), "cup.and.saucer.fill", .coffee, T("咖啡时间。")), (T("工作"), "laptopcomputer", .work, T("开工。")),
        (T("吃饭"), "fork.knife", .eat, T("吃饭了，放下手机。")), (T("跑步"), "figure.run", .run, T("换鞋，出门跑。")),
        (T("健身"), "dumbbell.fill", .gym, T("练起来。")), (T("散步"), "figure.walk", .walk, T("出去走走。")),
        (T("看电影"), "popcorn.fill", .movie, T("今晚看什么？")), (T("看书"), "book.fill", .read, T("看会儿书。")),
        (T("睡觉"), "moon.zzz.fill", .sleep, T("睡了。")),
    ]

    private static let key = "routine.v2"   // v1 的默认表太满，升级后重置成精简版
    static func load() -> Routine {
        if let d = UserDefaults(suiteName: Character.appGroup)?.data(forKey: key),
           let r = try? JSONDecoder().decode(Routine.self, from: d) { return r }
        return Routine()
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults(suiteName: Character.appGroup)?.set(d, forKey: Self.key) }
    }
}
