import SwiftUI

/// 它的窝（底部导航「窝」）：竖屏，四间房左右滑——卧室、客厅、观星台、游戏角。
/// 蛋壳永远是它的床（卧室）。家具随便买、买了当场摆上；有些家具带一个游戏（汤姆猫 2 的做法：道具就是游戏入口）。
enum NestRoom: Int, CaseIterable, Identifiable {
    case bedroom, living, stars, play
    var id: Int { rawValue }
    var name: String {
        switch self { case .bedroom: return T("卧室"); case .living: return T("客厅"); case .stars: return T("观星台"); case .play: return T("游戏角") }
    }
    var key: String { switch self { case .bedroom: return "bedroom"; case .living: return "living"; case .stars: return "stars"; case .play: return "play" } }
    var items: [NestItem] { NestItem.allCases.filter { $0.room == self } }
}

enum NestItem: String, CaseIterable, Identifiable {
    case cushion, blanket, rug, lamp, tv, snack, window, telescope, cups, cardtable, gacha
    // 纯装饰（2026-10-17 加，GPT 出图）
    case nightstand, lights, painting, glowplant, slippers, wardrobe
    case clock, plush, floorlamp, beanbag, plant
    case chime, globe, lounger, books
    case pinboard, trophies, beanbag2, toybox
    var id: String { rawValue }
    var ownedKey: String { "nest." + rawValue }
    var image: String { "nest_" + rawValue }

