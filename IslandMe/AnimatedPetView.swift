import SwiftUI
import CoreMotion

/// App 内的“活”角色：在静态帧上叠程序动画（呼吸、摇摆、眨眼、颠簸、Q 弹、视差、影子）。
/// 岛台里 iOS 不允许连续动画，所以只在 App 页面用。
struct AnimatedPetView: View {
    var pet: String
    var pose: Pose
    var frame: String = ""          // 需求/表情覆盖帧
    var accessories: [String] = []
    var size: CGFloat = 210

    @State private var blink = false
    @State private var poseKick: CGFloat = 0          // 换动作时的 Q 弹量 0→1→0
    @State private var tapKick: CGFloat = 0
    @State private var lastPose: Pose? = nil
    @StateObject private var tilt = TiltReader()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let m = motion(t)
            ZStack {
                // 影子：随起伏缩放
                Ellipse()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: size * 0.62 * (1 - m.lift / 60), height: size * 0.09)
                    .blur(radius: 6)
                    .offset(y: size * 0.47)
                DressedPetView(pet: pet, pose: pose, frame: blink && frame.isEmpty ? "blink" : frame, accessories: accessories)
                    .frame(width: size, height: size)
                    .scaleEffect(x: m.sx * (1 + 0.12 * poseKick + 0.08 * tapKick),
                                 y: m.sy * (1 - 0.10 * poseKick - 0.06 * tapKick), anchor: .bottom)
                    .rotationEffect(.degrees(m.rot + tilt.roll * 2), anchor: .bottom)
                    .offset(x: m.dx + tilt.roll * 3, y: -m.lift + tilt.pitch * 2)
                if pose == .sleep && frame.isEmpty { Zzz(t: t).offset(x: size * 0.28, y: -size * 0.35) }
            }
        }
        .onAppear { tilt.start(); scheduleBlink() }
        .onDisappear { tilt.stop() }
        .onChange(of: pose) { _, _ in kick() }
        .onChange(of: frame) { _, _ in kick() }
        // 不吞掉外层 Button 的点击（点舞台进聊天），只顺带抖一下
        .simultaneousGesture(TapGesture().onEnded {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) { tapKick = 1 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.4).delay(0.12)) { tapKick = 0 }
        })
    }

    private func kick() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.4)) { poseKick = 1 }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.45).delay(0.1)) { poseKick = 0 }
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2.5...5.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            blink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { blink = false; scheduleBlink() }
        }
    }

    struct Motion { var sx: CGFloat = 1, sy: CGFloat = 1, rot: Double = 0, dx: CGFloat = 0, lift: CGFloat = 0 }

    /// 按动作生成当前时刻的形变
    private func motion(_ t: Double) -> Motion {
        var m = Motion()
        let s = { (hz: Double) in sin(t * 2 * .pi * hz) }
        switch frame.isEmpty ? pose : .stand {
        case .walk:
            m.lift = CGFloat(abs(s(1.8))) * 6; m.rot = s(0.9) * 4; m.sy = 1 + CGFloat(s(1.8)) * 0.02
        case .run:
            m.lift = CGFloat(abs(s(3.2))) * 10; m.rot = s(1.6) * 6; m.dx = CGFloat(s(3.2)) * 2; m.sy = 1 + CGFloat(s(3.2)) * 0.03
        case .sleep:
            m.sy = 1 + CGFloat(s(0.25)) * 0.02; m.sx = 1 - CGFloat(s(0.25)) * 0.01
        case .eat, .coffee:
            m.sy = 1 + CGFloat(s(1.4)) * 0.025; m.rot = s(0.7) * 1
        case .gym:
            m.lift = CGFloat(max(0, s(0.8))) * 5; m.sy = 1 + CGFloat(s(0.8)) * 0.03
        case .wash:
            m.rot = s(2.2) * 2; m.sy = 1 + CGFloat(s(0.4)) * 0.015
        case .work, .read, .phone, .movie:
            m.sy = 1 + CGFloat(s(0.4)) * 0.02; m.rot = s(0.08) * 2 + (t.truncatingRemainder(dividingBy: 7) < 0.6 ? s(3) * 1.5 : 0)
        default:
            m.sy = 1 + CGFloat(s(0.42)) * 0.03; m.sx = 1 - CGFloat(s(0.42)) * 0.012; m.rot = s(0.21) * 1.2
        }
        if !frame.isEmpty {   // 表情/需求帧：小幅弹跳，显得有情绪
            m.lift += CGFloat(abs(s(1.2))) * 3
        }
        return m
    }

    /// 睡觉时飘起来的 Z
    struct Zzz: View {
        var t: Double
        var body: some View {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p = ((t / 2.4) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Text("z").font(.system(size: 14 + CGFloat(p) * 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent.opacity(1 - p))
                        .offset(x: CGFloat(sin(p * .pi * 2)) * 8, y: -CGFloat(p) * 50)
                }
            }
        }
    }
}

/// 读手机倾斜，做视差
final class TiltReader: ObservableObject {
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    private let mm = CMMotionManager()
    private var lastShake = Date.distantPast
    func start() {
        guard mm.isDeviceMotionAvailable else { return }
        mm.deviceMotionUpdateInterval = 1 / 30
        mm.startDeviceMotionUpdates(to: .main) { [weak self] d, _ in
            guard let self, let d else { return }
            let a = d.userAcceleration
            if a.x * a.x + a.y * a.y + a.z * a.z > 5.0, Date().timeIntervalSince(self.lastShake) > 3 {
                self.lastShake = Date(); NotificationCenter.default.post(name: .deviceShaken, object: nil)
            }
            let r = max(-1, min(1, d.attitude.roll)), p = max(-1, min(1, d.attitude.pitch - 0.6))
            self.roll = self.roll * 0.85 + r * 0.15
            self.pitch = self.pitch * 0.85 + p * 0.15
        }
    }
    func stop() { mm.stopDeviceMotionUpdates() }
}
