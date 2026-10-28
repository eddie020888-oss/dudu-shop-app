import SwiftUI

/// 全局配色：黑底 + 紫角淡紫做主色，橙色只给“需要你”的场合
enum Theme {
    static let ground   = Color(hex: "#0F0E13")
    static let surface  = Color(hex: "#1A1822")
    static let surface2 = Color(hex: "#2A2733")
    static let text     = Color(hex: "#F3F1F7")
    static let text2    = Color(hex: "#A9A3B8")
    static let text3    = Color(hex: "#6F6A80")
    static let accent   = Color(hex: "#B9A6E8")
    static let alert    = Color(hex: "#F59E4B")
    static let water    = Color(hex: "#8FB8F0")
    static let clean    = Color(hex: "#9FDCC4")
    static let joy      = Color(hex: "#F7A8C4")
    static let coin     = Color(hex: "#FFD166")

    static func needColor(_ n: Need) -> Color {
        switch n { case .hungry: return alert; case .thirsty: return water; case .dirty: return clean; case .happy: return joy }
    }
}

/// 需求行：图标 + 名称/百分比 + 进度 + 按钮；告急时整行转橙
struct NeedRow: View {
    var need: Need
    var level: Double
    var compact = false
    var onCare: () -> Void

    private var urgent: Bool { level < Need.threshold }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: need.careSymbol)
                .font(.system(size: 18)).frame(width: 24)
                .foregroundStyle(urgent ? Theme.alert : Theme.needColor(need))
            VStack(spacing: 6) {
                HStack {
                    Text(urgent ? need.label : need.careName).font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("\(Int(level * 100))%").font(.system(size: 13)).foregroundStyle(urgent ? Theme.alert : Theme.text2)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surface2)
                        Capsule().fill(urgent ? Theme.alert : Theme.needColor(need)).frame(width: max(6, g.size.width * level))
                    }
                }
                .frame(height: 6)
            }
            Button(action: onCare) {
                Text(need.careVerb).font(.system(size: 14, weight: urgent ? .bold : .medium))
                    .padding(.horizontal, 16).frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(urgent ? Color(hex: "#1A1206") : Theme.text)
            .background(urgent ? Theme.alert : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(urgent ? .clear : Color(hex: "#3A3744"), lineWidth: 1))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(urgent ? Color(hex: "#3A2A16") : .clear, lineWidth: 1))
        .foregroundStyle(Theme.text)
    }
}



/// 舞台里的照顾按钮：圆形图标 + 一圈进度环（低了变橙色、轻轻跳）
struct CareBubble: View {
    var need: Need
    var level: Double
    var onCare: () -> Void
    @State private var bounce = false
    private var urgent: Bool { level < Need.threshold }

    var body: some View {
        Button(action: onCare) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.08))
                    Circle().trim(from: 0, to: max(0.03, level))
                        .stroke(urgent ? Theme.alert : Theme.needColor(need), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(2)
                    Image(systemName: need.careSymbol).font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(urgent ? Theme.alert : .white)
                }
                .frame(width: 50, height: 50)
                .scaleEffect(urgent && bounce ? 1.08 : 1)
                Text(need.careVerb).font(.system(size: 11, weight: .medium)).foregroundStyle(urgent ? Theme.alert : Color.white.opacity(0.75))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(T("{0}，{1}%", need.careVerb, Int(level * 100)))
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { bounce = true } }
    }
}

/// 首页照顾按钮旁边的亲密度：粉色心 + 外圈是 0–100，底下写档位
struct IntimacyBubble: View {
    var im: Intimacy
    var onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.08))
                    Circle().trim(from: 0, to: max(0.03, im.value / 100))
                        .stroke(Color(hex: "#FF8FB1"), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(2)
                    Image(systemName: "heart.fill").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "#FF8FB1"))
                }
                .frame(width: 50, height: 50)
                Text(im.tier.name).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.white.opacity(0.75)).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(T("亲密度 {0}，{1}/100", im.tier.name, Int(im.value)))
    }
}


/// 管家代劳的小卡片：它见底了，管家用你的金币点了最好的（图 + 名字 + 花了多少 + 它说的话）
struct RescueCard: View {
    let r: Rescue
    let close: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 10) {
                Text(T("管家代劳")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text3)
                Image(r.image).resizable().scaledToFit().frame(height: 140)
                Text(r.name).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.text)
                Text(T("花了 {0} 币 · 亲密度掉了一点", r.price)).font(.system(size: 12)).foregroundStyle(Theme.coin)
                Text(r.line).font(.system(size: 14)).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
                Button(T("下次我早点来"), action: close)
                    .font(.system(size: 15, weight: .semibold)).padding(.horizontal, 22).padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule()).foregroundStyle(.white).padding(.top, 4)
            }
            .padding(22).frame(maxWidth: 320)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
            .padding(24)
        }
    }
}

/// 按下去缩一下（2026-10-22 手感打磨：原来很多按钮是 .plain，按下没有任何反馈）
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
extension ButtonStyle where Self == PressStyle { static var press: PressStyle { PressStyle() } }
