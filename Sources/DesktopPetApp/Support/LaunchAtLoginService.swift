import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    enum State: Equatable {
        case disabled
        case enabled
        case requiresApproval
    }

    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        state != .disabled
    }

    var state: State {
        Self.mapStatus(service.status)
    }

    static func currentIsEnabled() -> Bool {
        currentState() != .disabled
    }

    static func currentState() -> State {
        mapStatus(SMAppService.mainApp.status)
    }

    private static func mapStatus(_ status: SMAppService.Status) -> State {
        switch status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }

            return true
        } catch {
            fputs("Failed to update launch at login setting: \(error)\n", stderr)
            return false
        }
    }
}
