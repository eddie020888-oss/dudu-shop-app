import Foundation

/// 提醒频率三档
enum NotifyLevel: String, CaseIterable, Identifiable {
    case low, normal, high
    var id: String { rawValue }
    var title: String {
        switch self { case .low: return T("少"); case .normal: return T("正常"); case .high: return T("多") }
    }
    var detail: String {
        switch self {
        case .low: return T("只在饿了、渴了、脏了时提醒")
        case .normal: return T("需求提醒 + 每天报备一次 + 约两小时打个招呼")
        case .high: return T("需求提醒 + 报备 + 每小时打个招呼")
        }
    }
}

/// 安静时段（默认 22:00–08:00）：这段时间不发任何通知；需求提醒推迟到安静时段结束。
enum Quiet {
    private static let d = UserDefaults.standard
    static var start: Int {
        get { d.object(forKey: "quiet.start") as? Int ?? 22 }
        set { d.set(newValue, forKey: "quiet.start") }
    }
    static var end: Int {
        get { d.object(forKey: "quiet.end") as? Int ?? 8 }
        set { d.set(newValue, forKey: "quiet.end") }
    }
    static var level: NotifyLevel {
        get { NotifyLevel(rawValue: d.string(forKey: "notify.level") ?? "") ?? .normal }
        set { d.set(newValue.rawValue, forKey: "notify.level") }
    }

    static func isQuiet(hour h: Int) -> Bool {
        start > end ? (h >= start || h < end) : (h >= start && h < end)
    }
    static func isQuiet(_ date: Date) -> Bool { isQuiet(hour: Calendar.current.component(.hour, from: date)) }

    /// 落在安静时段的时间推到安静结束那一刻
    static func push(_ date: Date) -> Date {
        guard isQuiet(date) else { return date }
        let cal = Calendar.current
        var end = cal.date(bySettingHour: Quiet.end, minute: 5, second: 0, of: date)!
        if end <= date { end = cal.date(byAdding: .day, value: 1, to: end)! }
        return end
    }
}
