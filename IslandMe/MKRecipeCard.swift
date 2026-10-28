import SwiftUI

/// 配方卡（2026-10-21，学同类：点订单里的菜 / 选中厨具，直接看图示配方，不用读一长串字）
/// 一行：[食材图标 ✓/缺] + [食材] → [厨具] → [菜]；台面上有的打勾，没有的变暗
struct MKRecipeRow: View {
    let r: MK.Recipe
    let have: (String) -> Bool
    var size: CGFloat = 26
    var compact = false
    var body: some View {
        HStack(spacing: compact ? 3 : 6) {
            ForEach(Array(r.needs.enumerated()), id: \.offset) { p in
                if p.offset > 0 { Text("+").font(.system(size: compact ? 10 : 13, weight: .bold)).foregroundStyle(Theme.text3) }
                ingredient(p.element)
            }
            Image(systemName: "arrow.right").font(.system(size: compact ? 9 : 12, weight: .bold)).foregroundStyle(Theme.text3)
            MKIcon(id: r.at).frame(width: size * 0.85, height: size * 0.85).opacity(0.9)
            Image(systemName: "arrow.right").font(.system(size: compact ? 9 : 12, weight: .bold)).foregroundStyle(Theme.text3)
            MKIcon(id: r.id).frame(width: size, height: size)
        }
    }
    private func ingredient(_ id: String) -> some View {
        let ok = have(id)
        return MKIcon(id: id).frame(width: size, height: size)
            .opacity(ok ? 1 : 0.45)
            .overlay(alignment: .bottomTrailing) {
                if MK.chain(id) != nil {
                    Text("\(MK.tier(id))").font(.system(size: size * 0.3, weight: .heavy)).foregroundStyle(.black)
                        .frame(width: size * 0.42, height: size * 0.42).background(Theme.coin, in: Circle()).offset(x: 3, y: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if ok {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: size * 0.36)).foregroundStyle(Color(hex: "#7BE0A0"))
                        .background(Circle().fill(Color.black.opacity(0.6))).offset(x: 4, y: -4)
                }
            }
    }
}

/// 点订单里的菜弹出来：这道菜怎么做（要什么、哪个厨具、几分钟），食材本身是菜的再往下拆一层
struct MKRecipePopup: View {
    let recipe: MK.Recipe
    @ObservedObject var store: MKStore
    var close: () -> Void
    private func have(_ id: String) -> Bool {
        store.s.board.contains { $0.item == id && !$0.boxed } || (store.s.cooks[recipe.at]?.putIn.contains(id) ?? false)
    }
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    MKIcon(id: recipe.id).frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("「{0}」怎么做", recipe.name)).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                        Text(T("用{0}做 · {1} 分钟", MK.name(recipe.at), Int(recipe.minutes))).font(.system(size: 12)).foregroundStyle(Theme.text3)
                    }
                    Spacer()
                    Button(action: close) { Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.text3) }.buttonStyle(.press)
                }
                MKRecipeRow(r: recipe, have: have, size: 40)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
                // 食材里有菜（深菜）：先做那道
                ForEach(recipe.needs.compactMap { MK.recipe($0) }, id: \.id) { sub in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(T("先做「{0}」：", sub.name)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text2)
                        MKRecipeRow(r: sub, have: { id in store.s.board.contains { $0.item == id && !$0.boxed } }, size: 30)
                    }
                }
                Text(steps).font(.system(size: 12)).foregroundStyle(Theme.text3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 22)
        }
    }
    private var steps: String {
        let hasAppliance = store.s.board.contains { $0.item == recipe.at } || store.s.bag.contains { $0.hasPrefix(recipe.at) }
        if !hasAppliance { return T("还没有{0}：{1} 级会送一台。", MK.name(recipe.at), MK.appliances.first { $0.id == recipe.at }?.unlock ?? 0) }
        let missing = recipe.needs.filter { !have($0) }
        if missing.isEmpty { return T("食材都有了：把它们一个一个拖进{0}，满了就开始做。", MK.name(recipe.at)) }
        return T("还差：") + missing.map { MK.chain($0) != nil ? T("{0}（{1} 级）", MK.name($0), MK.tier($0)) : MK.name($0) }.joined(separator: T("、"))
            + T("。打勾的是台面上已经有的，齐了拖进{0}。", MK.name(recipe.at))
    }
}
