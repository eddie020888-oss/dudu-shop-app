import SwiftUI

// MARK: 装修（6 个地方、12 章、72 个任务；星星越往后越贵；故事一路讲到嘟嘟星之门）
enum MKStory {
    struct Task { let id: String; let title: String; let stars: Int; let deco: String?; let line: String }
    struct Chapter { let title: String; let tasks: [Task] }
    struct Spot { let x: CGFloat; let y: CGFloat; let w: CGFloat }
    struct Area { let key: String; let name: String; let bg: String; let chapters: [Chapter]; let spots: [String: Spot]; let order: [String] }

    private static func Tk(_ id: String, _ title: String, _ stars: Int, _ deco: String?, _ line: String) -> Task {
        Task(id: id, title: title, stars: stars, deco: deco, line: line)
    }
    private static func S(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) -> Spot { Spot(x: x, y: y, w: w) }

    /// 节奏（2026-10-20 真人模式自测：认真玩 16 天就全做完）：前 3 章原价，新手要快；
    /// 第 4 章起每章贵 10%，最多 1.8 倍。菜多了以后（每张单都可能要菜、做菜要等），同样的价格比原来慢不少：
    /// 15%/2.2 倍时机器人第 43–53 天才做完，太慢；25%/3 倍第 58 天。
    /// 目标：机器人（完美玩家）约 30 天、认真的真人约 6 周、随便玩 2–3 个月做完，之后靠更新加新区域
    static let areas: [Area] = priced(rawAreas)
    // 2026-10-27 产出器不再卡人以后机器人 27–29 天做完（原来 36–38），装修价涨回来：第 4 章起每章 +15%，最多 2.6 倍
    static func priceScale(chapter k: Int) -> Double { k < 3 ? 1 : min(2.6, 1 + 0.15 * Double(k - 2)) }
    private static func priced(_ raw: [Area]) -> [Area] {
        var k = 0
        return raw.map { a in
            let chs = a.chapters.map { ch -> Chapter in
                let m = priceScale(chapter: k); k += 1
                return Chapter(title: ch.title, tasks: ch.tasks.map { t in
                    Task(id: t.id, title: t.title, stars: Int((Double(t.stars) * m).rounded()), deco: t.deco, line: t.line)
                })
            }
            return Area(key: a.key, name: a.name, bg: a.bg, chapters: chs, spots: a.spots, order: a.order)
        }
    }
    private static let rawAreas: [Area] = [
        Area(key: "kd", name: T("小厨房"), bg: "kd_bg", chapters: [
            Chapter(title: T("第一章 · 空荡荡的小厨房"), tasks: [
                Tk("t1", T("擦干净灶台"), 5, nil, T("它躺在一边指挥：「左边……再左边一点。」")),
                Tk("t2", T("挂上星星吊灯"), 7, "kd_lamp", T("灯一亮，墙上映出一圈小星星，和蛋壳上的一样。")),
                Tk("t3", T("摆上小餐桌"), 8, "kd_table", T("「以后就在这儿吃，躺着吃。」")),
                Tk("t4", T("铺上格子地毯"), 8, "kd_rug", T("它在地毯上躺成一个「大」字，宣布这块归它。")),
                Tk("t5", T("放一个调料架"), 10, "kd_shelf", T("调料瓶里有一瓶亮晶晶的粉，瓶身写着嘟嘟星字。")),
                Tk("t6", T("挂上嘟嘟星窗帘"), 14, "kd_curtain", T("窗帘上的花纹，是它小时候见过的发光草。")),
            ]),
            Chapter(title: T("第二章 · 门那边的菜谱"), tasks: [
                Tk("t7", T("修好老冰箱"), 14, "kd_fridge", T("冰箱最里面压着一张旧菜谱，抬头一行嘟嘟星字。它一把抢过去，塞进了蛋壳底下。")),
                Tk("t8", T("摆上盆栽香草"), 15, "kd_herbs", T("「这个味道……我记得。」它闻了好久。")),
                Tk("t9", T("挂上小黑板"), 17, "kd_board", T("它在黑板上画了一间小房子，屋顶一颗星。你一看，它就擦掉了。")),
                Tk("t10", T("装一个小吧台"), 20, "kd_bar", T("吧台下面有个抽屉，打不开。钥匙孔是星星形状的。")),
                Tk("t11", T("把旧菜谱裱起来"), 22, "kd_frame", T("你还是把菜谱找出来裱上了。抬头那行字它终于念了：「嘟嘟小店——嘟嘟星，第一家。」落款一顶小厨师帽，和它蛋壳底下那个印记一模一样。")),
                Tk("t12", T("点亮整个厨房"), 27, "kd_lights", T("全亮的那一刻，灵动岛那道门轻轻动了一下。")),
            ]),
        ], spots: [
            "kd_lights": S(0.50, 0.10, 0.90), "kd_lamp": S(0.50, 0.17, 0.18),
            "kd_curtain": S(0.80, 0.250, 0.27), "kd_frame": S(0.36, 0.220, 0.12),
            "kd_board": S(0.16, 0.260, 0.17), "kd_shelf": S(0.50, 0.33, 0.30),
            "kd_fridge": S(0.17, 0.482, 0.36), "kd_bar": S(0.84, 0.512, 0.26),
            "kd_herbs": S(0.63, 0.379, 0.15), "kd_rug": S(0.50, 0.80, 0.80),
            "kd_table": S(0.50, 0.74, 0.44),
        ], order: ["kd_rug", "kd_lights", "kd_curtain", "kd_frame", "kd_board", "kd_shelf", "kd_fridge", "kd_bar", "kd_herbs", "kd_table", "kd_lamp"]),

        Area(key: "sf", name: T("小店门面"), bg: "sf_bg", chapters: [
            Chapter(title: T("第三章 · 换上真招牌"), tasks: [
                Tk("a1", T("把纸板招牌换成真招牌"), 22, "sf_sign", T("纸板招牌它没舍得扔，塞进蛋壳底下当枕头。新招牌挂歪了，它说歪着才有个性。")),
                Tk("a2", T("搬来木头柜台"), 24, "sf_counter", T("它在柜台后面给自己铺了个窝，说这是「收银员专座」。")),
                Tk("a3", T("立一块菜单板"), 27, "sf_menu", T("菜单最下面画了一颗星：「隐藏菜单。那边那家店的招牌菜，我只记得一半。」")),
                Tk("a4", T("挂上纸灯笼"), 29, "sf_lanterns", T("灯笼一亮，门口的小路像一条星河。")),
                Tk("a5", T("摆上点心柜"), 31, "sf_display", T("「样品不许吃。」它边说边舔了舔嘴。")),
                Tk("a6", T("门口放一盆大绿植"), 34, "sf_plant", T("叶子背面有一点点荧光，跟它家乡的发光草一样。")),
            ]),
            Chapter(title: T("第四章 · 外卖跑起来"), tasks: [
                Tk("a7", T("买一辆送餐小车"), 31, "sf_bike", T("它坐上去试了试，说自己负责「押车」。")),
                Tk("a8", T("堆好外卖盒"), 34, "sf_boxes", T("每个盒子上都贴了一颗它画的小星星。")),
                Tk("a9", T("加两张高脚凳"), 36, "sf_stools", T("「一张你的，一张我的。我的那张要放垫子。」")),
                Tk("a10", T("挂一个饼干钟"), 37, "sf_clock", T("钟停在 9 点 41 分。「那天该我接班。我太困了。」")),
                Tk("a11", T("撑起条纹遮阳棚"), 39, "sf_awning", T("下雨那天，棚子底下塞着一封信，信封上写：「给逃跑的小徒弟」。")),
                Tk("a12", T("布置橱窗"), 44, "sf_window", T("信里只有一行字：「店先关着。等你。」落款还是那顶小厨师帽。")),
            ]),
        ], spots: [
            "sf_awning": S(0.50, 0.12, 0.92), "sf_window": S(0.50, 0.30, 0.56), "sf_sign": S(0.80, 0.14, 0.26),
            "sf_lanterns": S(0.50, 0.19, 0.64), "sf_menu": S(0.12, 0.590, 0.19), "sf_clock": S(0.16, 0.24, 0.16),
            "sf_display": S(0.82, 0.48, 0.30), "sf_plant": S(0.90, 0.562, 0.20), "sf_boxes": S(0.86, 0.779, 0.20),
            "sf_counter": S(0.50, 0.62, 0.52), "sf_stools": S(0.50, 0.80, 0.40), "sf_bike": S(0.22, 0.86, 0.36),
        ], order: ["sf_window", "sf_awning", "sf_lanterns", "sf_sign", "sf_clock", "sf_menu", "sf_display", "sf_plant", "sf_boxes", "sf_counter", "sf_stools", "sf_bike"]),

        Area(key: "gd", name: T("后院菜园"), bg: "gd_bg", chapters: [
            Chapter(title: T("第五章 · 后院长出来了"), tasks: [
                Tk("b1", T("开一块菜地"), 36, "gd_bed", T("「胡萝卜要自己种的才甜。」它说完就去睡了。")),
                Tk("b2", T("种一棵樱桃树"), 37, "gd_tree", T("第一颗樱桃熟的时候，它把它留给了你。")),
                Tk("b3", T("修一口小井"), 39, "gd_well", T("井水里倒映的星空，比天上多一颗。那颗星，每到晚上九点多就会闪一下。")),
                Tk("b4", T("盖一间工具小屋"), 44, "gd_shed", T("小屋角落有个旧木箱，上面刻着一顶小厨师帽。")),
                Tk("b5", T("立一座小风车"), 46, "gd_windmill", T("风车转起来，它说嘟嘟星的风是甜的。")),
                Tk("b6", T("放一张长椅"), 49, "gd_bench", T("「坐着看菜长，也算干活。」")),
            ]),
            Chapter(title: T("第六章 · 夜里的菜园"), tasks: [
                Tk("b7", T("立一盏园灯"), 49, "gd_lamp", T("灯下的泥地上，有一串很小很小的脚印，不像地球上的。")),
                Tk("b8", T("挖一个小池塘"), 53, "gd_pond", T("池塘里的睡莲半夜会发光，一闪一闪，正好是 9 点 41 分。")),
                Tk("b9", T("搭一个小温室"), 54, "gd_greenhouse", T("温室里长出一株它叫得出名字的草——嘟嘟星的。")),
                Tk("b10", T("种一片玉米"), 58, "gd_corn", T("玉米长得比它高，它说这样就能藏起来偷懒了。")),
                Tk("b11", T("挂一张吊床"), 61, "gd_hammock", T("它在吊床上说梦话：「爷爷……灯……」")),
                Tk("b12", T("铺一条石子路"), 66, "gd_path", T("石子路一直通到后墙——墙上有扇你从没注意过的小门。")),
            ]),
        ], spots: [
            "gd_tree": S(0.18, 0.40, 0.34), "gd_windmill": S(0.84, 0.36, 0.28), "gd_shed": S(0.66, 0.44, 0.30),
            "gd_greenhouse": S(0.36, 0.46, 0.28), "gd_corn": S(0.90, 0.56, 0.22), "gd_well": S(0.12, 0.62, 0.22),
            "gd_lamp": S(0.30, 0.58, 0.12), "gd_bed": S(0.62, 0.66, 0.36), "gd_pond": S(0.30, 0.76, 0.36),
            "gd_path": S(0.56, 0.86, 0.40), "gd_bench": S(0.80, 0.78, 0.30), "gd_hammock": S(0.50, 0.58, 0.30),
        ], order: ["gd_path", "gd_tree", "gd_windmill", "gd_shed", "gd_greenhouse", "gd_corn", "gd_hammock", "gd_lamp", "gd_well", "gd_bed", "gd_pond", "gd_bench"]),

        Area(key: "tr", name: T("茶室"), bg: "tr_bg", chapters: [
            Chapter(title: T("第七章 · 慢慢的茶室"), tasks: [
                Tk("c1", T("摆上矮茶桌"), 49, "tr_table", T("「喝茶要慢，像我一样。」")),
                Tk("c2", T("放两个坐垫"), 53, "tr_cushions", T("它躺在两个坐垫上，一个当枕头，一个垫脚。")),
                Tk("c3", T("挂一幅星星画"), 54, "tr_scroll", T("画上是一间小店，门口的招牌歪歪的——和我们那块一样歪。它看了很久没说话。")),
                Tk("c4", T("立一扇屏风"), 60, "tr_screen", T("屏风后面，它藏了一张照片——一颗蛋。可蛋上的花纹，和它自己那颗不太一样。")),
                Tk("c5", T("架上小铁壶"), 61, "tr_kettle", T("水开的声音，它说像嘟嘟星的雨。")),
                Tk("c6", T("摆满茶罐"), 66, "tr_shelf", T("最里面那罐茶叶会发光，罐底写着「回家用」。")),
            ]),
            Chapter(title: T("第八章 · 月亮窗"), tasks: [
                Tk("c7", T("点一盏纸灯"), 66, "tr_lamp", T("纸灯上映出一张星图，有一颗星在一闪一闪。星图旁边，画着一条弯弯的虚线。")),
                Tk("c8", T("养一盆盆景"), 71, "tr_bonsai", T("它每天给盆景浇一滴水，说浇多了它会变懒。")),
                Tk("c9", T("开一扇月亮窗"), 75, "tr_moonwin", T("从月亮窗看出去，正好能看到那颗一闪一闪的星。")),
                Tk("c10", T("铺一块草编地毯"), 78, "tr_rug", T("「躺这儿看星星，最舒服。」")),
                Tk("c11", T("插一瓶薰衣草"), 82, "tr_vase", T("薰衣草的颜色，和它的毛一模一样。")),
                Tk("c12", T("放一个旧茶箱"), 88, "tr_chest", T("茶箱的抽屉里，有半张地图。另一半在哪？")),
            ]),
        ], spots: [
            "tr_moonwin": S(0.50, 0.26, 0.40), "tr_scroll": S(0.18, 0.26, 0.18), "tr_shelf": S(0.82, 0.24, 0.28),
            "tr_screen": S(0.16, 0.50, 0.30), "tr_lamp": S(0.88, 0.50, 0.16), "tr_vase": S(0.72, 0.500, 0.14),
            "tr_chest": S(0.86, 0.66, 0.22), "tr_bonsai": S(0.30, 0.46, 0.16), "tr_rug": S(0.50, 0.80, 0.80),
            "tr_table": S(0.50, 0.74, 0.40), "tr_cushions": S(0.50, 0.86, 0.50), "tr_kettle": S(0.16, 0.76, 0.20),
        ], order: ["tr_rug", "tr_moonwin", "tr_scroll", "tr_shelf", "tr_screen", "tr_lamp", "tr_vase", "tr_bonsai", "tr_chest", "tr_kettle", "tr_table", "tr_cushions"]),

        Area(key: "rt", name: T("屋顶观星台"), bg: "rt_bg", chapters: [
            Chapter(title: T("第九章 · 上屋顶"), tasks: [
                Tk("d1", T("架一台望远镜"), 63, "rt_telescope", T("它指着一颗星：「那里，是我家。」望远镜里，那颗星亮了好几块——都是你做的单。")),
                Tk("d2", T("挂上星星灯串"), 67, "rt_lights", T("灯串一亮，楼下的人都抬头看了一眼。")),
                Tk("d3", T("摆一张户外沙发"), 71, "rt_sofa", T("它宣布：屋顶也归它。")),
                Tk("d4", T("搬上几盆花"), 74, "rt_plants", T("花一开，那颗星好像也亮了一点。")),
                Tk("d5", T("放一个小烤炉"), 78, "rt_grill", T("「烤胡萝卜，嘟嘟星的家乡菜。」")),
                Tk("d6", T("搭一顶小帐篷"), 84, "rt_tent", T("帐篷里，它摊开了茶箱里那半张地图。抬头一看——另外半张，画在天窗的玻璃上。")),
            ]),
            Chapter(title: T("第十章 · 拼起来的星图"), tasks: [
                Tk("d7", T("摆几盏地灯"), 79, "rt_lanterns", T("地灯排成一个形状——和地图上的星座一样。")),
                Tk("d8", T("点一个小火塘"), 84, "rt_firepit", T("火光里，它讲起了掉下来那天：蛋壳滚了很久，它一直在睡。")),
                Tk("d9", T("立一块星图板"), 89, "rt_starmap", T("两张半地图拼在一起：虚线从一颗星出发，穿过一道门，一直画到……这条街。")),
                Tk("d10", T("挂上三角彩旗"), 92, "rt_bunting", T("「等门开了，要办一个派对。」")),
                Tk("d11", T("装一个吊椅秋千"), 97, "rt_swing", T("你轻轻推了一下秋千，它说：「再高一点……想离家近一点。」")),
                Tk("d12", T("放一个大懒人沙发"), 104, "rt_beanbag", T("它窝在里面，盯着地图的终点看了很久：「原来是这样。」")),
            ]),
        ], spots: [
            "rt_lights": S(0.50, 0.34, 0.72), "rt_bunting": S(0.40, 0.24, 0.60), "rt_starmap": S(0.82, 0.48, 0.24),
            "rt_telescope": S(0.18, 0.50, 0.26), "rt_tent": S(0.70, 0.56, 0.34), "rt_swing": S(0.34, 0.54, 0.26),
            "rt_plants": S(0.90, 0.66, 0.20), "rt_grill": S(0.12, 0.70, 0.18), "rt_sofa": S(0.50, 0.70, 0.46),
            "rt_firepit": S(0.50, 0.84, 0.24), "rt_lanterns": S(0.16, 0.86, 0.22), "rt_beanbag": S(0.82, 0.84, 0.26),
        ], order: ["rt_lights", "rt_bunting", "rt_starmap", "rt_telescope", "rt_tent", "rt_swing", "rt_plants", "rt_grill", "rt_sofa", "rt_firepit", "rt_lanterns", "rt_beanbag"]),

        Area(key: "gt", name: T("嘟嘟星之门"), bg: "gt_bg", chapters: [
            Chapter(title: T("第十一章 · 小门后面"), tasks: [
                Tk("e1", T("点亮两根水晶柱"), 75, "gt_pillars", T("后院小门后面，是一间圆圆的石头屋子。屋子很暗，门缝里透过来的光，比平时弱。")),
                Tk("e2", T("放出光球"), 81, "gt_orbs", T("光球绕着它转，有几只暗暗的，它把它们一只只捧到灯下。")),
                Tk("e3", T("铺一条星星地毯"), 84, "gt_carpet", T("地毯一直铺到那扇巨大的圆门前。")),
                Tk("e4", T("擦干净石台"), 89, "gt_pedestal", T("石台上的钥匙孔，和吧台抽屉、信上的星星一模一样。")),
                Tk("e5", T("让发光藤蔓长出来"), 94, "gt_vines", T("藤蔓上开的花，是它最爱的薰衣草色。")),
                Tk("e6", T("摆上水晶簇"), 99, "gt_crystals", T("水晶里映出那家小店——窗户的光，比上次又暗了一点。")),
            ]),
            Chapter(title: T("第十二章 · 嘟嘟星之门"), tasks: [
                Tk("e7", T("点燃魔法灯"), 99, "gt_lamps", T("灯一亮，门上的花纹开始慢慢转动——门那边，好像也有人在一盏一盏点灯。")),
                Tk("e8", T("挂上月亮"), 104, "gt_moon", T("「我妈妈说过，月亮是门的守卫。」")),
                Tk("e9", T("摆好符文石"), 109, "gt_runes", T("符文石拼出一句话：「做给最重要的那个人吃。」")),
                Tk("e10", T("修好光之泉"), 113, "gt_fountain", T("泉水里映出总店门口：一个空碗，碗边放着一顶厨师帽。")),
                Tk("e11", T("挂起星星旗"), 120, "gt_banner", T("「门开了以后……爷爷会让我回去接班吧。」它小声说。")),
                Tk("e12", T("找到星星钥匙"), 132, "gt_key", T("钥匙插进去，门开了。门那边，总店的灯一盏一盏亮了起来。")),
            ]),
        ], spots: [
            "gt_vines": S(0.50, 0.06, 0.95), "gt_moon": S(0.84, 0.13, 0.12), "gt_banner": S(0.16, 0.15, 0.12),
            "gt_orbs": S(0.16, 0.40, 0.18), "gt_pillars": S(0.50, 0.48, 0.62), "gt_lamps": S(0.50, 0.66, 0.56),
            "gt_fountain": S(0.13, 0.69, 0.20), "gt_crystals": S(0.87, 0.67, 0.20), "gt_carpet": S(0.50, 0.81, 0.30),
            "gt_runes": S(0.50, 0.90, 0.44), "gt_pedestal": S(0.50, 0.71, 0.14), "gt_key": S(0.50, 0.645, 0.11),
        ], order: ["gt_vines", "gt_banner", "gt_moon", "gt_orbs", "gt_pillars", "gt_lamps", "gt_fountain", "gt_crystals", "gt_carpet", "gt_runes", "gt_pedestal", "gt_key"]),

        Area(key: "sn", name: T("雪夜小屋"), bg: "sn_bg", chapters: [
            Chapter(title: T("第十三章 · 地球上的第一场雪"), tasks: [
                Tk("f1", T("生起小壁炉"), 87, "sn_fire", T("它把蛋壳挪到壁炉边，说这是「全屋最好的位置」。")),
                Tk("f2", T("铺一块毛毛地毯"), 90, "sn_rug", T("它趴在地毯上不肯起来：「毛毛的，像家里的草。」")),
                Tk("f3", T("搬来软软的扶手椅"), 94, "sn_sofa", T("椅子是给你的。它坐上去试了试，就没下来。")),
                Tk("f4", T("立一棵小星星树"), 97, "sn_tree", T("树顶的星星，它坚持要挂那颗最亮的。")),
                Tk("f5", T("煮一杯热可可"), 100, "sn_cocoa", T("「喝热的要慢……像我一样。」它说这是养生。")),
                Tk("f6", T("挂上两只袜子"), 103, "sn_socks", T("一只大的给你，一只小的给它。它的那只里放了半块饼干。")),
            ]),
            Chapter(title: T("第十四章 · 雪夜里的信"), tasks: [
                Tk("f7", T("点一盏暖灯"), 106, "sn_lantern", T("窗外的雪被灯照得一闪一闪，像门那边的星。")),
                Tk("f8", T("挂一个冬日花环"), 109, "sn_wreath", T("花环上的星星，又是那个熟悉的形状。")),
                Tk("f9", T("摆一个雪花水晶球"), 112, "sn_snowglobe", T("水晶球里有间小屋。摇一摇，雪花里好像还藏着一颗小小的蛋影子。")),
                Tk("f10", T("靠两副小雪橇"), 115, "sn_skis", T("「我不滑。你滑，我坐后面。分工明确。」")),
                Tk("f11", T("堆一个小雪人"), 119, "sn_snowman", T("雪人戴着它的围巾。它说这样雪人就不冷了。")),
                Tk("f12", T("包好一堆礼物"), 125, "sn_gifts", T("最小的那个盒子上写着你的名字，字歪歪扭扭的。它说：「明年也一起过。」")),
            ]),
        ], spots: [
            "sn_wreath": S(0.50, 0.14, 0.22), "sn_lantern": S(0.84, 0.16, 0.14), "sn_socks": S(0.24, 0.30, 0.30),
            "sn_tree": S(0.84, 0.46, 0.30), "sn_fire": S(0.22, 0.52, 0.34), "sn_snowglobe": S(0.62, 0.50, 0.14),
            "sn_skis": S(0.08, 0.62, 0.16), "sn_rug": S(0.50, 0.82, 0.78), "sn_sofa": S(0.70, 0.70, 0.36),
            "sn_cocoa": S(0.40, 0.72, 0.20), "sn_gifts": S(0.86, 0.80, 0.26), "sn_snowman": S(0.14, 0.82, 0.22),
        ], order: ["sn_rug", "sn_wreath", "sn_lantern", "sn_socks", "sn_tree", "sn_fire", "sn_snowglobe", "sn_skis", "sn_sofa", "sn_cocoa", "sn_gifts", "sn_snowman"]),

        // 2026-10-21 第 8 片：温泉小院（第十五、十六章）。故事不收尾，只给同伴蛋留一点脚印
        Area(key: "hs", name: T("温泉小院"), bg: "hs_bg", chapters: [
            Chapter(title: T("第十五章 · 冬天要泡温泉"), tasks: [
                Tk("h1", T("挖一个小温泉池"), 128, "hs_pool", T("它试了一下水温，然后就再也没出来过。")),
                Tk("h2", T("点一盏石灯笼"), 131, "hs_lantern", T("灯光落在水面上一晃一晃，它的眼皮也跟着一晃一晃。")),
                Tk("h3", T("放一个泡澡木桶"), 134, "hs_bucket", T("木桶是给你的。它的意思是：搓背归你。")),
                Tk("h4", T("放三只小黄鸭"), 137, "hs_ducks", T("它给小黄鸭排了队：大的、中的、它自己。它说它也算一只。")),
                Tk("h5", T("挂上暖帘"), 140, "hs_noren", T("暖帘一挂，就算正式营业了。客人只有它一个。")),
                Tk("h6", T("种一盆红梅"), 144, "hs_plum", T("开了一朵。它说这是给门那边报个平安。")),
            ]),
            Chapter(title: T("第十六章 · 一锅温泉蛋"), tasks: [
                Tk("h7", T("立一排竹篱笆"), 147, "hs_fence", T("「这样就没人看见我泡得有多久了。」")),
                Tk("h8", T("搬来竹躺椅"), 150, "hs_lounger", T("泡完要躺，躺完再泡。它说这叫循环。")),
                Tk("h9", T("煮一锅温泉蛋"), 153, "hs_eggs", T("锅里放了八个蛋。它数了三遍，每遍都是九个，多出来那个花纹不太一样。……一转眼，又只剩八个了。")),
                Tk("h10", T("挂一只玻璃风铃"), 156, "hs_chime", T("风一吹，叮的一声。它说门那边的风铃，也是这个声音。")),
                Tk("h11", T("放一箱瓶装牛奶"), 160, "hs_milk", T("泡完温泉喝牛奶要叉腰。它叉不到腰，就叉肚子。")),
                Tk("h12", T("挂满一院子灯笼"), 166, "hs_lights", T("灯笼全亮的时候，雪地上多了一串小小的脚印，绕着温泉走了一圈，又不见了。「……不是我的。我没那么小。」")),
            ]),
        ], spots: [
            "hs_lights": S(0.50, 0.11, 0.72), "hs_noren": S(0.18, 0.30, 0.22), "hs_chime": S(0.84, 0.22, 0.09),
            "hs_fence": S(0.88, 0.47, 0.26), "hs_plum": S(0.12, 0.49, 0.24), "hs_pool": S(0.50, 0.66, 0.70),
            "hs_ducks": S(0.55, 0.65, 0.20), "hs_lantern": S(0.13, 0.73, 0.20), "hs_bucket": S(0.84, 0.70, 0.20),
            "hs_lounger": S(0.74, 0.86, 0.34), "hs_milk": S(0.22, 0.88, 0.22), "hs_eggs": S(0.44, 0.88, 0.18),
        ], order: ["hs_lights", "hs_noren", "hs_chime", "hs_fence", "hs_plum", "hs_pool", "hs_ducks", "hs_lantern", "hs_bucket", "hs_lounger", "hs_milk", "hs_eggs"]),
    ]

