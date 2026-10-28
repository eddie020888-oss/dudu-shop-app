import Foundation

/// 心情：决定嘟嘟的样子和表情帧
enum Mood: String {
    case happy, calm, sleepy, hungry, thirsty, dirty, shy, sulky, excited, worried, confused, lonely

    /// 表情帧（Pets.xcassets 里的 purple_<frame>）
    var frame: String? {
        switch self {
        case .happy: return "happy"
        case .calm: return nil
        case .sleepy: return "yawn"
        case .hungry: return "hungry"
        case .thirsty: return "thirsty"
        case .dirty: return "dirty"
        case .shy: return "shy"
        case .sulky: return "angry"
        case .excited: return "laugh"
        case .worried, .confused: return "think"
        case .lonely: return "cry"
        }
    }
    /// 嘟语
    var dudu: [String] {
        switch self {
        case .happy:    return [T("嘟嘟！✨"), T("嘟嘟嘟～"), T("嘟！")]
        case .calm:     return [T("嘟。"), T("嘟～"), T("嘟嘟。")]
        case .sleepy:   return [T("嘟……💤"), T("嘟～～"), T("嘟…嘟……")]
        case .hungry:   return [T("嘟…🍔"), T("嘟嘟！🍰"), T("嘟……🍪")]
        case .thirsty:  return [T("嘟…🧋"), T("嘟嘟…💧")]
        case .dirty:    return [T("嘟…🫧"), T("嘟嘟？🛁")]
        case .shy:      return [T("嘟…///"), T("嘟…嘿")]
        case .sulky:    return [T("嘟——。"), T("嘟。哼。")]
        case .excited:  return [T("嘟嘟嘟嘟嘟！"), T("嘟嘟！！")]
        case .worried:  return [T("嘟？…嘟。"), T("嘟……？")]
        case .confused: return [T("嘟？？"), T("嘟？")]
        case .lonely:   return [T("嘟……"), T("嘟…🥺")]
        }
    }
}

/// 关键词"听懂"（本地，不需要服务器）
enum Keyword: String, CaseIterable {
    case water, sleep, eat, pet, praise, tired, hello, love, sad, back
    case skip, junk, meal      // 养生家：你说没吃饭 / 吃了垃圾食品 / 吃了饭

    var patterns: [String] {
        switch self {
        case .water:  return [T("喝水"), T("水"), "drink", "water"]
        case .sleep:  return [T("晚安"), T("睡觉"), T("睡了"), "good night", "sleep", "night"]
        case .eat:    return [T("吃饭"), T("饿"), T("吃"), "eat", "hungry", "food", "snack"]
        case .pet:    return [T("摸摸"), T("摸"), T("抱抱"), "pet", "hug", "rub"]
        case .praise: return [T("乖"), T("真棒"), T("可爱"), T("好棒"), "good", "cute", "love you"]
        case .tired:  return [T("累"), T("困"), T("好烦"), "tired", "exhausted"]
        case .hello:  return [T("你好"), T("早"), T("嗨"), "hi", "hello", "morning"]
        case .love:   return [T("爱你"), T("喜欢你"), T("想你"), "miss you"]
        case .sad:    return [T("难过"), T("伤心"), T("哭"), "sad", "upset", "cry"]
        case .back:   return [T("我回来"), T("回来了"), "i'm back", "im back"]
        case .skip:   return [T("没吃"), T("不吃"), T("没空吃"), T("不想吃"), T("忘了吃"), T("减肥"), T("节食"), "skip", "didn't eat", "not eating", "diet"]
        case .junk:   return [T("炸鸡"), T("薯条"), T("汉堡"), T("泡面"), T("辣条"), T("奶茶"), T("可乐"), T("外卖"), T("烧烤"), "fried", "burger", "fries", "pizza", "soda", "boba", "takeout"]
        case .meal:   return [T("吃了"), T("吃过了"), T("吃完"), T("早饭"), T("午饭"), T("晚饭"), T("吃的"), "ate", "breakfast", "lunch", "dinner"]
        }
    }
    var mood: Mood {
        switch self {
        case .water: return .thirsty
        case .sleep, .tired: return .sleepy
        case .eat: return .hungry
        case .pet, .praise, .love: return .shy
        case .hello, .back: return .happy
        case .sad, .skip: return .worried
        case .junk: return .confused
        case .meal: return .happy
        }
    }
    /// 听懂后它做什么（舞台播哪段动作，nil = 只换表情）
    var action: Pose? {
        switch self {
        case .water: return .coffee
        case .sleep, .tired: return .sleep
        case .eat, .meal: return .eat
        default: return nil
        }
    }

