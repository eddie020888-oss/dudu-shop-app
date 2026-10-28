import SwiftUI
import UserNotifications

/// 嘟嘟星来信：陪伴到第 3、7、14、21、30、45、60、100 天，灵动岛那道"门"那边寄来一封信 + 一点小礼物。
/// 信是嘟嘟语写的——它会说到哪，就能给你翻译到哪：只会嘟嘟时只能念，会单词时念出几个词，会短句以后整封读给你听。
/// 以前看不懂的信，等它会说话了再打开，就能听懂了。谁写的不揭晓（设定第 9 节：第一版只给线索）。
struct DuduLetter: Identifiable {
    let id: Int          // 第几天
    let dudu: String
    let words: [String]  // 单词期能念出来的几个词
    let zh: String
    let en: String
    var food: String? = nil
    var coins: Int = 0
    /// 1000 以上是嘟嘟小店每章装修完寄来的
    var title: String { id > 1000 ? T("嘟嘟小店 · 第{0}章之后", id - 1000) : T("第 {0} 天", id) }
}

@MainActor
final class LetterStore: ObservableObject {
    static let all: [DuduLetter] = [
        DuduLetter(id: 3, dudu: T("嘟嘟？嘟。嘟嘟嘟～ 嘟。"), words: [T("到了"), T("睡")],
                   zh: T("到了吗？到了就好。那边的床软不软？记得多睡。"), en: "Did you arrive? Good. Is the bed soft there? Sleep plenty.",
                   food: "riceball"),
        DuduLetter(id: 7, dudu: T("嘟嘟嘟。嘟——嘟？嘟嘟，嘟。"), words: [T("一周"), T("胖")],
                   zh: T("一周了。那边的人对你好吗？……看信号，你胖了一点。应该挺好。"), en: "A week now. Are they kind to you? …the signal says you got a bit rounder. Must be good.",
                   coins: 10),
        DuduLetter(id: 14, dudu: T("嘟～嘟嘟。嘟嘟嘟嘟，嘟！"), words: [T("草"), T("亮")],
                   zh: T("家里的发光草开花了，碰一下就亮。你还在壳里的时候，就总往那边滚。"), en: "The glow-grass at home is blooming. Touch it and it lights up. You kept rolling toward it, even inside your shell.",
                   food: "goji"),
        DuduLetter(id: 21, dudu: T("嘟。嘟嘟嘟嘟嘟……嘟。"), words: [T("躺"), T("也行")],
                   zh: T("别老躺着。……算了，躺着也行，我们这边都这样。"), en: "Don't lie around all day. …never mind, lying around is fine. We all do it here.",
                   coins: 10),
        DuduLetter(id: 30, dudu: T("嘟嘟嘟嘟。嘟嘟，嘟嘟嘟。✦"), words: [T("一个月"), T("谢谢")],
                   zh: T("一个月了。替我们谢谢照顾你的人。（信纸背面画了一个星星，和蛋壳上那个一模一样。）"), en: "A month already. Thank the one looking after you for us. (On the back: a star, exactly like the one on your shell.)",
                   food: "cake"),
        DuduLetter(id: 45, dudu: T("嘟嘟～嘟？嘟嘟嘟。"), words: [T("星星"), T("看见")],
                   zh: T("最近夜里，天上最亮的那颗星换了位置。你那边能看见吗？"), en: "Lately the brightest star moved. Can you see it from there?",
                   coins: 15),
        DuduLetter(id: 60, dudu: T("嘟。嘟嘟嘟嘟嘟嘟。嘟！"), words: [T("蛋"), T("动了")],
                   zh: T("有一颗蛋也开始动了，花纹跟你那颗一样。先别告诉别人。"), en: "Another egg started moving. Same pattern as yours. Don't tell anyone yet.",
                   food: "popcorn"),
        DuduLetter(id: 100, dudu: T("嘟嘟嘟。嘟嘟……嘟嘟嘟嘟。♡"), words: [T("一百天"), T("家")],
                   zh: T("一百天了。你在那边有家了。……我们都知道。"), en: "A hundred days. You have a home there now. …we all know.",
                   food: "cake", coins: 20),
    ] + shop

