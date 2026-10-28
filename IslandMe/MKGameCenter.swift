import GameKit
import SwiftUI

/// 每周交单榜（Game Center 循环排行榜，苹果自带，不用自己的服务器）。
/// - 每交一张外卖单 +1 分，这一轮的分数存在本机，交完就提交（排行榜只留最高分，所以提交累计数就行）
/// - 一轮结束：按上一轮名次发奖（第 1 名 / 前 10% / 参加了）
/// - 没登录 Game Center 也照常玩，只是看不到榜
@MainActor
final class MKGameCenter: ObservableObject {
    static let shared = MKGameCenter()
    /// App Store Connect 里建的循环排行榜 ID（每周一轮）
    static let boardID = "dudu.orders.weekly"

    @Published private(set) var authed = false
    @Published private(set) var rank: Int? = nil
    @Published private(set) var players: Int? = nil
    @Published private(set) var ends: Date? = nil
    @Published private(set) var score: Int = 0
    /// 上一轮的奖励（店里拿到后发）
    var onReward: ((Int, Int) -> Void)?

    private let d = UserDefaults.standard
    private var started = false
    private var board: GKLeaderboard?

    private init() { score = d.integer(forKey: "gc.score") }

    /// 第一次点榜单卡时才登录（不在开 App 时弹框）；登录过的人之后每次进店自动连上
    func start(prompt: Bool) {
        guard !MKDemo.on, !Shot.on else { return }
        guard prompt || d.bool(forKey: "gc.asked") else { return }
        d.set(true, forKey: "gc.asked")
        guard !started else { if authed { refresh() }; return }
        started = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, _ in
            Task { @MainActor in
                guard let self else { return }
                if let vc { Self.top()?.present(vc, animated: true) }
                self.authed = GKLocalPlayer.local.isAuthenticated
                if self.authed { self.refresh() }
            }
        }
    }

    /// 交了一张外卖单
    func addOrder() {
        guard !MKDemo.on, !Shot.on else { return }
        score += 1
        d.set(score, forKey: "gc.score")
        guard authed else { return }
        Task { await submit() }
    }

    func refresh() {
        Task { await load() }
    }

    private func load() async {
        guard authed else { return }
        guard let lb = try? await GKLeaderboard.loadLeaderboards(IDs: [Self.boardID]).first else { return }
        board = lb
        // 新的一轮：分数归零；看看上一轮排第几，发奖
        let occ = lb.startDate.map { String(Int($0.timeIntervalSince1970)) } ?? ""
        if !occ.isEmpty, d.string(forKey: "gc.occ") != occ {
            let hadPrev = d.string(forKey: "gc.occ") != nil
            d.set(occ, forKey: "gc.occ")
            score = 0; d.set(0, forKey: "gc.score")
            if hadPrev, let prev = try? await lb.loadPreviousOccurrence(),
               let r = try? await prev.loadEntries(for: [GKLocalPlayer.local], timeScope: .allTime),
               let me = r.0, !d.bool(forKey: "gc.rewarded." + occ) {
                d.set(true, forKey: "gc.rewarded." + occ)
                let total = (try? await prev.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 1)))?.2 ?? 0
                onReward?(me.rank, max(total, me.rank))
            }
        }
        if let s = lb.startDate { ends = s.addingTimeInterval(lb.duration) }
        if let r = try? await lb.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 1)) {
            rank = r.0?.rank
            players = r.2
            if let mine = r.0?.score, mine > score { score = mine; d.set(score, forKey: "gc.score") }
        }
    }

    private func submit() async {
        try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.boardID])
        await load()
    }

    /// 打开苹果自带的榜单页
    func show() {
        guard authed else { start(prompt: true); return }
        let vc = GKGameCenterViewController(leaderboardID: Self.boardID, playerScope: .global, timeScope: .allTime)
        vc.gameCenterDelegate = Dismisser.shared
        Self.top()?.present(vc, animated: true)
    }

    private final class Dismisser: NSObject, GKGameCenterControllerDelegate {
        static let shared = Dismisser()
        func gameCenterViewControllerDidFinish(_ vc: GKGameCenterViewController) { vc.dismiss(animated: true) }
    }

    static func top() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        var v = root
        while let p = v?.presentedViewController { v = p }
        return v
    }
}