    var room: NestRoom {
        switch self {
        case .cushion, .blanket, .rug, .lamp, .wardrobe, .nightstand, .lights, .painting, .glowplant, .slippers: return .bedroom
        case .tv, .snack, .clock, .plush, .floorlamp, .beanbag, .plant:                         return .living
        case .window, .telescope, .chime, .globe, .lounger, .books:                           return .stars
        case .cups, .cardtable, .gacha, .pinboard, .trophies, .beanbag2, .toybox:             return .play
        }
    }
    /// 这件家具带的游戏
    var game: GameKind? {
        switch self {
        case .lamp:      return .dudu
        case .tv:        return .coins
        case .snack:     return .fling
        case .telescope: return .stars
        case .cups:      return .cups
        case .cardtable: return .match
        case .gacha:     return .gacha
        default:         return nil
        }
    }
    var name: String {
        switch self {
        case .cushion:   return T("软垫")
        case .blanket:   return T("星星小毯子")
        case .rug:       return T("星星地毯")
        case .lamp:      return T("星星夜灯")
        case .tv:        return T("小电视")
        case .snack:     return T("零食柜")
        case .window:    return T("嘟嘟星圆窗")
        case .telescope: return T("小望远镜")
        case .cups:      return T("杯子小桌")
        case .cardtable: return T("翻牌小桌")
        case .gacha:     return T("扭蛋机")
        case .wardrobe:  return T("衣柜")
        case .nightstand: return T("床头小柜")
        case .lights:    return T("星星串灯")
        case .painting:  return T("嘟嘟星风景画")
        case .glowplant: return T("发光草")
        case .slippers:  return T("小拖鞋")
        case .clock:     return T("星星挂钟")
        case .plush:     return T("饭团抱枕和相框")
        case .floorlamp: return T("蘑菇落地灯")
        case .beanbag:   return T("懒人豆袋")
        case .plant:     return T("绿植")
        case .chime:     return T("星星风铃")
        case .globe:     return T("星球仪")
        case .lounger:   return T("看星星躺椅")
        case .books:     return T("一摞星星书")
        case .pinboard:  return T("贴纸墙")
        case .trophies:  return T("奖杯架")
        case .beanbag2:  return T("薄荷豆袋")
        case .toybox:    return T("玩具箱")
        }
    }
    var price: Int {
        switch self {
        case .cushion: return 30; case .blanket: return 40; case .rug: return 45; case .lamp: return 50
        case .tv: return 80; case .snack: return 60
        case .window: return 90; case .telescope: return 100
        case .cups, .wardrobe: return 0; case .cardtable: return 60; case .gacha: return 100
        case .slippers, .plant, .books: return 15
        case .glowplant, .clock, .plush, .chime, .toybox: return 20
        case .nightstand, .lights, .floorlamp, .globe, .trophies: return 25
        case .painting, .pinboard: return 30
        case .beanbag, .beanbag2, .lounger: return 40
        }
    }
    var note: String {
        switch self {
        case .cushion:   return T("放在壳边上，它可以从壳里滚下来接着躺")
        case .blanket:   return T("睡前盖的那条，上面的星星会发光")
        case .rug:       return T("铺在蛋壳底下，一圈星星会亮")
        case .lamp:      return T("夜灯一开它就说梦话 · 解锁「猜嘟语」")
        case .tv:        return T("它躺着看，爆米花往外蹦 · 解锁「接爆米花」")
        case .snack:     return T("它的宝库，养生家也要囤点 · 解锁「投喂」")
        case .window:    return T("挂在墙上，能看见嘟嘟星")
        case .telescope: return T("对着嘟嘟星的方向 · 解锁「星星连线」")
        case .cups:      return T("送的 · 「猜杯子」")
        case .cardtable: return T("它的表情和配饰做的牌 · 解锁「翻牌配对」")
        case .gacha:     return T("每天免费扭一次，攒贴纸 · 解锁「扭蛋」")
        case .wardrobe:  return T("买过的衣服都在里面 · 点开就是试衣间")
        case .nightstand: return T("床头放保温杯，半夜渴了不用起来")
        case .lights:    return T("挂在墙上，一闪一闪")
        case .painting:  return T("画的是嘟嘟星，有发光的草")
        case .glowplant: return T("嘟嘟星来的草，碰一下就亮")
        case .slippers:  return T("它从来不穿，但要有")
        case .clock:     return T("看几点了……该吃饭了")
        case .plush:     return T("饭团抱枕，和一张你们的合照")
        case .floorlamp: return T("暖暖的光，适合躺着")
        case .beanbag:   return T("陷进去就起不来")
        case .plant:     return T("养生家的绿植，它负责看着")
        case .chime:     return T("天窗下面，风一吹就响")
        case .globe:     return T("转一转，找嘟嘟星在哪")
        case .lounger:   return T("躺着看星星，专业的")
        case .books:     return T("星星书，它只看图")
        case .pinboard:  return T("攒的贴纸会贴在上面，越攒越满")
        case .trophies:  return T("游戏赢来的小奖杯摆在这儿")
        case .beanbag2:  return T("薄荷色的，玩累了陷进去")
        case .toybox:    return T("它的玩具都扔在这里")
        }
    }
    /// 买回来它说的
    var thanks: String {
        switch self {
        case .cushion:   return T("软的……我不起来了。")
        case .blanket:   return T("毯子！今晚就盖这个。")
        case .rug:       return T("脚底下软软的，壳也不凉了。")
        case .lamp:      return T("那边……就是嘟嘟星的方向。")
        case .tv:        return T("电视！我躺着看就行。")
        case .snack:     return T("我的宝库……你也可以拿一点。就一点。")
        case .window:    return T("那颗紫色的……是我家吗？")
        case .telescope: return T("我看看……那几颗星好像连得起来。")
        case .cups:      return T("杯子底下藏东西，我最会了。")
        case .cardtable: return T("这些牌上都是我。")
        case .gacha:     return T("扭一个！不对，你扭，我看着。")
        case .wardrobe:  return T("衣服都收好了。")
        case .nightstand: return T("保温杯有地方放了。")
        case .lights:    return T("亮晶晶的……好看。")
        case .painting:  return T("这就是我家那边。")
        case .glowplant: return T("家里的草！你看，会亮。")
        case .slippers:  return T("我不穿，但要有。")
        case .clock:     return T("以后吃饭不会迟到了。")
        case .plush:     return T("饭团！还有我们的照片。")
        case .floorlamp: return T("这个光，适合躺着。")
        case .beanbag:   return T("我陷进去了……不起来了。")
        case .plant:     return T("我负责看着它长。")
        case .chime:     return T("叮……叮……好听。")
        case .globe:     return T("嘟嘟星在……这儿！大概。")
        case .lounger:   return T("躺着看星星，我是专业的。")
        case .books:     return T("我看图就行。")
        case .pinboard:  return T("我们的贴纸有地方贴了！")
        case .trophies:  return T("这些都是我们赢的。你赢的。")
        case .beanbag2:  return T("绿的这个也是我的。")
        case .toybox:    return T("玩具都在这，我躺着玩。")
        }
    }
    /// 在窝里点它时它说的
    var tapLines: [String] {
        switch self {
        case .cushion:   return [T("软垫是我的。"), T("别坐，我刚焐热。")]
        case .blanket:   return [T("盖着才睡得着。"), T("这条有嘟嘟星的味道。")]
        case .rug:       return [T("别踩，星星会疼。"), T("毛毛的，好躺。")]
        case .lamp:      return [T("亮着我就不怕黑。"), T("看，像不像我家？")]
        case .tv:        return [T("这个台好看。"), T("看着看着就……困了。")]
        case .snack:     return [T("我就看看，不吃。"), T("……吃一个没事吧？")]
        case .window:    return [T("今天嘟嘟星好亮。"), T("我在想家……一下下。")]
        case .telescope: return [T("那边有个星星在眨眼。"), T("你看，我不动，你看。")]
        case .cups:      return [T("猜不猜？"), T("饭团在哪我不说。")]
        case .cardtable: return [T("这张是我笑的样子。"), T("翻吧，我看着。")]
        case .gacha:     return [T("里面有我的照片。"), T("就扭一个。")]
        case .wardrobe:  return [T("今天穿哪件？"), T("你挑，我站着不动。")]
        case .nightstand: return [T("保温杯里是枸杞茶。"), T("半夜渴了伸手就有。")]
        case .lights:    return [T("一闪一闪的。"), T("像家里的天。")]
        case .painting:  return [T("那边的草会发光。"), T("我想家……一下下。")]
        case .glowplant: return [T("碰一下就亮。"), T("嘟嘟星的草，长得慢。")]
        case .slippers:  return [T("我不穿。"), T("摆着好看。")]
        case .clock:     return [T("几点了……饭点了吗？"), T("还没到？那我再躺会儿。")]
        case .plush:     return [T("饭团不能吃，我试过。"), T("照片里你笑得好看。")]
        case .floorlamp: return [T("暖的。"), T("灯下面最好躺。")]
        case .beanbag:   return [T("别叫我，我陷进去了。"), T("软……")]
        case .plant:     return [T("它今天长了一点点。"), T("浇水的事你来，我看着。")]
        case .chime:     return [T("叮……"), T("风来了。")]
        case .globe:     return [T("转转转……晕了。"), T("嘟嘟星在这儿附近。")]
        case .lounger:   return [T("躺着看星星，我是专业的。"), T("别让我起来。")]
        case .books:     return [T("这本图多。"), T("看着看着就睡着了。")]
        case .pinboard:  return [T("再攒几张就贴满了。"), T("这张我最喜欢。")]
        case .trophies:  return [T("这个是你赢的。"), T("我躺着帮你加油的。")]
        case .beanbag2:  return [T("绿的也软。"), T("玩累了就陷这儿。")]
        case .toybox:    return [T("玩具都在这。"), T("不收拾，懒。")]
        }
    }
    /// 在房间里的位置：x、y（相对宽、高）、宽度（相对宽）、y 指物件的底边还是中心
    /// 在房间里的位置（按 GPT 出的房间背景量的，背景 2:3）：x、y（相对宽、高）、宽度（相对宽）、y 指物件的底边还是中心
    var spot: (x: CGFloat, y: CGFloat, w: CGFloat, bottom: Bool) {
        switch self {
        case .lamp:      return (0.50, 0.375, 0.17, true)   // 卧室墙上拱形壁龛里
        case .cushion:   return (0.15, 0.94, 0.30, false)
        case .blanket:   return (0.86, 0.95, 0.30, false)
        case .rug:       return (0.50, 0.925, 0.84, false)  // 烘焙在卧室背景里，这里不叠
        case .tv:        return (0.25, 0.78, 0.40, true)
        case .snack:     return (0.85, 0.66, 0.26, true)
        case .window:    return (0.50, 0.32, 0.46, false)
        case .telescope: return (0.24, 0.86, 0.38, true)
        case .cups:      return (0.27, 0.74, 0.42, true)
        case .cardtable: return (0.75, 0.74, 0.40, true)
        case .gacha:     return (0.20, 0.98, 0.34, true)
        case .lights:    return (0.16, 0.15, 0.26, false)
        case .painting:  return (0.84, 0.30, 0.20, false)
        case .wardrobe:  return (0.15, 0.67, 0.30, true)
        case .nightstand: return (0.86, 0.64, 0.22, true)
        case .glowplant: return (0.86, 0.49, 0.13, true)    // 摆在床头小柜上
        case .slippers:  return (0.86, 0.80, 0.17, false)
        case .clock:     return (0.22, 0.25, 0.15, false)
        case .plush:     return (0.50, 0.235, 0.20, true)    // 搁板上
        case .floorlamp: return (0.64, 0.60, 0.11, true)
        case .beanbag:   return (0.84, 0.95, 0.30, true)
        case .plant:     return (0.10, 0.98, 0.22, true)
        case .chime:     return (0.85, 0.22, 0.12, false)
        case .globe:     return (0.12, 0.64, 0.16, true)
        case .lounger:   return (0.70, 0.88, 0.44, true)
        case .books:     return (0.43, 0.96, 0.18, true)
        case .pinboard:  return (0.50, 0.32, 0.40, false)
        case .trophies:  return (0.15, 0.33, 0.22, false)
        case .beanbag2:  return (0.46, 0.90, 0.26, true)
        case .toybox:    return (0.90, 0.99, 0.24, true)
        }
    }
    /// 前后遮挡：墙上的先画，地上的按底边从远到近
    var depth: CGFloat {
        let s = spot
        if !s.bottom && s.y < 0.5 { return -1 + s.y }
        return s.y
    }
    var free: Bool { price == 0 }
}

