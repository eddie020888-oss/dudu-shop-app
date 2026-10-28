import Foundation
import WidgetKit

/// App → 桌面小组件的状态。App Group（group.com.eddiejiang.islandme）开通后小组件就能读到实时状态；
/// 没开通时 UserDefaults(suiteName:) 退化为各自私有存储，小组件按时间自己推断它在干嘛。
struct WidgetState: Codable {
    var frame: String          // purple_<frame>
    var line: String
    var need: String
    var name: String
    var at: Date
    // 小店：下一件「好了」的事（出锅、宝箱、体力满）——小组件上倒计时
    var shopIcon: String? = nil
    var shopLine: String? = nil
    var shopAt: Date? = nil
}

enum WidgetBridge {
    static let key = "widget.state.v1"
    private static var lastReload = Date.distantPast

    static func publish(_ s: WidgetState) {
        guard let d = UserDefaults(suiteName: Character.appGroup), let data = try? JSONEncoder().encode(s) else { return }
        d.set(data, forKey: key)
        // 小组件刷新有系统预算，30 秒内最多叫一次
        if Date().timeIntervalSince(lastReload) > 30 {
            lastReload = Date()
            WidgetCenter.shared.reloadTimelines(ofKind: "XiaoziHome")
        }
    }

    /// 离开小店时记下下一件事（不动它的样子）
    static func publishShop(icon: String?, line: String?, at: Date?) {
        guard var s = read() else { return }
        s.shopIcon = icon; s.shopLine = line; s.shopAt = at
        guard let d = UserDefaults(suiteName: Character.appGroup), let data = try? JSONEncoder().encode(s) else { return }
        d.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: "XiaoziHome")
    }

    static func read() -> WidgetState? {
        guard let data = UserDefaults(suiteName: Character.appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetState.self, from: data)
    }
}
