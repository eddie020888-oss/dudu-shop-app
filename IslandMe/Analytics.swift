import Foundation

/// 本地埋点：先记在手机上（最多 2000 条），接上服务器后再批量上传。
/// 关心的指标见设定第 25 节：开蛋完成率、路线比例、留存、每天互动、熟悉度增长、请求响应率、里程碑、分享。
enum Analytics {
    struct Event: Codable { let t: Date; let name: String; let p: [String: String] }

    private static let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("events.json")
    }()
    private static var cache: [Event]? = nil

    static func log(_ name: String, _ p: [String: String] = [:]) {
        var all = load()
        all.append(Event(t: Date(), name: name, p: p))
        if all.count > 2000 { all.removeFirst(all.count - 2000) }
        cache = all
        if let d = try? JSONEncoder().encode(all) { try? d.write(to: url) }
    }

    static func load() -> [Event] {
        if let c = cache { return c }
        let all = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Event].self, from: $0) } ?? []
        cache = all
        return all
    }

    /// 每天第一次打开记一条（算留存用）
    static func dailyOpen() {
        let key = "analytics.lastOpen"
        let today = Wallet.day()
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)
        log("app_open_day")
    }

    /// 调试页用：每种事件的次数
    static func summary() -> [(String, Int)] {
        Dictionary(grouping: load(), by: \.name).map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }
}
