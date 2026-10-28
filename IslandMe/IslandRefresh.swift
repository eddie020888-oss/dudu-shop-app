import ActivityKit
import BackgroundTasks
import CoreMotion
import Foundation

/// App 不在前台时，iOS 会把我们挂起，岛台就停在最后一张图上。
/// 这里用系统的「后台刷新」：系统隔一阵（一般 15 分钟到 1 小时，看你用手机的习惯）叫醒我们一下，
/// 我们查一眼你刚才在干嘛（运动记录：走路 / 跑步 / 开车），再看看钟点（该睡了 / 上班 / 晚上），
/// 把岛台上的嘟嘟换成对应的样子 + 一句短话。真正「你一动它就跟着动」要服务器推送，这是不用服务器能做到的。
enum IslandRefresh {
    static let id = "com.eddiejiang.islandme.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
            guard let t = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            handle(t)
        }
    }

    static func schedule() {
        let r = BGAppRefreshTaskRequest(identifier: id)
        r.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(r)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()   // 先排好下一次
        let work = Task {
            await refresh()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    /// 也给前台退到后台的那几十秒用：马上换成「你走开了」时的样子
    static func refresh() async {
        guard let act = Activity<IslandMeAttributes>.activities.first(where: { $0.activityState == .active }) else { return }
        var s = act.content.state
        let p = Profile.load()
        let pose = await guessPose(wakeHour: p.wakeHour, sleepHour: p.sleepHour)
        // 有需求（饿了渴了）时岛台显示需求，不抢；动作没变就不浪费一次更新
        guard s.need.isEmpty, pose != s.pose else { return }
        s.pose = pose
        s.since = Date()
        s.frame = ""
        s.tick += 1
        if let l = line(pose) { s.lastLine = l }
        await act.update(.init(state: s, staleDate: nil))
    }

    /// 最近 10 分钟的运动记录 → 走 / 跑 / 坐车；没有就按钟点
    static func guessPose(wakeHour: Int, sleepHour: Int, now: Date = Date()) async -> Pose {
        if CMMotionActivityManager.isActivityAvailable(),
           CMMotionActivityManager.authorizationStatus() == .authorized,
           let a = await lastActivity(since: now.addingTimeInterval(-10 * 60)) {
            if a.automotive { return .drive }
            if a.running { return .run }
            if a.walking || a.cycling { return .walk }
        }
        let h = Calendar.current.component(.hour, from: now)
        // 睡觉时段：从 sleepHour 到 wakeHour（可以跨午夜）
        let span = (wakeHour - sleepHour + 24) % 24
        if (h - sleepHour + 24) % 24 < span { return .sleep }
        switch h {
        case 9..<18: return .work
        case 19..<23: return .movie
        default: return .stand
        }
    }

    private static let motion = CMMotionActivityManager()
    private static func lastActivity(since: Date) async -> CMMotionActivity? {
        await withCheckedContinuation { c in
            motion.queryActivityStarting(from: since, to: Date(), to: .main) { list, _ in
                let good = (list ?? []).filter { $0.confidence != .low }
                c.resume(returning: good.last)
            }
        }
    }

    /// 岛台右耳 / 展开态那一句：短，懒洋洋的，跟着你在做的事
    static func line(_ p: Pose) -> String? {
        let zh: [Pose: [String]] = [
            .walk: [T("你走，我坐滑板跟着"), T("慢点走…"), T("又出门啦")],
            .run: [T("跑这么快干嘛…"), T("我滑板追不上了")],
            .drive: [T("开车别看我"), T("系好安全带")],
            .sleep: [T("嘘…睡了"), T("晚安…")],
            .work: [T("你忙，我在这儿"), T("累了就歇会儿")],
            .movie: [T("晚上了，看个片？"), T("躺着就好")],
        ]
        return zh[p]?.randomElement()
    }
}