    /// 第一次进店的开场：四页，一页一句事
    static let introPages: [(String, String)] = [
        (T("肚子饿了"), T("礼包里那个饭团，它几口就吃完了，\n然后盯着空盘子，一动不动。\n打开冰箱——空的，只剩一点米。")),
        (T("没钱"), T("它把蛋壳底下翻了个遍，摸出 3 枚硬币。\n连一袋米都买不起。\n它把硬币摆在肚子上，叹了口气。")),
        (T("门缝里的纸条"), T("「楼上的。好香……能卖我一个吗？」\n\n它慢慢抬起头，看着你。")),
        (T("那就做吧"), T("你在后厨做，它躺在蛋壳里收钱。\n赚的钱，都花在它身上。\n\n先把楼上这一单做出来。")),
    ]
    /// 第 3 单做完：纸板招牌，当天开张
    static let signLine = T("它找来一块纸箱板，用蜡笔写了一个歪歪扭扭的「嘟」。\n想了想，又写了一个。\n「写两遍，因为一遍不够大。」\n\n纸板招牌立在了窗口。\n从今天起，这是一家店。")

    /// 72 件做完以后：小紫的心愿，一直有（星星越来越多，奖励宝石 + 大宝箱）
    private static let wishes: [(String, String)] = [
        (T("给它织一条新毯子"), T("它把新毯子卷成一个卷，自己躺进去，只露一个角。")),
        (T("给门那边寄一盒饼干"), T("它在盒子上画了一颗星，说这样就寄得到。")),
        (T("在屋顶办一场星空电影夜"), T("电影还没开始，它已经睡着了。爆米花一颗没少。")),
        (T("给吊床换新绳子"), T("「这次结实了，我可以更放心地不动了。」")),
        (T("给发光草浇一次星星水"), T("发光草亮了一整晚，它说家里的也是这样亮。")),
        (T("把茶室的灯换成星星灯"), T("灯影落在墙上，像那张星图。")),
        (T("给它的蛋壳擦一遍"), T("蛋壳亮得能照出人影。它照了照，觉得自己又圆了一点。")),
        (T("做一桌嘟嘟星家乡菜"), T("它吃到一半停下来：「跟那边的味道……差不多。不对，更好。」")),
        (T("给后院添一棵樱桃树苗"), T("「等它结果，我负责吃。」")),
        (T("在橱窗挂上新季节的装饰"), T("路过的人都多看了一眼。它假装没在看他们。")),
        (T("陪它在屋顶数一晚星星"), T("数到第七颗它就睡着了，你替它数完了。")),
        (T("给信箱刷一层新漆"), T("第二天，门那边就来了一封信。好像知道似的。")),
    ]
    static func wish(_ n: Int) -> Task {
        let w = wishes[(n - 1) % wishes.count]
        return Task(id: "w\(n)", title: w.0, stars: min(200, 110 + n * 8), deco: nil, line: w.1)
    }

