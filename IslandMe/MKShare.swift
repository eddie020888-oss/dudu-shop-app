import SwiftUI

/// 小店里的分享卡：装修好的一角、金色拍立得、集齐一套。生成一张竖图，走系统分享
struct MKShareCard: View {
    let title: String
    let line: String
    var area: MKStory.Area? = nil
    var done: [String] = []
    var card: MKCard? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: "#FFE7A8"))
                .multilineTextAlignment(.center).padding(.top, 24).padding(.horizontal, 20)
            if let area {
                MKAreaScene(area: area, done: done, shown: true, glow: false)
                    .frame(width: 320, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else if let card {
                MKPolaroid(card: card, width: 220)
            }
            if !line.isEmpty {
                Text("“\(line)”").font(.system(size: 15)).foregroundStyle(Color(hex: "#2A2140"))
                    .multilineTextAlignment(.center).lineLimit(3)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(hex: "#F3EEFF"), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Image("purple_happy").resizable().scaledToFit().frame(height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("嘟嘟小店")).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    Text(T("住在灵动岛里的嘟嘟")).font(.system(size: 11)).foregroundStyle(Color(hex: "#9C93B8"))
                }
            }
            .padding(.bottom, 20)
        }
        .frame(width: 360, height: 600)
        .background(LinearGradient(colors: [Color(hex: "#2E1F5C"), Color(hex: "#0E0A1C")], startPoint: .top, endPoint: .bottom))
    }

    @MainActor func image() -> Image? {
        let r = ImageRenderer(content: self)
        r.scale = 3
        return r.uiImage.map { Image(uiImage: $0) }
    }
}

/// 分享按钮：点出来时才生成图片
struct MKShareButton: View {
    let card: MKShareCard
    var label: String = T("分享")
    @State private var img: Image? = nil

    var body: some View {
        Group {
            if let img {
                ShareLink(item: img, preview: SharePreview(card.title, image: img)) {
                    Label(label, systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Theme.text)
                }
                .buttonStyle(.plain)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .onAppear { if img == nil { img = card.image() } }
    }
}
