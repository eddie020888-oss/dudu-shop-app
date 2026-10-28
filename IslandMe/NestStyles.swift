import SwiftUI

/// 窝里每个位置的可替换款式（2026-10-19）：原款 + 2 个新款。
/// 买过的款式随时换，摆在同一个位置。v1 是中档换色换材质，v2 是大件主题款（攒一两周的目标）。
struct NestStyle: Identifiable, Hashable {
    let item: NestItem
    let n: Int            // 0 = 原款，1、2 = 新款
    let name: String
    let price: Int
    let note: String
    /// 纪念款（2026-10-27）：不卖，装修完一整片地方送（值是那片地方的名字；"all" = 全部装修完）
    var award: String? = nil

    var id: String { "\(item.rawValue).v\(n)" }
    var ownedKey: String { n == 0 ? item.ownedKey : "nest.\(item.rawValue).v\(n)" }
    var image: String { n == 0 ? item.image : "nest_\(item.rawValue)_v\(n)" }
    var tier: String { award != nil ? T("纪念款") : (price >= 500 ? T("大件") : (price >= 200 ? T("中档") : T("小件"))) }
    /// 怎么得到（纪念款）
    var awardText: String? { award.map { $0 == "all" ? T("96 件装修全部做完送") : T("装修完「{0}」送", $0) } }
}

extension NestItem {
    /// 能换款的位置（地毯烘焙在背景里；游戏桌、扭蛋机、衣柜、杯子桌是功能件，不换）
    var styleable: Bool { ![.rug, .cups, .cardtable, .gacha, .wardrobe].contains(self) }

    /// 纪念款：每片地方装修完送一件，摆在窝里（商城买不到）。图 nest_<item>_v3
    static let awards: [(area: String, item: NestItem, name: String, note: String)] = [
        ("kd", .snack,     T("小厨房碗柜"),     T("小厨房开张那天的碗柜，碗都摞得歪歪的")),
        ("sf", .painting,  T("开张那天"),       T("小店门面刚装好的样子，它站在门口")),
        ("gd", .plant,     T("菜园胡萝卜盆"),   T("从后院菜园挖回来的一盆胡萝卜")),
        ("tr", .floorlamp, T("茶室纸灯笼"),     T("茶室里那盏暖黄的纸灯笼")),
        ("rt", .globe,     T("观星台星图仪"),   T("屋顶观星台上那台，星星会自己转")),
        ("gt", .window,    T("嘟嘟星之门圆窗"), T("窗外就是嘟嘟星，一闪一闪")),
        ("sn", .blanket,   T("雪夜毛线被"),     T("雪夜小屋里那条厚厚的毛线被")),
        ("hs", .lounger,   T("温泉竹躺椅"),     T("温泉小院的竹躺椅，躺上去暖洋洋")),
        ("all", .trophies, T("嘟嘟小店金奖杯"), T("96 件装修全部做完才有的金奖杯")),
    ]
    /// 某片地方（或 "all"）对应的纪念款 key
    static func awardKey(for area: String) -> String? {
        awards.first { $0.area == area }.map { "nest.\($0.item.rawValue).v3" }
    }