/// 卧室：背景图（墙、星星、地面、地毯）+ 蛋壳里的它（视频底色和背景图同一块，看不出方框）+ 家具
struct NestScene: View {
    static let aspect: CGFloat = 2.0 / 3.0
    var owned: [String]
    var night = false
    /// 蛋壳里它正在干嘛：shell（窝着）/ shell_bored / shell_sleep / shell_eat / shell_happy
    var clip: String = "shell"
    var onTap: (NestItem?) -> Void = { _ in }

    private var rug: Bool { owned.contains(NestItem.rug.ownedKey) }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Image(rug ? "nest_bg_bedroom_rug" : "nest_bg_bedroom").resizable().frame(width: w, height: h)
                Group {
                    if let url = Bundle.main.url(forResource: "purple_room_\(clip)\(rug ? "_rug" : "")", withExtension: "mp4") {
                        LoopingVideoView(url: url)
                            .id(url)
                            .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                    } else {
                        Image("nest_shell").resizable().scaledToFit().padding(w * 0.08)
                    }
                }
                .frame(width: w * 0.66, height: w * 0.66)
                .position(x: w * 0.5, y: h * 0.78)
                .contentShape(Rectangle())
                .onTapGesture { onTap(nil) }
                ForEach(NestRoom.bedroom.items.filter { $0 != .rug }.sorted { $0.depth < $1.depth }, id: \.self) { RoomPiece(item: $0, owned: owned, w: w, h: h, onTap: onTap) }
                if night {
                    Color.black.opacity(0.45).allowsHitTesting(false)
                    if NestItem.lamp.has(owned) {
                        Circle().fill(RadialGradient(colors: [Color(hex: "#A8E6FF").opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: w * 0.35))
                            .frame(width: w * 0.7, height: w * 0.7)
                            .position(x: w * 0.5, y: h * 0.31)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

/// 其他三间房：同一块墙和地面换个色调，它坐在里面（静态表情），家具摆在固定位置；没买的位置是个虚线"＋"
struct RoomScene: View {
    let room: NestRoom
    let owned: [String]
    let pet: String
    let accessories: [String]
    var face: String
    var onTap: (NestItem?) -> Void

    private var petSpot: (x: CGFloat, y: CGFloat, w: CGFloat) {
        switch room {
        case .living:  return (0.58, 0.95, 0.40)    // 坐在前面看电视
        case .stars:   return (0.70, 0.95, 0.42)
        case .play:    return (0.66, 0.99, 0.40)
        case .bedroom: return (0.5, 0.9, 0.5)
        }
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Image("nest_bg_\(room.key)").resizable().frame(width: w, height: h)
                ForEach(room.items.sorted { $0.depth < $1.depth }) { RoomPiece(item: $0, owned: owned, w: w, h: h, onTap: onTap) }
                let s = petSpot
                Ellipse().fill(Theme.accent.opacity(0.18)).frame(width: w * s.w * 0.8, height: w * 0.05)
                    .position(x: w * s.x, y: h * s.y - w * 0.02)
                DressedPetView(pet: pet, pose: .stand, frame: face, accessories: accessories)
                    .frame(width: w * s.w, height: w * s.w)
                    .position(x: w * s.x, y: h * s.y - w * s.w / 2)
                    .onTapGesture { onTap(nil) }
            }
        }
        .aspectRatio(NestScene.aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

/// 房间里的一件家具：买了就画图，没买画一个虚线占位（点了也能买）
struct RoomPiece: View {
    let item: NestItem
    let owned: [String]
    let w: CGFloat
    let h: CGFloat
    let onTap: (NestItem?) -> Void

    var body: some View {
        let s = item.spot
        let have = item.has(owned)
        if have, let ui = UIImage(named: item.shownImage(owned)) {
            let iw = w * s.w * (NestItem.widthBoost[item.shownImage(owned)] ?? 1), ih = iw * ui.size.height / max(ui.size.width, 1)
            Image(uiImage: ui).resizable()
                .frame(width: iw, height: ih)
                .overlay {
                    if item == .pinboard { StickerPins().padding(.horizontal, iw * 0.13).padding(.vertical, ih * 0.14) }
                }
                .overlay(alignment: .topTrailing) {
                    if item.game != nil {
                        Image(systemName: "gamecontroller.fill").font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black).padding(5).background(Theme.coin, in: Circle())
                    }
                }
                .position(x: w * s.x, y: s.bottom ? h * s.y - ih / 2 : h * s.y)
                .onTapGesture { onTap(item) }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else if !have && item != .rug {
            let iw = w * s.w * 0.7
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .overlay(Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.4)))
                .frame(width: iw, height: iw * 0.8)
                .position(x: w * s.x, y: s.bottom ? h * s.y - iw * 0.4 : h * s.y)
                .onTapGesture { onTap(item) }
        }
    }
}

/// 窝页面
struct NestView: View {
    @ObservedObject var profile: ProfileStore
    var pet: String
    var petName: String
    @Binding var room: NestRoom
    var onBought: (NestItem) -> Void = { _ in }
    var onGame: (GameResult) -> Stickers.Sticker? = { _ in nil }
    @State private var bubble: String? = nil
    @State private var clip = NestView.baseClip()
    @State private var happyUntil = Date.distantPast
    @State private var night = Calendar.current.component(.hour, from: Date()) >= 20 || Calendar.current.component(.hour, from: Date()) < 6
    @State private var focus: NestItem? = nil
    @State private var playing: GameKind? = nil
    @State private var gacha = false
    @State private var album = false
    @State private var fitting = false
    @State private var face = "happy"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // 房间切换
                    HStack(spacing: 6) {
                        ForEach(NestRoom.allCases) { r in
                            Button { withAnimation(.easeInOut) { room = r } } label: {
                                Text(r.name).font(.system(size: 14, weight: room == r ? .semibold : .regular))
                                    .foregroundStyle(room == r ? Color.black : Theme.text2)
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(room == r ? Theme.accent : Theme.surface, in: Capsule())
                            }
                            .buttonStyle(.press)
                        }
                    }
                    .padding(.horizontal, 20)

                    ZStack(alignment: .top) {
                        TabView(selection: $room) {
                            ForEach(NestRoom.allCases) { r in
                                Group {
                                    if r == .bedroom {
                                        NestScene(owned: profile.profile.owned, night: night, clip: clip) { tap($0) }
                                    } else {
                                        RoomScene(room: r, owned: profile.profile.owned, pet: pet, accessories: profile.profile.equipped,
                                                  face: face) { tap($0) }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .tag(r)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: (UIScreen.main.bounds.width - 40) / NestScene.aspect)
                        if let b = bubble {
                            Text("“\(b)”").font(.system(size: 14)).foregroundStyle(Color(hex: "#2A2140"))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(hex: "#F3EEFF"), in: Capsule())
                                .padding(.top, 14)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    HStack {
                        Text(T("{0}里的东西", room.name)).font(.system(size: 13)).foregroundStyle(Theme.text2)
                        Spacer()
                        CoinBadge(coins: profile.profile.coins)
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        ForEach(room.items) { i in row(i) }
                        if room == .play {
                            Button { album = true } label: {
                                HStack {
                                    Text("✦").foregroundStyle(Color(hex: "#A8E6FF"))
                                    Text(T("贴纸册")).foregroundStyle(Theme.text)
                                    Spacer()
                                    Text("\(Stickers.owned.count)/\(Stickers.all.count) ›").foregroundStyle(Theme.text3)
                                }
                                .font(.system(size: 14))
                            }
                            .buttonStyle(EntryButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)

                    MKShopRooms(pet: pet, accessories: profile.profile.equipped).padding(.horizontal, 20)

                    Text(T("蛋壳永远是它的床。带 🎮 的家具点一下就能陪它玩，每个游戏每天第一局给币。"))
                        .font(.system(size: 11)).foregroundStyle(Theme.text3).multilineTextAlignment(.center)
                        .padding(.horizontal, 30).padding(.bottom, 110)
                }
                .padding(.top, 4)
            }
            .background(Theme.ground.ignoresSafeArea())
            .onReceive(Timer.publish(every: 12, on: .main, in: .common).autoconnect()) { _ in
                guard Date() > happyUntil else { return }
                let b = NestView.baseClip()
                withAnimation { clip = (b == "shell" && Int.random(in: 0..<3) == 0) ? "shell_bored" : b }
                face = ["happy", "idle", "think", "yawn"].randomElement()!
            }
            .navigationTitle(T("{0}的窝", petName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation { night.toggle() } } label: { Image(systemName: night ? "moon.fill" : "sun.max.fill") }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $focus) { i in
            ItemSheet(item: i, profile: profile, claimed: i.game.map { profile.gameClaimed($0) } ?? true) { action in
                focus = nil
                switch action {
                case .buy:
                    if profile.buyNest(i) { i.choose(0); say(i.thanks); onBought(i) }
                case .buyStyle(let st):
                    if profile.buyNest(st) { i.choose(st.n); say([T("新的！摆上了。"), T("这个款……我喜欢。"), T("{0}！我先躺躺看。", st.name)].randomElement()!); onBought(i) }
                case .choose(let n):
                    i.choose(n); profile.objectWillChange.send(); say([T("换了个样子。"), T("嗯，这个也好。")].randomElement()!)
                case .play:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if i.game == .gacha { gacha = true } else { playing = i.game }
                    }
                }
            }
            .presentationDetents([.height(i.styles.count > 1 ? 470 : 300)])
        }
        .fullScreenCover(item: $playing) { k in
            GameShell(kind: k, pet: pet, accessories: profile.profile.equipped, rewardAvailable: !profile.gameClaimed(k), onFinish: onGame)
        }
        .fullScreenCover(isPresented: $gacha) { GachaView(profile: profile, pet: pet) }
        .sheet(isPresented: $album) { StickerAlbum() }
        .sheet(isPresented: $fitting) { FittingRoom(profile: profile, pet: pet) }
    }

    @ViewBuilder private func row(_ i: NestItem) -> some View {
        let have = i.has(profile.profile.owned)
        HStack(spacing: 12) {
            Image(i.shownImage(profile.profile.owned)).resizable().scaledToFit().frame(width: 52, height: 52)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(i.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                Text(i.note).font(.system(size: 12)).foregroundStyle(Theme.text3).lineLimit(2)
            }
            Spacer()
            if i == .wardrobe {
                Button { fitting = true } label: {
                    Text(T("试衣间")).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 14).frame(minHeight: 40)
                }
                .buttonStyle(.press)
                .foregroundStyle(Color(hex: "#15101F"))
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
            } else if have, let g = i.game {
                Button { if g == .gacha { gacha = true } else { playing = g } } label: {
                    Text(profile.gameClaimed(g) ? T("玩") : T("玩 +币")).font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 14).frame(minHeight: 40)
                }
                .buttonStyle(.press)
                .foregroundStyle(Color(hex: "#15101F"))
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
            } else if have {
                if i.styles.count > 1 {
                    Button { focus = i } label: {
                        Text(T("换款 {0}/{1}", i.styles.filter { profile.profile.owned.contains($0.ownedKey) || ($0.n == 0 && i.free) }.count, i.styles.count))
                            .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 12).frame(minHeight: 36)
                    }
                    .buttonStyle(.press).foregroundStyle(Theme.text)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                }
            } else {
                let afford = profile.profile.coins >= i.price
                Button {
                    if profile.buyNest(i) { say(i.thanks); onBought(i) }
                } label: {
                    Text(T("{0} 币", i.price)).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 14).frame(minHeight: 40)
                }
                .buttonStyle(.press)
                .foregroundStyle(Color(hex: "#15101F"))
                .background(Theme.coin, in: RoundedRectangle(cornerRadius: 12))
                .disabled(!afford).opacity(afford ? 1 : 0.4)
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    /// 按时间：夜里睡、饭点吃、其余窝着
    static func baseClip(_ d: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        let t = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        switch t {
        case 0..<450, 1380..<1440, 840..<900: return "shell_sleep"
        case 690..<780, 1080..<1170:          return "shell_eat"
        default:                               return "shell"
        }
    }

    private func tap(_ i: NestItem?) {
        if let i {
            if i.has(profile.profile.owned) { say(i.tapLines.randomElement()!) }
            if i == .wardrobe { fitting = true } else { focus = i }
            return
        }
        if room == .bedroom {
            // 点它：壳像不倒翁一样晃起来，笑；睡着时先被晃醒
            happyUntil = Date().addingTimeInterval(3.6)
            withAnimation { clip = "shell_happy" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) { if Date() >= happyUntil { withAnimation { clip = NestView.baseClip() } } }
        } else {
            face = "laugh"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { face = "happy" }
        }
        let n = profile.profile.owned.filter { $0.hasPrefix("nest.") }.count
        say(n == 0 ? [T("壳里最舒服。"), T("这是我的床，我出生的地方。"), T("空空的……添点东西？")].randomElement()!
                   : [T("窝越来越像家了。"), T("别吵，我躺着呢。"), T("这些都是你给的。")].randomElement()!)
    }

    private func say(_ s: String) {
        withAnimation { bubble = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { if bubble == s { withAnimation { bubble = nil } } }
    }
}

/// 点家具弹出来：没买 → 买；有游戏 → 玩；能换款的列出所有款式（买过的点一下就换上）
private struct ItemSheet: View {
    enum Action { case buy, play, buyStyle(NestStyle), choose(Int) }
    let item: NestItem
    @ObservedObject var profile: ProfileStore
    let claimed: Bool
    let act: (Action) -> Void
    @State private var pick: Int = -1

    var body: some View {
        let owned = profile.profile.owned
        let have = item.has(owned)
        let styles = item.styles
        let sel = pick >= 0 ? pick : item.chosen
        let cur = styles[min(sel, styles.count - 1)]
        let curOwned = (cur.n == 0 && item.free) || owned.contains(cur.ownedKey)
        VStack(spacing: 12) {
            Image(cur.image).resizable().scaledToFit().frame(height: 110)
                .id(cur.id).transition(.scale(scale: 0.8).combined(with: .opacity))
            HStack(spacing: 6) {
                Text(cur.name).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
                if styles.count > 1 {
                    Text(cur.tier).font(.system(size: 10, weight: .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(cur.award != nil ? Color.pink.opacity(0.85) : (cur.price >= 500 ? Theme.coin : Theme.accent.opacity(0.8)), in: Capsule())
                }
            }
            Text(cur.note).font(.system(size: 13)).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
            if styles.count > 1 {
                HStack(spacing: 10) {
                    ForEach(styles) { st in
                        let o = (st.n == 0 && item.free) || owned.contains(st.ownedKey)
                        Button { withAnimation(.spring(response: 0.3)) { pick = st.n } } label: {
                            VStack(spacing: 4) {
                                Image(st.image).resizable().scaledToFit().frame(height: 54).padding(6)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(st.n == sel ? Theme.accent : .clear, lineWidth: 2))
                                Text(o ? (item.chosen == st.n && have ? T("摆着") : T("有了")) : (st.award != nil ? T("装修送") : T("{0} 币", st.price)))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(o ? Theme.text2 : (st.award != nil ? Color.pink : Theme.coin))
                            }
                        }
                        .buttonStyle(.press)
                    }
                }
            }
            if !curOwned, let how = cur.awardText {
                Text(how).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text2)
                    .frame(maxWidth: .infinity, minHeight: 50).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            } else if !curOwned {
                let afford = profile.profile.coins >= cur.price
                Button { act(cur.n == 0 ? .buy : .buyStyle(cur)) } label: {
                    Text(afford ? T("{0} 币 · 摆到窝里", cur.price) : T("还差 {0} 币", cur.price - profile.profile.coins))
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 50).background(Theme.coin, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.press).disabled(!afford).opacity(afford ? 1 : 0.5)
            } else if cur.n != item.chosen {
                Button { act(.choose(cur.n)) } label: {
                    Text(T("换成这个")).font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 50).background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.press)
            } else if let g = item.game {
                Button { act(.play) } label: {
                    Text(claimed ? T("玩「{0}」", g.title) : T("玩「{0}」· 今天 +币", g.title))
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 50).background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.press)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

/// 贴纸墙上贴着的贴纸（最多 12 张，4×3）
struct StickerPins: View {
    var body: some View {
        let owned = Stickers.all.filter { Stickers.owned.contains($0.id) }.prefix(12)
        GeometryReader { g in
            let cw = g.size.width / 4, ch = g.size.height / 3
            ForEach(Array(owned.enumerated()), id: \.element.id) { i, s in
                StickerImage(sticker: s)
                    .frame(width: cw * 0.8, height: ch * 0.8)
                    .rotationEffect(.degrees(Double((i * 37) % 17) - 8))
                    .position(x: cw * (CGFloat(i % 4) + 0.5), y: ch * (CGFloat(i / 4) + 0.5))
            }
        }
        .allowsHitTesting(false)
    }
}

/// 试衣间（点卧室的衣柜进来）：大大的它 + 买过的衣服点一下就穿/脱；没买的也能在这直接买
struct FittingRoom: View {
    @ObservedObject var profile: ProfileStore
    let pet: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28).fill(Color.black)
                        VideoPetView(pet: pet, pose: .stand, accessories: profile.profile.equipped, size: 220)
                    }
                    .frame(height: 300)
                    .padding(.horizontal, 20)

                    Text(profile.profile.equipped.isEmpty ? T("什么都没穿，最自在。") : T("一次穿一件，穿新的会把旧的收回衣柜。"))
                        .font(.system(size: 13)).foregroundStyle(Theme.text3)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Accessory.all) { a in
                            let have = profile.profile.owned.contains(a.id)
                            let on = profile.isEquipped(a)
                            Button {
                                if have { if on { profile.unequip(a) } else { profile.equip(a) } }
                                else { _ = profile.buy(a) }
                            } label: {
                                VStack(spacing: 6) {
                                    Image("acc_" + a.id).resizable().scaledToFit().frame(height: 56)
                                        .opacity(have ? 1 : 0.4)
                                    Text(a.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
                                    let locked = !have && !a.onSale()
                                    Text(on ? T("穿着") : (have ? T("点一下穿上") : (locked ? a.lockText : T("{0} 币", a.price))))
                                        .font(.system(size: 11)).foregroundStyle(on ? Theme.accent : (have ? Theme.text3 : (locked ? Theme.text3 : Theme.coin)))
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(on ? Theme.accent : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.press)
                            .disabled(!have && (profile.profile.coins < a.price || !a.onSale()))
                        }
                    }
                    .padding(.horizontal, 20)
                    if !profile.profile.equipped.isEmpty {
                        Button(T("全部脱下")) { for a in Accessory.all where profile.isEquipped(a) { profile.unequip(a) } }
                            .font(.system(size: 14)).foregroundStyle(Theme.text2)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("试衣间"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { CoinBadge(coins: profile.profile.coins) }
                ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}
