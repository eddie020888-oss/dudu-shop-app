import SwiftUI

/// 把配饰画在角色帧上。坐标按新小紫（v4）idle 帧量的：头顶≈0.24、眼睛≈0.41、嘴下≈0.55。
struct AccessoryOverlay: View {
    var ids: [String]
    var peek = false     // 探头帧：头更大、更靠下，脖子以下不可见

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            if peek {
                // 探头帧 = 从蛋壳沿露出脑袋、小手扒着壳沿（324×283，按高放进 44×36 的耳朵）
                // 量过：全身帧卷毛顶 0.111、头中线 0.469；探头帧头中线 0.555 → x 放大 1.039、y 放大 1.271
                ctx.translateBy(x: w * 0.555, y: 0)
                ctx.scaleBy(x: 1.039, y: 1.271)
                ctx.translateBy(x: -w * 0.469, y: -h * 0.111)
            }
            // 新小紫（v4）比旧图头顶低：头顶（不含卷毛）≈0.24，眼睛≈0.41，嘴下≈0.55
            let hatDY = h * 0.065, eyeDY = h * 0.045, neckDY = -h * 0.01
            for id in ids {
                if peek, Accessory.by(id)?.slot == "neck" { continue }
                switch id {
                case "hat_straw":
                    ctx.translateBy(x: 0, y: hatDY); defer { ctx.translateBy(x: 0, y: -hatDY) }
                    let brim = CGRect(x: w * 0.22, y: h * 0.17, width: w * 0.56, height: h * 0.07)
                    ctx.fill(Path(ellipseIn: brim), with: .color(Color(hex: "#E8C56A")))
                    let dome = CGRect(x: w * 0.33, y: h * 0.08, width: w * 0.34, height: h * 0.14)
                    ctx.fill(Path(roundedRect: dome, cornerRadius: w * 0.1), with: .color(Color(hex: "#F2D27E")))
                    ctx.fill(Path(CGRect(x: w * 0.33, y: h * 0.165, width: w * 0.34, height: h * 0.025)), with: .color(Color(hex: "#C0392B")))
                case "hat_party":
                    ctx.translateBy(x: 0, y: hatDY); defer { ctx.translateBy(x: 0, y: -hatDY) }
                    var p = Path(); p.move(to: CGPoint(x: w * 0.5, y: h * 0.02))
                    p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.22)); p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.22)); p.closeSubpath()
                    ctx.fill(p, with: .color(Color(hex: "#6C8CFF")))
                    ctx.fill(Path(ellipseIn: CGRect(x: w * 0.47, y: 0, width: w * 0.06, height: w * 0.06)), with: .color(Color(hex: "#FFD166")))
                case "hat_beanie":
                    ctx.translateBy(x: 0, y: hatDY); defer { ctx.translateBy(x: 0, y: -hatDY) }
                    let cap = CGRect(x: w * 0.3, y: h * 0.06, width: w * 0.4, height: h * 0.16)
                    ctx.fill(Path(roundedRect: cap, cornerRadius: w * 0.12), with: .color(Color(hex: "#E76F51")))
                    ctx.fill(Path(roundedRect: CGRect(x: w * 0.3, y: h * 0.18, width: w * 0.4, height: h * 0.045), cornerRadius: 4), with: .color(Color(hex: "#F4A261")))
                    ctx.fill(Path(ellipseIn: CGRect(x: w * 0.46, y: h * 0.03, width: w * 0.08, height: w * 0.08)), with: .color(Color(hex: "#F4A261")))
                case "glasses_sun", "glasses_round":
                    let dark = id == "glasses_sun"
                    let r = w * 0.085, y = h * 0.37 + eyeDY
                    for cx in [w * 0.405, w * 0.595] {
                        let rect = CGRect(x: cx - r, y: y - r, width: r * 2, height: r * 2)
                        if dark { ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: "#1B1B22").opacity(0.92))) }
                        ctx.stroke(Path(ellipseIn: rect), with: .color(dark ? Color(hex: "#2D2D36") : Color(hex: "#3B2F2F")), lineWidth: w * 0.014)
                    }
                    ctx.stroke(Path { p in p.move(to: CGPoint(x: w * 0.49, y: y)); p.addLine(to: CGPoint(x: w * 0.51, y: y)) },
                               with: .color(Color(hex: "#3B2F2F")), lineWidth: w * 0.014)
                case "bow_red":
                    let cy = h * 0.60 + neckDY, cx = w * 0.5, s = w * 0.07
                    var p = Path()
                    p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: CGPoint(x: cx - s * 1.6, y: cy - s)); p.addLine(to: CGPoint(x: cx - s * 1.6, y: cy + s)); p.closeSubpath()
                    p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: CGPoint(x: cx + s * 1.6, y: cy - s)); p.addLine(to: CGPoint(x: cx + s * 1.6, y: cy + s)); p.closeSubpath()
                    ctx.fill(p, with: .color(Color(hex: "#E63946")))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - s * 0.45, y: cy - s * 0.45, width: s * 0.9, height: s * 0.9)), with: .color(Color(hex: "#B5172B")))
                case "scarf_blue":
                    let band = CGRect(x: w * 0.32, y: h * 0.56 + neckDY, width: w * 0.36, height: h * 0.07)
                    ctx.fill(Path(roundedRect: band, cornerRadius: h * 0.035), with: .color(Color(hex: "#4C8DFF")))
                    ctx.fill(Path(roundedRect: CGRect(x: w * 0.44, y: h * 0.60 + neckDY, width: w * 0.09, height: h * 0.14), cornerRadius: 4), with: .color(Color(hex: "#3A6FD8")))
                default: break
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 角色 + 配饰 一起画
struct DressedPetView: View {
    var pet: String
    var pose: Pose
    var frame: String = ""
    var tick: Int = 0
    var accessories: [String]