    static var chapters: [Chapter] { areas.flatMap { $0.chapters } }

    // MARK: 谜（2026-10-19 主线「嘟嘟星在变暗」）：线索本最上面挂一个主问题，答了就换下一个；底下六个小谜
    struct Mystery: Identifiable { let id: String; let q: String; let clues: [String]; let answerAt: String; let answer: String; var halfAt: String? = nil; var half: String? = nil }
    /// 主问题：变暗 → 它会回去吗 → 同伴蛋（明年）。返回（问题、答了没有的那句）
    static func bigQuestion(done: [String]) -> (q: String, a: String) {
        if done.contains("e12") { return (T("和它同一天出发的那颗蛋，落到了谁手里？"), T("……明年，继续。")) }
        if done.contains("b12") { return (T("门开了以后，它会回去吗？"), T("……还不知道。")) }
        return (T("嘟嘟星，为什么在变暗？"), T("……还不知道。"))
    }
    static let mysteries: [Mystery] = [
        Mystery(id: "m1", q: T("冰箱里那张旧菜谱，是哪家店的？"), clues: ["t7", "t9", "t11"], answerAt: "t12",
                answer: T("嘟嘟星上也有一家「嘟嘟小店」，菜谱是那家店的招牌菜。它说我们这家的名字，是它随便起的。\n——说完把脸埋进了蛋壳里。")),
        Mystery(id: "m2", q: T("「给逃跑的小徒弟」，是写给谁的？"), clues: ["a3", "a10", "a11"], answerAt: "a12",
                answer: T("写给它。嘟嘟星的嘟嘟小店是星星爷爷开的，它是爷爷唯一的徒弟。交班那天晚上 9 点 41 分，它太困了，钻进蛋壳睡了一觉——蛋壳滚出了门，掉进了你的手机。那家店，从那天起就关着。")),
        Mystery(id: "m3", q: T("嘟嘟星，为什么在变暗？"), clues: ["b3", "b4", "b8", "b11"], answerAt: "b12",
                answer: T("嘟嘟星没有太阳，光是大家互相做饭点亮的。店关了以后，大家各吃各的——一个人吃饭，是不会亮的。门那边来的单，是还亮着的人在找一口热饭。\n从今晚起，每晚 9:41，留意一下灵动岛：门开的时候，会亮一下。")),
        Mystery(id: "m4", q: T("蛋壳为什么偏偏滚到了你这儿？"), clues: ["c7", "d6", "d8", "d9"], answerAt: "d12",
                answer: T("地图上的虚线不是乱滚的。星星爷爷看着蛋壳滚出门，没去追，只轻轻推了一下——推向一个一个人吃饭的人。\n那晚 9 点 41 分，你一个人吃饭，手里拿着手机。")),
        Mystery(id: "m5", q: T("总店，还会亮吗？"), clues: ["d1", "e6", "e7", "e10"], answerAt: "e12",
                answer: T("会。门开的那一刻，你们做的每一单顺着门送了过去，最后一块也亮了。爷爷在门口挂上「嘟嘟小店 · 总店」，寄来一张我们那块纸板招牌的照片，背面写着：「分店」。")),
        Mystery(id: "m6", q: T("照片里那颗花纹不一样的蛋，是谁？"), clues: ["c4", "c12", "f9", "f12"], answerAt: "f12",
                answer: T("雪夜里，门那边寄来一张新照片：那颗蛋，裂开了一条缝。……它会落到这条街上谁的手里？（明年，继续。）"),
                halfAt: "c12", half: T("茶箱里压着那张照片的背面，有一行嘟嘟语。它小声念出来：「和你同一天出发。」\n那颗蛋，是和它一起从嘟嘟星出发的同伴。\n……可那颗蛋，后来落到哪儿去了？")),
    ]

