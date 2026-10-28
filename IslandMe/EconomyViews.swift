import SwiftUI

/// 点「喂食」弹出：背包里的食物；没有的可以直接花币买一个喂。
struct FoodPicker: View {
    @ObservedObject var profile: ProfileStore
    var onPick: (Food) -> Void
    @Environment(\.dismiss) private var dismiss

    /// 背包里有的排前面，其余按价钱
    private var foods: [Food] {
        Food.all.filter { $0.id != "water" && (!$0.dish || profile.count($0) > 0) }.sorted { a, b in
            let ha = profile.count(a) > 0, hb = profile.count(b) > 0
            if ha != hb { return ha }
            return a.price < b.price
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    HStack {
                        Text(T("背包")).font(.system(size: 13)).foregroundStyle(Theme.text2)
                        Spacer()
                        CoinBadge(coins: profile.profile.coins)
                    }
                    ForEach(foods) { f in
                        let have = profile.count(f)
                        let afford = profile.profile.coins >= f.price
                        Button {
                            if have > 0 || profile.buy(f) { onPick(f); dismiss() }
                        } label: {
                            HStack(spacing: 12) {
                                if let icon = f.icon, UIImage(named: icon) != nil {
                                    Image(icon).resizable().scaledToFit().frame(width: 44, height: 44)
                                } else {
                                    Text(f.emoji).font(.system(size: 30)).frame(width: 44)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(f.name).font(.system(size: 15, weight: .semibold))
                                        if f.favorite { Text(T("最爱")).font(.system(size: 10, weight: .bold)).padding(.horizontal, 5).padding(.vertical, 1).background(Theme.joy.opacity(0.25), in: Capsule()).foregroundStyle(Theme.joy) }
                                    }
                                    Text(f.effectText).font(.system(size: 12)).foregroundStyle(Theme.text2)
                                }
                                Spacer()
                                Text(have > 0 ? "×\(have)" : T("{0} 币买一个", f.price))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(have > 0 ? Theme.text : Theme.coin)
                            }
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                            .opacity(have > 0 || afford ? 1 : 0.4)
                        }
                        .buttonStyle(.press)
                        .foregroundStyle(Theme.text)
                        .disabled(have == 0 && !afford)
                    }
                    Text(T("🍱 嘟嘟小店里做的菜，点「带回家」就会出现在这里，比买的更顶饱。")).font(.system(size: 12)).foregroundStyle(Theme.text3).padding(.top, 4)
                    Text(T("钱不够？签到、起床、走路、运动、聊天、陪它玩都能赚；你不在时它也会捡点钱。")).font(.system(size: 12)).foregroundStyle(Theme.text3).padding(.top, 4)
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("喂它吃什么")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(T("关闭")) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

struct CoinBadge: View {
    var coins: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.hexagongrid.circle.fill").foregroundStyle(Theme.coin)
            Text("\(coins)").font(.system(size: 16, weight: .bold)).monospacedDigit()
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.surface, in: Capsule())
    }
}

/// 赚钱规则 + 今天完成情况
struct EarnGuide: View {
    @ObservedObject var profile: ProfileStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("金币怎么来")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
            ForEach(EarnRule.allCases, id: \.self) { r in
                let done = profile.isClaimed(r)
                HStack(spacing: 8) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? Theme.clean : Theme.text3)
                    Text(r.title).font(.system(size: 12)).foregroundStyle(done ? Theme.text2 : Theme.text)
                    Spacer()
                    Text("+\(r.amount)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.coin)
                }
            }
            Text(T("照顾它不给钱；水、清理、陪玩免费，食物和配饰要花钱。")).font(.system(size: 11)).foregroundStyle(Theme.text3).padding(.top, 2)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 金币明细
struct LedgerView: View {
    @ObservedObject var profile: ProfileStore
    var body: some View {
        List {
            Section { EarnGuide(profile: profile).listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
            Section(T("背包")) {
                ForEach(Food.shop) { f in
                    HStack { Text("\(f.emoji) \(f.name)"); Spacer(); Text("×\(profile.count(f))").foregroundStyle(.secondary) }
                }
            }
            Section(T("明细")) {
                ForEach(profile.wallet.ledger) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.reason).font(.system(size: 14))
                            Text(e.at.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if e.amount != 0 {
                            Text(e.amount > 0 ? "+\(e.amount)" : "\(e.amount)").monospacedDigit()
                                .foregroundStyle(e.amount > 0 ? Theme.coin : Theme.text2)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle(T("金币 {0}", profile.profile.coins))
    }
}

/// 首页右上角飘一下 "+10 签到"
struct RewardToast: View {
    var reward: ProfileStore.Reward
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.hexagongrid.circle.fill").foregroundStyle(Theme.coin)
            Text("+\(reward.amount)").font(.system(size: 15, weight: .bold)).monospacedDigit().foregroundStyle(Theme.coin)
            Text(reward.reason).font(.system(size: 13)).foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.coin.opacity(0.4), lineWidth: 1))
    }
}
