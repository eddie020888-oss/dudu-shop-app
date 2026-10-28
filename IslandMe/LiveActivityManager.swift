import ActivityKit
import Foundation
import UIKit

/// 负责 Live Activity 的启动 / 更新 / 结束，以及前台时的“小动作”（眨眼 / 哈欠 / 呼吸弹跳）。
@MainActor
final class LiveActivityManager: ObservableObject {
    @Published private(set) var isRunning = false
    private var activity: Activity<IslandMeAttributes>?
    private var currentPose: Pose?
    private var last: IslandMeAttributes.ContentState?
    private var idleTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    /// 小动作间隔（秒）。系统对本地更新有预算，不要低于 5。
    static let idleInterval: TimeInterval = 7

    var isEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// 岛台默认开；只有用户在首页手动关掉才记住"不开"
    static var userTurnedOff: Bool {
        get { UserDefaults.standard.bool(forKey: "island.userOff") }
        set { UserDefaults.standard.set(newValue, forKey: "island.userOff") }
    }

    /// 启动 / 回到前台时调用：没被用户关掉就保证岛台在（系统 8 小时自动结束后也会重新拉起）
    func ensureRunning(pose: Pose, character: Character, lastLine: String = "", need: Need? = nil) {
        guard !Self.userTurnedOff else { return }
        if let a = activity, a.activityState == .active { return }
        activity = nil; isRunning = false
        start(pose: pose, character: character, lastLine: lastLine, need: need)
    }

    init() {
        // 只在前台跑定时器：iOS 不允许后台持续更新 Live Activity（后台需推送）
        let nc = NotificationCenter.default
        observers = [
            nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.startIdleTimer() }
            },
            nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.stopIdleTimer() }
            },
        ]
    }

    private var need: String = ""

    func start(pose: Pose, character: Character, lastLine: String = "", need: Need? = nil) {
        self.need = need?.rawValue ?? ""
        Self.userTurnedOff = false
        guard isEnabled else { return }
        // 复用已有的（应用冷启动后系统可能还保留着）
        if let existing = Activity<IslandMeAttributes>.activities.first(where: { $0.activityState == .active }) {
            activity = existing
            isRunning = true
            update(pose: pose, character: character, lastLine: lastLine, need: need)
            startIdleTimer()
            return
        }
        let state = IslandMeAttributes.ContentState(pose: pose, since: Date(), character: character, lastLine: lastLine, need: self.need)
        do {
            activity = try Activity.request(
                attributes: IslandMeAttributes(startedAt: Date()),
                content: .init(state: state, staleDate: nil),
                pushType: nil)
            currentPose = pose
            last = state
            isRunning = true
            startIdleTimer()
        } catch {
            print("Live Activity start failed:", error)
        }
    }

    func update(pose: Pose, character: Character, lastLine: String = "", need: Need? = nil) {
        guard let activity else { return }
        self.need = need?.rawValue ?? ""
        let since = (pose == currentPose) ? (activity.content.state.since) : Date()
        currentPose = pose
        let state = IslandMeAttributes.ContentState(pose: pose, since: since, character: character, lastLine: lastLine,
                                                    frame: "", tick: (last?.tick ?? 0) + 1, need: self.need)
        push(state)
    }

    /// 重要时刻（饿了、它要东西、里程碑）：发"带提醒"的更新，系统会把大岛自动弹开几秒。
    /// 一天最多 3 次、安静时段不弹；App 在前台时也不弹（用户正看着它）。返回是否弹了。
    @discardableResult
    func alert(pose: Pose, character: Character, line: String, frame: String, need: Need?, title: String) -> Bool {
        guard let activity else { return false }
        let d = UserDefaults.standard
        let day = Wallet.day()
        var n = d.string(forKey: "island.alertDay") == day ? d.integer(forKey: "island.alertCount") : 0
        guard n < 3, !Quiet.isQuiet(Date()), UIApplication.shared.applicationState != .active else { return false }
        n += 1
        d.set(day, forKey: "island.alertDay"); d.set(n, forKey: "island.alertCount")
        self.need = need?.rawValue ?? ""
        currentPose = pose
        var state = IslandMeAttributes.ContentState(pose: pose, since: Date(), character: character, lastLine: line,
                                                    frame: frame, tick: (last?.tick ?? 0) + 1, need: self.need)
        state.shopAt = shopAt; state.shopIcon = shopIcon; state.shopLine = shopLine
        state.shopOpen = shopScene?.open; state.shopTickets = shopScene?.tickets; state.shopSign = shopScene?.sign
        last = state
        // 声音名留空 = 不响（和通知一样全部静音）
        let cfg = AlertConfiguration(title: LocalizedStringResource(stringLiteral: title),
                                     body: LocalizedStringResource(stringLiteral: line),
                                     sound: .named(""))
        Task { await activity.update(.init(state: state, staleDate: nil), alertConfiguration: cfg) }
        return true
    }

    func end(byUser: Bool = false) {
        if byUser { Self.userTurnedOff = true }
        stopIdleTimer()
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
        isRunning = false
    }

    // MARK: - 小动作

    private func startIdleTimer() {
        guard activity != nil, idleTimer == nil else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: Self.idleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.idleTick() }
        }
    }

    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func idleTick() {
        guard var s = last, activity != nil else { return }
        // 在做事（走路、听歌、打电话……）时不眨眼换帧：眨眼帧是站着的全身，会把「在干嘛」盖掉
        if s.pose != .stand { s.tick += 1; push(s); return }
        let r = Int.random(in: 0..<10)
        if r < 6 {                                                  // 眨眼
            s.frame = "blink"; push(s)
            revert(after: 0.35)
        } else if r < 8 {                                           // 哈欠
            s.frame = "yawn"; push(s)
            revert(after: 1.4)
        } else {                                                    // 呼吸弹跳
            s.tick += 1; push(s)
        }
    }

    private func revert(after delay: TimeInterval) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, var s = self.last, !s.frame.isEmpty else { return }
            s.frame = ""
            self.push(s)
        }
    }

    // 嘟嘟小店的提醒：离开小店时设上，进店时清掉；之后每次更新都带着
    private var shopAt: Date?
    private var shopIcon: String?
    private var shopLine: String?
    private var shopScene: ShopScene?
    struct ShopScene: Equatable { var open: Bool; var tickets: Int; var sign: Int }
    /// 只更新店面（开 App 时刷一下，不动提醒）
    func setShopScene(_ scene: ShopScene?) {
        guard scene != shopScene else { return }
        shopScene = scene
        if let s = last { push(s) }
    }
    func setShop(at: Date?, icon: String?, line: String?, scene: ShopScene? = nil) {
        shopAt = at; shopIcon = icon; shopLine = line
        if let scene { shopScene = scene }
        if let s = last { push(s) }
    }

    private func push(_ state: IslandMeAttributes.ContentState) {
        guard let activity else { return }
        var state = state
        state.shopAt = shopAt; state.shopIcon = shopIcon; state.shopLine = shopLine
        state.shopOpen = shopScene?.open; state.shopTickets = shopScene?.tickets; state.shopSign = shopScene?.sign
        last = state
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }
}
