import SwiftUI
import UserNotifications

/// 按年龄的陪伴方向（设定第 21 节）。开场选一次，「我」里能改。全部静音、安静时段不发、提醒档"少"时不发。
/// - 学生/年轻：多打气（考试、面试、比赛前说一句加油；聊天里听懂"考试/面试"）
/// - 上班：工作日 10:30 喝口水、15:30 起来走两步
/// - 长辈：每天 10:00 喝水、16:00 活动活动；可设吃药时间（它陪你吃，水它准备好了）
enum AgeGroup: String, CaseIterable, Identifiable {
    case young, work, senior
    var id: String { rawValue }
    var title: String {
        switch self { case .young: return T("学生 / 年轻人"); case .work: return T("上班族"); case .senior: return T("长辈") }
    }
    var detail: String {
        switch self {
        case .young:  return T("考试、面试前它给你打气")
        case .work:   return T("工作日提醒你喝水、起来走走")
        case .senior: return T("提醒喝水、活动，还能设吃药时间")
        }
    }
    static var current: AgeGroup? {
        get { UserDefaults.standard.string(forKey: "age.group").flatMap(AgeGroup.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: "age.group"); AgeCare.schedule() }
    }
}

enum AgeCare {
    /// 吃药时间（分钟数，如 8*60 = 08:00）
    static var medTimes: [Int] {
        get { UserDefaults.standard.array(forKey: "age.med") as? [Int] ?? [] }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: "age.med") }
    }

    static func schedule() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix("age.") })
            guard let g = AgeGroup.current else { return }
            var items: [(String, Int, String, Bool)] = []          // id, 分钟, 文案, 只工作日
            switch g {
            case .young: break
            case .work:
                items = [("water", 630, [T("喝口水吧，我也喝。"), T("保温杯里的水凉了吗？喝一口。")].randomElement()!, true),
                         ("stand", 930, [T("起来走两步，我替你躺着。"), T("坐太久了，伸个懒腰？我先伸。")].randomElement()!, true)]
            case .senior:
                items = [("water", 600, T("喝杯温水吧，慢慢喝。"), false),
                         ("move", 960, T("起来活动活动，走两步就好，我在这儿等你。"), false)]
                for (i, t) in medTimes.enumerated() {
                    items.append(("med\(i)", t, T("该吃药了。水我准备好了，你吃，我陪着。"), false))
                }
            }
            let cal = Calendar.current
            for offset in 0...2 {
                guard let day = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
                let wd = cal.component(.weekday, from: day)
                for (k, mins, body, weekdayOnly) in items {
                    if weekdayOnly && (wd == 1 || wd == 7) { continue }
                    let isMed = k.hasPrefix("med")
                    if !isMed && Quiet.level == .low { continue }           // 吃药提醒不受"少"档影响
                    var dc = cal.dateComponents([.year, .month, .day], from: day)
                    dc.hour = mins / 60; dc.minute = mins % 60
                    guard let when = cal.date(from: dc), when > Date(), isMed || !Quiet.isQuiet(when) else { continue }
                    let c = UNMutableNotificationContent()
                    c.title = ChatStore.petName
                    c.body = body
                    c.interruptionLevel = isMed ? .timeSensitive : .passive
                    if isMed { c.sound = .default }
                    center.add(UNNotificationRequest(identifier: "age.\(Wallet.day(day)).\(k)", content: c,
                                                     trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
                }
            }
        }
    }

    /// 聊天里听到考试/面试/比赛：打气（所有年龄都回，年轻人档多一句）
    static func cheer(for text: String) -> String? {
        let keys = [T("考试"), T("面试"), T("比赛"), T("答辩"), T("考研"), T("高考"), "exam", "interview"]
        guard keys.contains(where: { text.lowercased().contains($0) }) else { return nil }
        if Voice.route == .dudu || Voice.stage == 0 { return T("嘟！嘟嘟！（它握紧小拳头给你打气）") }
        var s = [T("加油！我躺着替你紧张。"), T("你可以的。考完请我吃饭团。"), T("深呼吸，别慌，我在。")].randomElement()!
        if AgeGroup.current == .young { s += T("前一晚早点睡，养生家说的。") }
        return s
    }
}

/// 年龄段选择（开场和「我」共用）
struct AgePicker: View {
    @Binding var selection: String?
    var body: some View {
        VStack(spacing: 8) {
            ForEach(AgeGroup.allCases) { g in
                Button { selection = g.rawValue } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                            Text(g.detail).font(.system(size: 12)).foregroundStyle(Theme.text3)
                        }
                        Spacer()
                        Image(systemName: selection == g.rawValue ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection == g.rawValue ? Theme.accent : Theme.text3)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 52)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
