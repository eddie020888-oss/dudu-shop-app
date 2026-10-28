import SwiftUI
import Foundation

/// 「今天陪你」：不是任务，是你想让它陪你做的事。
/// 用户自己挑想被陪的事（"我"页面），每天从里面抽 3 件；能自动知道的自动打勾，
/// 知道不了的（吃饭、喝水、早睡…）点一下"做了"就算。没做完不罚、不催。
enum CompanionItem: String, CaseIterable, Codable, Identifiable {
    // 自动知道的
    case walk, workout, wakeOnTime, feed, play, chat, islandPet, callName
    // 你说做了就算
    case lunch, dinner, water, earlySleep, standUp, breakfast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walk:       return T("一起走 3000 步")
        case .workout:    return T("动一动（任何运动）")
        case .wakeOnTime: return T("按时起床来看看它")
        case .feed:       return T("喂它两口")
        case .play:       return T("陪它玩一局")
        case .chat:       return T("跟它说三句话")
        case .islandPet:  return T("在灵动岛上摸它一下")
        case .callName:   return T("叫一次它的名字")
        case .breakfast:  return T("吃早饭")
        case .lunch:      return T("按点吃午饭")
        case .dinner:     return T("吃晚饭")
        case .water:      return T("喝杯温水")
        case .earlySleep: return T("早点睡")
        case .standUp:    return T("起来走两步")
        }
    }
    /// 它在旁边说的（养生家 + 懒）
    var hint: String {
        switch self {
        case .walk:       return T("你走，我在口袋里替你数。")
        case .workout:    return T("你动，我看着。")
        case .wakeOnTime: return T("你先起，我再赖一会儿。")
        case .feed:       return T("饿……")
        case .play:       return T("就一局。")
        case .chat:       return T("说点什么，我听着。")
        case .islandPet:  return T("顶上那个是我。")
        case .callName:   return T("叫我。")
        case .breakfast:  return T("空肚子不行，我也吃。")
        case .lunch:      return T("饭点到了，一起。")
        case .dinner:     return T("晚饭清淡点，睡得香。")
        case .water:      return T("保温杯里还有，我分你。")
        case .earlySleep: return T("我已经躺好了。")
        case .standUp:    return T("你走两步，我替你躺着。")
        }
    }
    var symbol: String {
        switch self {
        case .walk: return "figure.walk"
        case .workout: return "figure.mixed.cardio"
        case .wakeOnTime: return "sunrise.fill"
        case .feed: return "fork.knife"
        case .play: return "gamecontroller.fill"
        case .chat: return "bubble.left.fill"
        case .islandPet: return "hand.wave.fill"
        case .callName: return "ear"
        case .breakfast, .lunch, .dinner: return "takeoutbag.and.cup.and.straw.fill"
        case .water: return "cup.and.saucer.fill"
        case .earlySleep: return "moon.zzz.fill"
        case .standUp: return "figure.stand"
        }
    }
    /// 需要几次才算（自动的）
    var goal: Int {
        switch self { case .walk: return 3000; case .feed: return 2; case .chat: return 3; default: return 1 }
    }
    /// 用户自己点"做了"
    var selfReport: Bool {
        switch self { case .lunch, .dinner, .water, .earlySleep, .standUp, .breakfast: return true; default: return false }
    }
    /// 一天里什么时候出现合适（饭点类只在对应时间段之后能点）
    func available(hour h: Int, wakeHour: Int, sleepHour: Int) -> Bool {
        switch self {
        case .breakfast:  return h < 11
        case .lunch:      return h >= 11
        case .dinner:     return h >= 17
        case .earlySleep: return h >= max(sleepHour - 2, 18)
        case .wakeOnTime: return true
        default:          return true
        }
    }
    /// 默认大家都想要的
    static let defaults: [CompanionItem] = [.walk, .feed, .chat, .lunch, .water, .play, .islandPet, .earlySleep]
}

struct CompanionDay: Codable {
    var day = ""
    var picks: [CompanionItem] = []
    var progress: [String: Int] = [:]
    var done: [String] = []
    var bonusGiven = false
}

@MainActor
final class CompanionStore: ObservableObject {
    @Published private(set) var today = CompanionDay()
    @Published var chosen: [CompanionItem] { didSet { saveChosen() } }
    /// 刚完成一件 → 首页说一句
    @Published var justDone: CompanionItem? = nil
    /// 三件都做完 → 嘟嘟星包裹
    @Published var bonusReady = false

    private let d = UserDefaults.standard

    init() {
        let ids = UserDefaults.standard.stringArray(forKey: "companion.chosen")
        chosen = ids?.compactMap(CompanionItem.init(rawValue:)) ?? CompanionItem.defaults
        if let data = d.data(forKey: "companion.day"), let t = try? JSONDecoder().decode(CompanionDay.self, from: data) { today = t }
    }

    /// 每天第一次打开（或过了零点）抽 3 件：尽量 1 件生活 + 1 件照顾它 + 1 件随意
    func roll(wakeHour: Int, sleepHour: Int, force: Bool = false) {
        let day = Wallet.day()
        guard force || today.day != day || today.picks.isEmpty else { return }
        var pool = chosen.isEmpty ? CompanionItem.defaults : chosen
        pool.shuffle()
        let life = pool.filter { [.walk, .workout, .breakfast, .lunch, .dinner, .water, .earlySleep, .standUp, .wakeOnTime].contains($0) }
        let care = pool.filter { [.feed, .islandPet, .play].contains($0) }
        var picks: [CompanionItem] = []
        if let a = life.first { picks.append(a) }
        if let b = care.first { picks.append(b) }
        for x in pool where picks.count < 3 && !picks.contains(x) { picks.append(x) }
        today = CompanionDay(day: day, picks: picks)
        save()
    }