    private static let table: [NestItem: [(String, Int, String)]] = [
        .cushion:    [(T("草莓软垫"), 120, T("草莓形状，上面有小籽")), (T("云朵大软垫"), 420, T("一大朵云，陷进去看不见它"))],
        .blanket:    [(T("格子小毛毯"), 130, T("暖暖的格子，边上有流苏")), (T("星河羽绒被"), 480, T("被面是一整条银河，星星会闪"))],
        .lamp:       [(T("月亮夜灯"), 160, T("弯弯的月亮，暖黄色")), (T("水母夜灯"), 520, T("软软的水母，触须一闪一闪"))],
        .tv:         [(T("复古木纹电视"), 240, T("老式旋钮，木头外壳")), (T("兔耳大电视"), 800, T("大屏幕，顶上两只兔耳天线"))],
        .snack:      [(T("糖果罐柜"), 200, T("一排玻璃罐，装满糖")), (T("零食贩卖机"), 900, T("投币就掉零食，它不会投币"))],
        .window:     [(T("花边小圆窗"), 260, T("挂着小窗帘，窗台有盆花")), (T("星星彩窗"), 1000, T("彩色玻璃拼的星星，阳光照进来一地颜色"))],
        .telescope:  [(T("黄铜望远镜"), 320, T("亮晶晶的老式黄铜")), (T("观星台大望远镜"), 1200, T("白色大炮筒，专业的"))],
        .nightstand: [(T("蘑菇床头柜"), 120, T("红顶白点的大蘑菇")), (T("小冰箱床头柜"), 360, T("半夜饿了伸手就有"))],
        .lights:     [(T("爱心串灯"), 90, T("一串粉色小爱心")), (T("星月吊饰灯"), 300, T("月亮和星星挂成一串，会慢慢转"))],
        .painting:   [(T("饭团小画"), 120, T("画的是一个饭团，它很满意")), (T("嘟嘟星三联画"), 400, T("三幅连在一起：草地、海边、夜空"))],
        .glowplant:  [(T("发光小蘑菇"), 90, T("一小丛，碰一下就亮")), (T("水晶簇"), 350, T("嘟嘟星的水晶，自己会发光"))],
        .slippers:   [(T("兔子拖鞋"), 80, T("带兔耳朵，它还是不穿")), (T("云朵拖鞋"), 240, T("踩上去像踩云"))],
        .clock:      [(T("饭团挂钟"), 100, T("指针是两根筷子")), (T("布谷鸟钟"), 450, T("整点会弹出一只小鸟"))],
        .plush:      [(T("胡萝卜抱枕"), 90, T("长长的一根，抱着睡")), (T("星星大抱枕"), 300, T("比它还大的星星，抱着就睡着"))],
        .floorlamp:  [(T("郁金香落地灯"), 120, T("一朵粉色郁金香")), (T("月亮落地灯"), 380, T("灯罩是半个月亮"))],
        .beanbag:    [(T("蜜桃豆袋"), 160, T("粉粉的一颗桃子，软乎乎")), (T("布丁懒人沙发"), 600, T("焦糖顶，duang duang 的"))],
        .plant:      [(T("小仙人掌"), 70, T("不扎手的那种")), (T("嘟嘟星发光树"), 520, T("叶子是小星星，晚上会亮"))],
        .chime:      [(T("贝壳风铃"), 90, T("海边捡的小贝壳")), (T("星月风铃"), 320, T("叮——比原来的更好听"))],
        .globe:      [(T("木头星球仪"), 120, T("手工木头做的")), (T("悬浮星球仪"), 480, T("星球自己飘在底座上转"))],
        .lounger:    [(T("小吊床"), 220, T("晃啊晃，就睡着了")), (T("月亮躺椅"), 900, T("躺在月亮里看星星"))],
        .books:      [(T("绘本塔"), 80, T("全是图，没有字")), (T("小书架"), 280, T("书摆得整整齐齐（它没摆）"))],
        .pinboard:   [(T("云朵布告板"), 120, T("毛毡做的云，贴纸按上去就粘住")), (T("星星小黑板"), 360, T("黑板上画着星星"))],
        .trophies:   [(T("奖牌挂墙"), 120, T("挂满了小奖牌")), (T("水晶奖杯柜"), 420, T("玻璃柜，奖杯会反光"))],
        .beanbag2:   [(T("柠檬豆袋"), 160, T("黄黄的一瓣柠檬")), (T("西瓜懒人沙发"), 600, T("半个西瓜，它坐中间"))],
        .toybox:     [(T("恐龙玩具箱"), 100, T("一只张着嘴的小恐龙")), (T("火箭玩具箱"), 400, T("一艘小火箭，玩具从舱门里掉出来"))],
    ]

    /// 原款 + 新款
    var styles: [NestStyle] {
        var a = [NestStyle(item: self, n: 0, name: name, price: price, note: note)]
        if styleable, let t = Self.table[self] {
            for (k, v) in t.enumerated() { a.append(NestStyle(item: self, n: k + 1, name: v.0, price: v.1, note: v.2)) }
        }
        if let e = Self.awards.first(where: { $0.item == self }) {
            a.append(NestStyle(item: self, n: 3, name: e.name, price: 0, note: e.note, award: e.area == "all" ? "all" : (MKStory.areas.first { $0.key == e.area }?.name ?? e.area)))
        }
        return a
    }

    private var styleKey: String { "nest.style." + rawValue }
    /// 现在摆的是第几款
    var chosen: Int { UserDefaults.standard.integer(forKey: styleKey) }
    func choose(_ n: Int) { UserDefaults.standard.set(n, forKey: styleKey) }

    /// 这个位置有没有东西（原款或任何一款买过）
    func has(_ owned: [String]) -> Bool { free || styles.contains { owned.contains($0.ownedKey) } }

    /// 个别新款形状更扁/更宽，摆在同一个位置时放大一点看着才一样大
    static let widthBoost: [String: CGFloat] = ["nest_trophies_v1": 1.35, "nest_toybox_v2": 0.9, "nest_lights_v1": 1.05]

    /// 现在该画哪张图：选中的款买过就画它，否则回落到原款
    func shownImage(_ owned: [String]) -> String {
        let s = styles
        if chosen > 0, chosen < s.count, owned.contains(s[chosen].ownedKey), UIImage(named: s[chosen].image) != nil { return s[chosen].image }
        if !(free || owned.contains(ownedKey)), let first = s.dropFirst().first(where: { owned.contains($0.ownedKey) }), UIImage(named: first.image) != nil {
            return first.image
        }
        return image
    }
}
