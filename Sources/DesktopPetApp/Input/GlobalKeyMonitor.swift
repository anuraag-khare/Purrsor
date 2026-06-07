import AppKit

@MainActor
final class GlobalKeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onKeyDown: (NSEvent) -> Void

    init(onKeyDown: @escaping (NSEvent) -> Void) {
        self.onKeyDown = onKeyDown
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else {
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.onKeyDown(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.onKeyDown(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}

// normal typing
// fast typing: asdflkasdj
