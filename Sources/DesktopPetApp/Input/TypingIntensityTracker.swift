import Foundation

@MainActor
final class TypingIntensityTracker {
    var onKeysPerSecondChange: (Int) -> Void = { _ in }

    private var timestamps: [TimeInterval] = []
    private var timer: Timer?
    private var lastPublishedKeysPerSecond = -1

    func start() {
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(
            timeInterval: 0.20,
            target: self,
            selector: #selector(handleTimerTick),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = 0.05
        onKeysPerSecondChange(0)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func recordKeypress() {
        timestamps.append(Date().timeIntervalSinceReferenceDate)
        publishCurrentState()
    }

    @objc private func handleTimerTick() {
        publishCurrentState()
    }

    private func publishCurrentState() {
        let now = Date().timeIntervalSinceReferenceDate
        timestamps.removeAll { now - $0 > 1.0 }

        let keysPerSecond = timestamps.count
        guard keysPerSecond != lastPublishedKeysPerSecond else {
            return
        }

        lastPublishedKeysPerSecond = keysPerSecond
        onKeysPerSecondChange(keysPerSecond)
    }
}
