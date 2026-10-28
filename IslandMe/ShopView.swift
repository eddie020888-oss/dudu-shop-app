import SwiftUI

/// 商城（2026-10-19 改版）：本周上新 + 食物 / 配饰 / 家具 / 菜谱。
/// 币从你的生活和嘟嘟小店来，在这里花回嘟嘟身上；菜谱书买了，小店就多几道菜。
struct ShopView: View {
    @ObservedObject var profile: ProfileStore
    var character: Character
    var pose: Pose

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    @State private var tab = Shot.on ? Shot.shopTab : 0
    @State private var slot = "all"
    @State private var room: NestRoom = .bedroom
    @State private var toast: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text(T("商城")).font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.text)
                    Spacer()
                    CoinBadge(coins: profile.profile.coins)
                }
                .padding(.horizontal, 20).padding(.top, 8)

                weekly

                Picker("", selection: $tab) {
                    Text(T("食物")).tag(0); Text(T("配饰")).tag(1); Text(T("家具")).tag(2); Text(T("菜谱")).tag(3)
                }
                .pickerStyle(.segmented).padding(.horizontal, 20)

                switch tab {
                case 0: foodSection
                case 1: accessorySection
                case 2: furnitureSection
                default: bookSection
                }
            }
        }
        .background(Theme.ground.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let t = toast {
                Text(t).font(.system(size: 14, weight: .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.coin, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func say(_ s: String) {
        withAnimation(.spring(response: 0.3)) { toast = s }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { if toast == s { withAnimation { toast = nil } } }
    }

    // MARK: 本周上新（每周一换 4 件，八折；不买也没关系，下次还会轮到）

    private var weekly: some View {
        let picks = Weekly.picks(profile.profile.owned)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                Image("ui_weekly_gift").resizable().scaledToFit().frame(width: 28, height: 28)
                Text(T("本周上新")).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.text)
                Text(T("八折")).font(.system(size: 11, weight: .heavy)).foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.coin, in: Capsule())
                Spacer()
                Image("ui_hourglass").resizable().scaledToFit().frame(width: 14, height: 14)
                Text(T("还有 {0} 天换一批", Weekly.daysLeft())).font(.system(size: 11)).foregroundStyle(Theme.text3)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(picks) { p in weeklyCard(p) }
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(hex: "#2B2340"), Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.coin.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func weeklyCard(_ p: Weekly.Pick) -> some View {
        let owned = p.owned(profile.profile.owned)
        let price = p.salePrice
        let afford = profile.profile.coins >= price
        return VStack(spacing: 6) {
            Image(p.image).resizable().scaledToFit().padding(10)
                .frame(width: 112, height: 92)
                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
            Text(p.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
            if owned {
                Text(T("已拥有")).font(.system(size: 12)).foregroundStyle(Theme.text3).frame(height: 30)
            } else {
                Button { if buyWeekly(p) { say(T("买到了「{0}」", p.name)) } } label: {
                    HStack(spacing: 4) {
                        Text("\(price)").font(.system(size: 13, weight: .bold))
                        Text("\(p.price)").font(.system(size: 10)).strikethrough().opacity(0.6)
                    }
                    .foregroundStyle(Color(hex: "#15101F"))
                    .frame(width: 100, height: 30)
                    .background(Theme.coin, in: Capsule())
                }
                .buttonStyle(.press).disabled(!afford).opacity(afford ? 1 : 0.45)
            }
        }
        .frame(width: 112)
    }

    private func buyWeekly(_ p: Weekly.Pick) -> Bool {
        guard profile.spend(p.salePrice, T("本周上新 · {0}", p.name)) else { return false }
        switch p.kind {
        case .acc(let a):   profile.profile.owned.append(a.id); profile.equip(a)
        case .style(let s): profile.profile.owned.append(s.ownedKey); s.item.choose(s.n)
        case .book(let b):  profile.profile.owned.append("book." + b.id); MK.addBook(b.id)
        }
        return true
    }

    // MARK: 食物

    private var foodSection: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Food.shop) { f in foodCard(f) }
            }
            Text(T("💧 水免费，点「喝水」直接喝 · 🍱 嘟嘟小店做的菜在店里点「带回家」"))
                .font(.system(size: 12)).foregroundStyle(Theme.text3).multilineTextAlignment(.center)
            EarnGuide(profile: profile)
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
    }

    private func foodCard(_ f: Food) -> some View {
        let afford = profile.profile.coins >= f.price
        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let ic = f.icon, UIImage(named: ic) != nil {
                        Image(ic).resizable().scaledToFit().padding(12)
                    } else {
                        Text(f.emoji).font(.system(size: 46))
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 96)
                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                if f.favorite {
                    Text(T("最爱")).font(.system(size: 10, weight: .heavy)).foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.joy, in: Capsule()).padding(6)
                }
                let n = profile.count(f)
                if n > 0 {
                    Text("×\(n)").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.surface2, in: Capsule())
                        .padding(6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            Text(f.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
            Text(f.effectText).font(.system(size: 11)).foregroundStyle(Theme.text2).lineLimit(1)
            Text(f.note).font(.system(size: 10)).foregroundStyle(Theme.text3).lineLimit(2).frame(height: 26, alignment: .top)
            Button { if profile.buy(f) { say(T("{0} {1} 放进背包了", f.emoji, f.name)) } } label: {
                Text(T("{0} 币", f.price)).font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.press)
            .foregroundStyle(Color(hex: "#15101F"))
            .background(Theme.coin, in: RoundedRectangle(cornerRadius: 12))
            .disabled(!afford).opacity(afford ? 1 : 0.4)
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: 配饰

    private var accessorySection: some View {
        VStack(spacing: 14) {
            ZStack {
                Color.black
                DressedPetView(pet: character.pet, pose: .stand, accessories: profile.profile.equipped).frame(height: 170)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                ForEach(["all", "head", "eyes", "neck"], id: \.self) { k in
                    let n = ["all": T("全部"), "head": T("帽子"), "eyes": T("眼镜"), "neck": T("脖子")][k] ?? k
                    Button { withAnimation { slot = k } } label: {
                        Text(n).font(.system(size: 13, weight: slot == k ? .semibold : .regular))
                            .foregroundStyle(slot == k ? .black : Theme.text2)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(slot == k ? Theme.accent : Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.press)
                }
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Accessory.all.filter { slot == "all" || $0.slot == slot }.sorted { $0.price < $1.price }) { a in accCard(a) }
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
    }

    private func accCard(_ a: Accessory) -> some View {
        let owned = profile.profile.owned.contains(a.id)
        let on = profile.isEquipped(a)
        return VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.35)
                if UIImage(named: "acc_" + a.id) != nil {
                    Image("acc_" + a.id).resizable().scaledToFit().padding(18)
                } else {
                    AccessoryOverlay(ids: [a.id]).frame(width: 110, height: 110)
                }
                tierChip(a.tier, big: a.price >= 500).padding(8)
            }
            .frame(height: 110).clipShape(RoundedRectangle(cornerRadius: 16))
            HStack {
                Text(a.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                Spacer()
                if !owned { Text("\(a.price)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.coin) }
            }
            Button {
                if !owned { if profile.buy(a) { say(T("戴上「{0}」了", a.name)) } } else if on { profile.unequip(a) } else { profile.equip(a) }
            } label: {
                Text(!owned ? T("购买") : (on ? T("脱下") : T("戴上")))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.press)
            .foregroundStyle(!owned ? Color(hex: "#15101F") : Theme.text)
            .background(!owned ? Theme.accent : (on ? Theme.surface2 : Theme.surface), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(owned ? Color(hex: "#3A3744") : .clear, lineWidth: 1))
            .disabled(!owned && profile.profile.coins < a.price)
            .opacity(!owned && profile.profile.coins < a.price ? 0.45 : 1)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(on ? Theme.accent : .clear, lineWidth: 1.5))
    }

    private func tierChip(_ t: String, big: Bool) -> some View {
        Text(t).font(.system(size: 9, weight: .heavy)).foregroundStyle(.black)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(big ? Theme.coin : Theme.accent.opacity(0.85), in: Capsule())
    }

    // MARK: 家具（窝里每个位置的所有款式）

    private var furnitureSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(NestRoom.allCases) { r in
                    Button { withAnimation { room = r } } label: {
                        Text(r.name).font(.system(size: 13, weight: room == r ? .semibold : .regular))
                            .foregroundStyle(room == r ? Color.black : Theme.text2)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(room == r ? Theme.accent : Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.press)
                }
            }
            ForEach(room.items.filter { !$0.free || $0.styles.count > 1 }) { i in furnitureRow(i) }
            Text(T("买了就摆进窝里同一个位置；买过的款式在窝里点那件家具随时换。"))
                .font(.system(size: 11)).foregroundStyle(Theme.text3).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
    }

    private func furnitureRow(_ i: NestItem) -> some View {
        let owned = profile.profile.owned
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(i.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                if i.game != nil { Image(systemName: "gamecontroller.fill").font(.system(size: 10)).foregroundStyle(Theme.coin) }
                Spacer()
                Text(T("{0}/{1} 款", i.styles.filter { ($0.n == 0 && i.free) || owned.contains($0.ownedKey) }.count, i.styles.count))
                    .font(.system(size: 11)).foregroundStyle(Theme.text3)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(i.styles) { st in
                        let have = (st.n == 0 && i.free) || owned.contains(st.ownedKey)
                        let afford = profile.profile.coins >= st.price
                        VStack(spacing: 6) {
                            ZStack(alignment: .topLeading) {
                                Image(st.image).resizable().scaledToFit().padding(10)
                                    .frame(width: 104, height: 84)
                                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                                if st.n > 0 { tierChip(st.tier, big: st.price >= 500).padding(6) }
                            }
                            Text(st.name).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.text2).lineLimit(1)
                            if have {
                                Text(i.chosen == st.n ? T("摆着") : T("有了")).font(.system(size: 12)).foregroundStyle(Theme.text3).frame(height: 28)
                            } else {
                                Button {
                                    if profile.buyNest(st) { i.choose(st.n); say(T("「{0}」摆进窝里了", st.name)) }
                                } label: {
                                    Text(T("{0} 币", st.price)).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "#15101F"))
                                        .frame(width: 92, height: 28).background(Theme.coin, in: Capsule())
                                }
                                .buttonStyle(.press).disabled(!afford).opacity(afford ? 1 : 0.45)
                            }
                        }
                        .frame(width: 104)
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: 菜谱（买了小店多几道菜）

    private var bookSection: some View {
        let lv = max(1, UserDefaults.standard.integer(forKey: "merge.level"))
        return VStack(spacing: 12) {
            Text(T("嘟嘟小店赚来的币，可以在这里换菜谱。买了以后店里的厨具会多几道菜，客人也会开始点。"))
                .font(.system(size: 12)).foregroundStyle(Theme.text2).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(MK.books, id: \.id) { b in
                let have = MK.hasBook(b.id)
                let afford = profile.profile.coins >= b.price
                HStack(spacing: 12) {
                    Image("mk_" + b.id).resizable().scaledToFit().frame(width: 76, height: 76)
                        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(b.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                        Text(b.note).font(.system(size: 11)).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 4) {
                            ForEach(MK.recipes.filter { $0.book == b.id }, id: \.id) { r in
                                Image("mk_" + r.id).resizable().scaledToFit().frame(width: 24, height: 24)
                                    .opacity(have ? 1 : 0.55)
                            }
                        }
                        if lv < b.level {
                            Text(T("小店 {0} 级以后才用得上", b.level)).font(.system(size: 10)).foregroundStyle(Theme.alert)
                        }
                    }
                    Spacer(minLength: 0)
                    if have {
                        Text(T("已收进\n小店")).font(.system(size: 11)).foregroundStyle(Theme.text3).multilineTextAlignment(.center)
                    } else {
                        Button {
                            if profile.spend(b.price, T("菜谱 · {0}", b.name)) {
                                profile.profile.owned.append("book." + b.id); MK.addBook(b.id)
                                say(T("📖 {0} 送到小店了", b.name))
                            }
                        } label: {
                            Text("\(b.price)").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: "#15101F"))
                                .frame(width: 64, height: 40).background(Theme.coin, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.press).disabled(!afford).opacity(afford ? 1 : 0.45)
                    }
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
    }
}

/// 本周上新：按周数挑 4 件没买过的（配饰 / 家具新款 / 菜谱各有机会），八折
enum Weekly {
    enum Kind { case acc(Accessory), style(NestStyle), book(MK.Book) }
    struct Pick: Identifiable {
        let kind: Kind
        var id: String { switch kind { case .acc(let a): return a.id; case .style(let s): return s.id; case .book(let b): return b.id } }
        var name: String { switch kind { case .acc(let a): return a.name; case .style(let s): return s.name; case .book(let b): return b.name } }
        var price: Int { switch kind { case .acc(let a): return a.price; case .style(let s): return s.price; case .book(let b): return b.price } }
        var image: String { switch kind { case .acc(let a): return "acc_" + a.id; case .style(let s): return s.image; case .book(let b): return "mk_" + b.id } }
        var salePrice: Int { max(1, Int((Double(price) * 0.8).rounded())) }
        func owned(_ o: [String]) -> Bool {
            switch kind {
            case .acc(let a): return o.contains(a.id)
            case .style(let s): return o.contains(s.ownedKey)
            case .book(let b): return MK.hasBook(b.id)
            }
        }
    }

    static func week(_ d: Date = Date()) -> Int {
        var c = Calendar(identifier: .iso8601); c.timeZone = .current
        return c.component(.yearForWeekOfYear, from: d) * 100 + c.component(.weekOfYear, from: d)
    }
    static func daysLeft(_ d: Date = Date()) -> Int {
        var c = Calendar(identifier: .iso8601); c.timeZone = .current
        let wd = c.component(.weekday, from: d)          // 1 = 周日
        return wd == 1 ? 1 : 9 - wd
    }

    /// 这周的 4 件：同一周里固定（买掉的还显示「已拥有」，不会补新的）
    static func picks(_ owned: [String]) -> [Pick] {
        let accs = Accessory.all.filter { $0.price >= 90 }.map { Pick(kind: .acc($0)) }
        let styles = NestItem.allCases.flatMap { $0.styles.dropFirst() }.map { Pick(kind: .style($0)) }
        let books = MK.books.map { Pick(kind: .book($0)) }
        var seed = UInt64(week()) &* 2654435761
        func next() -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int(seed >> 33) }
        func take(_ a: [Pick], _ n: Int) -> [Pick] {
            var pool = a, out: [Pick] = []
            while out.count < n, !pool.isEmpty { out.append(pool.remove(at: next() % pool.count)) }
            return out
        }
        // 两件衣服、一件家具新款、一件随机（菜谱或家具）
        let a = take(accs, 2), s = take(styles, 2)
        let last = next() % 3 == 0 ? take(books, 1) : Array(s.dropFirst())
        return a + Array(s.prefix(1)) + last
    }
}