    static func match(_ text: String) -> Keyword? {
        let t = text.lowercased()
        // 顺序有讲究：先长后短，避免"喝水"被"水"以外的词抢走
        let order: [Keyword] = [.back, .love, .skip, .junk, .meal, .sleep, .water, .eat, .pet, .tired, .sad, .praise, .hello]
        return order.first { k in k.patterns.contains { t.contains($0) } }
    }
}

/// 小紫说话：按语言路线 + 成长阶段出台词。
/// - 路线 B，或任何路线的阶段 0：只说嘟语。
/// - 阶段 1：单词；阶段 2：短句（偶尔错）；阶段 3：短句聊天。
/// 台词按场景 key 存：need.hungry / cared.hungry / pose.walk / kw.water …
enum Voice {
    static var route: LangRoute = .zh
    static var stage = 0
    static var signature = ""
    static var petName = T("嘟嘟")

    static var speaks: Bool { route.speaks && stage >= 1 }

    struct Entry {
        let mood: Mood
        let zh: [[String]]   // [单词期, 短句期, 能聊天]
        let en: [[String]]
    }

    /// 取一句话；{n} {food} {name} 会被替换
    static func line(_ key: String, mood: Mood? = nil, _ args: [String: String] = [:]) -> String {
        let e = table[key]
        let m = mood ?? e?.mood ?? .calm
        guard speaks, let e else {
            // 嘟语；熟悉度到 3 阶段后，打招呼/晚安/撒娇用专属嘟嘟
            if stage >= 3, !signature.isEmpty, key.hasPrefix("kw.hello") || key.hasPrefix("kw.sleep") || key.hasPrefix("kw.love") || key.hasPrefix("back.") {
                return signature
            }
            return m.dudu.randomElement()!
        }
        let lists = route == .en ? e.en : e.zh
        let idx = min(max(stage - 1, 0), lists.count - 1)
        var pool = lists[idx]
        if pool.isEmpty { pool = lists.last(where: { !$0.isEmpty }) ?? [T("嘟。")] }
        var s = pool.randomElement()!
        for (k, v) in args { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        s = s.replacingOccurrences(of: "{name}", with: petName)
        // 阶段 1–2 偶尔夹一句嘟
        if stage <= 2, Int.random(in: 0..<4) == 0, !s.contains(T("嘟")) { s += route == .en ? " dudu." : T(" 嘟。") }
        return s
    }

    static func frame(_ key: String) -> String? { table[key]?.mood.frame }
    static func mood(_ key: String) -> Mood { table[key]?.mood ?? .calm }

    /// 动作变化时嘀咕的话
    static func pose(_ p: Pose) -> String {
        let key = "pose.\(p.rawValue)"
        if table[key] != nil { return line(key) }
        // 没单独写的动作：阶段 3 用旧台词，阶段 1–2 用单词
        if speaks && stage >= 3, let full = ChatStore.lines[p]?.randomElement() { return route == .en ? "Mm." : full }
        if speaks { return route == .en ? "\(p.label)…" : T("{0}…嘟", p.label) }
        return Mood.calm.dudu.randomElement()!
    }

    // MARK: 台词表

    static let table: [String: Entry] = [
        // 需求
        "need.hungry": Entry(mood: .hungry,
            zh: [[T("饿…"), T("吃…嘟"), T("肚子…")], [T("肚子…咕咕叫了。"), T("想吃…东西。"), T("饿饿，给吃的。")], [T("饿了……有吃的吗？"), T("肚子在叫了。"), T("能不能先喂我一口。")]],
            en: [["Hungry…", "Food…"], ["Tummy… rumbling.", "Want… snack."], ["I'm hungry… any snacks?", "My tummy's talking."]]),
        "need.thirsty": Entry(mood: .thirsty,
            zh: [[T("渴…"), T("水…嘟")], [T("想喝…东西。"), T("嘴巴干干。")], [T("渴了，想喝点什么。"), T("嗓子干了……")]],
            en: [["Thirsty…", "Drink…"], ["Mouth… dry."], ["I'm thirsty. Something to drink?"]]),
        "need.dirty": Entry(mood: .dirty,
            zh: [[T("脏…"), T("泡泡…")], [T("有点…脏脏。"), T("想泡…澡。")], [T("身上黏黏的，想泡澡。"), T("该洗洗了……")]],
            en: [["Dirty…", "Bath…"], ["Bit… sticky."], ["I feel sticky. Bath time?"]]),
        "need.happy": Entry(mood: .lonely,
            zh: [[T("陪…"), T("无聊…")], [T("没人…理我。"), T("陪我…一下。")], [T("没人理我……"), T("你好久没戳我了。")]],
            en: [["Lonely…", "Play…"], ["Nobody… plays."], ["You haven't poked me in ages…"]]),

        // 照顾后
        "cared.hungry": Entry(mood: .happy,
            zh: [[T("好吃！"), T("嗯！")], [T("好吃…还要。"), T("饱了…一半。")], [T("好吃！"), T("这顿记你一功。")]],
            en: [["Yum!", "Good!"], ["Yummy… more."], ["Yum! I owe you one."]]),
        "cared.thirsty": Entry(mood: .happy,
            zh: [[T("咕咚！"), T("舒服…")], [T("喝饱了…嘟。"), T("活过来了。")], [T("咕咚咕咚，舒服。"), T("活过来了。")]],
            en: [["Gulp!", "Ahh…"], ["Better… now."], ["Gulp gulp. Much better."]]),
        "cared.dirty": Entry(mood: .happy,
            zh: [[T("香香！"), T("泡泡…")], [T("干净了…香。"), T("泡得…好舒服。")], [T("香喷喷的了。"), T("泡完了，不想起来。")]],
            en: [["Clean!", "Bubbles…"], ["Smell… nice."], ["All clean. Don't want to get out."]]),
        "cared.happy": Entry(mood: .excited,
            zh: [[T("开心！"), T("嘿嘿")], [T("好玩…再来。"), T("开心…嘟！")], [T("哈哈，再来！"), T("和你玩最好玩。")]],
            en: [["Fun!", "Hehe"], ["Again… again."], ["Haha, again!"]]),
        "full.hungry": Entry(mood: .calm,
            zh: [[T("饱…"), T("不…")], [T("吃不下…了。")], [T("还不饿，留着下次。"), T("肚子圆着呢。")]],
            en: [["Full…"], ["Can't… eat."], ["Not hungry. Save it for later."]]),
        "full.thirsty": Entry(mood: .calm,
            zh: [[T("不渴…")], [T("喝不下…了。")], [T("不渴，留着吧。")]],
            en: [["Not thirsty…"], ["No… more."], ["Not thirsty. Keep it."]]),
        "full.dirty": Entry(mood: .calm,
            zh: [[T("干净…")], [T("刚洗…过。")], [T("挺干净的，不用。")]],
            en: [["Clean…"], ["Just… washed."], ["I'm clean, thanks."]]),
        "full.happy": Entry(mood: .happy,
            zh: [[T("开心…")], [T("已经…很开心。")], [T("已经很开心了！再玩我要飘了。")]],
            en: [["Happy…"], ["Already… happy."], ["Already happy! I'll float away."]]),

        // 吃到具体的东西
        "fed.water":    Entry(mood: .happy, zh: [[T("水…好")], [T("咕咚…舒服。")], [T("咕咚咕咚。舒服。")]], en: [["Water…"], ["Gulp… nice."], ["Gulp. Nice."]]),
        "fed.carrot":   Entry(mood: .happy, zh: [[T("脆！")], [T("嘎嘣…脆。")], [T("嘎嘣脆。还行，再来一根？")]], en: [["Crunch!"], ["Crunchy…"], ["Crunchy. One more?"]]),
        "fed.riceball": Entry(mood: .happy, zh: [[T("饭团！")], [T("饭团…顶饱。")], [T("饭团！饱了一半。")]], en: [["Rice!"], ["Filling…"], ["Rice ball! Half full."]]),
        "fed.coffee":   Entry(mood: .happy, zh: [[T("香…")], [T("第一口…最香。")], [T("第一口最香。")]], en: [["Smells…"], ["First sip… best."], ["First sip is the best."]]),
        "fed.popcorn":  Entry(mood: .excited, zh: [[T("爆米花！")], [T("边看…边吃。")], [T("边看边吃，完美。")]], en: [["Popcorn!"], ["Watch… and eat."], ["Watch and munch. Perfect."]]),
        "fed.cake":     Entry(mood: .excited, zh: [[T("甜！")], [T("好甜…奶油。")], [T("好甜……嘴上都是奶油。")]], en: [["Sweet!"], ["So… sweet."], ["So sweet… cream everywhere."]]),
        "fed.favorite": Entry(mood: .excited,
            zh: [[T("这个！这个！")], [T("最…最喜欢这个！")], [T("这个！我最喜欢这个！！")]],
            en: [["This! This!"], ["My… favorite!"], ["THIS. This is my favorite!!"]]),
        "fed.lastbite": Entry(mood: .shy,
            zh: [[T("最后…")], [T("最后一口…舍不得。")], [T("最后一口……我们再相处一会儿。")]],
            en: [["Last…"], ["Last bite… sad."], ["Last bite… let's stay together a bit longer."]]),
        "firstword":    Entry(mood: .excited, zh: [[T("还……要。")], [T("还……要。")], [T("还……要。")]], en: [["More…"], ["More…"], ["More…"]]),

        // 戳它、按住它
        "poke": Entry(mood: .happy,
            zh: [[T("嘿嘿"), T("痒！"), T("嗯？")], [T("痒…别挠。"), T("干嘛…戳我。"), T("嘿嘿…再来。")], [T("痒！别挠。"), T("干嘛！"), T("在呢在呢。"), T("哈哈，再来。")]],
            en: [["Hehe", "Tickles!"], ["Tickles… stop.", "Why… poke?"], ["Tickles! Stop!", "I'm here, I'm here."]]),
        "poke.annoyed": Entry(mood: .sulky,
            zh: [[T("不！"), T("哼。")], [T("别戳…了！"), T("再戳…翻脸。")], [T("别戳了！"), T("再戳我翻脸。")]],
            en: [["No!", "Hmph."], ["Stop… poking!"], ["Okay, stop poking!"]]),
        "belly": Entry(mood: .excited,
            zh: [[T("哈哈！"), T("肚肚…")], [T("肚子…痒…哈哈！"), T("不许…摸肚子！")], [T("哈哈哈不许摸肚子！"), T("装作没感觉……失败了。")]],
            en: [["Haha!", "Tummy…"], ["Tummy… tickles!"], ["Hahaha no tummy rubs!"]]),
        "hold": Entry(mood: .shy,
            zh: [[T("…暖"), T("嗯…")], [T("好暖…不想动。")], [T("你的手好暖……我不动了。")]],
            en: [["…warm"], ["So warm… stay."], ["Your hand's warm… I'm not moving."]]),

        // 自己嘀咕
        "flourish": Entry(mood: .calm,
            zh: [[T("零食…"), T("困…"), T("嗯…")], [T("在想…晚饭。"), T("要不要…吃点。"), T("不想动…")], [T("在想晚饭吃什么。"), T("你忙吧，我在。"), T("要不要喂我一口。"), T("一直盯着我干嘛。")]],
            en: [["Snack…", "Sleepy…"], ["Thinking… dinner."], ["Thinking about dinner.", "You do you. I'm here."]]),

        // 关键词
        "kw.water":  Entry(mood: .thirsty, zh: [[T("喝…")], [T("嗯…喝。")], [T("好，喝一口。")]], en: [["Drink…"], ["Mm… drink."], ["Okay, a sip."]]),
        "kw.sleep":  Entry(mood: .sleepy, zh: [[T("晚…安。"), T("毯子…")], [T("晚安…毯子。")], [T("晚安。毯子给我盖好。")]], en: [["Night…"], ["Night… blanket."], ["Night. Tuck me in."]]),
        // 养生家：你吃没吃、吃了什么（只劝"配点菜、慢点吃、按点吃"，不算热量、不提体重、不教节食）
        "kw.skip":   Entry(mood: .worried, zh: [[T("吃…一点…")], [T("不吃…不行。一起…吃一点？")], [T("不吃饭我会担心的。吃一点点也好，我陪你吃。")]], en: [["Eat… a bit…"], ["No food… no good. Eat… a little?"], ["I worry when you skip meals. Just a little? I'll eat with you."]]),
        "kw.junk":   Entry(mood: .confused, zh: [[T("菜…呢？")], [T("好香…配点…青菜？")], [T("闻着好香……配点青菜吧，菜我替你吃一口。"), T("偶尔吃没事，喝杯温水解解腻。")]], en: [["Veggies…?"], ["Smells good… some greens?"], ["Smells great… add some greens? I'll eat one for you.", "Once in a while is fine. Warm water after?"]]),
        "kw.meal":   Entry(mood: .happy, zh: [[T("饱！")], [T("吃了…好！慢慢…吃。")], [T("按点吃饭，好。吃饱了吗？"), T("吃饭要慢，我吃饭就很慢。")]], en: [["Full!"], ["Ate… good! Slow… eat."], ["Eating on time. Good. Full?", "Eat slow. I eat very slow."]]),
        // 饭点提醒（它要吃饭了，喊你一起，不是催你）
        "meal.breakfast": Entry(mood: .hungry, zh: [[T("早…饭…")], [T("早饭…一起？")], [T("我要吃早饭了，你也吃点？空肚子不行。"), T("起来先喝口温水，再吃早饭。")]], en: [["Break…fast…"], ["Breakfast… together?"], ["Breakfast time for me. You too? No empty tummy.", "Warm water first, then breakfast."]]),
        "meal.lunch":     Entry(mood: .hungry, zh: [[T("午饭…")], [T("饭点…到了。一起吃？")], [T("饭点到了，我饿了。你也去吃吧，有菜有肉最好。"), T("中午了，放下手机，我们吃饭。")]], en: [["Lunch…"], ["Lunch… time. Together?"], ["Lunch time, I'm hungry. You go eat too — some veggies, some meat.", "Noon. Phone down, food time."]]),
        "meal.dinner":    Entry(mood: .hungry, zh: [[T("晚饭…")], [T("晚饭…吃了没？")], [T("该吃晚饭了，晚上吃清淡点，睡得香。"), T("晚饭时间，我已经躺好等吃了。")]], en: [["Dinner…"], ["Dinner… eaten?"], ["Dinner time. Something light at night — sleep better.", "Dinner time. I'm already lying down, ready."]]),
        "fed.goji":  Entry(mood: .calm, zh: [[T("养…生…")], [T("枸杞…泡好了。")], [T("保温杯泡枸杞，养生。"), T("喝点热的，舒服。")]], en: [["Heal…thy…"], ["Goji tea… ready."], ["Goji tea in my thermos. Very healthy.", "Something warm. Nice."]]),
        // 今天陪你
        "companion.done":  Entry(mood: .happy, zh: [[T("好！")], [T("做到了…好！")], [T("做到了！我躺着陪你做的。"), T("好，给你记一笔。"), T("嗯，我看见了。")]], en: [["Yay!"], ["Did it… yay!"], ["Did it! I was with you — lying down.", "Nice. Noted.", "I saw that."]]),
        "companion.bonus": Entry(mood: .excited, zh: [[T("包…裹！")], [T("嘟嘟星…寄东西来了！")], [T("三件都做完啦！嘟嘟星寄来个包裹，里面有{food}。")]], en: [["Pack…age!"], ["Dudu planet… sent stuff!"], ["All three done! A package from Dudu planet — there's a {food} inside."]]),
        "kw.eat":    Entry(mood: .hungry, zh: [[T("吃！")], [T("吃…什么？")], [T("吃！吃什么？")]], en: [["Eat!"], ["Eat… what?"], ["Food! What is it?"]]),
        "kw.pet":    Entry(mood: .shy, zh: [[T("嘿嘿…")], [T("肚子…给你。")], [T("嗯……肚子给你摸。")]], en: [["Hehe…"], ["Tummy… here."], ["Mm… you can rub my tummy."]]),
        "kw.praise": Entry(mood: .shy, zh: [[T("嘿…")], [T("我…乖。")], [T("嘿嘿……我知道。")]], en: [["Hehe…"], ["I'm… good."], ["Hehe… I know."]]),
        "kw.tired":  Entry(mood: .sleepy, zh: [[T("坐…")], [T("坐这儿…一起躺。")], [T("你坐这儿，我也不想动。")]], en: [["Sit…"], ["Sit… lie here."], ["Sit here. I don't wanna move either."]]),
        "kw.hello":  Entry(mood: .happy, zh: [[T("嗨…")], [T("你…来啦。")], [T("你来啦。")]], en: [["Hi…"], ["You… came."], ["Hey, you're here."]]),
        "kw.love":   Entry(mood: .shy, zh: [[T("…喜欢。")], [T("我也…喜欢。")], [T("我也……喜欢你。")]], en: [["…like."], ["Me… too."], ["Me too… a lot."]]),
        "kw.sad":    Entry(mood: .worried, zh: [[T("抱…")], [T("抱抱…不哭。")], [T("过来，抱一下。我不说话，就陪着。")]], en: [["Hug…"], ["Hug… no cry."], ["Come here. I'll just stay with you."]]),
        "kw.back":   Entry(mood: .happy, zh: [[T("回…来！")], [T("你回来了…嘟！")], [T("你回来啦。我刚醒。")]], en: [["Back!"], ["You're… back!"], ["You're back. I just woke up."]]),
        "kw.name":   Entry(mood: .happy, zh: [[T("在！")], [T("在…叫我？")], [T("在。叫我干嘛？")]], en: [["Here!"], ["Me?"], ["Yeah? You called?"]]),
        "chat.fallback": Entry(mood: .calm,
            zh: [[T("嗯…"), T("嘟？"), T("不懂…")], [T("听…不太懂。"), T("嗯…然后呢？"), T("你说…我听。")], [T("嗯……然后呢？"), T("听不太懂，但我在听。"), T("这个字太多了，我们吃点心吧？")]],
            en: [["Mm…", "Huh?"], ["Don't… get it.", "And… then?"], ["Mm… and then?", "Too many words. Snack?"]]),
        "chat.offtopic": Entry(mood: .confused,
            zh: [[T("不懂…")], [T("这个…太难了。")], [T("嘟…看不懂…有吃的吗？"), T("这个我不会，我只会吃。")]],
            en: [["Don't know…"], ["Too… hard."], ["Dudu… I only know snacks."]]),

        // 小愿望
        "req.food":    Entry(mood: .hungry, zh: [["{food}…"], [T("想吃…{food}。")], [T("想吃{food}……就一个。")]], en: [["{food}…"], ["Want… {food}."], ["Can I have {food}? Just one."]]),
        "req.drink":   Entry(mood: .thirsty, zh: [["{food}…"], [T("想喝…上次那个。")], [T("想喝上次那个{food}……")]], en: [["{food}…"], ["Want… that one."], ["Want that {food} again…"]]),
        "req.belly":   Entry(mood: .shy, zh: [[T("肚…")], [T("摸摸…肚子。")], [T("……摸一下肚子嘛。")]], en: [["Tummy…"], ["Rub… tummy."], ["…tummy rub, please?"]]),
        "req.blanket": Entry(mood: .sleepy, zh: [[T("毯…")], [T("困…毯子。")], [T("困了。毯子……")]], en: [["Blanket…"], ["Sleepy… blanket."], ["Sleepy. Blanket…"]]),
        "req.giveup":  Entry(mood: .sleepy, zh: [[T("…算了")], [T("算了…睡觉。")], [T("……算了，我先睡会儿。")]], en: [["…nevermind"], ["Nevermind… nap."], ["…nevermind. Nap time."]]),
        "req.met":     Entry(mood: .excited, zh: [[T("！！")], [T("就是…这个！")], [T("就是这个！你记得！")]], en: [["!!"], ["That… one!"], ["That's the one! You remembered!"]]),

        // 盖毯子
        "blanket":   Entry(mood: .sleepy, zh: [[T("暖…")], [T("暖和…晚安。")], [T("暖和……晚安。")]], en: [["Warm…"], ["Warm… night."], ["So warm… night."]]),
        "blanket.1": Entry(mood: .sleepy, zh: [[T("毯…！")], [T("毯子…我拿来了。")], [T("毯子我自己抱来了，你盖。")]], en: [["Blanket!"], ["Brought… blanket."], ["I brought the blanket. Your turn."]]),
        "blanket.2": Entry(mood: .shy, zh: [[T("…躺好了")], [T("躺好了…肚子露着。")], [T("我躺好了，肚子也露出来了，盖吧。")]], en: [["…ready"], ["Lying… ready."], ["I'm lying down already. Tummy out. Go."]]),

        // 离开后回来
        "back.1d":  Entry(mood: .sleepy, zh: [[T("…你？")], [T("你…回来了。")], [T("……嗯？是你啊。回来啦。")]], en: [["…you?"], ["You're… back."], ["…hm? Oh, it's you."]]),
        "back.3d":  Entry(mood: .sulky, zh: [[T("哼…")], [T("好久…才来。")], [T("嘟——。你好久才来。摸一下才原谅你。")]], en: [["Hmph…"], ["Took… long."], ["Hmph. You took forever. One pat and I'll forgive you."]]),
        "back.7d":  Entry(mood: .sleepy, zh: [[T("…呼")], [T("在蛋壳里…睡觉。")], [T("我在蛋壳里睡着了……你把我叫醒了。")]], en: [["…zz"], ["Sleeping… in shell."], ["I was asleep in my eggshell… you woke me."]]),
        "back.wake": Entry(mood: .excited, zh: [[T("你！")], [T("是你！…抱！")], [T("是你！我就知道你会来！")]], en: [["You!"], ["It's you!"], ["It's you! I knew you'd come!"]]),

        // 其他
        "found":      Entry(mood: .happy, zh: [[T("币…{n}！")], [T("捡到…{n}个币！")], [T("你不在的时候我捡到 {n} 个金币。")]], en: [["Coins… {n}!"], ["Found… {n} coins!"], ["Found {n} coins while you were out."]]),
        "selfate":    Entry(mood: .shy, zh: [[T("吃了…")], [T("自己吃了…{food}。")], [T("你不在，我自己吃了一个{food}。")]], en: [["Ate…"], ["Ate… {food}."], ["You were gone, so I ate a {food}."]]),
        "screenshot": Entry(mood: .happy, zh: [[T("咔嚓！")], [T("拍我…比耶。")], [T("咔嚓！我上镜吗？")]], en: [["Click!"], ["Photo… peace!"], ["Click! Am I photogenic?"]]),
        "shake":      Entry(mood: .confused, zh: [[T("晕…")], [T("别…摇！")], [T("晃晕了……别摇！")]], en: [["Dizzy…"], ["Don't… shake!"], ["Dizzy… stop shaking!"]]),
        "battery":    Entry(mood: .sleepy, zh: [[T("困…")], [T("没电…我也困。")], [T("电量不多了，我也好困……")]], en: [["Sleepy…"], ["Low… battery."], ["Battery's low. I'm sleepy too…"]]),
        "play.zero":  Entry(mood: .shy, zh: [[T("…没接到")], [T("一个…都没。")], [T("一个都没接到……下次再来。")]], en: [["…missed"], ["None… caught."], ["Didn't catch any… next time."]]),
        "game.win":   Entry(mood: .excited, zh: [[T("赢…了！")], [T("赢了！我…躺着赢的。")], [T("赢了！我全程躺着，也算我一半。")]], en: [["Won!"], ["Won! …lying down."], ["We won! I was lying down, still counts as half mine."]]),
        "game.lose":  Entry(mood: .shy, zh: [[T("…输了")], [T("没事…我也没赢过。")], [T("输了也好玩。再来一局？我先躺着。")]], en: [["…lost"], ["It's ok… I never win."], ["Losing is fun too. Again? I'll stay lying here."]]),
        "play.some":  Entry(mood: .excited, zh: [[T("{n}个！")], [T("接到…{n}个！")], [T("接到 {n} 个！好玩！")]], en: [["{n}!"], ["Caught… {n}!"], ["Caught {n}! Fun!"]]),
        "workout":    Entry(mood: .happy, zh: [[T("厉害！")], [T("你…好厉害。我躺着。")], [T("你练完啦？好厉害。我躺着替你歇会儿。")]], en: [["Wow!"], ["You… strong."], ["Done working out? Amazing. I'll rest for you."]]),
        "dream":      Entry(mood: .sleepy, zh: [[T("梦…")], [T("做了…一个梦。")], [T("我做了个梦……")]], en: [["Dream…"], ["Had… a dream."], ["I had a dream…"]]),
        "share":      Entry(mood: .shy, zh: [[T("…给你。")], [T("给你…一点。就一点。")], [T("这个……分你一点。就一点点。")]], en: [["…for you."], ["Some… for you."], ["Here… a little for you. Just a little."]]),
    ]
}