    /// 换一件（用户想要什么就陪什么）
    func swap(_ item: CompanionItem) {
        guard let i = today.picks.firstIndex(of: item), !today.done.contains(item.rawValue) else { return }
        let pool = (chosen.isEmpty ? CompanionItem.defaults : chosen) + CompanionItem.allCases
        if let next = pool.shuffled().first(where: { !today.picks.contains($0) }) {
            today.picks[i] = next
            if !next.selfReport, progress(next) >= next.goal { complete(next) } else { save() }
        }
    }

    func isDone(_ i: CompanionItem) -> Bool { today.done.contains(i.rawValue) }
    func progress(_ i: CompanionItem) -> Int { today.progress[i.rawValue] ?? 0 }
    var doneCount: Int { today.picks.filter(isDone).count }

    /// 自动记一次（喂食、聊天…）；不在今天清单里的也记着，换进来时直接算
    func record(_ i: CompanionItem, amount: Int = 1, absolute: Bool = false) {
        guard today.day == Wallet.day() else { return }
        let v = absolute ? amount : progress(i) + amount
        today.progress[i.rawValue] = max(progress(i), v)
        if today.picks.contains(i), !isDone(i), progress(i) >= i.goal { complete(i) } else { save() }
    }

    /// 自己说"做了"
    func report(_ i: CompanionItem) {
        guard i.selfReport, today.picks.contains(i), !isDone(i) else { return }
        today.progress[i.rawValue] = 1
        complete(i)
    }

    private func complete(_ i: CompanionItem) {
        today.done.append(i.rawValue)
        justDone = i
        if !today.bonusGiven && today.picks.allSatisfy(isDone) { bonusReady = true }
        save()
        Analytics.log("companion_done", ["item": i.rawValue, "self": i.selfReport ? "1" : "0"])
    }

    func takeBonus() {
        today.bonusGiven = true
        bonusReady = false
        save()
    }

    private func save() { if let data = try? JSONEncoder().encode(today) { d.set(data, forKey: "companion.day") } }
    private func saveChosen() { d.set(chosen.map(\.rawValue), forKey: "companion.chosen") }
}


/// 首页卡片：今天陪你的 3 件事
struct CompanionCard: View {
    @ObservedObject var store: CompanionStore
    var petName: String
    var wakeHour: Int
    var sleepHour: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(T("今天陪你")).font(.system(size: 13)).foregroundStyle(Theme.text2)
                Spacer()
                Text("\(store.doneCount)/\(store.today.picks.count)").font(.system(size: 13)).foregroundStyle(Theme.text2).monospacedDigit()
            }
            ForEach(store.today.picks) { item in row(item) }
            Text(T("想让{0}陪你做什么，可以在「我」里挑。没做完也没关系。", petName))
                .font(.system(size: 11)).foregroundStyle(Theme.text3)
        }
    }

    @ViewBuilder private func row(_ item: CompanionItem) -> some View {
        let done = store.isDone(item)
        let h = Calendar.current.component(.hour, from: Date())
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : item.symbol)
                .font(.system(size: 16)).frame(width: 24)
                .foregroundStyle(done ? Theme.accent : Theme.text2)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 14)).foregroundStyle(done ? Theme.text2 : Theme.text)
                    .strikethrough(done, color: Theme.text3)
                Text(done ? "✓" : progressText(item)).font(.system(size: 11)).foregroundStyle(Theme.text3)
            }
            Spacer()
            if !done {
                if item.selfReport {
                    Button(T("做了")) { store.report(item) }
                        .font(.system(size: 13, weight: .semibold))
                        .buttonStyle(.bordered).tint(Theme.accent)
                        .disabled(!item.available(hour: h, wakeHour: wakeHour, sleepHour: sleepHour))
                }
                Button { withAnimation { store.swap(item) } } label: {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 13))
                }
                .foregroundStyle(Theme.text3)
                .accessibilityLabel(T("换一件"))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func progressText(_ i: CompanionItem) -> String {
        if i.goal > 1 {
            let p = min(store.progress(i), i.goal)
            return i == .walk ? T("{0} / {1} 步 · {2}", p, i.goal, i.hint) : "\(p) / \(i.goal) · \(i.hint)"
        }
        return i.hint
    }
}

/// 「我」页面：挑想让它陪你做的事
struct CompanionPicker: View {
    @ObservedObject var store: CompanionStore
    var wakeHour: Int
    var sleepHour: Int

    var body: some View {
        Form {
            Section {
                ForEach(CompanionItem.allCases) { item in
                    Button {
                        if let i = store.chosen.firstIndex(of: item) { store.chosen.remove(at: i) } else { store.chosen.append(item) }
                    } label: {
                        HStack {
                            Image(systemName: item.symbol).frame(width: 24).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).foregroundStyle(Theme.text)
                                Text(item.selfReport ? T("你点「做了」就算") : T("自动知道")).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.chosen.contains(item) { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                        }
                    }
                }
            } footer: {
                Text(T("每天从你挑的里面抽 3 件。不挑也行，会用默认的。"))
            }
            Section {
                Button(T("今天的重新抽")) { store.roll(wakeHour: wakeHour, sleepHour: sleepHour, force: true) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle(T("想让它陪你做的事"))
    }
}
