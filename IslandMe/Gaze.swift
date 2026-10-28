import AVFoundation
import Vision
import SwiftUI

/// 前置摄像头"对视"（设定第 22 节）：只在 App 开着、你在「我」里打开时运行。
/// 每秒看 4 次有没有一张正对屏幕的脸；只在手机上算，不拍照、不录像、不上传。
final class GazeWatcher: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "gaze.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "gaze.enabled") }
    }

    @Published private(set) var looking = false
    @Published private(set) var lookSince: Date? = nil
    /// 脸在画面里偏左（-1）还是偏右（1）
    @Published private(set) var faceX: CGFloat = 0

    private let session = AVCaptureSession()
    private let q = DispatchQueue(label: "gaze")
    private var configured = false
    private var lastRun = Date.distantPast
    private var lostFrames = 0

    func start() {
        if Shot.on { return }   // 截图模式不要摄像头权限框
        guard Self.enabled else { return }
        AVCaptureDevice.requestAccess(for: .video) { ok in
            guard ok else { return }
            self.q.async {
                self.configure()
                if !self.session.isRunning { self.session.startRunning() }
            }
        }
    }

    func stop() {
        q.async { if self.session.isRunning { self.session.stopRunning() } }
        DispatchQueue.main.async { self.looking = false; self.lookSince = nil }
    }

    private func configure() {
        guard !configured,
              let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: dev) else { return }
        session.beginConfiguration()
        session.sessionPreset = .low
        if session.canAddInput(input) { session.addInput(input) }
        let out = AVCaptureVideoDataOutput()
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(self, queue: q)
        if session.canAddOutput(out) { session.addOutput(out) }
        session.commitConfiguration()
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastRun) > 0.25, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastRun = Date()
        let req = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cvPixelBuffer: pb, orientation: .leftMirrored).perform([req])
        let face = req.results?.max { $0.boundingBox.width < $1.boundingBox.width }
        var look = false
        if let f = face, f.boundingBox.width > 0.12 {
            let yaw = abs(f.yaw?.doubleValue ?? 1), pitch = abs(f.pitch?.doubleValue ?? 0)
            look = yaw < 0.35 && pitch < 0.45
        }
        // 偶尔漏检一两帧不算移开视线
        if look { lostFrames = 0 } else { lostFrames += 1 }
        let now = look || lostFrames < 3
        let x = face.map { CGFloat($0.boundingBox.midX * 2 - 1) } ?? 0
        DispatchQueue.main.async {
            if now != self.looking { self.looking = now; self.lookSince = now ? Date() : nil }
            self.faceX = x
        }
    }
}