    /// 嘟嘟小店：每章装修完，门那边寄来一封（接那一章的线索，只给线索不揭晓）
    static let shop: [DuduLetter] = [
        DuduLetter(id: 1001, dudu: T("嘟嘟？嘟嘟嘟。嘟。"), words: [T("饭团"), T("亮")],
                   zh: T("饭团收到了。饭团湾，好久没亮过了。——饭团湾的一个人"), en: "The rice ball arrived. Riceball Bay hasn't glowed in a long time. —someone from Riceball Bay", coins: 15),
        DuduLetter(id: 1002, dudu: T("嘟嘟嘟……嘟嘟。✦"), words: [T("菜谱"), T("还在")],
                   zh: T("菜谱还在？那就好。"), en: "The recipe's still there? Good.", food: "riceball"),
        DuduLetter(id: 1003, dudu: T("嘟！嘟嘟嘟嘟，嘟。"), words: [T("招牌"), T("歪")],
                   zh: T("听说又开张了。招牌挂歪了吧？它以前也说，歪着才有个性。"), en: "We hear you're open again. The sign's crooked, isn't it? It always said crooked has character.", coins: 20),
        DuduLetter(id: 1004, dudu: T("嘟嘟？嘟——嘟嘟嘟。✦"), words: [T("等"), T("不急")],
                   zh: T("店先关着。不急，你那边一个月，我们这边才一天。"), en: "The shop stays closed for now. No hurry. A month for you is one day for us.", food: "goji"),
        DuduLetter(id: 1005, dudu: T("嘟嘟嘟～嘟嘟！"), words: [T("草"), T("种子")],
                   zh: T("发光草种活了？那是总店门口那盆的种子。它要是不浇水，你替它浇。"), en: "The glow-grass took root? Those seeds came from the pot by the main shop's door. If it forgets to water them, you do it.", coins: 20),
        DuduLetter(id: 1006, dudu: T("嘟。嘟嘟……嘟嘟嘟。"), words: [T("门"), T("一封")],
                   zh: T("你看到门了。每晚只开一下，够塞一封信，也够送一碗饭。够了。"), en: "You've seen the door. It opens once a night, wide enough for a letter, and for a bowl of food. That's enough.", food: "cake"),
        DuduLetter(id: 1007, dudu: T("嘟嘟嘟嘟。嘟～"), words: [T("茶叶"), T("不急")],
                   zh: T("那罐会发光的茶叶，是回家用的。……不过不着急，一点都不急。"), en: "The glowing tea is for going home. …but there's no hurry. None at all.", coins: 25),
        DuduLetter(id: 1008, dudu: T("嘟嘟？嘟嘟嘟嘟嘟。"), words: [T("地图"), T("抬头")],
                   zh: T("另外半张地图，在你们一抬头就能看见的地方。"), en: "The other half of the map is somewhere you can see just by looking up.", food: "popcorn"),
        DuduLetter(id: 1009, dudu: T("嘟嘟嘟！嘟嘟。♡"), words: [T("店"), T("光")],
                   zh: T("望远镜里看到店了吧。窗户那点光，是我。还亮着。"), en: "You saw the shop through the telescope. That little light in the window is me. Still on.", coins: 25),
        DuduLetter(id: 1010, dudu: T("嘟嘟嘟嘟。嘟嘟嘟。✦"), words: [T("推"), T("知道")],
                   zh: T("是我推的。别告诉它。……它肯定已经知道了。"), en: "I'm the one who nudged it. Don't tell it. …it already knows, doesn't it.", food: "cake"),
        DuduLetter(id: 1011, dudu: T("嘟嘟……嘟嘟嘟嘟嘟。"), words: [T("光"), T("一起")],
                   zh: T("别担心光。光是我们一起亮的，分一点过去，不算暗。"), en: "Don't worry about the light. We make it together; sending some your way doesn't make us dark.", coins: 30),
        DuduLetter(id: 1012, dudu: T("嘟。嘟嘟嘟嘟嘟嘟……嘟。♡"), words: [T("分店"), T("钱")],
                   zh: T("看见它了。胖了。分店交给你们了。别让它当收银员，它会把钱都放肚子上。"), en: "We saw it. It's gotten rounder. The branch is yours now. Don't let it be the cashier—it'll keep all the coins on its tummy.", food: "cake", coins: 50),
        DuduLetter(id: 1013, dudu: T("嘟嘟？嘟嘟嘟～ ❄"), words: [T("帽子"), T("肚子")],
                   zh: T("帽子是它以前那顶，我改小了。……它肯定放肚子上了。"), en: "That's its old hat; I took it in. …it's on its tummy, isn't it.", food: "goji", coins: 30),
        DuduLetter(id: 1014, dudu: T("嘟嘟嘟嘟。嘟。♡ ❄"), words: [T("明年"), T("一起")],
                   zh: T("明年也一起过吧。另一颗蛋的事，等它自己说。——总店"), en: "Spend next year together too. As for the other egg—let it tell you itself. —the main shop", food: "cake", coins: 60),
    ]

    /// 嘟嘟小店装修完第 k 章，寄一封（只寄一次）
    @discardableResult
    func deliverShop(chapter k: Int) -> DuduLetter? {
        guard let l = Self.shop.first(where: { $0.id == 1000 + k }), received[l.id] == nil else { return nil }
        received[l.id] = Date()
        unread.insert(l.id)
        save()
        Analytics.log("letter_arrived", ["day": "\(l.id)"])
        return l
    }

    /// 收到的信：第几天 → 收到时间
    @Published private(set) var received: [Int: Date] = [:]
    @Published private(set) var unread: Set<Int> = []
    @Published private(set) var gifted: Set<Int> = []
    private let d = UserDefaults.standard

    init() {
        if let data = d.data(forKey: "letters.v1"), let r = try? JSONDecoder().decode([Int: Date].self, from: data) { received = r }
        unread = Set(d.array(forKey: "letters.unread") as? [Int] ?? [])
        gifted = Set(d.array(forKey: "letters.gifted") as? [Int] ?? [])
    }

