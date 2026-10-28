import Foundation
import HealthKit
import UserNotifications

/// HealthKit：读今天步数、最近的运动记录（跑步/力量训练…）。
/// Watch 上的运动是结束后才同步过来，所以这里给的是“刚练完”状态：练完后 20 分钟内动作锁定为跑步/健身，它会夸一句；
/// 作息里安排了跑步/健身但到点一小时还没记录，它会催一句。
@MainActor
final class HealthStore: ObservableObject {
    @Published private(set) var stepsToday: Int = 0
    @Published private(set) var lastWorkout: Workout? = nil
    @Published private(set) var authorized = false

    struct Workout: Equatable {
        var pose: Pose          // run / walk / gym
        var minutes: Int
        var end: Date
        var label: String
    }

    static let available = HKHealthStore.isHealthDataAvailable()
    private let store = HKHealthStore()
    private var seenWorkout: Date? {
        get { UserDefaults.standard.object(forKey: "health.lastWorkoutEnd") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "health.lastWorkoutEnd") }
    }
    /// 新运动记录到达时的回调（App 层用来让它说话、更新岛台）
    var onWorkout: (Workout) -> Void = { _ in }

    static let holdMinutes = 20.0

    /// “刚练完”期间给探测器的动作覆盖
    var workoutPose: Pose? {
        guard let w = lastWorkout, Date().timeIntervalSince(w.end) < Self.holdMinutes * 60 else { return nil }
        return w.pose
    }

    func start(then done: (() -> Void)? = nil) {
        guard Self.available else { done?(); return }
        let read: Set<HKObjectType> = [HKObjectType.workoutType(), HKQuantityType(.stepCount)]
        store.requestAuthorization(toShare: [], read: read) { [weak self] ok, _ in
            Task { @MainActor in
                done?()
                guard let self, ok else { return }
                self.authorized = true
                self.refresh()
                self.observeWorkouts()
            }
        }
    }

    func refresh() {
        fetchSteps()
        fetchLatestWorkout()
    }

    private func fetchSteps() {
        let type = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { [weak self] _, stats, _ in
            let n = Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            Task { @MainActor in self?.stepsToday = n }
        }
        store.execute(q)
    }

    private func fetchLatestWorkout() {
        let pred = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-6 * 3600), end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: .workoutType(), predicate: pred, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let w = samples?.first as? HKWorkout, let pose = Self.pose(for: w.workoutActivityType) else { return }
            let item = Workout(pose: pose, minutes: Int(w.duration / 60), end: w.endDate, label: Self.label(for: w.workoutActivityType))
            Task { @MainActor in
                guard let self else { return }
                let isNew = self.seenWorkout.map { w.endDate > $0 } ?? true
                self.lastWorkout = item
                if isNew {
                    self.seenWorkout = w.endDate
                    self.cancelNag(for: pose)
                    self.onWorkout(item)
                }
            }
        }
        store.execute(q)
    }

    /// 后台投递：Watch 同步进来新运动时唤醒 App（需要 HealthKit Background Delivery 权限）
    private func observeWorkouts() {
        let q = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { [weak self] _, done, _ in
            Task { @MainActor in self?.fetchLatestWorkout() }
            done()
        }
        store.execute(q)
        store.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate) { _, _ in }
    }

    static func pose(for t: HKWorkoutActivityType) -> Pose? {
        switch t {
        case .running, .trackAndField: return .run
        case .walking, .hiking, .cycling, .stairs, .stairClimbing: return .walk
        case .traditionalStrengthTraining, .functionalStrengthTraining, .highIntensityIntervalTraining, .crossTraining,
             .coreTraining, .yoga, .pilates, .rowing, .elliptical, .mixedCardio, .jumpRope, .boxing, .kickboxing, .flexibility:
            return .gym
        default: return nil
        }
    }
    static func label(for t: HKWorkoutActivityType) -> String {
        switch t {
        case .running: return T("跑步")
        case .walking: return T("走路")
        case .hiking: return T("徒步")
        case .cycling: return T("骑车")
        case .traditionalStrengthTraining, .functionalStrengthTraining: return T("力量")
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return T("瑜伽")
        case .pilates: return T("普拉提")
        case .rowing: return T("划船")
        case .elliptical: return T("椭圆机")
        default: return T("运动")
        }
    }

    // MARK: 催练：作息里的跑步/健身到点一小时还没记录 → 一条通知；练了就取消

    static func scheduleNags(routine: Routine) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            center.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix("nag.") })
            guard available else { return }
            for it in routine.items where it.pose == .run || it.pose == .gym {
                var dc = DateComponents(); dc.hour = it.hour + 1; dc.minute = it.minute
                guard dc.hour! < 24, !Quiet.isQuiet(hour: dc.hour!), Quiet.level != .low else { continue }
                let c = UNMutableNotificationContent()
                c.title = ChatStore.petName
                c.body = it.pose == .run ? T("说好的跑步呢？我鞋都穿好了。") : T("该去练了，我帮你数组数。")
                c.interruptionLevel = .passive
                center.add(UNNotificationRequest(identifier: "nag.\(it.pose.rawValue)", content: c,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
            }
        }
    }

    /// 今天练过了就把今天这条催练压掉（删掉重复通知，明天 App 启动时再排回来）
    private func cancelNag(for pose: Pose) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nag.\(pose.rawValue)"])
    }

    static func praise(_ w: Workout) -> String {
        switch w.pose {
        case .run: return T("跑了 {0} 分钟，不错。记得喝水。", w.minutes)
        case .gym: return T("{0}练了 {1} 分钟，拉伸一下再走。", w.label, w.minutes)
        default: return T("走了 {0} 分钟，舒服。", w.minutes)
        }
    }
}
