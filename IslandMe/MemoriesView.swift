import SwiftUI

/// 回忆：蛋壳、陪伴天数、它现在会说到哪、"第一次"们、它爱吃的、做过的梦
struct MemoriesView: View {
    @ObservedObject var bond: BondStore
    var petName: String
    @StateObject private var letters = LetterStore()

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "oval.portrait.fill")
                        .font(.system(size: 40)).foregroundStyle(Theme.accent.opacity(0.7))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(T("一起 {0} 天", bond.daysTogether)).font(.headline)
                        if let d = bond.hatchDate {
                            Text(T("破壳于 ") + d.formatted(date: .long, time: .omitted)).font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(bond.route == .dudu ? T("只说嘟嘟语") : (bond.route == .en ? T("学英文") : T("学中文")))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(T("现在：{0}", bond.stageName)); Spacer(); Text(T("熟悉度 {0}", bond.familiarity)).foregroundStyle(.secondary) }
                    if let next = bond.nextThreshold {
                        ProgressView(value: Double(bond.familiarity), total: Double(next)).tint(Theme.accent)
                        Text(T("再 {0} 点会有新变化", next - bond.familiarity)).font(.footnote).foregroundStyle(.secondary)
                    }
                    if bond.stage >= 3 && !bond.signature.isEmpty {
                        Text(T("你们的专属嘟嘟：{0}", bond.signature)).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                let im = Intimacy.load()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("❤️ " + T("亲密度：{0}", im.tier.name))
                        Spacer()
                        Text("\(Int(im.value))/100").foregroundStyle(.secondary)
                    }
                    ProgressView(value: im.value, total: 100).tint(Color(hex: "#FF8FB1"))
                    Text(im.bonus > 0 ? T("嘟嘟小店爆率 +{0}%：产出器多掉东西、掉福袋、掉高一级的货", Int(im.bonus * 100)) : T("还没有爆率加成"))
                        .font(.footnote).foregroundStyle(.secondary)
                    if let n = im.next {
                        Text(T("到 {0}（{1}）爆率 +{2}%", n.name, n.floor, Int(n.bonus * 100))).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } header: { Text(T("亲密度")) } footer: {
                Text(T("它饿了、渴了、脏了、闷了的时候及时管它，亲密度就涨；一整天没让它见底再加一点。让它饿到底、脏到底，管家会用你的金币给它点最好的，但亲密度会掉。好几天不来看它也会掉。"))
            }

            Section(T("第一次")) {
                ForEach(Milestone.allCases, id: \.self) { m in
                    let date = bond.milestones.first { $0.0 == m }?.1
                    HStack {
                        Image(systemName: m.symbol).frame(width: 24).foregroundStyle(date == nil ? Color.secondary : Theme.accent)
                        Text(date == nil ? T("？？？") : m.title).foregroundStyle(date == nil ? .secondary : .primary)
                        Spacer()
                        if let date { Text(date.formatted(date: .abbreviated, time: .omitted)).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
            }

            Section(T("它的口味")) {
                row(T("第一口吃的"), bond.firstFood.map { "\($0.emoji) \($0.name)" })
                row(T("第一杯喝的"), bond.firstDrink.map { "\($0.emoji) \($0.name)" })
                row(T("最爱吃的"), bond.favoriteFood.map { "\($0.emoji) \($0.name)" } ?? T("还没发现，多喂几样试试"))
            }

            Section(T("习惯")) {
                let lv = bond.habitLevel("blanket")
                row(T("晚上盖毯子"), lv == 0 ? T("还不是习惯") : (lv == 1 ? T("开始等你盖了") : T("没毯子睡不着")))
            }

            Section(T("嘟嘟星来信")) {
                if letters.letters.isEmpty {
                    Text(T("还没收到。一起待久一点，门那边会寄东西来。")).foregroundStyle(.secondary)
                }
                ForEach(letters.letters) { l in
                    NavigationLink {
                        LetterView(letter: l, route: bond.route, stage: bond.stage, petName: petName)
                    } label: {
                        Label(l.title + T("的信"), systemImage: "envelope.open.fill")
                    }
                }
            }

            Section(T("它做过的梦")) {
                if bond.dreams.isEmpty {
                    Text(T("还没做过梦。它睡觉时偶尔会梦到嘟嘟星。")).foregroundStyle(.secondary)
                }
                ForEach(bond.dreams, id: \.self) { d in
                    Label(bond.route == .en ? d.textEn : d.text, systemImage: d.symbol)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle(T("和{0}的回忆", petName))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareCardButton(card: ShareCard(petName: petName, days: bond.daysTogether, line: ChatStore.lastLineForShare, frame: "idle"), label: T("分享今天的它"))
            }
        }
    }

    private func row(_ k: String, _ v: String?) -> some View {
        HStack { Text(k); Spacer(); Text(v ?? "—").foregroundStyle(.secondary) }
    }
}

/// 解锁里程碑时首页弹出的卡片（可分享）
struct MilestoneCard: View {
    let milestone: Milestone
    let petName: String
    let days: Int
    var close: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: milestone.symbol).font(.system(size: 38)).foregroundStyle(Theme.accent)
            Text(T("第一次")).font(.system(size: 13)).foregroundStyle(Theme.text2)
            Text(milestone.title).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.text)
            Text(T("和{0}在一起的第 {1} 天", petName, days)).font(.system(size: 13)).foregroundStyle(Theme.text2)
            HStack(spacing: 12) {
                ShareCardButton(card: ShareCard(petName: petName, days: days, line: ChatStore.lastLineForShare, title: milestone.title, frame: "happy"))
                .buttonStyle(.bordered)
                Button(T("好"), action: close).buttonStyle(.borderedProminent)
            }
            .tint(Theme.accent)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 300)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28))
        .shadow(radius: 20)
    }
}