    // MARK: 门单：每章一张从灵动岛门缝掉进来的小票；做完点亮嘟嘟星的一个区（第 12 区是总店）
    struct Door { let name: String; let note: String }
    static let doors: [Door] = [
        Door(name: T("饭团湾"), note: T("好久没吃过热的了。能做一个饭团吗？")),
        Door(name: T("汤锅镇"), note: T("锅都凉了一年了。")),
        Door(name: T("米仓坡"), note: T("听说嘟嘟小店又开张了？")),
        Door(name: T("蜂蜜谷"), note: T("我们这儿的蜂，好久没出窝了。")),
        Door(name: T("胡萝卜原"), note: T("你那边的胡萝卜，还是金色的吗？")),
        Door(name: T("睡莲湖"), note: T("今晚湖里亮了一朵。是你吗？")),
        Door(name: T("茶雾山"), note: T("慢慢做，不着急。")),
        Door(name: T("月亮渡口"), note: T("船夫说，门那边飘来了香味。")),
        Door(name: T("星星集市"), note: T("集市要重新开了！先订一份。")),
        Door(name: T("灯塔岬"), note: T("从灯塔上，看得见门缝里的光。")),
        Door(name: T("星星爷爷"), note: T("一碗汤。（落款一顶小厨师帽）")),
        Door(name: T("嘟嘟小店 · 总店"), note: T("门开那天，大家都来门口。")),
        Door(name: T("雪绒岭"), note: T("第一场雪。给小徒弟也带一份。")),
        Door(name: T("光之泉"), note: T("明年也一起过。")),
    ]
    /// 门单做完，它说一句（按区）
    static let doorLit: [String] = [
        T("……饭团湾，亮了一点点。"), T("汤锅镇的锅，热了。"), T("米仓坡……别告诉他们是我。"), T("蜂出窝了。我闻得到。"),
        T("胡萝卜原，金色的。跟以前一样。"), T("睡莲湖那朵，是我们点的。"), T("茶雾山也亮了。慢慢的。"), T("渡口的船，能开了。"),
        T("集市开了！……我不去，我躺着听。"), T("灯塔岬亮了。灯塔又能看见我们了。"), T("爷爷喝到汤了。"), T("总店……亮了。"),
        T("雪绒岭的雪，是亮的。"), T("整颗星都亮了。……你做的。"),
    ]

