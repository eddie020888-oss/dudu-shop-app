import SwiftUI

/// 开场故事（只给新玩家，开蛋之前放一次，约 20 秒）：4 张剧情插图慢慢推镜头 + 一句字幕。
/// 不剧透「店是嘟嘟关的」（那是第 3–4 章的谜）。点一下下一页，右上角可跳过；「我的」里能重看。
struct StoryIntroView: View {
    var done: () -> Void
    static let seenKey = "intro.story.v1"
    static var seen: Bool { UserDefaults.standard.bool(forKey: seenKey) }

    private let pages: [(img: String, line: String)] = [
        ("story_planet", T("很远很远的地方，有一颗嘟嘟星。\n那里没有太阳。")),
        ("story_shop_lit", T("嘟嘟星的光，是大家互相做饭点亮的。\n全星的饭，都从一家小店端出去。")),
        ("story_shop_dark", T("后来，小店关了门。\n大家各吃各的，星星一片一片暗了下去。")),
        ("story_door", T("那天晚上 9 点 41 分，\n一颗蛋顺着门缝里的光，滚进了你的灵动岛……")),
    ]
    @State private var k = 0
    @State private var zoom = false
    @State private var showLine = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { g in
                Image(pages[k].img).resizable().scaledToFill()
                    .frame(width: g.size.width, height: g.size.height)
                    .scaleEffect(zoom ? 1.14 : 1.0)
                    .clipped()
                    .id(k)
                    .transition(.opacity)
            }
            .ignoresSafeArea()
            // 下半部分压暗，字幕看得清
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom).ignoresSafeArea()
            VStack {
                HStack {
                    HStack(spacing: 5) {
                        ForEach(0..<pages.count, id: \.self) { j in
                            Capsule().fill(j <= k ? Color.white.opacity(0.9) : Color.white.opacity(0.25)).frame(width: j == k ? 18 : 6, height: 5)
                        }
                    }
                    Spacer()
                    Button { finish() } label: {
                        Text(T("跳过")).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 14).padding(.vertical, 7).background(Color.white.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.top, 8)
                Spacer()
                Text(pages[k].line)
                    .font(.system(size: 20, weight: .semibold)).lineSpacing(8)
                    .multilineTextAlignment(.center).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6)
                    .padding(.horizontal, 28).padding(.bottom, 70)
                    .opacity(showLine ? 1 : 0).offset(y: showLine ? 0 : 12)
                    .id("line\(k)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { next() }
        // 每页 5 秒自动翻（用 task：翻页时自动取消上一页的计时；Timer 闭包里改不动 @State，自测发现停在第一页）
        .task(id: k) {
            start()
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { next() }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private func start() {
        zoom = false; showLine = false
        withAnimation(.easeInOut(duration: 5.5)) { zoom = true }
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) { showLine = true }
        if k == pages.count - 1 { MKSfx.play("discover", volume: 0.5) }
    }
    private func next() {
        if k >= pages.count - 1 { finish(); return }
        MKSfx.play("flip", volume: 0.35)
        withAnimation(.easeInOut(duration: 0.6)) { k += 1 }
    }
    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        done()
    }
}
