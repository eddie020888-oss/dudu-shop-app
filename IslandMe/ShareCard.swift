import SwiftUI

/// 分享卡片（设定第 23 节）：全身照 + 它今天说的一句话 + "陪伴第 N 天"；里程碑卡片带标题。
struct ShareCard: View {
    var petName: String
    var days: Int
    var line: String
    var title: String? = nil
    var frame: String = "happy"

    var body: some View {
        VStack(spacing: 14) {
            if let title {
                Text(T("✦ 第一次 · {0}", title)).font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "#E9DEFF"))
                    .padding(.top, 22)
            } else {
                Spacer().frame(height: 18)
            }
            if !line.isEmpty {
                Text("“\(line)”")
                    .font(.system(size: 17)).foregroundStyle(Color(hex: "#2A2140"))
                    .multilineTextAlignment(.center).lineLimit(3)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color(hex: "#F3EEFF"), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 26)
            }
            Image("purple_" + frame).resizable().scaledToFit()
                .frame(height: 250)
                .background(
                    Ellipse().fill(RadialGradient(colors: [Color(hex: "#8E6BE8").opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 120))
                        .frame(width: 240, height: 40).offset(y: 120)
                )
            Text(T("和{0}在一起的第 {1} 天", petName, days)).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            Text(T("嘟嘟小店 · 住在灵动岛里的嘟嘟")).font(.system(size: 11)).foregroundStyle(Color(hex: "#9C93B8"))
                .padding(.bottom, 20)
        }
        .frame(width: 360, height: 520)
        .background(LinearGradient(colors: [Color(hex: "#2E1F5C"), Color(hex: "#0E0A1C")], startPoint: .top, endPoint: .bottom))
    }

    @MainActor func image() -> Image {
        let r = ImageRenderer(content: self)
        r.scale = 3
        if let ui = r.uiImage { return Image(uiImage: ui) }
        return Image("purple_" + frame)
    }
}

/// 分享按钮：点了才生成图片
struct ShareCardButton: View {
    var card: ShareCard
    var label: String = T("分享")
    @State private var img: Image? = nil

    var body: some View {
        Group {
            if let img {
                ShareLink(item: img, preview: SharePreview(T("和{0}的第 {1} 天", card.petName, card.days), image: img)) {
                    Label(label, systemImage: "square.and.arrow.up")
                }
            } else {
                ProgressView()
            }
        }
        .onAppear { img = card.image() }
    }
}