    // MARK: 章末小戏：每章最后一件装修做完，它摆个样子，一句一句说（第 0 场 = 开张那晚第一张门单）
    struct Beat { let frame: String; let line: String; var img: String? = nil }
    private static func B(_ f: String, _ l: String, _ img: String? = nil) -> Beat { Beat(frame: f, line: l, img: img) }
    /// 揭谜时配的插图
    static let revealImage: [String: String] = ["m1": "story_recipe", "m2": "story_envelope", "m3": "story_planet", "m4": "story_maps", "m5": "story_shop_lit", "m6h": "story_egg", "m6": "story_egg"]
    static let scenes: [Int: [Beat]] = [
        0: [B("surprised", T("灵动岛突然亮了一下。\n一张紫色的小票，从门缝里飘了下来。"), "story_ticket"), B("surprised", T("上面的字弯弯曲曲的——是嘟嘟星的字。\n它一下子不困了。")), B("think", T("「……饭团湾。」")), B("idle", T("「那是我家那边。」"))],
        1: [B("think", T("它把那张门单的小票，压在了肚子底下。")), B("think", T("「那是嘟嘟星的字。」")), B("yawn", T("「没什么。我困了。」"))],
        2: [B("shy", T("「好吧。那边也有一家嘟嘟小店。」")), B("shy", T("「我们这家……是我照着起的名。」")), B("idle", T("「别问了。今天的钱，放我肚子上。」"))],
        3: [B("surprised", T("门单背面还有一行小字：\n「听说嘟嘟小店又开张了？」")), B("surprised", T("它坐直了。今年坐得最直的一次。")), B("think", T("「不能让他们知道是我。」")), B("cry", T("「……因为店，是我关的。」"))],
        4: [B("cry", T("「我不是故意的。我就是……困。」")), B("think", T("你问它：爷爷生气了吗？\n它摇头，点头，又摇头。")), B("shy", T("「他说等我。」"))],
        5: [B("think", T("「那边的胡萝卜原，以前是金色的。」")), B("think", T("「现在……」它没说完。")), B("idle", T("它去给发光草浇水了。\n这辈子第一次，主动干活。"))],
        6: [B("cry", T("「是我弄暗的。」")), B("think", T("它把今天的门单，贴在了蛋壳上。")), B("happy", T("「那就做回来。一张一张做。」")), B("laugh", T("「……我负责盯着你做。」"))],
        7: [B("think", T("它抱着那罐写着「回家用」的茶叶，没打开。")), B("think", T("「等那边全亮了，门就能开大一点。」")), B("shy", T("「到时候……」\n它没说下去。"))],
        8: [B("think", T("「另外半张地图……」")), B("idle", T("「爷爷说，在一抬头就能看见的地方。」"))],
        9: [B("think", T("望远镜里，星星正中间那一块，还是黑的。"), "story_shop_dark"), B("think", T("「那是店。」")), B("cry", T("「窗户里还有一点点光……爷爷还在等。」"))],
        10: [B("surprised", T("「原来不是我逃跑。」")), B("shy", T("「……好吧，是我逃跑。但是爷爷推了一下。」")), B("happy", T("「所以你也算店里的人。」"))],
        11: [B("think", T("门那边的来信，字越来越淡了。")), B("cry", T("「爷爷把光都送过来了。他自己……快不亮了。」")), B("surprised", T("它从蛋壳里坐了起来。")), B("happy", T("「今晚做一桌最大的单。」"))],
        12: [B("idle", T("门开着。它可以回去了。"), "story_door"), B("think", T("它躺在门口，回头看了你一眼。")), B("happy", T("「店开在哪儿都一样。门那边的单，我们在这儿做。」"), "story_branch"), B("shy", T("「……而且这边，有你做饭。」"))],
        13: [B("surprised", T("门那边寄来一个小包裹：一顶小小的厨师帽，正好是它的尺寸。"), "story_hat"), B("happy", T("它戴了三秒，又摘了：「太正式了。」")), B("idle", T("帽子放在了肚子上。"))],
        14: [B("surprised", T("门那边又寄来一张照片：那颗花纹不一样的蛋，裂开了一条缝。"), "story_egg"), B("think", T("「和我同一天出发的那颗……」")), B("think", T("「落到这条街上，谁那儿了？」"))],
        15: [B("happy", T("「冬天就该这样：泡着，不动。」")), B("yawn", T("「你也下来。……水是我焐热的。」"))],
        16: [B("surprised", T("雪地上那串小脚印，一直走到了院墙外面。")), B("think", T("「和我同一天出发的那颗……」")), B("idle", T("「算了，先泡着。它想来，自己会来的。」"))],
    ]

