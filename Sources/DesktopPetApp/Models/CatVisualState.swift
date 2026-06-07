import Foundation

enum CatMood: String, Codable {
    case idle
    case watching
    case dragging
    case typing
    case excited
    case overheated
    case petting
    case sleepy
    case reminding

    var label: String {
        switch self {
        case .idle:
            return "idle"
        case .watching:
            return "watching"
        case .dragging:
            return "drag"
        case .typing:
            return "typing"
        case .excited:
            return "hyped"
        case .overheated:
            return "overheat"
        case .petting:
            return "purring"
        case .sleepy:
            return "sleepy"
        case .reminding:
            return "stretch"
        }
    }
}

struct CatVisualState: Equatable {
    var mood: CatMood
    var motion: CatMotionState
    var keysPerSecond: Int
    var message: String

    var wordsPerMinute: Int {
        Int((Double(keysPerSecond) * 12.0).rounded())
    }

    static let idle = CatVisualState(
        mood: .idle,
        motion: .idle,
        keysPerSecond: 0,
        message: "waiting"
    )
}
