import SwiftUI
import WidgetKit

/// 桌面小组件「小紫」：一眼看它在干嘛（设定第 16 节）。点一下进 App。
/// 有 App 同步来的状态（30 分钟内）就用实时的；没有就按时间推断——它很懒，作息好猜。
struct XiaoziEntry: TimelineEntry {
    let date: Date
    let frame: String
    let line: String
    let need: String
    let name: String
    var shopIcon: String? = nil
    var shopLine: String? = nil
    var shopAt: Date? = nil
}

struct XiaoziProvider: TimelineProvider {
    func placeholder(in context: Context) -> XiaoziEntry { guess(Date()) }
    func getSnapshot(in context: Context, completion: @escaping (XiaoziEntry) -> Void) { completion(entry(Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<XiaoziEntry>) -> Void) {
        let now = Date()
        var es = [entry(now)]
        for i in 1...16 { es.append(guess(now.addingTimeInterval(Double(i) * 1800))) }
        completion(Timeline(entries: es, policy: .atEnd))
    }

    private func entry(_ d: Date) -> XiaoziEntry {
        let s = WidgetBridge.read()
        var e: XiaoziEntry
        if let s, d.timeIntervalSince(s.at) < 1800 {
            e = XiaoziEntry(date: d, frame: s.need.isEmpty ? s.frame : (Need(rawValue: s.need)?.frame ?? s.frame),
                            line: s.line, need: s.need, name: s.name)
        } else { e = guess(d) }
        // 小店的下一件事：还没到点就显示倒计时（到点了显示「好了」，一小时后不再显示）
        if let s, let at = s.shopAt, let line = s.shopLine, d.timeIntervalSince(at) < 3600 {
            e.shopIcon = s.shopIcon; e.shopLine = line; e.shopAt = at
        }
        return e
    }

    /// 按时间猜：夜里睡、饭点吃、下午打盹、其余发呆想吃的
    func guess(_ d: Date) -> XiaoziEntry {
        let h = Calendar.current.component(.hour, from: d), m = Calendar.current.component(.minute, from: d)
        let t = h * 60 + m
        let name = WidgetBridge.read()?.name ?? T("嘟嘟")
        let pick: (String, [String])
        switch t {
        case 0..<450, 1380..<1440: pick = ("sleep", ["Zzz……", T("别叫我，梦里在吃。"), T("睡觉是最好的养生。")])
        case 450..<540:            pick = ("yawn", [T("再躺五分钟。"), T("起……不来。"), T("你先起，我随后。")])
        case 690..<780:            pick = ("eat", [T("饭点到了，一起吃。"), T("饭团在肚子上，方便。"), T("吃饭要按点。")])
        case 840..<900:            pick = ("sleep", [T("午睡中，勿扰。"), T("饭后躺一躺。")])
        case 1080..<1170:          pick = ("eat", [T("晚饭清淡点。"), T("吃饱了才有力气躺。")])
        case 1260..<1380:          pick = ("movie", [T("看一集就睡。"), T("最后一集。真的。")])
        default:                   pick = (["idle", "think", "read", "coffee"][(t / 30) % 4], [T("在想晚饭吃什么。"), T("我很忙，在发呆。"), T("喝口温水吧。"), T("你忙，我躺着陪你。"), T("有点想吃零食。")])
        }
        return XiaoziEntry(date: d, frame: pick.0, line: pick.1[(t / 30) % pick.1.count], need: "", name: name)
    }
}

struct XiaoziWidgetView: View {
    var entry: XiaoziEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemSmall {
                VStack(spacing: 4) {
                    Image("purple_" + entry.frame).resizable().scaledToFit()
                    Text(entry.line).font(.system(size: 11)).foregroundStyle(Color(hex: "#E7E3F2")).lineLimit(1).minimumScaleFactor(0.8)
                }
            } else {
                HStack(spacing: 12) {
                    Image("purple_" + entry.frame).resizable().scaledToFit()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.name).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        if let n = Need(rawValue: entry.need) {
                            Text(n.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex: "#FFB86B"))
                        }
                        Text("“\(entry.line)”").font(.system(size: 13)).foregroundStyle(Color(hex: "#E7E3F2")).lineLimit(entry.shopLine == nil ? 3 : 2)
                        if let l = entry.shopLine, let at = entry.shopAt {
                            HStack(spacing: 4) {
                                Text((entry.shopIcon ?? "🍲") + " " + l).lineLimit(1)
                                if at > entry.date { Text(at, style: .timer).monospacedDigit() } else { Text(T("好了")) }
                            }
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(hex: "#FFD166"))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(hex: "#1A1230"), .black], startPoint: .top, endPoint: .bottom)
        }
        .widgetURL(URL(string: "islandme://home"))
    }
}

struct XiaoziHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "XiaoziHome", provider: XiaoziProvider()) { XiaoziWidgetView(entry: $0) }
            .configurationDisplayName(T("嘟嘟"))
            .description(T("看一眼它在干嘛。点一下去陪它。"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