    static func mystery(answeredBy taskID: String) -> Mystery? { mysteries.first { $0.answerAt == taskID } }
    /// 揭一角：返回一份只带半个谜底的副本（id 以 h 结尾）
    static func mystery(halfBy taskID: String) -> Mystery? {
        guard let m = mysteries.first(where: { $0.halfAt == taskID }), let h = m.half else { return nil }
        return Mystery(id: m.id + "h", q: m.q, clues: [], answerAt: "", answer: h)
    }

    // MARK: 熟客：不画人，只有地址、图标和小票上的一句话；常来的几家有自己的小故事
    struct Regular { let key: String; let icon: String; let place: String; let who: String; let notes: [String]; let reply: [String]; let postcard: String }
    /// 普通外卖单的客人：每个地址住着固定的一个人，交单时偶尔回一句
    static var takeoutFolks: [String: (name: String, lines: [String])] { [
        T("3 号楼"): (T("3 号楼的王奶奶"), [T("还热乎，孙子放学正好吃。"), T("下次少放点盐，我血压高。"), T("店里那只紫色的又胖了吧？")]),
        T("蘑菇小区"): (T("蘑菇小区的小胖"), [T("我妈说你们家比楼下的好吃！"), T("能不能多送一个勺子？"), T("我要攒钱再点一次。")]),
        T("星星路 12 号"): (T("星星路的程序员"), [T("加班救命饭，谢了。"), T("代码没跑通，饭先跑通了。"), T("明天同一时间，老样子。")]),
        T("河边公寓"): (T("河边公寓的画家"), [T("颜色真好看，先画下来再吃。"), T("窗外的河今天很亮。"), T("给店里那只紫色的画了一张，下次带去。")]),
        T("学校门口"): (T("学校门口的保安叔叔"), [T("孩子们都在问你们家什么时候开分店。"), T("值班到晚上，就靠这一口。")]),
        T("图书馆"): (T("图书馆的小林"), [T("嘘……在图书馆，悄悄吃。"), T("这本书看完了，饭也吃完了。")]),
        T("东门"): (T("东门的修车师傅"), [T("手上全是油，直接上嘴了。"), T("吃饱了干活有劲。")]),
        T("花店楼上"): (T("花店楼上的姐姐"), [T("送你一枝花，放柜台上吧。"), T("今天的花卖得好，奖励自己一顿。")]),
        T("公园长椅"): (T("公园长椅上的爷爷"), [T("鸽子也想吃，我不给。"), T("太阳正好，饭也正好。")]),
        T("灯塔"): (T("灯塔的守塔人"), [T("海上起雾了，热饭最好。"), T("今晚灯亮着，你们看得见吗？")]),
    ] }

