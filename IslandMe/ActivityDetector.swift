import CoreMotion
import AVFoundation
import UIKit
import Combine
import CallKit

/// 把 CoreMotion + 屏幕状态融合成一个 Pose。
/// 规则是启发式的，后续可以改成按时间段/Focus 模式/用户校正学习。
@MainActor
final class ActivityDetector: ObservableObject {
    @Published private(set) var pose: Pose = .stand
    /// 作息表给出的“此刻该做的事”；静止且没在看手机时用它，没有作息表才退回时间段启发式
    var routinePose: () -> Pose? = { nil }
    /// 刚练完（HealthKit 记录）：静止时优先显示跑步/健身一会儿
    var workoutPose: () -> Pose? = { nil }
    /// 小紫自己的安排（打篮球/上学…）进行中
    var lifePose: () -> Pose? = { nil }
    /// App 在前台 = 你正看着它：静止时不再显示“看手机”，改成待机陪你（会自己搞小动作）
    var appActive = false { didSet { if appActive != oldValue { evaluate() } } }

    private let activity = CMMotionActivityManager()
    private let motion = CMMotionManager()
    private var lastMotionActivity: CMMotionActivity?
    private var facingUp = false            // 手机朝向：屏幕朝上且略倾斜 ≈ 在看手机
    private var screenOn = true
    private var carPlay = false             // CarPlay / 车载音频已连接
    private var lastEmit = Date.distantPast
    private var cancellables = Set<AnyCancellable>()

    // 实时互动信号（App 运行时有效）
    private var headphones = false          // 耳机 / AirPods / 蓝牙耳机
    private var otherAudio = false          // 别的 App 在放声音（音乐、播客）
    private var onCall = false
    private var charging = false
    private var landscape = false           // 横屏（App 在前台时：看视频）
    /// 你在聊天页打字（ChatView 发通知）
    var typing = false { didSet { if typing != oldValue { evaluate() } } }
    private let callObserver = CXCallObserver()
    private var callDelegate: CallDelegate?
    private var audioTimer: Timer?

    private final class CallDelegate: NSObject, CXCallObserverDelegate {
        let onChange: () -> Void
        init(_ f: @escaping () -> Void) { onChange = f }
        func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) { onChange() }
    }

    func start() {
        startSignals()
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activity.startActivityUpdates(to: .main) { [weak self] a in
            guard let self, let a else { return }
            self.lastMotionActivity = a
            self.evaluate()
        }
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0
            motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
                guard let self, let m else { return }
                // 重力 z 分量：-1 = 屏幕朝上平放；手持看手机通常在 -0.4 ~ -0.95 之间且 pitch 有倾角
                let g = m.gravity
                self.facingUp = g.z < -0.35 && abs(m.attitude.pitch) < 1.2
                self.evaluate()
            }
        }
        NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)
            .sink { [weak self] _ in self?.screenOn = true; self?.evaluate() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)
            .sink { [weak self] _ in self?.screenOn = false; self?.evaluate() }.store(in: &cancellables)
    }

    /// 不需要权限的信号：声音路由、打电话、充电、横屏。运动权限被拒也照样工作。
    private static let headphonePorts: [AVAudioSession.Port] = [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
    private var signalsStarted = false
    func startSignals() {
        guard !signalsStarted else { return }
        signalsStarted = true
        let nc = NotificationCenter.default
        nc.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateAudio() }.store(in: &cancellables)
        nc.publisher(for: AVAudioSession.silenceSecondaryAudioHintNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateAudio() }.store(in: &cancellables)
        // 别的 App 开始/停止放歌没有通知，每 5 秒看一眼（很轻）
        audioTimer?.invalidate()
        audioTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateAudio() }
        }
        updateAudio()

        // 打电话
        callDelegate = CallDelegate { [weak self] in Task { @MainActor in self?.updateCall() } }
        callObserver.setDelegate(callDelegate, queue: .main)
        updateCall()

        // 充电
        UIDevice.current.isBatteryMonitoringEnabled = true
        nc.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateBattery() }.store(in: &cancellables)
        updateBattery()

        // 横屏
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        nc.publisher(for: UIDevice.orientationDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateOrientation() }.store(in: &cancellables)
    }

    /// 声音从哪出 + 有没有别的 App 在放：CarPlay → 坐车；耳机 + 在放 → 听歌；扬声器 + 在放 → 跳舞
    private func updateAudio() {
        let session = AVAudioSession.sharedInstance()
        let outs = session.currentRoute.outputs
        let c = outs.contains { $0.portType == .carAudio }
        let h = outs.contains { Self.headphonePorts.contains($0.portType) }
        let o = session.isOtherAudioPlaying || session.secondaryAudioShouldBeSilencedHint
        guard c != carPlay || h != headphones || o != otherAudio else { return }
        carPlay = c; headphones = h; otherAudio = o
        evaluate()
    }
    private func updateCall() {
        let on = callObserver.calls.contains { !$0.hasEnded }
        if on != onCall { onCall = on; evaluate() }
    }
    private func updateBattery() {
        let st = UIDevice.current.batteryState
        let on = st == .charging || st == .full
        if on != charging { charging = on; evaluate() }
    }
    private func updateOrientation() {
        let o = UIDevice.current.orientation
        guard o.isLandscape || o.isPortrait else { return }      // 平放/倒扣不算
        if o.isLandscape != landscape { landscape = o.isLandscape; evaluate() }
    }
    /// 现在是不是在放歌（给"在听什么"用）
    var isListening: Bool { otherAudio && !carPlay }

    /// 外部状态变了（比如刚同步进来一条运动记录）→ 立刻重算
    func reevaluate() { evaluate() }

    func stop() {
        audioTimer?.invalidate(); audioTimer = nil
        activity.stopActivityUpdates()
        motion.stopDeviceMotionUpdates()
    }

    private func evaluate() {
        let a = lastMotionActivity
        let hour = Calendar.current.component(.hour, from: Date())
        var next: Pose = .stand

        // 优先级：打电话 > 坐车 > 打字(看着 App) > 小紫自己的安排 > 走跑 > 听歌/跳舞 > 运动后 > 充电 > 横屏看视频 > 陪你 > 看手机 > 作息 > 时段
        if onCall { next = .call }
        else if carPlay || a?.automotive == true { next = .drive }
        else if typing && appActive { next = .type }
        else if let l = lifePose() { next = l }
        else if a?.running == true { next = .run }
        else if a?.walking == true || a?.cycling == true { next = .walk }
        else if otherAudio && headphones { next = .music }
        else if otherAudio { next = .dance }
        else if let w = workoutPose() { next = w }
        else if charging && !appActive { next = .charge }
        else if appActive && landscape { next = .movie }
        else if appActive { next = .stand }
        else if screenOn && facingUp { next = .phone }
        else if let r = routinePose() { next = r }
        else if hour >= 23 || hour < 6 { next = .sleep }
        else if (9..<18).contains(hour) { next = .work }
        else if (19..<23).contains(hour) { next = .movie }
        // 节流：Live Activity 更新有预算，最短 20s 才允许改一次（动作变化除外）
        if next != pose || Date().timeIntervalSince(lastEmit) > 20 {
            pose = next
            lastEmit = Date()
        }
    }
}
