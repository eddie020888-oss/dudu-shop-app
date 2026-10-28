import Foundation
import UserNotifications

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case me, bot }
    var id = UUID()
    var role: Role
    var text: String
    var at: Date = Date()
    var frame: String? = nil     // 表情包帧名（happy/cry/think…），nil = 不带表情
}

/// 聊天记录 + 回复逻辑。先用本地规则，后续把 `reply(to:)` 换成调 LLM。
@MainActor
final class ChatStore: ObservableObject {
    static var petName = T("嘟嘟")      // 通知标题用；由“我”页设置
    @Published private(set) var messages: [ChatMessage] = []
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = dir.appendingPathComponent("chat.json")
        if let d = try? Data(contentsOf: url), let m = try? JSONDecoder().decode([ChatMessage].self, from: d) {
            messages = m
        } else {
            messages = [ChatMessage(role: .bot, text: T("我是你，缩小版。你动我就动。"))]
        }
    }

    /// 最近一条小人说的话，给岛台展开态显示
    var lastBotLine: String { messages.last(where: { $0.role == .bot })?.text ?? "" }

    func send(_ text: String, pose: Pose) async {
        append(ChatMessage(role: .me, text: text))
        try? await Task.sleep(for: .milliseconds(600))
        append(ChatMessage(role: .bot, text: reply(to: text, pose: pose), frame: Self.sticker(for: text)))
    }

    /// 根据你说的话挑一张表情包（之后换 LLM 时让模型直接输出 frame 名）
    static func sticker(for text: String) -> String? {
        let t = text.lowercased()
        func has(_ ws: [String]) -> Bool { ws.contains { t.contains($0) } }
        if has(["生日", "恭喜", "庆祝", "成功", "通过了", "发财", "birthday", "congrats", "yay", "passed"]) { return "party" }
        if has(["哈哈", "笑死", "lol", "233", "haha"]) { return "laugh" }
        if has(["爱你", "喜欢你", "真棒", "好乖", "可爱", "乖", "love you", "good boy", "good girl", "cute", "good job"]) { return "happy" }
        if has(["谢谢", "辛苦", "thank", "thanks"]) { return "shy" }
        if has(["笨", "滚", "讨厌", "闭嘴", "烦", "stupid", "shut up", "hate", "annoying"]) { return "cry" }
        if has(["生气", "气死", "不爽", "angry", "mad"]) { return "angry" }
        if has(["什么", "真的", "啊?", "啊？", "!!", "！！", "what", "really", "whoa"]) { return "surprised" }
        if has(["?", "？", "怎么", "为什么", "吗", "how", "why"]) { return "think" }
        return nil
    }

    /// 岛台右耳显示的那句话：动作变化只改这里，不进聊天、不弹通知
    @Published private(set) var islandLine: String = ""

    /// 动作变化：只小声嘀咕一句给岛台看，不发消息
    func mutter(for pose: Pose) {
        islandLine = Voice.pose(pose)      // 按路线/阶段：嘟语 → 单词 → 碎碎念
    }
    /// 嘀咕指定的一句（戳它 / 自发小动作），不进聊天记录
    func mutter(_ line: String) { islandLine = line; Self.lastLineForShare = line }
    /// 分享卡片用：它最近说的一句
    static var lastLineForShare: String {
        get { UserDefaults.standard.string(forKey: "share.line") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "share.line") }
    }

    /// 让它说一句指定的话（需求 / 照顾后的反馈 / 作息 / 问候）；notify 才弹通知
    func say(_ line: String, notify: Bool = true, frame: String? = nil) {
        append(ChatMessage(role: .bot, text: line, frame: frame))
        islandLine = line; Self.lastLineForShare = line
        guard notify else { return }
        let content = UNMutableNotificationContent()
        content.title = Self.petName
        content.body = line
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func append(_ m: ChatMessage) {
        messages.append(m)
        if messages.count > 500 { messages.removeFirst(messages.count - 500) }
        if let d = try? JSONEncoder().encode(messages) { try? d.write(to: url) }
    }

    // MARK: 本地规则回复（占位，之后换成 LLM：把 pose / 步数 / 时间作为上下文传入）

    /// 先按"听懂"规则回：叫名字 → 关键词 → 能说话的阶段才回答时间/动作 → 兜底。
    /// 说什么、说几个字由路线（中/英/嘟嘟）和阶段决定（Voice）。之后接 Claude 也走同样的阶段限制。
    private func reply(to text: String, pose: Pose) -> String {
        let bond = BondStore.shared
        bond.add(.chat)
        let t = text.lowercased()
        let name = Self.petName.lowercased()
        if !name.isEmpty, t.contains(name) {
            NotificationCenter.default.post(name: Notification.Name("calledName"), object: nil)
            if bond.consumeHeardName() { return Voice.line("kw.name", mood: .excited) }
            if Voice.stage >= 1 { return Voice.line("kw.name", mood: .happy) }
        }
        if let c = AgeCare.cheer(for: text) { return c }
        if let k = Keyword.match(text) {
            Analytics.log("kw", ["k": k.rawValue])
            return Voice.line("kw." + k.rawValue, mood: k.mood)
        }
        let talks = Voice.route.speaks && Voice.stage >= 2
        if talks && (t.contains("几点") || t.contains("时间") || t.contains("time")) {
            return (Voice.route == .en ? "It's " : T("现在 ")) + Date().formatted(date: .omitted, time: .shortened) + (Voice.route == .en ? "." : T("。"))
        }
        if talks && Voice.route == .zh && Voice.stage >= 3 && Bool.random() {
            return Self.lines[pose]!.randomElement()!
        }
        return Voice.line("chat.fallback")
    }

    /// 碎嘴子（2026-10-17）：它的内心独白，懒、嘴馋、嘴上养生、爱给自己找理由。
    /// 打趣只冲自己，不数落你、不催你；放在岛台右耳和首页那句话里，不发通知。
    static let lines: [Pose: [String]] = [
        .walk:  [T("你走你的，我负责精神支持。"), T("你每走一步，我就多躺一秒，很公平。"), T("走路这种事，交给有腿的人。哦，我也有。算了。")],
        .run:   [T("你跑，我在心里替你喘。"), T("跑这么快干嘛，饭又不会跑。"), T("我宣布你今天是冠军，我是观众。")],
        .phone: [T("你刷你的，我看你刷，挺好。"), T("这条好笑吗？给我也看看。"), T("低头族遇上躺平族，绝配。")],
        .work:  [T("看你忙得我都累了，我先躺会儿。"), T("你上班，我上床，分工明确。"), T("加油，我负责在旁边打哈欠。")],
        .movie: [T("爆米花呢？没爆米花的电影没有灵魂。"), T("这个反派我早看出来了。真的。"), T("窝着，谁也别叫我。")],
        .eat:   [T("吃什么呢？分我一口，就一口。"), T("吃饭要慢，我一向很慢，所以我很健康。"), T("这顿有菜吗？我是说替你问的。")],
        .sleep: ["Zzz……", T("睡觉是最好的养生，我是专业的。"), T("别叫我，我在梦里吃东西。")],
        .stand: [T("站着多累，坐下聊。"), T("我在，说吧，说完我好接着躺。"), T("发呆也算休息，我常干。")],
        .wash:  [T("洗干净了？我就不洗了，我天生干净。"), T("泡泡泡泡……我替你数到二十。")],
        .coffee: [T("咖啡里泡枸杞，养生两不误。"), T("第一口最香，第二口也香，第三口也……")],
        .gym:   [T("你练，我看，我也算参与了。"), T("看你运动我都出汗了，心理上。")],
        .read:  [T("这页讲啥？算了别说，我看个封面就够了。"), T("安静看书，我负责安静。")],
        .wake:  [T("早……再给我五分钟，五个五分钟。"), T("你起你的，我还在开机。")],
        .drive: [T("你开车，我坐副驾，不说话，偶尔说。"), T("到了叫我，没到也别叫。"), T("开慢点，我的零食会洒。")],
        .music: [T("这首好听，我在心里跳了。"), T("耳机分我一只？算了我耳朵在头顶。"), T("单曲循环中，我也循环躺着。")],
        .dance: [T("你跳，我扭一下屁股，就一下。"), T("这节奏……我坐着也能晃。"), T("跳舞好累，我选择点头。")],
        .call:  [T("嘘，你在打电话，我在偷听。"), T("谁打来的？问问他吃了没。"), T("我也在通话中……跟枕头。")],
        .charge: [T("你充电，我也充电，躺着充。"), T("插着线不能乱跑，正合我意。"), T("电满了叫我，我还没满。")],
        .type:  ["……", T("你打字，我在旁边认真地看着，真的。"), T("写啥呢？写我好看点。")],
        .study: [T("在上课……其实在打瞌睡。")],
        .ball:  [T("嘟…不想动。")],
        .paint: [T("在涂……涂歪了。")],
        .uke:   PetActivity.uke.busyLines,
    ]
}