    static let regulars: [Regular] = [
        Regular(key: "lighthouse", icon: "🗼", place: T("灯塔"), who: T("守塔的人"),
                notes: [T("一个人守夜，又加班了，饭团要两个。"), T("昨晚 9 点 41 分，海上闪过一道紫光，你们看见了吗？"), T("今晚不用守夜！要个蛋糕庆祝。"), T("谢谢你们。从灯塔上看得见你们店的灯，很暖。")],
                reply: [T("灯塔又加班？我替他困了。"), T("紫光？……我什么都没看见。（它把脸埋进了肚子里）"), T("不加班真好。我天天不加班。")],
                postcard: T("灯塔寄来一张明信片：画着海、灯塔，和远处一扇亮着的小店窗户。")),
        Regular(key: "library", icon: "📚", place: T("图书馆"), who: T("写小说的人"),
                notes: [T("一个人在图书馆坐了一天，写不出来，需要甜的。"), T("新小说的主角是一只懒懒的紫色小怪兽……听说你们店里就有一只？"), T("写完了！书名叫《嘟嘟小店》。"), T("寄来一本样书，扉页写着：给那只躺着收钱的小家伙。")],
                reply: [T("写不出来就躺会儿，我都是这么写的。"), T("紫色小怪兽？懒？……这是诽谤。"), T("书里有我吗？有几页？")],
                postcard: T("图书馆寄来一本样书。第一页画着它躺在柜台后面，肚子上放着三枚金币。")),
        Regular(key: "flower", icon: "💐", place: T("花店楼上"), who: T("新搬来的人"),
                notes: [T("刚搬来，什么都没有，先来点吃的。"), T("楼下花店老板说，你们家的胡萝卜最甜。"), T("今天是我在这儿过的第一个生日。"), T("我也在窗台上种了发光草——你们给的种子，发芽了。")],
                reply: [T("刚搬来的都饿，我懂。我来的时候也是。"), T("那当然，自己种的。（它其实一根没种）"), T("生日？那要加一颗星星饼干。我替他吃一半。")],
                postcard: T("花店楼上寄来一张照片：窗台上一排小花盆，中间那盆在夜里微微发光。")),
        Regular(key: "school", icon: "🎒", place: T("学校门口"), who: T("考试的学生"),
                notes: [T("明天考试，一个人复习到半夜，要提神的。"), T("考完了……不太好。要甜的。"), T("补考过了！请全班吃爆米花。"), T("毕业了。以后去外地读书，会想念你们的饭团。")],
                reply: [T("考试别熬夜。睡觉是最好的复习，我是专业的。"), T("没考好也要吃饱。吃饱了再难过。"), T("全班？那我得多数几遍钱。")],
                postcard: T("学校门口寄来一张毕业照，角落里有人用笔画了一只紫色的小怪兽。")),
        Regular(key: "granny", icon: "🏠", place: T("河边公寓"), who: T("一个人住的奶奶"),
                notes: [T("孩子们都在外地，一个人吃饭，少做点。"), T("今天孩子打电话了，开心，多要一碗。"), T("腿不太好，谢谢你们总送上楼。"), T("奶奶织了一条小围巾，说是给那个紫色的小家伙的。")],
                reply: [T("一个人吃饭……那我们做香一点。"), T("多一碗！我也开心。"), T("慢慢走，饭会等你。")],
                postcard: T("河边公寓寄来一条小小的毛线围巾，刚好够它围一圈。")),
    ]
    static func regular(_ key: String?) -> Regular? { regulars.first { $0.key == key } }
    static var all: [Task] { chapters.flatMap { $0.tasks } }
    /// 店里平时显示的地方：最近装修过的那个
    static func shown(done: [String]) -> Area {
        let last = all.last { done.contains($0.id) }
        return last.flatMap { area(of: $0.id) } ?? areas[0]
    }
    static func area(of taskID: String) -> Area? { areas.first { a in a.chapters.contains { c in c.tasks.contains { $0.id == taskID } } } }
    /// 拿大宝箱的节点：每章最后一个任务
    static var chapterEnds: Set<String> { Set(chapters.compactMap { $0.tasks.last?.id }) }
}

