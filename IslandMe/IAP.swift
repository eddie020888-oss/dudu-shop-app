import StoreKit
import SwiftUI

/// 内购（2026-10-21）：只卖宝石（小店里加速用的），价格档位跟同类合成游戏一样（$1.99 / $4.99 / $9.99 / $19.99），
/// 外加一次性的新手礼包。全部是「消耗型」商品。
/// 买到的东西先记在「待领取」里（UserDefaults），小店每秒检查一次，领进存档后再清掉——
/// 这样就算在小店外面买（或者购买在后台补发），也不会丢。
@MainActor
final class IAP: ObservableObject {
    static let shared = IAP()

    struct Pack: Identifiable {
        let id: String          // App Store Connect 里的 productId
        let gems: Int
        let bag: Int            // 背包加几格
        let energy: Int
        let name: String
        let bonus: String?      // 角标：多送多少
        var once = false        // 只能买一次（新手礼包）
        var usd: String { [200: "$1.99", 80: "$1.99", 220: "$4.99", 480: "$9.99", 1000: "$19.99"][gems] ?? "" }   // 截图演示用
    }
    static let packs: [Pack] = [
        Pack(id: "com.eddiejiang.islandme.starter", gems: 200, bag: 5, energy: 100, name: T("新手礼包"), bonus: T("只能买一次"), once: true),
        Pack(id: "com.eddiejiang.islandme.gems80", gems: 80, bag: 0, energy: 0, name: T("一小袋宝石"), bonus: nil),
        Pack(id: "com.eddiejiang.islandme.gems220", gems: 220, bag: 0, energy: 0, name: T("一袋宝石"), bonus: T("多送 10%")),
        Pack(id: "com.eddiejiang.islandme.gems480", gems: 480, bag: 0, energy: 0, name: T("一盒宝石"), bonus: T("多送 20%")),
        Pack(id: "com.eddiejiang.islandme.gems1000", gems: 1000, bag: 0, energy: 0, name: T("一箱宝石"), bonus: T("多送 25%")),
    ]
    static func pack(_ id: String) -> Pack? { packs.first { $0.id == id } }

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var busy: String? = nil
    @Published var message: String? = nil

    private let d = UserDefaults.standard
    private var listener: Task<Void, Never>?

    private init() {}

    /// App 启动时调一次：听后台补发的交易（家长批准、网络断了重连、上次没走完的）
    func start() {
        guard listener == nil, !MKDemo.on, !Shot.on else { return }
        listener = Task { [weak self] in
            for await r in StoreKit.Transaction.updates { await self?.handle(r) }
        }
        Task { await load() }
        Task { for await r in StoreKit.Transaction.unfinished { await handle(r) } }
    }

    func load() async {
        guard products.isEmpty else { return }
        if let ps = try? await Product.products(for: Self.packs.map(\.id)) {
            products = Dictionary(uniqueKeysWithValues: ps.map { ($0.id, $0) })
        }
    }

    func boughtOnce(_ p: Pack) -> Bool { d.bool(forKey: "iap.once." + p.id) }

    func buy(_ p: Pack) async {
        guard busy == nil else { return }
        if p.once && boughtOnce(p) { message = T("新手礼包已经买过了。"); return }
        if products[p.id] == nil { await load() }
        guard let prod = products[p.id] else { message = T("商店暂时连不上，过一会儿再试。"); return }
        busy = p.id; defer { busy = nil }
        do {
            switch try await prod.purchase() {
            case .success(let r): await handle(r)
            case .pending: message = T("等待确认中（比如家长批准），确认后会自动到账。")
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            message = T("没买成：{0}", error.localizedDescription)
        }
    }

    private func handle(_ r: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = r else { return }          // 没通过苹果验证的不发
        if t.revocationDate == nil, let p = Self.pack(t.productID), !d.bool(forKey: "iap.tx.\(t.id)") {
            d.set(true, forKey: "iap.tx.\(t.id)")                 // 同一笔只发一次
            d.set(d.integer(forKey: "iap.pending.gems") + p.gems, forKey: "iap.pending.gems")
            d.set(d.integer(forKey: "iap.pending.bag") + p.bag, forKey: "iap.pending.bag")
            d.set(d.integer(forKey: "iap.pending.energy") + p.energy, forKey: "iap.pending.energy")
            if p.once { d.set(true, forKey: "iap.once." + p.id) }
            Analytics.log("iap", ["product": p.id])
            message = T("到账了：{0}。谢谢你，它会好好用的。", p.name)
        }
        await t.finish()
    }

    /// 小店来领：返回（宝石，背包格，体力），领完清零
    static func takePending() -> (Int, Int, Int)? {
        let d = UserDefaults.standard
        let g = d.integer(forKey: "iap.pending.gems"), b = d.integer(forKey: "iap.pending.bag"), e = d.integer(forKey: "iap.pending.energy")
        guard g > 0 || b > 0 || e > 0 else { return nil }
        d.set(0, forKey: "iap.pending.gems"); d.set(0, forKey: "iap.pending.bag"); d.set(0, forKey: "iap.pending.energy")
        return (g, b, e)
    }
}

extension MKStore {
    /// 内购到账：领进存档（小店每秒查一次）
    func claimIAP() {
        guard !noSave, let (g, b, e) = IAP.takePending() else { return }
        s.gems += g; s.energy += e
        if b > 0 { s.bagSlots = min(Self.bagMax, s.bagSlots + b) }
        flushSave()
        MKSfx.play("reward")
        say(T("宝石 +{0}", g) + (b > 0 ? T("，背包 +{0} 格", b) : "") + (e > 0 ? T("，体力 +{0}", e) : ""))
    }
}

/// 宝石商店（点顶栏的宝石打开）
struct MKGemShop: View {
    @ObservedObject var store: MKStore
    @ObservedObject private var iap = IAP.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill").foregroundStyle(Color(hex: "#7FD8FF"))
                        Text(T("现在有 {0} 颗宝石", store.s.gems)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                        Spacer()
                    }
                    Text(T("宝石用来买体力、让宝箱和做菜马上好、升级产出器、加背包格子。不买也能玩完全部内容，只是慢一点。"))
                        .font(.system(size: 12)).foregroundStyle(Theme.text3).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(IAP.packs) { p in
                        if !(p.once && iap.boughtOnce(p)) { row(p) }
                    }
                    if let m = iap.message {
                        Text(m).font(.system(size: 13)).foregroundStyle(Theme.coin).multilineTextAlignment(.center).padding(.top, 4)
                    }
                    Text(T("购买由 Apple 处理。宝石只在这台设备的小店里用，删掉 App 会一起清掉。"))
                        .font(.system(size: 11)).foregroundStyle(Theme.text3).multilineTextAlignment(.center).padding(.top, 8)
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(T("宝石")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(T("好")) { dismiss() } } }
            .task { await iap.load() }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
    }

    private func row(_ p: IAP.Pack) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(p.once ? Theme.coin.opacity(0.18) : Theme.surface2)
                Image(systemName: p.once ? "gift.fill" : "diamond.fill")
                    .font(.system(size: p.once ? 26 : 18 + CGFloat(min(4, p.gems / 250)) * 3))
                    .foregroundStyle(p.once ? Theme.coin : Color(hex: "#7FD8FF"))
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                Text(T("宝石 {0}", p.gems) + (p.bag > 0 ? T(" · 背包 +{0} 格", p.bag) : "") + (p.energy > 0 ? T(" · 体力 +{0}", p.energy) : ""))
                    .font(.system(size: 12)).foregroundStyle(Theme.text2)
                if let b = p.bonus { Text(b).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.coin) }
            }
            Spacer()
            Button { Task { await iap.buy(p) } } label: {
                Group {
                    if iap.busy == p.id { ProgressView().tint(.black) }
                    else { Text(iap.products[p.id]?.displayPrice ?? (MKDemo.on ? p.usd : "—")).font(.system(size: 14, weight: .bold)) }
                }
                .frame(minWidth: 72, minHeight: 36)
                .background(Theme.accent, in: Capsule()).foregroundStyle(.black)
            }
            .buttonStyle(.press)
            .disabled(iap.busy != nil || iap.products[p.id] == nil)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(p.once ? Theme.coin.opacity(0.5) : .clear, lineWidth: 1.5))
    }
}

