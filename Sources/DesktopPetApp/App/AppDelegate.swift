import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private var settings: AppSettings
    private var accessibilityPollTimer: Timer?
    private var accessibilityTrusted = false

    private var overlayController: OverlayWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private var statusItemController: StatusItemController?
    private var keyMonitor: GlobalKeyMonitor?
    private var behaviorController: PetBehaviorController
    private var motionController: PetMotionController?
    private var typingTracker = TypingIntensityTracker()
    private var currentBehaviorState = CatVisualState.idle
    private var currentMotionState: CatMotionState = .idle

    override init() {
        settings = settingsStore.load()
        behaviorController = PetBehaviorController(settings: settings)
        super.init()
        accessibilityTrusted = AccessibilityPermission.isTrusted()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayController = OverlayWindowController(settings: settings)
        overlayController?.onFrameChange = { [weak self] frame in
            guard let self else { return }
            settings.overlayOriginX = frame.origin.x
            settings.overlayOriginY = frame.origin.y
            motionController?.updateOrigin(frame.origin, treatAsHome: true)
            persistSettings()
        }
        overlayController?.onHoverChange = { [weak self] isHovering in
            self?.behaviorController.setCursorHovering(isHovering)
        }
        overlayController?.onDragChange = { [weak self] isDragging in
            self?.behaviorController.setDragging(isDragging)
        }
        overlayController?.onPet = { [weak self] in
            self?.behaviorController.registerPet()
        }

        if let frame = overlayController?.currentFrame {
            let controller = PetMotionController(origin: frame.origin, overlaySize: frame.size)
            controller.onOriginChange = { [weak self] origin in
                self?.overlayController?.setOrigin(origin)
            }
            controller.onMotionChange = { [weak self] motionState in
                self?.updateMotionState(motionState)
            }
            motionController = controller
        }

        preferencesWindowController = PreferencesWindowController(settings: settings)
        preferencesWindowController?.onMovementEnabledChange = { [weak self] enabled in
            self?.setWanderingEnabled(enabled)
        }
        preferencesWindowController?.onTextBubbleVisibilityChange = { [weak self] visible in
            self?.setTextBubbleVisible(visible)
        }
        preferencesWindowController?.onKeysPerSecondVisibilityChange = { [weak self] visible in
            self?.setKeysPerSecondVisible(visible)
        }
        preferencesWindowController?.onBubbleTextColorChange = { [weak self] color in
            self?.setBubbleTextColor(color)
        }
        preferencesWindowController?.onTypingIndicatorTextColorChange = { [weak self] color in
            self?.setTypingIndicatorTextColor(color)
        }
        preferencesWindowController?.onOverlayScaleChange = { [weak self] scale in
            self?.setOverlayScale(scale)
        }
        preferencesWindowController?.onReminderIntervalChange = { [weak self] minutes in
            self?.setStretchReminder(minutes: minutes)
        }
        preferencesWindowController?.onSleepDelayChange = { [weak self] seconds in
            self?.setSleepDelay(seconds: seconds)
        }
        preferencesWindowController?.onShowOverlayChange = { [weak self] visible in
            self?.setOverlayVisibility(visible)
        }
        preferencesWindowController?.onClickThroughChange = { [weak self] enabled in
            self?.setClickThrough(enabled)
        }
        preferencesWindowController?.onResetPosition = { [weak self] in
            self?.resetOverlayPosition()
        }
        preferencesWindowController?.onRequestAccessibility = { [weak self] in
            self?.requestAccessibilityAccess()
        }
        preferencesWindowController?.setAccessibilityTrusted(accessibilityTrusted)

        statusItemController = StatusItemController(
            overlayVisible: settings.overlayVisible,
            clickThroughEnabled: settings.clickThroughEnabled
        )
        statusItemController?.onOpenPreferences = { [weak self] in
            self?.showPreferences()
        }
        statusItemController?.onToggleOverlay = { [weak self] in
            self?.toggleOverlayVisibility()
        }
        statusItemController?.onToggleClickThrough = { [weak self] in
            self?.toggleClickThrough()
        }
        statusItemController?.onRequestAccessibility = { [weak self] in
            self?.requestAccessibilityAccess()
        }
        statusItemController?.onQuit = {
            NSApp.terminate(nil)
        }
        statusItemController?.setAccessibilityTrusted(accessibilityTrusted)

        behaviorController.onStateChange = { [weak self] state in
            guard let self else { return }
            let previousMood = currentBehaviorState.mood
            currentBehaviorState = state
            updateMotionSuspension(using: state)
            renderCurrentVisualState()

            if state.mood == .reminding, previousMood != .reminding {
                overlayController?.performStretchReminderAnimation()
            }
        }
        behaviorController.start()
        updateMotionSuspension(using: currentBehaviorState)
        motionController?.start()

        typingTracker.onKeysPerSecondChange = { [weak self] keysPerSecond in
            self?.behaviorController.setKeysPerSecond(keysPerSecond)
        }
        typingTracker.start()

        startKeyMonitoring()
        startAccessibilityPolling()

        if !accessibilityTrusted {
            showPreferences()
            requestAccessibilityAccess()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityPollTimer?.invalidate()
        keyMonitor?.stop()
        typingTracker.stop()
        behaviorController.stop()
        motionController?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func toggleOverlayVisibility() {
        setOverlayVisibility(!settings.overlayVisible)
    }

    private func toggleClickThrough() {
        setClickThrough(!settings.clickThroughEnabled)
    }

    private func requestAccessibilityAccess() {
        AccessibilityPermission.promptIfNeeded()
        refreshAccessibilityState(restartMonitor: true)
    }

    private func showPreferences() {
        preferencesWindowController?.show(with: settings)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setOverlayVisibility(_ visible: Bool) {
        overlayController?.setOverlayVisible(visible)
        settings.overlayVisible = visible
        statusItemController?.setOverlayVisible(visible)
        preferencesWindowController?.sync(with: settings)
        updateMotionSuspension(using: currentBehaviorState)
        persistSettings()
    }

    private func setClickThrough(_ enabled: Bool) {
        overlayController?.setClickThroughEnabled(enabled)
        settings.clickThroughEnabled = enabled
        statusItemController?.setClickThroughEnabled(enabled)
        preferencesWindowController?.sync(with: settings)
        persistSettings()
    }

    private func setWanderingEnabled(_ enabled: Bool) {
        settings.wanderingEnabled = enabled
        preferencesWindowController?.sync(with: settings)
        updateMotionSuspension(using: currentBehaviorState)
        persistSettings()
    }

    private func setTextBubbleVisible(_ visible: Bool) {
        overlayController?.setTextBubbleVisible(visible)
        settings.textBubbleVisible = visible
        preferencesWindowController?.sync(with: settings)
        persistSettings()
    }

    private func setKeysPerSecondVisible(_ visible: Bool) {
        overlayController?.setKeysPerSecondVisible(visible)
        settings.keysPerSecondVisible = visible
        preferencesWindowController?.sync(with: settings)
        persistSettings()
    }

    private func setBubbleTextColor(_ color: OverlayTextColor) {
        overlayController?.setBubbleTextColor(color.nsColor)
        settings.bubbleTextColor = color
        preferencesWindowController?.sync(with: settings)
        persistSettings()
    }

    private func setTypingIndicatorTextColor(_ color: OverlayTextColor) {
        overlayController?.setTypingIndicatorTextColor(color.nsColor)
        settings.typingIndicatorTextColor = color
        preferencesWindowController?.sync(with: settings)
        persistSettings()
    }

    private func setOverlayScale(_ scale: Double) {
        settings.overlayScale = AppSettings.overlayScaleOptions.contains(scale)
            ? scale
            : AppSettings.defaultValue.overlayScale

        let frame = overlayController?.setScale(CGFloat(settings.overlayScale))
        if let frame {
            settings.overlayOriginX = frame.origin.x
            settings.overlayOriginY = frame.origin.y
            motionController?.setOverlaySize(frame.size)
            motionController?.updateOrigin(frame.origin, treatAsHome: true)
        }

        preferencesWindowController?.sync(with: settings)
        persistSettings()
    }

    private func setStretchReminder(minutes: Int) {
        settings.stretchReminderMinutes = AppSettings.reminderOptionsInMinutes.contains(minutes)
            ? minutes
            : AppSettings.defaultValue.stretchReminderMinutes
        behaviorController.setReminderInterval(minutes: settings.stretchReminderMinutes)
        preferencesWindowController?.sync(with: settings)
        persistSettings()
    }

    private func setSleepDelay(seconds: Int) {
        settings.sleepDelaySeconds = AppSettings.sleepDelayOptionsInSeconds.contains(seconds)
            ? seconds
            : AppSettings.defaultValue.sleepDelaySeconds
        behaviorController.setSleepDelay(seconds: settings.sleepDelaySeconds)
        preferencesWindowController?.sync(with: settings)
        persistSettings()
    }

    private func resetOverlayPosition() {
        settings.overlayOriginX = AppSettings.defaultValue.overlayOriginX
        settings.overlayOriginY = AppSettings.defaultValue.overlayOriginY
        let origin = NSPoint(x: settings.overlayOriginX, y: settings.overlayOriginY)
        overlayController?.setOrigin(origin)
        motionController?.updateOrigin(origin, treatAsHome: true)
        persistSettings()
    }

    private func persistSettings() {
        settingsStore.save(settings)
    }

    private func startKeyMonitoring() {
        let monitor = GlobalKeyMonitor { [weak self] _ in
            self?.typingTracker.recordKeypress()
        }
        monitor.start()
        keyMonitor = monitor
    }

    private func startAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleAccessibilityPoll),
            userInfo: nil,
            repeats: true
        )
        accessibilityPollTimer?.tolerance = 0.2
    }

    private func refreshAccessibilityState(restartMonitor: Bool) {
        let trusted = AccessibilityPermission.isTrusted()
        let changed = trusted != accessibilityTrusted
        accessibilityTrusted = trusted

        statusItemController?.setAccessibilityTrusted(trusted)
        preferencesWindowController?.setAccessibilityTrusted(trusted)

        guard changed, restartMonitor else { return }

        keyMonitor?.stop()
        startKeyMonitoring()
    }

    @objc private func handleAccessibilityPoll() {
        refreshAccessibilityState(restartMonitor: true)
    }

    private func renderCurrentVisualState() {
        var state = currentBehaviorState
        state.motion = currentMotionState
        overlayController?.render(state)
    }

    private func updateMotionState(_ motionState: CatMotionState) {
        guard currentMotionState != motionState else {
            return
        }

        currentMotionState = motionState
        renderCurrentVisualState()
    }

    private func updateMotionSuspension(using state: CatVisualState) {
        let shouldSuspend =
            !settings.overlayVisible ||
            !settings.wanderingEnabled ||
            state.mood == .watching ||
            state.mood == .dragging ||
            state.mood == .petting ||
            state.mood == .sleepy ||
            state.mood == .reminding ||
            state.mood == .typing ||
            state.mood == .excited ||
            state.mood == .overheated

        motionController?.setSuspended(shouldSuspend)
    }
}