/// 一个地方的场景：背景 + 已完成的装修摆上去
struct MKAreaScene: View {
    let area: MKStory.Area
    let done: [String]
    var fill = false
    var highlight: String? = nil   // 刚装修好的那件：从上面落下来、发光
    var shown = true
    var glow = false
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let have = Set(area.chapters.flatMap { $0.tasks }.filter { done.contains($0.id) }.compactMap(\.deco))
            ZStack {
                if UIImage(named: area.bg) != nil {
                    Image(area.bg).resizable().frame(width: w, height: h)
                } else {
                    LinearGradient(colors: [Color(hex: "#2A2140"), Color(hex: "#1A1426")], startPoint: .top, endPoint: .bottom)
                }
                ForEach(area.order.filter { have.contains($0) }, id: \.self) { d in
                    if d == highlight {
                        decoImage(d, w: w, h: h)
                            .shadow(color: Color(hex: "#FFE9A8").opacity(glow ? 0.95 : 0), radius: 22)
                            .shadow(color: Color(hex: "#FFE9A8").opacity(glow ? 0.6 : 0), radius: 6)
                            .scaleEffect(shown ? 1 : 1.45)
                            .offset(y: shown ? 0 : -h * 0.07)
                            .opacity(shown ? 1 : 0)
                    } else {
                        decoImage(d, w: w, h: h)
                    }
                }
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: fill ? .fill : .fit)
        .clipShape(RoundedRectangle(cornerRadius: fill ? 0 : 22))
    }
    @ViewBuilder private func decoImage(_ d: String, w: CGFloat, h: CGFloat) -> some View {
        if let s = area.spots[d], let ui = UIImage(named: d) {
            let iw = w * s.w
            Image(uiImage: ui).resizable().frame(width: iw, height: iw * ui.size.height / max(1, ui.size.width))
                .position(x: w * s.x, y: h * s.y)
        }
    }
}


/// 窝里去小店逛逛：你装修过的地方，它躺在里面；点它说一句这里的事
struct MKShopVisit: View {
    let area: MKStory.Area
    let done: [String]
    let pet: String
    let accessories: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var line: String? = nil
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MKAreaScene(area: area, done: done)
                .overlay {
                    GeometryReader { g in
                        Button { say() } label: {
                            DressedPetView(pet: pet, pose: .stand, frame: line == nil ? "idle" : "happy", accessories: accessories)
                                .frame(width: g.size.width * 0.34, height: g.size.width * 0.34)
                        }
                        .buttonStyle(.press)
                        .position(x: g.size.width * 0.5, y: g.size.height * 0.88)
                    }
                }
                .padding(.horizontal, 12)
            VStack {
                HStack {
                    Text(area.name).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(.white.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.press)
                }
                .padding(.horizontal, 20).padding(.top, 10)
                Spacer()
                if let line {
                    Text("“\(line)”").font(.system(size: 15)).foregroundStyle(Color(hex: "#2A2140"))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color(hex: "#F3EEFF"), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24).padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    private func say() {
        let lines = area.chapters.flatMap { $0.tasks }.filter { done.contains($0.id) }.map(\.line)
        withAnimation { line = lines.randomElement() ?? T("这里还空着呢。") }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// 窝页面底下的「嘟嘟小店」入口：装修过的地方一排小图，点进去逛
struct MKShopRooms: View {
    let pet: String
    let accessories: [String]
    @State private var done: [String] = []
    @State private var visit: MKStory.Area? = nil
    var body: some View {
        let areas = MKStory.areas.filter { a in a.chapters.flatMap { $0.tasks }.contains { done.contains($0.id) } }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(T("嘟嘟小店里装修好的地方")).font(.system(size: 13)).foregroundStyle(Theme.text2)
                Spacer()
                Text("\(done.filter { !$0.hasPrefix("w") }.count)/\(MKStory.all.count)").font(.system(size: 12)).foregroundStyle(Theme.text3)
            }
            if areas.isEmpty {
                Text(T("去首页的嘟嘟小店装修第一件，这里就能来逛了。")).font(.system(size: 12)).foregroundStyle(Theme.text3)
                    .frame(maxWidth: .infinity, minHeight: 60).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(areas, id: \.key) { a in
                            Button { visit = a } label: {
                                VStack(spacing: 4) {
                                    MKAreaScene(area: a, done: done).frame(width: 96)
                                    Text(a.name).font(.system(size: 11)).foregroundStyle(Theme.text2)
                                }
                            }
                            .buttonStyle(.press)
                        }
                    }
                }
            }
        }
        .onAppear { done = MKState.load().done }
        .fullScreenCover(item: $visit) { a in MKShopVisit(area: a, done: done, pet: pet, accessories: accessories) }
    }
}
extension MKStory.Area: Identifiable { var id: String { key } }