/// 体力用完时的小卡（2026-10-22）：先给不花钱的路，再给宝石；新手礼包只在没买过时提一句。语气是陪着，不是催
struct MKEnergyCard: View {
    @ObservedObject var store: MKStore
    let openGems: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let full = Int(ceil(Double(MK.maxEnergy - store.s.energy) * MK.regenSeconds / 60))
        let starter = IAP.packs.first { $0.once }
        VStack(spacing: 12) {
            DressedPetView(pet: "purple", pose: .stand, frame: "yawn", accessories: []).frame(width: 96, height: 96)
            Text(T("体力用完了")).font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.text)
            Text(T("它也累了，正好一起歇会儿。")).font(.system(size: 13)).foregroundStyle(Theme.text2)
            VStack(alignment: .leading, spacing: 8) {
                row("clock", T("每 2 分钟回 1 点，大约 {0} 分钟回满", full))
                row("figure.walk", T("出去走走：每 1000 步 +10 体力"))
                row("arrow.triangle.merge", T("合成、交单、做菜不花体力，台面上的还能接着弄"))
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
            if store.s.gems >= store.energyCost {
                Button { store.buyEnergy(); dismiss() } label: {
                    Text(T("用 {0} 宝石买 50 体力", store.energyCost)).font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 46).background(Theme.accent, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black)
                }.buttonStyle(.press)
            } else {
                Button(action: openGems) {
                    Text(T("宝石不够了，看看宝石")).font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 46).background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Theme.text)
                }.buttonStyle(.press)
            }
            if let p = starter, !IAP.shared.boughtOnce(p) {
                Button(action: openGems) {
                    Text(T("新手礼包：宝石 200 + 体力 100 + 背包 5 格，只能买一次")).font(.system(size: 12)).foregroundStyle(Theme.coin)
                }.buttonStyle(.press)
            }
            Button(T("歇会儿")) { dismiss() }.font(.system(size: 14)).foregroundStyle(Theme.text3).padding(.top, 2)
        }
        .padding(20)
        .background(Theme.ground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Theme.accent).frame(width: 20)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.text)
        }
    }
}

/// 请玩家打分（2026-10-22）：在开心的时候问（装修完一章、小游戏赢了），装了 2 天以后才问，两次之间至少隔 60 天。
/// 苹果自己还会限制：一年最多弹 3 次
enum ReviewAsk {
    @MainActor static func happyMoment() {
        guard !MKDemo.on, !Shot.on else { return }
        let d = UserDefaults.standard
        if d.object(forKey: "review.firstOpen") == nil { d.set(Date(), forKey: "review.firstOpen"); return }
        guard let first = d.object(forKey: "review.firstOpen") as? Date, Date().timeIntervalSince(first) > 2 * 86400 else { return }
        if let last = d.object(forKey: "review.lastAsk") as? Date, Date().timeIntervalSince(last) < 60 * 86400 { return }
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        d.set(Date(), forKey: "review.lastAsk")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { AppStore.requestReview(in: scene) }
        Analytics.log("review_ask", [:])
    }
}
