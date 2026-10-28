import SwiftUI

// 剪影人物：纯矢量绘制，App 预览和 Widget 共用。
// 坐标系：以 100 单位为标准身高，底部居中，通过 GeometryReader 缩放。
struct SilhouetteView: View {
    var pose: Pose
    var character: Character

    var body: some View {
        Canvas { ctx, size in
            let hgt = character.heightCM / 175
            let unit = size.height / 112
            let fg = Color(hex: character.figureHex)
            ctx.translateBy(x: size.width / 2, y: size.height * 0.88)
            ctx.scaleBy(x: unit, y: unit)

            switch pose {
            case .sleep:
                drawSleep(&ctx, fg: fg)
            case .work, .movie, .eat:
                drawSeated(&ctx, fg: fg, hgt: hgt)
            default:
                drawStanding(&ctx, fg: fg, hgt: hgt)
            }
        }
        .background(Color(hex: character.backgroundHex))
    }

    // MARK: 参数

    private var fem: Bool { character.gender == .female }
    private var bw: Double { 0.75 + character.build * 0.7 }
    private var shW: Double { 9 * bw * (0.8 + character.shoulder * 0.5) * (fem ? 0.88 : 1.08) }
    private var hipW: Double { 6 * bw * (fem ? 1.15 : 1) }

    // MARK: 站姿系列（stand / walk / run / phone）

    private func drawStanding(_ ctx: inout GraphicsContext, fg: Color, hgt: Double) {
        let legL = 46 * hgt, torso = 34 * hgt, head = 11.0
        let top = -legL - torso
        let stroke = StrokeStyle(lineWidth: 5 * bw * (fem ? 0.9 : 1), lineCap: .round, lineJoin: .round)

        // 腿：walk / run 用固定的迈步姿态（Live Activity 不能逐帧动画）
        let swing: Double = pose == .walk ? 0.45 : pose == .run ? 0.85 : 0
        for side in [1.0, -1.0] {
            let ang = swing * side
            let half = legL * 0.5
            let knee = ang < 0 ? -ang * 0.9 : 0
            let k = CGPoint(x: sin(ang) * half, y: -legL + cos(ang) * half)
            let f = CGPoint(x: k.x + sin(ang - knee) * half, y: k.y + cos(ang - knee) * half)
            var p = Path(); p.move(to: CGPoint(x: 0, y: -legL)); p.addLine(to: k); p.addLine(to: f)
            ctx.stroke(p, with: .color(fg), style: stroke)
        }

        // 躯干
        var body = Path()
        body.move(to: CGPoint(x: -hipW, y: -legL))
        body.addLine(to: CGPoint(x: hipW, y: -legL))
        body.addLine(to: CGPoint(x: shW, y: top + 4))
        body.addQuadCurve(to: CGPoint(x: -shW, y: top + 4), control: CGPoint(x: 0, y: top - 2))
        body.closeSubpath()
        ctx.fill(body, with: .color(fg))

        // 手臂
        let armStroke = StrokeStyle(lineWidth: 3.6 * bw, lineCap: .round, lineJoin: .round)
        let sy = top + 6
        if pose == .phone {
            var l = Path(); l.move(to: CGPoint(x: -shW + 1, y: sy)); l.addLine(to: CGPoint(x: -shW - 4, y: sy + 14)); l.addLine(to: CGPoint(x: 0, y: sy + 2))
            var r = Path(); r.move(to: CGPoint(x: shW - 1, y: sy)); r.addLine(to: CGPoint(x: shW + 3, y: sy + 14)); r.addLine(to: CGPoint(x: 2, y: sy + 2))
            ctx.stroke(l, with: .color(fg), style: armStroke)
            ctx.stroke(r, with: .color(fg), style: armStroke)
            ctx.fill(Path(CGRect(x: -4, y: sy - 5, width: 8, height: 12)), with: .color(fg))
        } else {
            let armSwing: Double = pose == .walk ? 0.4 : pose == .run ? 0.8 : 0.05
            let bend: Double = pose == .run ? 0.9 : 0.1
            for (side, ang) in [(-1.0, armSwing), (1.0, -armSwing)] {
                let ex = -sin(ang) * 22 * hgt * side, ey = 22 * hgt * cos(ang)
                let s = CGPoint(x: side * (shW - 1), y: sy)
                var p = Path(); p.move(to: s)
                p.addLine(to: CGPoint(x: s.x + ex * 0.55, y: s.y + ey * 0.55 * (1 - bend * 0.3)))
                p.addLine(to: CGPoint(x: s.x + ex * (1 - bend * 0.6) + (pose == .run ? -6 * side : 0), y: s.y + ey * (1 - bend * 0.7)))
                ctx.stroke(p, with: .color(fg), style: armStroke)
            }
        }
        drawHead(&ctx, fg: fg, at: CGPoint(x: 0, y: top - head + 2), r: head, tilt: pose == .phone ? 0.35 : 0)
    }

