import AppKit

@MainActor
final class StatusItemController: NSObject {
    private enum StatusIcon {
        static let size = NSSize(width: 18, height: 18)
        static let lineWidth: CGFloat = 1.6
    }

    var onOpenPreferences: (() -> Void)?
    var onToggleOverlay: (() -> Void)?
    var onToggleClickThrough: (() -> Void)?
    var onRequestAccessibility: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
    private let overlayItem = NSMenuItem(title: "", action: #selector(toggleOverlay), keyEquivalent: "")
    private let clickThroughItem = NSMenuItem(title: "", action: #selector(toggleClickThrough), keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "", action: #selector(requestAccessibility), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit Purrsor", action: #selector(quit), keyEquivalent: "q")

    private var overlayVisible: Bool
    private var clickThroughEnabled: Bool

    init(overlayVisible: Bool, clickThroughEnabled: Bool) {
        self.overlayVisible = overlayVisible
        self.clickThroughEnabled = clickThroughEnabled
        super.init()
        configure()
    }

    func setOverlayVisible(_ visible: Bool) {
        overlayVisible = visible
        refreshMenuTitles()
    }

    func setClickThroughEnabled(_ enabled: Bool) {
        clickThroughEnabled = enabled
        refreshMenuTitles()
    }

    func setAccessibilityTrusted(_ trusted: Bool) {
        accessibilityItem.title = trusted
            ? "Accessibility Access Granted"
            : "Grant Accessibility Access"
        accessibilityItem.isEnabled = !trusted
    }

    private func configure() {
        if let button = statusItem.button {
            button.image = makeStatusBarIcon()
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "Purrsor"
            button.setAccessibilityLabel("Purrsor")
        }

        preferencesItem.target = self
        overlayItem.target = self
        clickThroughItem.target = self
        accessibilityItem.target = self
        quitItem.target = self

        refreshMenuTitles()
        setAccessibilityTrusted(false)

        menu.addItem(preferencesItem)
        menu.addItem(.separator())
        menu.addItem(overlayItem)
        menu.addItem(clickThroughItem)
        menu.addItem(.separator())
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeStatusBarIcon() -> NSImage {
        let image = NSImage(size: StatusIcon.size, flipped: false) { _ in
            Self.drawStatusBarIcon()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawStatusBarIcon() {
        let strokeColor = NSColor.labelColor
        strokeColor.setStroke()
        strokeColor.setFill()

        let faceRect = NSRect(x: 3.0, y: 3.8, width: 12.0, height: 10.0)
        let facePath = NSBezierPath(roundedRect: faceRect, xRadius: 4.8, yRadius: 4.8)
        facePath.lineWidth = StatusIcon.lineWidth

        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 5.2, y: 12.2))
        leftEar.line(to: NSPoint(x: 6.9, y: 16.0))
        leftEar.line(to: NSPoint(x: 8.2, y: 12.6))
        leftEar.close()

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 9.8, y: 12.6))
        rightEar.line(to: NSPoint(x: 11.1, y: 16.0))
        rightEar.line(to: NSPoint(x: 12.8, y: 12.2))
        rightEar.close()

        leftEar.fill()
        rightEar.fill()
        facePath.stroke()

        let leftEye = NSBezierPath(ovalIn: NSRect(x: 6.2, y: 8.5, width: 1.5, height: 2.4))
        let rightEye = NSBezierPath(ovalIn: NSRect(x: 10.3, y: 8.5, width: 1.5, height: 2.4))
        leftEye.fill()
        rightEye.fill()

        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 9.0, y: 7.4))
        nose.line(to: NSPoint(x: 8.1, y: 6.6))
        nose.line(to: NSPoint(x: 9.9, y: 6.6))
        nose.close()
        nose.fill()

        let mouth = NSBezierPath()
        mouth.lineWidth = 1.0
        mouth.move(to: NSPoint(x: 9.0, y: 6.5))
        mouth.line(to: NSPoint(x: 9.0, y: 5.7))
        mouth.move(to: NSPoint(x: 9.0, y: 5.7))
        mouth.curve(
            to: NSPoint(x: 7.6, y: 5.4),
            controlPoint1: NSPoint(x: 8.7, y: 5.2),
            controlPoint2: NSPoint(x: 8.2, y: 5.1)
        )
        mouth.move(to: NSPoint(x: 9.0, y: 5.7))
        mouth.curve(
            to: NSPoint(x: 10.4, y: 5.4),
            controlPoint1: NSPoint(x: 9.3, y: 5.2),
            controlPoint2: NSPoint(x: 9.8, y: 5.1)
        )
        mouth.stroke()
    }

    private func refreshMenuTitles() {
        overlayItem.title = overlayVisible ? "Hide Overlay" : "Show Overlay"
        clickThroughItem.title = clickThroughEnabled ? "Disable Click-Through" : "Enable Click-Through"
    }

    @objc private func toggleOverlay() {
        onToggleOverlay?()
    }

    @objc private func openPreferences() {
        onOpenPreferences?()
    }

    @objc private func toggleClickThrough() {
        onToggleClickThrough?()
    }

    @objc private func requestAccessibility() {
        onRequestAccessibility?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
