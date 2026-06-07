import AppKit

@MainActor
final class PetMotionController {
    private enum Constants {
        static let tickInterval = 1.0 / 30.0
        static let moveSpeed: CGFloat = 34
        static let arrivalThreshold: CGFloat = 2
        static let minimumTravelDistance: CGFloat = 24
        static let horizontalWanderRange: ClosedRange<CGFloat> = -96...96
        static let verticalWanderRange: ClosedRange<CGFloat> = -28...28
        static let edgeInset = NSSize(width: 18, height: 12)
    }

    private enum Phase {
        case idling(until: TimeInterval)
        case moving(target: NSPoint)
    }

    var onOriginChange: (NSPoint) -> Void = { _ in }
    var onMotionChange: (CatMotionState) -> Void = { _ in }

    private var timer: Timer?
    private var lastTickAt: TimeInterval?
    private var currentOrigin: NSPoint
    private var homeOrigin: NSPoint
    private var overlaySize: NSSize
    private var phase: Phase
    private var isSuspended = false
    private var currentMotionState: CatMotionState = .idle

    init(origin: NSPoint, overlaySize: NSSize) {
        currentOrigin = origin
        homeOrigin = origin
        self.overlaySize = overlaySize
        let now = Date().timeIntervalSinceReferenceDate
        phase = .idling(until: now + Self.randomIdleDelay(short: false))
    }

    func start() {
        guard timer == nil else {
            return
        }

        lastTickAt = Date().timeIntervalSinceReferenceDate
        timer = Timer.scheduledTimer(
            timeInterval: Constants.tickInterval,
            target: self,
            selector: #selector(handleTick),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = 0.01
        setMotionState(.idle)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setSuspended(_ suspended: Bool) {
        guard isSuspended != suspended else {
            return
        }

        isSuspended = suspended
        setMotionState(.idle)

        guard !suspended else {
            return
        }

        let now = Date().timeIntervalSinceReferenceDate
        phase = .idling(until: now + Self.randomIdleDelay(short: true))
    }

    func updateOrigin(_ origin: NSPoint, treatAsHome: Bool) {
        currentOrigin = clampedOrigin(for: origin)

        if treatAsHome {
            homeOrigin = currentOrigin
            let now = Date().timeIntervalSinceReferenceDate
            phase = .idling(until: now + Self.randomIdleDelay(short: false))
            setMotionState(.idle)
        }
    }

    func setOverlaySize(_ overlaySize: NSSize) {
        self.overlaySize = overlaySize
        homeOrigin = clampedOrigin(for: homeOrigin)

        let clampedCurrentOrigin = clampedOrigin(for: currentOrigin)
        guard clampedCurrentOrigin != currentOrigin else {
            return
        }

        currentOrigin = clampedCurrentOrigin
        onOriginChange(clampedCurrentOrigin)
    }

    @objc private func handleTick() {
        let now = Date().timeIntervalSinceReferenceDate
        let delta = max(0, now - (lastTickAt ?? now))
        lastTickAt = now

        guard !isSuspended else {
            return
        }

        switch phase {
        case let .idling(until):
            setMotionState(.idle)

            if now >= until {
                phase = .moving(target: nextTarget())
            }

        case let .moving(target):
            let deltaX = target.x - currentOrigin.x
            let deltaY = target.y - currentOrigin.y
            let distance = hypot(deltaX, deltaY)

            guard distance > Constants.arrivalThreshold else {
                currentOrigin = target
                onOriginChange(target)
                setMotionState(.idle)
                phase = .idling(until: now + Self.randomIdleDelay(short: false))
                return
            }

            let stepDistance = min(distance, Constants.moveSpeed * delta)
            let nextOrigin = clampedOrigin(
                for: NSPoint(
                    x: currentOrigin.x + (deltaX / distance) * stepDistance,
                    y: currentOrigin.y + (deltaY / distance) * stepDistance
                )
            )

            guard nextOrigin != currentOrigin else {
                setMotionState(.idle)
                phase = .idling(until: now + Self.randomIdleDelay(short: true))
                return
            }

            currentOrigin = nextOrigin
            onOriginChange(nextOrigin)
            setMotionState(deltaX >= 0 ? .walkingRight : .walkingLeft)
        }
    }

    private func nextTarget() -> NSPoint {
        let preferHomeAnchor = Double.random(in: 0...1) < 0.35
        let anchor = preferHomeAnchor ? homeOrigin : currentOrigin

        for _ in 0..<10 {
            let candidate = clampedOrigin(
                for: NSPoint(
                    x: anchor.x + CGFloat.random(in: Constants.horizontalWanderRange),
                    y: anchor.y + CGFloat.random(in: Constants.verticalWanderRange)
                )
            )

            if hypot(candidate.x - currentOrigin.x, candidate.y - currentOrigin.y) >= Constants.minimumTravelDistance {
                return candidate
            }
        }

        return clampedOrigin(for: homeOrigin)
    }

    private func clampedOrigin(for origin: NSPoint) -> NSPoint {
        let bounds = movementBounds(near: origin)
        let maxX = max(bounds.minX, bounds.maxX - overlaySize.width)
        let maxY = max(bounds.minY, bounds.maxY - overlaySize.height)

        return NSPoint(
            x: min(max(origin.x, bounds.minX), maxX),
            y: min(max(origin.y, bounds.minY), maxY)
        )
    }

    private func movementBounds(near origin: NSPoint) -> NSRect {
        let probePoint = NSPoint(
            x: origin.x + overlaySize.width / 2.0,
            y: origin.y + overlaySize.height / 2.0
        )
        let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(probePoint) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        return visibleFrame.insetBy(
            dx: Constants.edgeInset.width,
            dy: Constants.edgeInset.height
        )
    }

    private func setMotionState(_ motionState: CatMotionState) {
        guard currentMotionState != motionState else {
            return
        }

        currentMotionState = motionState
        onMotionChange(motionState)
    }

    private static func randomIdleDelay(short: Bool) -> TimeInterval {
        if short {
            return Double.random(in: 0.8...1.6)
        }

        return Double.random(in: 2.4...4.8)
    }
}
