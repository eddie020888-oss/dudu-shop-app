import Foundation
import SwiftUI

/// iCloud 存档（2026-10-22）：不用自己的服务器。
/// 把本地存档（嘟嘟、小店、钱包、信、贴纸……都在 UserDefaults 里）打包压缩，放进 iCloud 键值存储（同一个 Apple ID 的设备共享）。
/// - 什么时候存：App 退到后台时、在前台每 5 分钟一次
/// - 什么时候取：新装 / 换手机，本地还没孵出嘟嘟、iCloud 里有存档 → 问一句要不要恢复，恢复后整个界面重新加载
/// - 两台手机都在玩：以最后一次存的为准（整份覆盖，不合并）
enum CloudSave {
    private static let kv = NSUbiquitousKeyValueStore.default
    private static let dataKey = "save.v1"
    private static let metaKey = "save.meta.v1"

    /// 要存的 key（前缀）。系统和苹果自己的 key 不碰；灵动岛、小组件这种跟设备走的也不存
    private static let prefixes = ["merge.", "mk.", "bond.", "profile.", "wallet.", "petneeds.", "intimacy.", "character.", "routine.",
                                   "letters.", "stickers.", "stars.", "wish.", "life.", "meals.", "companion.", "age.", "gaze.", "quiet.",
                                   "notify.", "onboarded.", "rescue.", "gc.", "iap.", "share.", "health.lastWorkoutEnd"]
    private static let skip = ["mk.haptics", "mk.sfx", "mk.music", "mk.ignoreSilent"]   // 声音、震动跟着这台手机

    struct Meta: Codable, Equatable { let date: Date; let level: Int; let days: Int; let device: String }

    private static var domains: [(String, UserDefaults)] {
        [("std", .standard)] + (UserDefaults(suiteName: Character.appGroup).map { [("group", $0)] } ?? [])
    }

    // MARK: 存
    static func backup() {
        guard !MKDemo.on, !Shot.on, !localIsFresh() else { return }
        var all: [String: [String: Any]] = [:]
        for (name, d) in domains {
            all[name] = d.dictionaryRepresentation().filter { k, _ in
                prefixes.contains { k.hasPrefix($0) } && !skip.contains(k)
            }
        }
        guard let plist = try? PropertyListSerialization.data(fromPropertyList: all, format: .binary, options: 0),
              let packed = try? (plist as NSData).compressed(using: .zlib) as Data,
              packed.count < 900_000 else { return }          // 一个 key 最多 1MB
        kv.set(packed, forKey: dataKey)
        let meta = Meta(date: Date(), level: UserDefaults.standard.integer(forKey: "merge.level"), days: daysTogether(), device: UIDevice.current.name)
        if let m = try? JSONEncoder().encode(meta) { kv.set(m, forKey: metaKey) }
        kv.synchronize()
        UserDefaults.standard.set(Date(), forKey: "cloud.lastBackup")
    }

    static var lastBackup: Date? { UserDefaults.standard.object(forKey: "cloud.lastBackup") as? Date }

    // MARK: 取
    static func cloudMeta() -> Meta? {
        guard kv.data(forKey: dataKey) != nil, let m = kv.data(forKey: metaKey) else { return nil }
        return try? JSONDecoder().decode(Meta.self, from: m)
    }

    /// 把 iCloud 里的存档写回本地（覆盖）。调用后要重新加载界面
    @discardableResult
    static func restore() -> Bool {
        guard let packed = kv.data(forKey: dataKey),
              let plist = try? (packed as NSData).decompressed(using: .zlib) as Data,
              let all = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: [String: Any]] else { return false }
        for (name, d) in domains {
            for (k, v) in all[name] ?? [:] { d.set(v, forKey: k) }
        }
        UserDefaults.standard.set(true, forKey: "onboarded.v1")
        UserDefaults.standard.set(Date(), forKey: "cloud.lastBackup")
        Analytics.log("cloud_restore", [:])
        return true
    }

    /// 本地还是新的：没孵出嘟嘟、也没开过小店
    static func localIsFresh() -> Bool {
        if UserDefaults.standard.data(forKey: MKState.key) != nil { return false }
        return daysTogether() == 0 && !hatched()
    }
    private static func bondJSON() -> [String: Any]? {
        UserDefaults.standard.data(forKey: "bond.v1").flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
    private static func hatched() -> Bool { (bondJSON()?["hatched"] as? Bool) ?? false }
    private static func daysTogether() -> Int {
        guard let t = bondJSON()?["hatchDate"] as? Double else { return 0 }
        let date = Date(timeIntervalSinceReferenceDate: t)
        return max(1, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0) + 1)
    }
}

/// 最外层：负责「iCloud 里有存档，要不要恢复」；恢复后换一个 id，整个界面（所有 StateObject）重新从存档加载
struct CloudRoot: View {
    @State private var gen = 0
    @State private var offer: CloudSave.Meta? = nil
    @Environment(\.scenePhase) private var phase
    private let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    var body: some View {
        ContentView()
            .id(gen)
            .onAppear { if UserDefaults.standard.object(forKey: "review.firstOpen") == nil { UserDefaults.standard.set(Date(), forKey: "review.firstOpen") }; IAP.shared.start(); NSUbiquitousKeyValueStore.default.synchronize(); check() }
            .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in check() }
            .onReceive(timer) { _ in if phase == .active { CloudSave.backup() } }
            .onChange(of: phase) { _, p in if p != .active { CloudSave.backup() } }
            .alert(T("找到 iCloud 里的进度"), isPresented: Binding(get: { offer != nil }, set: { if !$0 { offer = nil } })) {
                Button(T("恢复进度")) {
                    if CloudSave.restore() { gen += 1 }
                    offer = nil
                }
                Button(T("重新开始"), role: .cancel) {
                    UserDefaults.standard.set(true, forKey: "cloud.declined")
                    offer = nil
                }
            } message: {
                if let m = offer {
                    Text(T("{0} 存的：嘟嘟陪了你 {1} 天，小店 {2} 级（来自「{3}」）。恢复后接着玩；选「重新开始」会在下次存档时覆盖 iCloud 里的这份。",
                           m.date.formatted(date: .abbreviated, time: .shortened), m.days, m.level, m.device))
                }
            }
    }

    private func check() {
        guard !MKDemo.on, !Shot.on, offer == nil, !UserDefaults.standard.bool(forKey: "cloud.declined"),
              CloudSave.localIsFresh(), let m = CloudSave.cloudMeta() else { return }
        offer = m
    }
}
