import Foundation
import UserNotifications

/// 宠物需求的运行时：每分钟重算、照顾、预约“饿了”本地通知（App 冻结时也能提醒）。
@MainActor
final class NeedsStore: ObservableObject {
    @Published private(set) var needs = PetNeeds.load()
    @Published private(set) var urgent: Need? = nil
    @Published private(set) var updatedAt = Date()   // 每分钟刷新一次，让进度条跟着走
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func level(_ n: Need) -> Double { needs.level(n) }

    /// 灵动岛按钮在 App 外改了存档 → 重新读
    func reload() {
        needs = PetNeeds.load()
        refresh()
        scheduleReminders()
    }

    func refresh() {
        updatedAt = Date()
        let u = needs.urgent()
        if u != urgent { urgent = u }
    }

    func care(_ n: Need) {
        needs.care(n)
        if n != .happy { needs.add(.happy, 0.05) }     // 被照顾也会开心一点
        needs.save()
        refresh()
        scheduleReminders()
    }
    /// 吃东西：一次加减多项
    func apply(_ eff: [Need: Double]) {
        for (n, d) in eff { needs.add(n, d) }
        needs.save()
        refresh()
        scheduleReminders()
    }
    /// 互动/聊天/一起运动：加开心值
    func cheer(_ delta: Double) {
        needs.add(.happy, delta)
        needs.save()
        refresh()
        scheduleReminders()
    }

    /// 为每个需求预约一条本地通知：在它跌到阈值的那一刻提醒（重新照顾时会重排）
    func scheduleReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Need.allCases.map { "need.\($0.rawValue)" })
        for n in Need.allCases {
            var t = needs.timeUntilNeed(n)
            guard t > 60 else { continue }
            // 安静时段不打扰：推到安静结束
            let when = Quiet.push(Date().addingTimeInterval(t))
            t = when.timeIntervalSinceNow
            let c = UNMutableNotificationContent()
            c.title = ChatStore.petName
            c.body = Voice.line("need.\(n.rawValue)")
            c.sound = .default
            center.add(UNNotificationRequest(identifier: "need.\(n.rawValue)", content: c,
                                             trigger: UNTimeIntervalNotificationTrigger(timeInterval: t, repeats: false)))
        }
    }

    static let needLines: [Need: [String]] = [
        .hungry:  [T("饿了……有吃的吗？"), T("肚子咕咕叫了。"), T("能不能先喂我一口。")],
        .thirsty: [T("渴了，想喝水。"), T("嗓子干了。"), T("水，水。")],
        .dirty:   [T("我这儿该收拾了。"), T("有点脏，帮我清一下？"), T("不太舒服，要洗澡。")],
        .happy:   [T("没人理我……"), T("无聊。陪我玩会儿。"), T("你好久没戳我了。")],
    ]
    static let caredFrame: [Need: String] = [.hungry: "eat", .thirsty: "coffee", .dirty: "bath", .happy: "laugh"]
    /// 还不需要照顾时硬喂的回应
    static let fullLines: [Need: [String]] = [
        .hungry:  [T("还不饿，先放着。"), T("刚吃过，肚子圆着呢。")],
        .thirsty: [T("不渴，谢了。"), T("水还够。")],
        .dirty:   [T("挺干净的，不用。"), T("刚洗过啦。")],
        .happy:   [T("已经很开心了！"), T("再玩我要飘了。")],
    ]
    static let caredLines: [Need: [String]] = [
        .hungry:  [T("好吃！"), T("饱了，谢谢。"), T("这顿记你一功。")],
        .thirsty: [T("咕咚咕咚。舒服。"), T("活过来了。")],
        .dirty:   [T("清爽！"), T("香喷喷的了。")],
        .happy:   [T("哈哈哈，再来！"), T("开心！"), T("和你玩最好玩。")],
    ]
}