    var letters: [DuduLetter] { Self.all.filter { received[$0.id] != nil } }
    var firstUnread: DuduLetter? { Self.all.first { unread.contains($0.id) } }

    /// 到日子的信寄到（一次最多寄一封，补寄的下次打开再来）；返回新到的
    @discardableResult
    func deliver(days: Int) -> DuduLetter? {
        guard let l = Self.all.first(where: { $0.id <= days && received[$0.id] == nil }) else { return nil }
        received[l.id] = Date()
        unread.insert(l.id)
        save()
        Analytics.log("letter_arrived", ["day": "\(l.id)"])
        return l
    }

    /// 收下信里夹的礼物（只能收一次）
    func claim(_ l: DuduLetter) -> Bool {
        guard received[l.id] != nil, gifted.insert(l.id).inserted else { return false }
        save()
        return true
    }

    func open(_ l: DuduLetter) {
        guard unread.remove(l.id) != nil else { return }
        save()
        Analytics.log("letter_opened", ["day": "\(l.id)"])
    }

    /// 下一封信那天早上 10 点（安静时段顺延）轻轻提醒一次
    func scheduleNext(hatchDate: Date?) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["letter.next"])
        guard let h = hatchDate, Quiet.level != .low,
              let next = Self.all.first(where: { $0.id < 1000 && received[$0.id] == nil }) else { return }
        let start = Calendar.current.startOfDay(for: h)
        guard let day = Calendar.current.date(byAdding: .day, value: next.id - 1, to: start),
              var at = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: day) else { return }
        at = Quiet.push(at)
        guard at > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = T("嘟嘟星来信了")
        content.body = T("门那边寄来一封信，它在等你一起拆。")
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        c.add(UNNotificationRequest(identifier: "letter.next", content: content,
                                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(received) { d.set(data, forKey: "letters.v1") }
        d.set(Array(unread), forKey: "letters.unread")
        d.set(Array(gifted), forKey: "letters.gifted")
    }

    /// 它能给你读到哪
    static func reading(_ l: DuduLetter, route: LangRoute, stage: Int) -> (title: String, body: String) {
        if route == .dudu {
            return stage >= 2 ? (T("它抱着信比划给你看"), T("（好像是说：{0}）", l.zh))
                              : (T("它抱着信念了一遍"), T("{0}\n\n（它念得很认真。等它更懂你一点，也许能比划给你看。）", l.dudu))
        }
        let full = route == .en ? l.en : l.zh
        switch stage {
        case 0:  return (T("它只会念"), T("{0}\n\n（它看了半天，只会嘟嘟。等它会说话了，再打开这封信。）", l.dudu))
        case 1:  return (T("它念出了几个词"), "\(l.dudu)\n\n“……" + l.words.joined(separator: "……") + "……”")
        default: return (T("它读给你听"), full)
        }
    }
}

/// 首页那张"来信了"小卡片
struct LetterBanner: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill").font(.system(size: 18)).foregroundStyle(Color(hex: "#A8E6FF"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("嘟嘟星来信了")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(T("门那边寄来的，一起拆开看看")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                }
                Spacer()
                Text(T("拆开 ›")).font(.system(size: 13)).foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                LinearGradient(colors: [Color(hex: "#3A2A6E"), Color(hex: "#241848")], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#A8E6FF").opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.press)
    }
}

/// 拆信
struct LetterView: View {
    let letter: DuduLetter
    let route: LangRoute
    let stage: Int
    let petName: String
    var gifted: Bool = true
    var claim: (() -> Void)? = nil      // 回忆页里重读时不显示礼物
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let r = LetterStore.reading(letter, route: route, stage: stage)
        ScrollView {
            VStack(spacing: 18) {
                Text("✦").font(.system(size: 34)).foregroundStyle(Color(hex: "#A8E6FF"))
                    .shadow(color: Color(hex: "#A8E6FF").opacity(0.6), radius: 10)
                    .padding(.top, 28)
                Text(T("{0} · 嘟嘟星", letter.title)).font(.system(size: 13)).foregroundStyle(Theme.text3)
                VStack(alignment: .leading, spacing: 10) {
                    Text(r.title).font(.system(size: 12)).foregroundStyle(Theme.text3)
                    Text(r.body).font(.system(size: 17)).lineSpacing(6).foregroundStyle(Color(hex: "#2A2140"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(Color(hex: "#F3EEFF"), in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 20)

                if let claim, letter.food != nil || letter.coins > 0 {
                    let f = letter.food.flatMap(Food.by)
                    let gift = [f.map { "\($0.emoji) \($0.name)" }, letter.coins > 0 ? T("{0} 币", letter.coins) : nil].compactMap { $0 }.joined(separator: " + ")
                    Button {
                        claim()
                    } label: {
                        Text(gifted ? T("已收下：{0}", gift) : T("信里还夹着：{0} · 收下", gift))
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .disabled(gifted)
                    .padding(.horizontal, 20)
                }
                Button(T("放回信封")) { dismiss() }
                    .font(.system(size: 14)).foregroundStyle(Theme.text3)
                    .padding(.bottom, 30)
            }
        }
        .background(Theme.ground.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
