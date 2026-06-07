import AppKit

@MainActor
final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    private static let baseSize = NSSize(width: 180, height: 180)
    private enum StretchReminderAnimation {
        static let scale: CGFloat = 2.0
        static let moveDuration: TimeInterval = 0.28
        static let holdDuration: TimeInterval = 1.0
    }

    var onFrameChange: ((NSRect) -> Void)?
    var onHoverChange: ((Bool) -> Void)?
    var onDragChange: ((Bool) -> Void)? {
        didSet {
            overlayView.onDragChange = onDragChange
        }
    }
    var onPet: (() -> Void)? {
        didSet {
            overlayView.onPet = onPet
        }
    }

    private let overlayView = CatOverlayView(frame: NSRect(origin: .zero, size: baseSize))
    private var cursorTrackingTimer: Timer?
    private var lastHoverState = false
    private var pendingProgrammaticMoveEvents = 0
    private var suppressFrameChangeNotifications = false
    private var isAnimatingStretchReminder = false

    init(settings: AppSettings) {
        let overlaySize = Self.scaledSize(for: CGFloat(settings.clampedOverlayScale))
        let frame = NSRect(
            x: settings.overlayOriginX,
            y: settings.overlayOriginY,
            width: overlaySize.width,
            height: overlaySize.height
        )

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .canJoinAllApplications,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.isMovableByWindowBackground = true
        panel.ignoresMouseEvents = settings.clickThroughEnabled
        overlayView.autoresizingMask = [.width, .height]
        panel.contentView = overlayView

        super.init(window: panel)

        panel.delegate = self
        apply(settings: settings)
        overlayView.render(.idle)
        startCursorTracking()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    var isOverlayVisible: Bool {
        window?.isVisible ?? false
    }

    var isClickThroughEnabled: Bool {
        window?.ignoresMouseEvents ?? false
    }

    var currentFrame: NSRect? {
        window?.frame
    }

    func render(_ state: CatVisualState) {
        overlayView.render(state)
    }

    func apply(settings: AppSettings) {
        setClickThroughEnabled(settings.clickThroughEnabled)
        setScale(CGFloat(settings.clampedOverlayScale))
        setOrigin(NSPoint(x: settings.overlayOriginX, y: settings.overlayOriginY))
        setTextBubbleVisible(settings.textBubbleVisible)
        setKeysPerSecondVisible(settings.keysPerSecondVisible)
        setBubbleTextColor(settings.bubbleTextColor.nsColor)
        setTypingIndicatorTextColor(settings.typingIndicatorTextColor.nsColor)
        setOverlayVisible(settings.overlayVisible)
    }

    @discardableResult
    func setScale(_ scale: CGFloat) -> NSRect? {
        guard let window else {
            return nil
        }

        let nextSize = Self.scaledSize(for: scale)
        let currentFrame = window.frame
        guard currentFrame.size != nextSize else {
            return currentFrame
        }

        var nextFrame = NSRect(origin: currentFrame.origin, size: nextSize)
        let visibleFrame = (screen(containing: currentFrame) ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame

        if let visibleFrame {
            let maxX = max(visibleFrame.minX, visibleFrame.maxX - nextFrame.width)
            let maxY = max(visibleFrame.minY, visibleFrame.maxY - nextFrame.height)
            nextFrame.origin.x = min(max(nextFrame.origin.x, visibleFrame.minX), maxX)
            nextFrame.origin.y = min(max(nextFrame.origin.y, visibleFrame.minY), maxY)
        }

        suppressFrameChangeNotifications = true
        window.setFrame(nextFrame.integral, display: true)
        suppressFrameChangeNotifications = false
        return window.frame
    }

    func setClickThroughEnabled(_ enabled: Bool) {
        window?.ignoresMouseEvents = enabled
    }

    func setOverlayVisible(_ visible: Bool) {
        guard let window else { return }

        if visible {
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }

    func setTextBubbleVisible(_ visible: Bool) {
        overlayView.setTextBubbleVisible(visible)
    }

    func setKeysPerSecondVisible(_ visible: Bool) {
        overlayView.setKeysPerSecondVisible(visible)
    }

    func setBubbleTextColor(_ color: NSColor) {
        overlayView.setBubbleTextColor(color)
    }

    func setTypingIndicatorTextColor(_ color: NSColor) {
        overlayView.setTypingIndicatorTextColor(color)
    }

    func setOrigin(_ origin: NSPoint, isProgrammatic: Bool = true) {
        guard let window else {
            return
        }

        let currentOrigin = window.frame.origin
        let originChanged =
            abs(currentOrigin.x - origin.x) >= 0.5 ||
            abs(currentOrigin.y - origin.y) >= 0.5

        guard originChanged else {
            return
        }

        if isProgrammatic {
            pendingProgrammaticMoveEvents += 1
        }

        window.setFrameOrigin(origin)
    }

    func performStretchReminderAnimation() {
        guard
            let window,
            window.isVisible,
            !isAnimatingStretchReminder
        else {
            return
        }

        isAnimatingStretchReminder = true
        let originalFrame = window.frame
        let reminderFrame = stretchReminderFrame(from: originalFrame)

        animateWindowFrame(to: reminderFrame, duration: StretchReminderAnimation.moveDuration) { [weak self] in
            guard let self else {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + StretchReminderAnimation.holdDuration) { [weak self] in
                guard let self else {
                    return
                }

                animateWindowFrame(
                    to: originalFrame,
                    duration: StretchReminderAnimation.moveDuration
                ) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.isAnimatingStretchReminder = false
                    }
                }
            }
        }
    }

    func toggleVisibility() {
        guard let window else { return }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let window else { return }

        if suppressFrameChangeNotifications {
            return
        }

        if pendingProgrammaticMoveEvents > 0 {
            pendingProgrammaticMoveEvents -= 1
            return
        }

        onFrameChange?(window.frame)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window else {
            return
        }

        if suppressFrameChangeNotifications {
            return
        }

        onFrameChange?(window.frame)
    }

    private func startCursorTracking() {
        guard cursorTrackingTimer == nil else {
            return
        }

        cursorTrackingTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(handleCursorTrackingTick),
            userInfo: nil,
            repeats: true
        )
        cursorTrackingTimer?.tolerance = 0.01
    }

    @objc private func handleCursorTrackingTick() {
        guard let window, window.isVisible else {
            overlayView.updateCursor(locationInView: nil, isHovering: false)
            if lastHoverState {
                lastHoverState = false
                onHoverChange?(false)
            }
            return
        }

        let cursorLocationOnScreen = NSEvent.mouseLocation
        let isHovering = window.frame.contains(cursorLocationOnScreen)
        let cursorLocationInWindow = window.convertPoint(fromScreen: cursorLocationOnScreen)
        let cursorLocationInView = overlayView.convert(cursorLocationInWindow, from: nil)

        overlayView.updateCursor(
            locationInView: cursorLocationInView,
            isHovering: isHovering
        )

        guard isHovering != lastHoverState else {
            return
        }

        lastHoverState = isHovering
        onHoverChange?(isHovering)
    }

    private func animateWindowFrame(
        to frame: NSRect,
        duration: TimeInterval,
        completion: @Sendable @escaping () -> Void
    ) {
        guard let window else {
            completion()
            return
        }

        suppressFrameChangeNotifications = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.allowsImplicitAnimation = true
            window.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.suppressFrameChangeNotifications = false
                completion()
            }
        }
    }

    private func stretchReminderFrame(from originalFrame: NSRect) -> NSRect {
        let screen = screen(containing: originalFrame)
            ?? window?.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? originalFrame
        let width = min(
            max(Self.baseSize.width * StretchReminderAnimation.scale, originalFrame.width),
            visibleFrame.width - 32
        )
        let height = min(
            max(Self.baseSize.height * StretchReminderAnimation.scale, originalFrame.height),
            visibleFrame.height - 32
        )

        return NSRect(
            x: visibleFrame.midX - (width / 2.0),
            y: visibleFrame.midY - (height / 2.0),
            width: width,
            height: height
        ).integral
    }

    private func screen(containing frame: NSRect) -> NSScreen? {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first(where: { $0.visibleFrame.contains(center) })
    }

    private static func scaledSize(for scale: CGFloat) -> NSSize {
        NSSize(
            width: (baseSize.width * scale).rounded(),
            height: (baseSize.height * scale).rounded()
        )
    }
}


// this is a test, normal typing speed
