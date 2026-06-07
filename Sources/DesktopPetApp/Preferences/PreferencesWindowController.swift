import AppKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    var onShowOverlayChange: ((Bool) -> Void)? {
        didSet { viewController.onShowOverlayChange = onShowOverlayChange }
    }

    var onClickThroughChange: ((Bool) -> Void)? {
        didSet { viewController.onClickThroughChange = onClickThroughChange }
    }

    var onMovementEnabledChange: ((Bool) -> Void)? {
        didSet { viewController.onMovementEnabledChange = onMovementEnabledChange }
    }

    var onTextBubbleVisibilityChange: ((Bool) -> Void)? {
        didSet { viewController.onTextBubbleVisibilityChange = onTextBubbleVisibilityChange }
    }

    var onKeysPerSecondVisibilityChange: ((Bool) -> Void)? {
        didSet { viewController.onKeysPerSecondVisibilityChange = onKeysPerSecondVisibilityChange }
    }

    var onLaunchAtLoginChange: ((Bool) -> Void)? {
        didSet { viewController.onLaunchAtLoginChange = onLaunchAtLoginChange }
    }

    var onBubbleTextColorChange: ((OverlayTextColor) -> Void)? {
        didSet { viewController.onBubbleTextColorChange = onBubbleTextColorChange }
    }

    var onTypingIndicatorTextColorChange: ((OverlayTextColor) -> Void)? {
        didSet { viewController.onTypingIndicatorTextColorChange = onTypingIndicatorTextColorChange }
    }

    var onOverlayScaleChange: ((Double) -> Void)? {
        didSet { viewController.onOverlayScaleChange = onOverlayScaleChange }
    }

    var onReminderIntervalChange: ((Int) -> Void)? {
        didSet { viewController.onReminderIntervalChange = onReminderIntervalChange }
    }

    var onSleepDelayChange: ((Int) -> Void)? {
        didSet { viewController.onSleepDelayChange = onSleepDelayChange }
    }

    var onResetPosition: (() -> Void)? {
        didSet { viewController.onResetPosition = onResetPosition }
    }

    var onRequestAccessibility: (() -> Void)? {
        didSet { viewController.onRequestAccessibility = onRequestAccessibility }
    }

    private let viewController = PreferencesViewController()
    private var latestSettings: AppSettings
    private var latestAccessibilityTrusted = false
    private var latestLaunchAtLoginState: LaunchAtLoginService.State = .disabled
    private var applyStateScheduled = false

    init(settings: AppSettings) {
        latestSettings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 504),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Purrsor Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = viewController

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show(with settings: AppSettings) {
        latestSettings = settings
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        scheduleApplyLatestState(force: true)
    }

    func sync(with settings: AppSettings) {
        latestSettings = settings
        scheduleApplyLatestState()
    }

    func setAccessibilityTrusted(_ trusted: Bool) {
        latestAccessibilityTrusted = trusted
        scheduleApplyLatestState()
    }

    func setLaunchAtLoginState(_ state: LaunchAtLoginService.State) {
        latestLaunchAtLoginState = state
        scheduleApplyLatestState()
    }

    private func scheduleApplyLatestState(force: Bool = false) {
        guard !applyStateScheduled else {
            return
        }

        applyStateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.applyStateScheduled = false

            if !force, self.window?.isVisible != true {
                return
            }

            self.applyLatestState()
        }
    }

    private func applyLatestState() {
        viewController.sync(with: latestSettings)
        viewController.setLaunchAtLoginState(latestLaunchAtLoginState)
        viewController.setAccessibilityTrusted(latestAccessibilityTrusted)
    }
}
