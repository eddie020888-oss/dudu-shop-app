import ActivityKit
import Foundation

// MARK: - 动作枚举（App 与 Widget 共用）

enum Pose: String, Codable, CaseIterable, Hashable {
    case stand, walk, run, phone, work, movie, eat, sleep
    case wash, coffee, gym, read, wake   // 作息动作（v2 新增）
    case drive                          // 在车上（CarPlay 连接 / 开车中）
    case music, dance, call, charge, type   // 实时互动：戴耳机听歌 / 外放跳舞 / 打电话 / 充电 / 你在聊天页打字
    case study, ball, paint, uke            // 小紫自己的生活：上学 / 打篮球 / 画画 / 弹尤克里里

    var label: String {
        switch self {
        case .stand: return T("站立")
        case .walk:  return T("走路")
        case .run:   return T("跑步")
        case .phone: return T("看手机")
        case .work:  return T("工作")
        case .movie: return T("看电影")
        case .eat:   return T("吃饭")
        case .sleep: return T("睡觉")
        case .wash:  return T("洗漱")
        case .coffee: return T("喝咖啡")
        case .gym:   return T("健身")
        case .read:  return T("看书")
        case .wake:  return T("起床")
        case .drive: return T("坐车")
        case .music: return T("听歌")
        case .dance: return T("跳舞")
        case .call:  return T("打电话")
        case .charge: return T("充电")
        case .type:  return T("打字")
        case .study: return T("上学")
        case .ball:  return T("打篮球")
        case .paint: return T("画画")
        case .uke:   return T("弹琴")
        }
    }
}

// MARK: - 人物外观（App Group 持久化，Widget 读取）

struct Character: Codable, Equatable, Hashable {
    enum Gender: String, Codable { case male, female }

    var pet: String = "purple"      // 当前角色 id（Asset 前缀），见 ASSET_SPEC.md
    var gender: Gender = .male
    var heightCM: Double = 175       // 150–195
    var build: Double = 0.4          // 0 瘦 – 1 胖
    var hair: Double = 0.5
    var nose: Double = 0.5           // 鼻梁高低
    var jaw: Double = 0.5            // 下颚骨方圆
    var shoulder: Double = 0.5
    var backgroundHex: String = "#000000"
    var figureHex: String = "#FFFFFF"
    var accessories: [String]? = nil   // 正在戴的配饰 id（可选：旧数据没有这个字段）

    static let appGroup = "group.com.eddiejiang.islandme"   // v1 未启用 App Groups；UserDefaults(suiteName:) 在无权限时自动退化为本 App 私有存储
    private static let key = "character.v1"

    static func load() -> Character {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key),
              var c = try? JSONDecoder().decode(Character.self, from: data) else { return Character() }
        c.pet = "purple"          // 只保留小紫一个角色；旧存档里选过别的也统一回小紫
        return c
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Character.appGroup)?.set(data, forKey: Character.key)
    }
}

// MARK: - Live Activity 属性

struct IslandMeAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var pose: Pose
        var since: Date          // 该动作开始时间，展开视图显示时长
        var character: Character // 随状态一起传，避免 Widget 读盘时序问题
        var lastLine: String = "" // 小人最近说的一句，岛台展开态显示
        var frame: String = ""    // 临时覆盖帧："blink" / "yawn"，空 = 按动作显示
        var tick: Int = 0         // 自增即触发一次“呼吸”弹跳过场动画
        var need: String = ""     // 当前最急的需求 Need.rawValue；非空时岛台优先显示需求而不是动作
        var shopAt: Date? = nil   // 嘟嘟小店：下一件「好了」的事（菜出锅 / 宝箱 / 产出器满 / 它的饭点）
        var shopIcon: String? = nil
        var shopLine: String? = nil
        // 嘟嘟小店的店面（岛台像一个小橱窗：它在柜台后面，几单在等）
        var shopOpen: Bool? = nil        // 开过店：岛台平时就显示店面
        var shopTickets: Int? = nil      // 还有几张外卖/堂食单在等
        var shopSign: Int? = nil         // 0 纸板招牌，1 真招牌
    }
    var startedAt: Date
}
