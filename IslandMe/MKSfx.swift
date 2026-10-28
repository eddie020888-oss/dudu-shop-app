import AVFoundation
import UIKit

/// 小店音效（scripts/sfx/make.py 用代码合成的，没有版权问题）
/// 跟随手机静音键（ambient），不打断用户在听的音乐；店里右上角和「我的」都能关
enum MKSfx {
    static var on: Bool {
        get { UserDefaults.standard.object(forKey: "mk.sfx") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "mk.sfx") }
    }
    /// 震动开关
    static var hapticsOn: Bool {
        get { UserDefaults.standard.object(forKey: "mk.haptics") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "mk.haptics") }
    }
    /// 手机开着静音键时店里也出声（默认开）。很多人手机常年静音，不开这个就会觉得「游戏没声音」。
    /// 不论开不开都和别的 App 的声音混着放（.mixWithOthers），不会打断用户在听的歌
    static var ignoreSilent: Bool {
        get { UserDefaults.standard.object(forKey: "mk.ignoreSilent") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "mk.ignoreSilent"); q.async { applied = nil }; session() }
    }
    /// 自测用：-noAudio 时完全不碰音频（对照模拟器卡死是不是音频引起的）
    static let muted = MKDemo.args.contains("-noAudio")
    private static var pools: [String: [AVAudioPlayer]] = [:]
    private static var applied: Bool? = nil
    /// 所有音频活都在这条串行队列上做，主线程只发个指令就走。
    /// 自测时发现：模拟器没声卡，prepareToPlay / setActive 会卡死调用它的线程——放在主线程上就是开场停在第一页、小店黑屏。
    /// 真机上也一样受益：第一次出声不会让画面顿一下
    static let q = DispatchQueue(label: "mk.audio", qos: .userInitiated)
    /// 统一设置音频会话（视频播放器也调这个，免得互相覆盖）
    static func session() {
        guard !muted else { return }
        let want = ignoreSilent
        q.async { applySession(want) }
    }
    /// 只在 q 上调
    static func applySession(_ want: Bool) {
        guard applied != want else { return }
        applied = want
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(want ? .playback : .ambient, options: [.mixWithOthers])
        try? s.setActive(true)
    }

    static func play(_ name: String, volume: Float = 0.7) {
        guard on, !Shot.on, !muted else { return }
        let want = ignoreSilent
        q.async {
            applySession(want)
            var pool = pools[name] ?? []
            if let p = pool.first(where: { !$0.isPlaying }) {
                p.volume = volume; p.currentTime = 0; p.play(); return
            }
            guard pool.count < 4, let u = Bundle.main.url(forResource: name, withExtension: "wav"),
                  let p = try? AVAudioPlayer(contentsOf: u) else { return }
            p.volume = volume
            p.prepareToPlay()
            p.play()
            pool.append(p)
            pools[name] = pool
        }
    }

    static func impact(_ st: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsOn else { return }
        UIImpactFeedbackGenerator(style: st).impactOccurred()
    }
    static func notify(_ t: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsOn else { return }
        UINotificationFeedbackGenerator().notificationOccurred(t)
    }
}

/// 小店背景音乐：进店淡入、离店淡出；别的 App 在放歌时不放（不抢）
enum MKMusic {
    static var on: Bool {
        get { UserDefaults.standard.object(forKey: "mk.music") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "mk.music"); newValue ? start() : stop() }
    }
    private static var player: AVAudioPlayer?
    private static var stopping = false
    static func start() {
        guard on, !Shot.on, !MKSfx.muted else { return }
        let want = MKSfx.ignoreSilent
        MKSfx.q.async {
            stopping = false
            guard !AVAudioSession.sharedInstance().isOtherAudioPlaying else { return }
            MKSfx.applySession(want)
            if player == nil, let u = Bundle.main.url(forResource: "bgm_shop", withExtension: "m4a") {
                player = try? AVAudioPlayer(contentsOf: u)
                player?.numberOfLoops = -1
                player?.volume = 0
                player?.prepareToPlay()
            }
            guard let p = player else { return }
            if !p.isPlaying { p.play() }
            p.setVolume(0.35, fadeDuration: 1.5)
        }
    }
    static func stop() {
        MKSfx.q.async {
            guard let p = player, p.isPlaying else { return }
            stopping = true
            p.setVolume(0, fadeDuration: 0.8)
            MKSfx.q.asyncAfter(deadline: .now() + 0.85) { if stopping { p.pause() } }
        }
    }
}