    // MARK: 坐姿系列（work / movie / eat）

    private func drawSeated(_ ctx: inout GraphicsContext, fg: Color, hgt: Double) {
        let legStroke = StrokeStyle(lineWidth: 5 * bw, lineCap: .round, lineJoin: .round)
        var legA = Path(); legA.move(to: CGPoint(x: 0, y: -30 * hgt)); legA.addLine(to: CGPoint(x: 18 * hgt, y: -30 * hgt)); legA.addLine(to: CGPoint(x: 18 * hgt, y: 0))
        var legB = Path(); legB.move(to: CGPoint(x: -1, y: -29 * hgt)); legB.addLine(to: CGPoint(x: 15 * hgt, y: -28 * hgt)); legB.addLine(to: CGPoint(x: 15 * hgt, y: 0))
        ctx.stroke(legA, with: .color(fg), style: legStroke)
        ctx.stroke(legB, with: .color(fg), style: legStroke)

        let lean: Double = pose == .movie ? -0.15 : pose == .work ? 0.2 : 0.08
        var c = ctx
        c.translateBy(x: 0, y: -30 * hgt)
        c.rotate(by: .radians(lean))
        let torso = 34 * hgt
        var body = Path()
        body.move(to: CGPoint(x: -6 * bw, y: 0)); body.addLine(to: CGPoint(x: 6 * bw, y: 0))
        body.addLine(to: CGPoint(x: shW, y: -torso + 4))
        body.addQuadCurve(to: CGPoint(x: -shW, y: -torso + 4), control: CGPoint(x: 0, y: -torso - 2))
        body.closeSubpath()
        c.fill(body, with: .color(fg))

        let sy = -torso + 6
        let armStroke = StrokeStyle(lineWidth: 3.6 * bw, lineCap: .round, lineJoin: .round)
        let arms: [[CGPoint]]
        switch pose {
        case .work:
            arms = [[CGPoint(x: shW - 1, y: sy), CGPoint(x: shW + 8, y: sy + 14), CGPoint(x: shW + 18, y: sy + 12)],
                    [CGPoint(x: -shW + 1, y: sy), CGPoint(x: shW + 2, y: sy + 16), CGPoint(x: shW + 16, y: sy + 13)]]
        case .eat:
            arms = [[CGPoint(x: shW - 1, y: sy), CGPoint(x: shW + 8, y: sy + 14), CGPoint(x: shW + 6, y: sy + 2)],
                    [CGPoint(x: -shW + 1, y: sy), CGPoint(x: shW, y: sy + 16), CGPoint(x: shW + 14, y: sy + 15)]]
        default:
            arms = [[CGPoint(x: shW - 1, y: sy), CGPoint(x: shW + 2, y: sy + 18), CGPoint(x: shW + 12, y: sy + 22)],
                    [CGPoint(x: -shW + 1, y: sy), CGPoint(x: -shW + 2, y: sy + 18), CGPoint(x: shW + 8, y: sy + 24)]]
        }
        for pts in arms {
            var p = Path(); p.move(to: pts[0]); p.addLine(to: pts[1]); p.addLine(to: pts[2])
            c.stroke(p, with: .color(fg), style: armStroke)
        }
        drawHead(&c, fg: fg, at: CGPoint(x: 0, y: -torso - 11 + 2), r: 11, tilt: pose == .work ? 0.15 : pose == .movie ? -0.05 : 0.1)

        // 道具
        switch pose {
        case .work:
            ctx.fill(Path(CGRect(x: 22 * hgt, y: -54 * hgt, width: 2, height: 24 * hgt)), with: .color(fg.opacity(0.9)))
            var screen = Path(); screen.move(to: CGPoint(x: 24 * hgt, y: -58 * hgt)); screen.addLine(to: CGPoint(x: 42 * hgt, y: -62 * hgt)); screen.addLine(to: CGPoint(x: 42 * hgt, y: -30 * hgt)); screen.addLine(to: CGPoint(x: 24 * hgt, y: -30 * hgt)); screen.closeSubpath()
            ctx.fill(screen, with: .color(fg.opacity(0.25)))
        case .movie:
            ctx.fill(Path(CGRect(x: 28 * hgt, y: -80 * hgt, width: 40, height: 34)), with: .color(fg.opacity(0.2)))
            ctx.fill(Path(CGRect(x: 30 * hgt, y: -78 * hgt, width: 36, height: 30)), with: .color(fg.opacity(0.6)))
        case .eat:
            ctx.fill(Path(ellipseIn: CGRect(x: 20 * hgt - 9, y: -42 * hgt - 2.5, width: 18, height: 5)), with: .color(fg.opacity(0.6)))
        default: break
        }
    }

