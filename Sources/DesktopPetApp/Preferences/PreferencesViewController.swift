import AppKit

@MainActor
final class PreferencesViewController: NSViewController {
    var onShowOverlayChange: ((Bool) -> Void)?
    var onClickThroughChange: ((Bool) -> Void)?
    var onMovementEnabledChange: ((Bool) -> Void)?
    var onTextBubbleVisibilityChange: ((Bool) -> Void)?
    var onKeysPerSecondVisibilityChange: ((Bool) -> Void)?
    var onLaunchAtLoginChange: ((Bool) -> Void)?
    var onBubbleTextColorChange: ((OverlayTextColor) -> Void)?
    var onTypingIndicatorTextColorChange: ((OverlayTextColor) -> Void)?
    var onOverlayScaleChange: ((Double) -> Void)?
    var onReminderIntervalChange: ((Int) -> Void)?
    var onSleepDelayChange: ((Int) -> Void)?
    var onResetPosition: (() -> Void)?
    var onRequestAccessibility: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "Purrsor")
    private let subtitleLabel = NSTextField(labelWithString: "Desktop companion controls")
    private let reminderLabel = NSTextField(labelWithString: "Stretch reminder")
    private let reminderPopupButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sleepDelayLabel = NSTextField(labelWithString: "Sleep after idle")
    private let sleepDelayPopupButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let showOverlayButton = NSButton(checkboxWithTitle: "Show overlay", target: nil, action: nil)
    private let clickThroughButton = NSButton(checkboxWithTitle: "Enable click-through", target: nil, action: nil)
    private let wanderingButton = NSButton(checkboxWithTitle: "Enable wandering", target: nil, action: nil)
    private let textBubbleButton = NSButton(checkboxWithTitle: "Show mood bubble", target: nil, action: nil)
    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let launchAtLoginStatusLabel = NSTextField(labelWithString: "")
    private let bubbleTextColorLabel = NSTextField(labelWithString: "Mood bubble text color")
    private let bubbleTextColorWell = NSColorWell(frame: .zero)
    private let typingIndicatorButton = NSButton(checkboxWithTitle: "Enable typing speed indicator", target: nil, action: nil)
    private let typingIndicatorColorLabel = NSTextField(labelWithString: "Typing indicator text color")
    private let typingIndicatorColorWell = NSColorWell(frame: .zero)
    private let overlayScaleLabel = NSTextField(labelWithString: "Scale")
    private let overlayScalePopupButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let resetPositionButton = NSButton(title: "Reset position", target: nil, action: nil)
    private let permissionStatusLabel = NSTextField(labelWithString: "Accessibility not granted")
    private let requestAccessibilityButton = NSButton(title: "Grant Accessibility Access", target: nil, action: nil)
    private var pendingSettings: AppSettings?
    private var pendingAccessibilityTrusted: Bool?
    private var pendingLaunchAtLoginState: LaunchAtLoginService.State?
    private var lastAppliedSettings: AppSettings?
    private var lastAppliedAccessibilityTrusted: Bool?
    private var lastAppliedLaunchAtLoginState: LaunchAtLoginService.State?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 532))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        applyPendingStateIfNeeded()
    }

    func sync(with settings: AppSettings) {
        guard pendingSettings != settings || lastAppliedSettings != settings else {
            return
        }

        pendingSettings = settings
        enqueueStateApplication()
    }

    func setAccessibilityTrusted(_ trusted: Bool) {
        guard pendingAccessibilityTrusted != trusted || lastAppliedAccessibilityTrusted != trusted else {
            return
        }

        pendingAccessibilityTrusted = trusted
        enqueueStateApplication()
    }

    func setLaunchAtLoginState(_ state: LaunchAtLoginService.State) {
        guard pendingLaunchAtLoginState != state || lastAppliedLaunchAtLoginState != state else {
            return
        }

        pendingLaunchAtLoginState = state
        enqueueStateApplication()
    }

    private func configure() {
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        subtitleLabel.textColor = .secondaryLabelColor
        reminderLabel.font = .systemFont(ofSize: 13, weight: .medium)
        sleepDelayLabel.font = .systemFont(ofSize: 13, weight: .medium)
        bubbleTextColorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        typingIndicatorColorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        overlayScaleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        permissionStatusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        launchAtLoginStatusLabel.font = .systemFont(ofSize: 12, weight: .regular)
        launchAtLoginStatusLabel.textColor = .secondaryLabelColor
        launchAtLoginStatusLabel.lineBreakMode = .byWordWrapping
        launchAtLoginStatusLabel.maximumNumberOfLines = 0

        reminderPopupButton.target = self
        reminderPopupButton.action = #selector(handleReminderChange)
        configureReminderOptions()

        sleepDelayPopupButton.target = self
        sleepDelayPopupButton.action = #selector(handleSleepDelayChange)
        configureSleepDelayOptions()

        showOverlayButton.target = self
        showOverlayButton.action = #selector(handleShowOverlayChange)

        clickThroughButton.target = self
        clickThroughButton.action = #selector(handleClickThroughChange)

        wanderingButton.target = self
        wanderingButton.action = #selector(handleWanderingChange)

        textBubbleButton.target = self
        textBubbleButton.action = #selector(handleTextBubbleChange)

        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(handleLaunchAtLoginChange)

        bubbleTextColorWell.target = self
        bubbleTextColorWell.action = #selector(handleBubbleTextColorChange)

        typingIndicatorButton.target = self
        typingIndicatorButton.action = #selector(handleTypingIndicatorChange)

        typingIndicatorColorWell.target = self
        typingIndicatorColorWell.action = #selector(handleTypingIndicatorColorChange)

        overlayScalePopupButton.target = self
        overlayScalePopupButton.action = #selector(handleOverlayScaleChange)
        configureOverlayScaleOptions()

        resetPositionButton.target = self
        resetPositionButton.action = #selector(handleResetPosition)
        resetPositionButton.bezelStyle = .rounded

        requestAccessibilityButton.target = self
        requestAccessibilityButton.action = #selector(handleRequestAccessibility)
        requestAccessibilityButton.bezelStyle = .rounded

        let reminderHeader = NSStackView(views: [reminderLabel, reminderPopupButton])
        reminderHeader.orientation = .horizontal
        reminderHeader.distribution = .fillProportionally
        reminderHeader.spacing = 12

        let sleepDelayHeader = NSStackView(views: [sleepDelayLabel, sleepDelayPopupButton])
        sleepDelayHeader.orientation = .horizontal
        sleepDelayHeader.distribution = .fillProportionally
        sleepDelayHeader.spacing = 12

        let bubbleColorRow = NSStackView(views: [bubbleTextColorLabel, bubbleTextColorWell])
        bubbleColorRow.orientation = .horizontal
        bubbleColorRow.alignment = .centerY
        bubbleColorRow.distribution = .fillProportionally
        bubbleColorRow.spacing = 12

        let launchAtLoginRow = NSStackView(views: [launchAtLoginButton])
        launchAtLoginRow.orientation = .vertical
        launchAtLoginRow.alignment = .leading
        launchAtLoginRow.spacing = 0

        let indicatorColorRow = NSStackView(views: [typingIndicatorColorLabel, typingIndicatorColorWell])
        indicatorColorRow.orientation = .horizontal
        indicatorColorRow.alignment = .centerY
        indicatorColorRow.distribution = .fillProportionally
        indicatorColorRow.spacing = 12

        let overlayScaleRow = NSStackView(views: [overlayScaleLabel, overlayScalePopupButton])
        overlayScaleRow.orientation = .horizontal
        overlayScaleRow.alignment = .centerY
        overlayScaleRow.distribution = .fillProportionally
        overlayScaleRow.spacing = 12

        let stack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            reminderHeader,
            sleepDelayHeader,
            showOverlayButton,
            clickThroughButton,
            wanderingButton,
            overlayScaleRow,
            textBubbleButton,
            launchAtLoginRow,
            launchAtLoginStatusLabel,
            bubbleColorRow,
            typingIndicatorButton,
            indicatorColorRow,
            resetPositionButton,
            permissionStatusLabel,
            requestAccessibilityButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
            reminderPopupButton.widthAnchor.constraint(equalToConstant: 150),
            sleepDelayPopupButton.widthAnchor.constraint(equalToConstant: 150),
            overlayScalePopupButton.widthAnchor.constraint(equalToConstant: 150),
            bubbleTextColorWell.widthAnchor.constraint(equalToConstant: 54),
            typingIndicatorColorWell.widthAnchor.constraint(equalToConstant: 54)
        ])
    }

    private func enqueueStateApplication() {
        DispatchQueue.main.async { [weak self] in
            self?.applyPendingStateIfNeeded()
        }
    }

    private func applyPendingStateIfNeeded() {
        guard isViewLoaded else {
            return
        }

        if let settings = pendingSettings {
            let overlayState: NSControl.StateValue = settings.overlayVisible ? .on : .off
            if showOverlayButton.state != overlayState {
                showOverlayButton.state = overlayState
            }

            let clickThroughState: NSControl.StateValue = settings.clickThroughEnabled ? .on : .off
            if clickThroughButton.state != clickThroughState {
                clickThroughButton.state = clickThroughState
            }

            let wanderingState: NSControl.StateValue = settings.wanderingEnabled ? .on : .off
            if wanderingButton.state != wanderingState {
                wanderingButton.state = wanderingState
            }

            let textBubbleState: NSControl.StateValue = settings.textBubbleVisible ? .on : .off
            if textBubbleButton.state != textBubbleState {
                textBubbleButton.state = textBubbleState
            }

            let launchAtLoginState: NSControl.StateValue = settings.launchAtLoginEnabled ? .on : .off
            if launchAtLoginButton.state != launchAtLoginState {
                launchAtLoginButton.state = launchAtLoginState
            }

            let bubbleColor = settings.bubbleTextColor.nsColor.usingColorSpace(.sRGB) ?? settings.bubbleTextColor.nsColor
            let currentBubbleColor = bubbleTextColorWell.color.usingColorSpace(.sRGB) ?? bubbleTextColorWell.color
            if !currentBubbleColor.isEqual(bubbleColor) {
                bubbleTextColorWell.color = bubbleColor
            }

            let typingIndicatorState: NSControl.StateValue = settings.keysPerSecondVisible ? .on : .off
            if typingIndicatorButton.state != typingIndicatorState {
                typingIndicatorButton.state = typingIndicatorState
            }

            selectOverlayScaleIfNeeded(settings.clampedOverlayScale)

            let indicatorColor = settings.typingIndicatorTextColor.nsColor.usingColorSpace(.sRGB) ?? settings.typingIndicatorTextColor.nsColor
            let currentIndicatorColor = typingIndicatorColorWell.color.usingColorSpace(.sRGB) ?? typingIndicatorColorWell.color
            if !currentIndicatorColor.isEqual(indicatorColor) {
                typingIndicatorColorWell.color = indicatorColor
            }

            let reminderMinutes = settings.clampedStretchReminderMinutes
            if reminderPopupButton.selectedTag() != reminderMinutes {
                selectReminderInterval(minutes: reminderMinutes)
            }

            let sleepDelaySeconds = settings.clampedSleepDelaySeconds
            if sleepDelayPopupButton.selectedTag() != sleepDelaySeconds {
                selectSleepDelay(seconds: sleepDelaySeconds)
            }

            lastAppliedSettings = settings
            pendingSettings = nil
        }

        if let launchAtLoginState = pendingLaunchAtLoginState {
            switch launchAtLoginState {
            case .disabled:
                launchAtLoginStatusLabel.stringValue = ""
                launchAtLoginStatusLabel.textColor = .secondaryLabelColor
            case .enabled:
                launchAtLoginStatusLabel.stringValue = "Launch at login is enabled."
                launchAtLoginStatusLabel.textColor = .systemGreen
            case .requiresApproval:
                launchAtLoginStatusLabel.stringValue = "Launch at login is pending approval in System Settings."
                launchAtLoginStatusLabel.textColor = .systemOrange
            }

            lastAppliedLaunchAtLoginState = launchAtLoginState
            pendingLaunchAtLoginState = nil
        }

        if let trusted = pendingAccessibilityTrusted {
            permissionStatusLabel.stringValue = trusted
                ? "Accessibility granted"
                : "Accessibility not granted"
            permissionStatusLabel.textColor = trusted ? .systemGreen : .systemOrange
            requestAccessibilityButton.isEnabled = !trusted
            requestAccessibilityButton.title = trusted
                ? "Accessibility Enabled"
                : "Grant Accessibility Access"
            lastAppliedAccessibilityTrusted = trusted
            pendingAccessibilityTrusted = nil
        }
    }

    @objc private func handleShowOverlayChange() {
        onShowOverlayChange?(showOverlayButton.state == .on)
    }

    @objc private func handleClickThroughChange() {
        onClickThroughChange?(clickThroughButton.state == .on)
    }

    @objc private func handleWanderingChange() {
        onMovementEnabledChange?(wanderingButton.state == .on)
    }

    @objc private func handleTextBubbleChange() {
        onTextBubbleVisibilityChange?(textBubbleButton.state == .on)
    }

    @objc private func handleBubbleTextColorChange() {
        onBubbleTextColorChange?(OverlayTextColor(bubbleTextColorWell.color))
    }

    @objc private func handleLaunchAtLoginChange() {
        onLaunchAtLoginChange?(launchAtLoginButton.state == .on)
    }

    @objc private func handleTypingIndicatorChange() {
        onKeysPerSecondVisibilityChange?(typingIndicatorButton.state == .on)
    }

    @objc private func handleTypingIndicatorColorChange() {
        onTypingIndicatorTextColorChange?(OverlayTextColor(typingIndicatorColorWell.color))
    }

    @objc private func handleOverlayScaleChange() {
        guard let selectedItem = overlayScalePopupButton.selectedItem,
              let scale = selectedItem.representedObject as? NSNumber else {
            return
        }

        onOverlayScaleChange?(scale.doubleValue)
    }

    @objc private func handleResetPosition() {
        onResetPosition?()
    }

    @objc private func handleSleepDelayChange() {
        let seconds = sleepDelayPopupButton.selectedTag()
        onSleepDelayChange?(seconds)
    }

    @objc private func handleRequestAccessibility() {
        onRequestAccessibility?()
    }

    @objc private func handleReminderChange() {
        let minutes = reminderPopupButton.selectedTag()
        onReminderIntervalChange?(minutes)
    }

    private func configureReminderOptions() {
        reminderPopupButton.removeAllItems()

        for minutes in AppSettings.reminderOptionsInMinutes {
            let title = minutes == 0 ? "Off" : "\(minutes) min"
            reminderPopupButton.addItem(withTitle: title)
            reminderPopupButton.lastItem?.tag = minutes
        }
    }

    private func configureSleepDelayOptions() {
        sleepDelayPopupButton.removeAllItems()

        for seconds in AppSettings.sleepDelayOptionsInSeconds {
            let title: String

            if seconds == 0 {
                title = "Off"
            } else if seconds < 60 {
                title = "\(seconds) sec"
            } else {
                let minutes = seconds / 60
                title = "\(minutes) min"
            }

            sleepDelayPopupButton.addItem(withTitle: title)
            sleepDelayPopupButton.lastItem?.tag = seconds
        }
    }

    private func configureOverlayScaleOptions() {
        overlayScalePopupButton.removeAllItems()

        for scale in AppSettings.overlayScaleOptions {
            let title: String

            if scale == 1.0 {
                title = "1x"
            } else {
                title = "\(scale)x"
            }

            overlayScalePopupButton.addItem(withTitle: title)
            overlayScalePopupButton.lastItem?.representedObject = NSNumber(value: scale)
        }
    }

    private func selectReminderInterval(minutes: Int) {
        if let item = reminderPopupButton.itemArray.first(where: { $0.tag == minutes }) {
            reminderPopupButton.select(item)
        } else {
            reminderPopupButton.selectItem(withTag: AppSettings.defaultValue.stretchReminderMinutes)
        }
    }

    private func selectSleepDelay(seconds: Int) {
        if let item = sleepDelayPopupButton.itemArray.first(where: { $0.tag == seconds }) {
            sleepDelayPopupButton.select(item)
        } else {
            sleepDelayPopupButton.selectItem(withTag: AppSettings.defaultValue.sleepDelaySeconds)
        }
    }

    private func selectOverlayScaleIfNeeded(_ scale: Double) {
        let currentScale = (overlayScalePopupButton.selectedItem?.representedObject as? NSNumber)?.doubleValue
        guard currentScale != scale else {
            return
        }

        if let item = overlayScalePopupButton.itemArray.first(where: {
            (($0.representedObject as? NSNumber)?.doubleValue ?? AppSettings.defaultValue.overlayScale) == scale
        }) {
            overlayScalePopupButton.select(item)
        } else {
            let defaultScale = AppSettings.defaultValue.overlayScale
            if let defaultItem = overlayScalePopupButton.itemArray.first(where: {
                (($0.representedObject as? NSNumber)?.doubleValue ?? defaultScale) == defaultScale
            }) {
                overlayScalePopupButton.select(defaultItem)
            } else {
                overlayScalePopupButton.selectItem(at: 0)
            }
        }
    }
}
