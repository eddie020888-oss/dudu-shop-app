import SwiftUI
import AVFoundation
import AVKit

/// 首页舞台：有视频片段的动作播 Kling 出的循环视频（真动），没有的回退到程序动画。
/// 视频全部静音；换动作时交叉淡入淡出；需求/表情覆盖帧仍用静态图。
struct VideoPetView: View {
    var pet: String
    var pose: Pose
    var frame: String = ""
    var accessories: [String] = []
    var size: CGFloat = 210
    /// 不属于任何动作的专门片段（"happy" 开心晃、"shell" 窝在蛋壳里），优先于 pose/frame
    var clip: String? = nil
    /// 小头像框里用：躺在蛋壳里的片段蛋壳比人宽，放大 1.25 倍会被框切掉、看着歪；这种片段按原大小整个放进框里
    var fitShell: Bool = false

    @State private var tapKick: CGFloat = 0
    @StateObject private var tilt = TiltReader()

    /// 有专门视频的表情帧：饿了趴着盯饭团、渴了抱空杯子
    static let frameClip: [String: String] = ["hungry": "x_want_eat", "thirsty": "x_want_drink"]

    static func clipURL(pet: String, pose: Pose, wearing: String? = nil) -> URL? {
        // 待机时戴着配饰：播它真戴着的那条视频（可灵按每件配饰单独出的）
        if pose == .stand, let w = wearing, let u = Bundle.main.url(forResource: "\(pet)_wear_\(w)", withExtension: "mp4") { return u }
        let name = pose == .stand ? "idle" : pose.rawValue
        if let u = Bundle.main.url(forResource: "\(pet)_\(name)", withExtension: "mp4") { return u }
        // 还没出专门视频的动作先借用相近的：打字→工作
        let fallback: [Pose: String] = [.type: "work", .call: "phone", .music: "idle", .charge: "sleep",
                                        .study: "read", .ball: "run", .paint: "work", .uke: "idle"]
        if let f = fallback[pose] { return Bundle.main.url(forResource: "\(pet)_\(f)", withExtension: "mp4") }
        return nil
    }

    /// 戴着、但没有专门视频的那件配饰
    private var overlayAccessory: String? {
        guard clip == nil, frame.isEmpty, pose == .stand, let w = Accessory.worn(accessories),
              Bundle.main.url(forResource: "\(pet)_wear_\(w)", withExtension: "mp4") == nil else { return nil }
        return w
    }

    private func zoom(_ url: URL) -> CGFloat {
        fitShell && url.lastPathComponent.contains("shell") ? 1.0 : 1.25
    }

    var body: some View {
        if let url = clip.flatMap({ Bundle.main.url(forResource: "\(pet)_\($0)", withExtension: "mp4") })
            ?? Self.frameClip[frame].flatMap({ Bundle.main.url(forResource: "\(pet)_\($0)", withExtension: "mp4") })
            ?? (frame.isEmpty ? Self.clipURL(pet: pet, pose: pose, wearing: clip == nil ? Accessory.worn(accessories) : nil) : nil) {
            ZStack {
                ZStack {
                    LoopingVideoView(url: url)
                        .scaleEffect(url.lastPathComponent.hasPrefix("\(pet)_wear_") && Accessory.baked(Accessory.worn(accessories)) ? 1 / Accessory.bakedScale : 1,
                                     anchor: Accessory.feet)
                        .id(url)                                        // 换动作 → 新播放器，淡入淡出
                        .transition(.opacity.animation(.easeInOut(duration: 0.35)))
                    // 新配饰还没有「真戴着」的视频：在待机视频上贴图（位置按待机视频量的）
                    if let a = overlayAccessory, url.lastPathComponent == "\(pet)_idle.mp4" {
                        AccessoryLayer(ids: [a], mode: .video).transition(.opacity)
                    }
                }
                    .frame(width: size * zoom(url), height: size * zoom(url))     // 视频里角色占画面约八成，放大一点和静态帧同大
                    .scaleEffect(x: 1 + 0.08 * tapKick, y: 1 - 0.06 * tapKick, anchor: .bottom)
                    .rotationEffect(.degrees(tilt.roll * 2), anchor: .bottom)
                    .offset(x: tilt.roll * 3, y: tilt.pitch * 2)
            }
            .frame(width: size, height: size)
            .animation(.easeInOut(duration: 0.35), value: pose)
            .onAppear { tilt.start() }
            .onDisappear { tilt.stop() }
            .simultaneousGesture(TapGesture().onEnded {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) { tapKick = 1 }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.4).delay(0.12)) { tapKick = 0 }
            })
        } else {
            // 静态表情帧和视频里的角色一样大（量过：视频里身高 ≈ 静态帧 1.3 倍、脚底低 0.094 个 size），换来换去不会忽大忽小
            AnimatedPetView(pet: pet, pose: pose, frame: frame, accessories: accessories, size: size)
                .scaleEffect(1.297, anchor: .bottom)
                .offset(y: size * 0.094)
        }
    }
}

/// 静音、无限循环、黑底的播放器
struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.load(url)
        return v
    }
    func updateUIView(_ v: PlayerView, context: Context) {
        if v.url != url { v.load(url) }
    }
    static func dismantleUIView(_ v: PlayerView, coordinator: ()) { v.stop() }

    final class PlayerView: UIView {
        private(set) var url: URL?
        private var queue = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var fgObserver: Any?

        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            playerLayer.videoGravity = .resizeAspect
            playerLayer.backgroundColor = UIColor.black.cgColor
            queue.isMuted = true
            queue.preventsDisplaySleepDuringVideoPlayback = false
            queue.actionAtItemEnd = .none
            MKSfx.session()   // 和小店音效共用一套设置（视频本身是静音的）
            playerLayer.player = queue
            fgObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.queue.play()
            }
        }
        required init?(coder: NSCoder) { fatalError() }

        func load(_ url: URL) {
            self.url = url
            let item = AVPlayerItem(url: url)
            looper?.disableLooping(); looper = nil
            queue.removeAllItems()
            if url.lastPathComponent.contains("_eat_") || url.lastPathComponent.contains("_shopx_") {
                // 吃喝动画只播一遍，播完停在最后一帧（吃完的样子），不从头再来
                queue.insert(item, after: nil)
            } else {
                looper = AVPlayerLooper(player: queue, templateItem: item)
            }
            queue.play()
        }
        func stop() {
            queue.pause()
            looper?.disableLooping()
            looper = nil
            if let o = fgObserver { NotificationCenter.default.removeObserver(o) }
        }
    }
}
