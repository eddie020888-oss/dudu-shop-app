import Foundation

/// 2026-10-20 开通 App Group（group.com.eddiejiang.islandme）。
/// 以前没开通时，UserDefaults(suiteName:) 存在 App 自己的 Library/Preferences/group.com.eddiejiang.islandme.plist；
/// 开通以后同一个名字会指到共享容器里，旧数据（币、背包、名字、需求、作息……）读不到了。
/// 第一次启动把旧文件里的键搬过去（共享容器里已经有的不覆盖），只搬一次。
enum GroupMigration {
    static func run() {
        guard let g = UserDefaults(suiteName: Character.appGroup), !g.bool(forKey: "group.migrated.v1") else { return }
        let path = NSHomeDirectory() + "/Library/Preferences/" + Character.appGroup + ".plist"
        if let old = NSDictionary(contentsOfFile: path) as? [String: Any] {
            for (k, v) in old where g.object(forKey: k) == nil { g.set(v, forKey: k) }
        }
        g.set(true, forKey: "group.migrated.v1")
    }
}