    var body: some View {
        // 有它真戴着的图就直接用（探头图 / 待机图），不再往上贴
        if let w = Accessory.worn(accessories), let f = wornFrame(w) {
            PetView(pet: pet, pose: pose, frame: f, tick: tick)
                .scaleEffect(Accessory.baked(w) && !f.hasPrefix("peek") ? 1 / Accessory.bakedScale : 1, anchor: Accessory.feet)
        } else {
            plain
        }
    }

    /// 灵动岛探头：它在做别的事（走路、听歌、打电话……）时用那个动作的探头图，不戴配饰，让人一眼看出它在干嘛
    private var actionPeek: Bool {
        frame == "peek" && pose != .stand && UIImage(named: "\(pet)_peek_\(pose.rawValue)") != nil
    }

    private func wornFrame(_ w: String) -> String? {
        if actionPeek { return nil }
        let f: String
        if frame == "peek" { f = "peekwear_\(w)" }
        else if (frame.isEmpty && pose == .stand) || frame == "idle" || frame == "blink" { f = "wear_\(w)" }
        else { return nil }
        return UIImage(named: "\(pet)_\(f)") != nil ? f : nil
    }

    private var plain: some View {
        ZStack {
            PetView(pet: pet, pose: pose, frame: frame, tick: tick)
            if !accessories.isEmpty {
                if frame == "peek" && !actionPeek {
                    AccessoryLayer(ids: accessories, mode: .peek)
                } else if (frame.isEmpty && pose == .stand) || frame == "idle" || frame == "blink" {
                    AccessoryLayer(ids: accessories, mode: .still)
                }
            }
        }
    }
}

/// 配饰图片层（可灵出的 3D 配饰，抠底）。按画面类型分三套位置，都是量出来的：
/// - video：待机视频（正脸，512 画面里）
/// - still：待机静帧（324 画布，3/4 侧脸）
/// - peek：灵动岛探头图（44×36 耳朵，蛋壳沿上露脑袋）
/// 其他动作/表情帧头的位置都不一样，戴了会飘，所以不画。
struct AccessoryLayer: View {
    enum Mode { case video, still, peek }
    var ids: [String]
    var mode: Mode

    /// (中心 x, y, 宽度, y 对齐物件的 0=上沿 0.5=中间 1=下沿)，都相对画面宽/高
    private static let spots: [Mode: [String: (CGFloat, CGFloat, CGFloat, CGFloat)]] = [
        .video: ["hat_straw": (0.50, 0.235, 0.56, 1), "hat_party": (0.50, 0.205, 0.24, 1), "hat_beanie": (0.50, 0.29, 0.50, 1),
                 "glasses_round": (0.50, 0.36, 0.42, 0.5), "glasses_sun": (0.50, 0.36, 0.42, 0.5),
                 "bow_red": (0.50, 0.49, 0.18, 0.5), "scarf_blue": (0.50, 0.44, 0.56, 0)],
        .still: ["hat_straw": (0.47, 0.36, 0.55, 1), "hat_party": (0.47, 0.33, 0.26, 1), "hat_beanie": (0.47, 0.37, 0.48, 1),
                 "glasses_round": (0.465, 0.425, 0.40, 0.5), "glasses_sun": (0.465, 0.425, 0.40, 0.5),
                 "bow_red": (0.47, 0.57, 0.18, 0.5), "scarf_blue": (0.47, 0.52, 0.60, 0)],
        .peek:  ["hat_straw": (0.53, 0.34, 0.50, 1), "hat_party": (0.53, 0.30, 0.22, 1), "hat_beanie": (0.53, 0.33, 0.44, 1),
                 "glasses_round": (0.54, 0.36, 0.36, 0.5), "glasses_sun": (0.54, 0.36, 0.36, 0.5)],
    ]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            // 先脖子、再眼睛、最后帽子
            ForEach(ids.sorted { Self.order($0) < Self.order($1) }, id: \.self) { id in
                if let s = Self.spots[mode]?[id], let ui = UIImage(named: "acc_" + id) {
                    let iw = w * s.2, ih = iw * ui.size.height / max(ui.size.width, 1)
                    Image(uiImage: ui).resizable()
                        .frame(width: iw, height: ih)
                        .position(x: w * s.0, y: h * s.1 - ih * (s.3 - 0.5))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func order(_ id: String) -> Int { id.hasPrefix("hat") ? 2 : (id.hasPrefix("glasses") ? 1 : 0) }
}
