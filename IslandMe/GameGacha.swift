import SwiftUI

/// 扭蛋（游戏角 · 扭蛋机）：每天免费扭一次，之后 10 币一次。扭出一张贴纸；重复的退 3 币。
/// 它懒：你转把手，它在旁边瞪大眼睛等。
struct GachaView: View {
    @ObservedObject var profile: ProfileStore
    let pet: String
    @Environment(\.dismiss) private var dismiss

    private static let price = 10
    @State private var turning = false
    @State private var angle: Double = 0
    @State private var capsule = false
    @State private var opened: Stickers.Sticker? = nil
    @State private var duplicate = false
    @State private var face = "surprised"
    @State private var album = false

    private var freeLeft: Bool { !profile.gameClaimed(.gacha) }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Text(T("扭蛋")).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.text)
                    Spacer()
                    CoinBadge(coins: profile.profile.coins)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.text)
                            .frame(width: 40, height: 40).background(Theme.surface, in: Circle())
                    }
                    .buttonStyle(.press).padding(.leading, 8)
                }
                .padding(.horizontal, 20).padding(.top, 10)

                ZStack(alignment: .bottomLeading) {
                    Image("nest_gacha").resizable().scaledToFit().frame(maxHeight: 300)
                        .rotationEffect(.degrees(turning ? 2 : -2))
                        .animation(turning ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: turning)
                        .frame(maxWidth: .infinity)
                    DressedPetView(pet: pet, pose: .stand, frame: face, accessories: profile.profile.equipped)
                        .frame(width: 110, height: 110).offset(x: -6, y: 10)
                }
                .padding(.horizontal, 20)

                ZStack {
                    if capsule && opened == nil {
                        Circle().fill(LinearGradient(colors: [Color(hex: "#F7A8C4"), Color(hex: "#B9A6E8")], startPoint: .top, endPoint: .bottom))
                            .frame(width: 70, height: 70)
                            .overlay(Rectangle().fill(.white.opacity(0.5)).frame(height: 3))
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if let s = opened {
                        VStack(spacing: 6) {
                            StickerImage(sticker: s).frame(width: 90, height: 90)
                            Text(s.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.text)
                            Text(duplicate ? T("这张有了，退你 3 币") : T("新贴纸！放进贴纸册了")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                        }
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .frame(height: 140)

                Button(action: pull) {
                    Text(freeLeft ? T("转一下（今天免费）") : T("转一下 · {0} 币", Self.price))
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.coin, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.press)
                .disabled(turning || (!freeLeft && profile.profile.coins < Self.price))
                .opacity(turning || (!freeLeft && profile.profile.coins < Self.price) ? 0.5 : 1)
                .padding(.horizontal, 20)

                Button { album = true } label: {
                    Text(T("贴纸册 {0}/{1} ›", Stickers.owned.count, Stickers.all.count)).font(.system(size: 14)).foregroundStyle(Theme.text2)
                }
                .buttonStyle(.press)
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $album) { StickerAlbum() }
    }

    private func pull() {
        if !profile.useFreeGacha() {
            guard profile.spend(Self.price, T("扭蛋")) else { return }
        }
        Analytics.log("gacha")
        withAnimation { opened = nil; capsule = false }
        turning = true
        face = "surprised"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            turning = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { capsule = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                let had = Stickers.owned
                let s = Stickers.drop()
                duplicate = had.contains(s.id)
                if duplicate { profile.earn(3, T("扭蛋 · 重复退币")) }
                face = duplicate ? "think" : "laugh"
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { opened = s }
            }
        }
    }
}
