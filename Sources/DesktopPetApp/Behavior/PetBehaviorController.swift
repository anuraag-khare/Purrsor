import Foundation

@MainActor
final class PetBehaviorController {
    private enum Thresholds {
        static let excitedKeysPerSecond = 6
        static let overheatedKeysPerSecond = 10
    }

    var onStateChange: (CatVisualState) -> Void = { _ in }

    private struct OverrideState {
        let mood: CatMood
        let message: String
        let expiresAt: TimeInterval
    }

    private var timer: Timer?
    private var lastTickAt: TimeInterval?
    private var lastState = CatVisualState.idle
    private var overrideState: OverrideState?

    private var keysPerSecond = 0
    private var isCursorHovering = false
    private var isDragging = false
    private var lastKeypressAt: TimeInterval?
    private var activeTypingSeconds: TimeInterval = 0
    private var reminderIntervalSeconds: TimeInterval
    private var sleepDelaySeconds: TimeInterval

    init(settings: AppSettings) {
        reminderIntervalSeconds = TimeInterval(settings.clampedStretchReminderMinutes * 60)
        sleepDelaySeconds = TimeInterval(settings.clampedSleepDelaySeconds)
    }

    func start() {
        guard timer == nil else {
            return
        }

        lastTickAt = Date().timeIntervalSinceReferenceDate
        timer = Timer.scheduledTimer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(handleTick),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = 0.05
        publishCurrentState()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setKeysPerSecond(_ keysPerSecond: Int) {
        self.keysPerSecond = keysPerSecond

        if keysPerSecond > 0 {
            lastKeypressAt = Date().timeIntervalSinceReferenceDate
        }

        publishCurrentState()
    }

    func setCursorHovering(_ isCursorHovering: Bool) {
        guard self.isCursorHovering != isCursorHovering else {
            return
        }

        self.isCursorHovering = isCursorHovering
        publishCurrentState()
    }

    func setDragging(_ isDragging: Bool) {
        guard self.isDragging != isDragging else {
            return
        }

        self.isDragging = isDragging
        publishCurrentState()
    }

    func setReminderInterval(minutes: Int) {
        reminderIntervalSeconds = TimeInterval(minutes * 60)
        activeTypingSeconds = 0
        publishCurrentState()
    }

    func setSleepDelay(seconds: Int) {
        sleepDelaySeconds = TimeInterval(seconds)
        publishCurrentState()
    }

    func registerPet() {
        let now = Date().timeIntervalSinceReferenceDate
        overrideState = OverrideState(
            mood: .petting,
            message: "purr...",
            expiresAt: now + 1.8
        )
        publishCurrentState()
    }

    @objc private func handleTick() {
        let now = Date().timeIntervalSinceReferenceDate
        let delta = max(0, now - (lastTickAt ?? now))
        lastTickAt = now

        if let lastKeypressAt, now - lastKeypressAt <= 5 {
            activeTypingSeconds += delta
        } else {
            activeTypingSeconds = 0
        }

        if reminderIntervalSeconds > 0, activeTypingSeconds >= reminderIntervalSeconds {
            activeTypingSeconds = 0
            overrideState = OverrideState(
                mood: .reminding,
                message: "time to stretch",
                expiresAt: now + 4.0
            )
        }

        if let overrideState, overrideState.expiresAt <= now {
            self.overrideState = nil
        }

        publishCurrentState()
    }

    private func publishCurrentState() {
        let now = Date().timeIntervalSinceReferenceDate
        let state: CatVisualState

        if let overrideState, overrideState.expiresAt > now {
            state = CatVisualState(
                mood: overrideState.mood,
                motion: .idle,
                keysPerSecond: keysPerSecond,
                message: overrideState.message
            )
        } else if isDragging {
            state = CatVisualState(
                mood: .dragging,
                motion: .idle,
                keysPerSecond: 0,
                message: "hold on"
            )
        } else if keysPerSecond >= Thresholds.overheatedKeysPerSecond {
            state = CatVisualState(
                mood: .overheated,
                motion: .idle,
                keysPerSecond: keysPerSecond,
                message: "too fast"
            )
        } else if keysPerSecond >= Thresholds.excitedKeysPerSecond {
            state = CatVisualState(
                mood: .excited,
                motion: .idle,
                keysPerSecond: keysPerSecond,
                message: "kneading"
            )
        } else if keysPerSecond >= 1 {
            state = CatVisualState(
                mood: .typing,
                motion: .idle,
                keysPerSecond: keysPerSecond,
                message: "tap tap"
            )
        } else if isCursorHovering {
            state = CatVisualState(
                mood: .watching,
                motion: .idle,
                keysPerSecond: 0,
                message: "watching you"
            )
        } else if sleepDelaySeconds > 0, let lastKeypressAt, now - lastKeypressAt >= sleepDelaySeconds {
            state = CatVisualState(
                mood: .sleepy,
                motion: .idle,
                keysPerSecond: 0,
                message: "z z z"
            )
        } else {
            state = .idle
        }

        guard state != lastState else {
            return
        }

        lastState = state
        onStateChange(state)
    }
}