    // MARK: 睡觉

    private func drawSleep(_ ctx: inout GraphicsContext, fg: Color) {
        var c = ctx
        c.translateBy(x: -30, y: -8)
        var body = Path(); body.move(to: CGPoint(x: 12, y: 0)); body.addLine(to: CGPoint(x: 30, y: 0)); body.addLine(to: CGPoint(x: 50, y: 2))
        c.stroke(body, with: .color(fg), style: StrokeStyle(lineWidth: 7 * bw, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: 0, y: -4 - 6 * bw, width: 32, height: 12 * bw)), with: .color(fg))
        var h = c
        h.translateBy(x: -4, y: -6)
        h.rotate(by: .radians(-Double.pi / 2 + 0.4))
        drawHead(&h, fg: fg, at: .zero, r: 10, tilt: 0)
        for i in 0..<3 {
            let t = Text("z").font(.system(size: 8, weight: .bold)).foregroundColor(fg.opacity(0.6 - Double(i) * 0.15))
            c.draw(t, at: CGPoint(x: Double(i) * 6, y: -22 - Double(i) * 7))
        }
    }

    // MARK: 头部（鼻梁 / 下颚 / 发量）

    private func drawHead(_ ctx: inout GraphicsContext, fg: Color, at p: CGPoint, r: Double, tilt: Double) {
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(tilt))
        let nose = character.nose, jaw = character.jaw, hair = character.hair

        c.fill(Path(CGRect(x: -2.6, y: r * 0.8, width: 5.2, height: 4)), with: .color(fg))
        c.fill(Path(ellipseIn: CGRect(x: -r * 0.95, y: -r, width: r * 1.9, height: r * 2)), with: .color(fg))

        var j = Path()
        j.move(to: CGPoint(x: -r * 0.9, y: r * 0.1))
        j.addLine(to: CGPoint(x: -r * (0.75 + jaw * 0.2), y: r * 0.85 + jaw * 0.1 * r))
        j.addLine(to: CGPoint(x: r * (0.45 + jaw * 0.35), y: r * 0.9 + jaw * 0.15 * r))
        j.addLine(to: CGPoint(x: r * 0.85, y: r * 0.2))
        j.closeSubpath()
        c.fill(j, with: .color(fg))

        var n = Path()
        n.move(to: CGPoint(x: r * 0.85, y: -r * 0.1))
        n.addLine(to: CGPoint(x: r * (0.95 + nose * 0.35), y: r * 0.25))
        n.addLine(to: CGPoint(x: r * 0.8, y: r * 0.4))
        n.closeSubpath()
        c.fill(n, with: .color(fg))

        var h = Path()
        if fem {
            h.move(to: CGPoint(x: -r * 1.05, y: -r * 0.2))
            h.addQuadCurve(to: CGPoint(x: -r * 0.6, y: r * (1.2 + hair * 1.4)), control: CGPoint(x: -r * 1.3, y: r * (0.6 + hair * 1.2)))
            h.addLine(to: CGPoint(x: r * 0.3, y: r * (1.0 + hair * 1.0)))
            h.addQuadCurve(to: CGPoint(x: 0, y: -r * 1.15), control: CGPoint(x: r * 1.1, y: -r * 0.6))
            h.addQuadCurve(to: CGPoint(x: -r * 1.05, y: -r * 0.2), control: CGPoint(x: -r * 1.1, y: -r * 0.9))
        } else {
            h.move(to: CGPoint(x: -r * 0.95, y: -r * 0.05))
            h.addQuadCurve(to: CGPoint(x: -r * 0.1, y: -r * (1.1 + hair * 0.6)), control: CGPoint(x: -r * 1.05, y: -r * (1.05 + hair * 0.5)))
            h.addQuadCurve(to: CGPoint(x: r * 0.95, y: -r * 0.3), control: CGPoint(x: r * 0.9, y: -r * (1.1 + hair * 0.45)))
            h.addQuadCurve(to: CGPoint(x: 0, y: -r * 0.75), control: CGPoint(x: r * 0.6, y: -r * 0.75))
            h.addQuadCurve(to: CGPoint(x: -r * 0.95, y: -r * 0.05), control: CGPoint(x: -r * 0.6, y: -r * 0.75))
        }
        h.closeSubpath()
        c.fill(h, with: .color(fg))
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
