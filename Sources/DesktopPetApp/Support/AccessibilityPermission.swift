import ApplicationServices

@MainActor
enum AccessibilityPermission {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func promptIfNeeded() {
        guard !isTrusted() else {
            return
        }

        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }
}
