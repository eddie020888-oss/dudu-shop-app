import Foundation

/// 中英双语（2026-10-19）：代码里的中文都包成 T("…")。手机系统语言是中文就原样显示，其余语言查 en.json。
/// 插值写成 {0} {1}：T("第 {0} 章", k)。en.json 由 scripts/l10n 生成，键就是中文原文。
enum L10n {
    static let isEN: Bool = !(Locale.preferredLanguages.first ?? "zh").hasPrefix("zh")
    static let en: [String: String] = {
        guard isEN, let u = Bundle.main.url(forResource: "en", withExtension: "json"),
              let d = try? Data(contentsOf: u),
              let m = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return m
    }()
}

func T(_ s: String, _ args: Any...) -> String {
    var out = L10n.isEN ? (L10n.en[s] ?? s) : s
    for (i, a) in args.enumerated() { out = out.replacingOccurrences(of: "{\(i)}", with: "\(a)") }
    return out
}
