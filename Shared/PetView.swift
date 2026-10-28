import SwiftUI

/// 宠物帧：从 Asset Catalog 读 "<pet>_<pose>" 图片，缺图时回退到 idle，再缺就显示占位。
/// Asset 命名示例：purple_idle, purple_walk, purple_run … 见 ASSET_SPEC.md
struct PetView: View {
    var pet: String        // 角色 id，如 "purple"
    var pose: Pose
    var frame: String = ""  // 临时覆盖帧（blink / yawn），空则按动作
    var tick: Int = 0       // 变化即播放一次弹跳过场

    private var imageName: String { "\(pet)_\(assetKey)" }
    /// Pose → 资产名；stand 用 idle 帧；frame 非空时优先
    private var assetKey: String { frame.isEmpty ? (pose == .stand ? "idle" : pose.rawValue) : frame }

    /// 探头帧按动作找：peek_<pose> → peek
    private var peekName: String? {
        guard frame == "peek" else { return nil }
        let specific = "\(pet)_peek_\(pose == .stand ? "idle" : pose.rawValue)"
        return UIImage(named: specific) != nil ? specific : nil
    }

    var body: some View {
        if let peekName {
            Image(peekName).resizable().scaledToFit()
                .id("\(peekName)-\(tick)")
                .transition(.scale(scale: 0.82).combined(with: .opacity))
        } else if UIImage(named: imageName) != nil {
            // id 变化 → 旧图退场、新图以缩放+淡入进场（Live Activity 允许的过场动画）
            Image(imageName).resizable().scaledToFit()
                .id("\(imageName)-\(tick)")
                .transition(.scale(scale: 0.82).combined(with: .opacity))
        } else if UIImage(named: "\(pet)_idle") != nil {
            Image("\(pet)_idle").resizable().scaledToFit()
        } else {
            // 占位：没有资产时画一个最简单的圆脸，方便跑通流程
            Placeholder(pose: pose)
        }
    }

    struct Placeholder: View {
        var pose: Pose
        var body: some View {
            Canvas { ctx, size in
                let r = min(size.width, size.height) * 0.45
                let c = CGPoint(x: size.width / 2, y: size.height * 0.58)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: "#B9A6E8")))
                let closed = pose == .sleep || pose == .eat
                for dx in [-0.35, 0.35] {
                    let e = CGPoint(x: c.x + r * dx, y: c.y - r * 0.15)
                    if closed {
                        ctx.stroke(Path { p in p.move(to: CGPoint(x: e.x - r * 0.15, y: e.y)); p.addLine(to: CGPoint(x: e.x + r * 0.15, y: e.y)) }, with: .color(.black), lineWidth: r * 0.08)
                    } else {
                        ctx.fill(Path(ellipseIn: CGRect(x: e.x - r * 0.14, y: e.y - r * 0.16, width: r * 0.28, height: r * 0.32)), with: .color(.black))
                    }
                }
                ctx.stroke(Path { p in p.addArc(center: CGPoint(x: c.x, y: c.y + r * 0.25), radius: r * 0.22, startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false) }, with: .color(.black), lineWidth: r * 0.07)
            }
        }
    }
}

/// 紧凑态右侧的小符号：与角色同一视觉语言，由 App 绘制而不是出图
struct PoseGlyph: View {
    var pose: Pose
    var body: some View {
        Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
    }
    var symbolName: String { symbol }
    private var symbol: String {
        switch pose {
        case .walk:  return "figure.walk"
        case .run:   return "wind"
        case .phone: return "ellipsis.bubble"
        case .work:  return "pencil"
        case .movie: return "popcorn"
        case .eat:   return "takeoutbag.and.cup.and.straw"
        case .sleep: return "zzz"
        case .stand: return "sparkle"
        case .wash:  return "drop.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .gym:   return "dumbbell.fill"
        case .read:  return "book.fill"
        case .wake:  return "sunrise.fill"
        case .drive: return "car.fill"
        case .music: return "headphones"
        case .dance: return "music.note"
        case .call:  return "phone.fill"
        case .charge: return "battery.100.bolt"
        case .type:  return "keyboard"
        case .study: return "backpack.fill"
        case .ball:  return "basketball.fill"
        case .paint: return "paintpalette.fill"
        case .uke:   return "guitars.fill"
        }
    }
}
