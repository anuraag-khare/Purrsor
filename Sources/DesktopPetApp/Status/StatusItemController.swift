import AppKit

@MainActor
final class StatusItemController: NSObject {
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
        statusItem.button?.title = "CAT"

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
