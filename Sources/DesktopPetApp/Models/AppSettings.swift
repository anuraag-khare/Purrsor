import AppKit

struct OverlayTextColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let white = OverlayTextColor(
        red: 1.0,
        green: 1.0,
        blue: 1.0,
        alpha: 1.0
    )

    init(
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: NSColor) {
        let resolved = color.usingColorSpace(.sRGB) ?? .white
        red = Double(resolved.redComponent)
        green = Double(resolved.greenComponent)
        blue = Double(resolved.blueComponent)
        alpha = Double(resolved.alphaComponent)
    }

    var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}

struct AppSettings: Codable, Equatable {
    static let reminderOptionsInMinutes = [0, 1, 5, 10, 20, 30, 45, 60]
    static let sleepDelayOptionsInSeconds = [0, 10, 12, 20, 30, 60, 120, 300]
    static let overlayScaleOptions = [1.0, 1.5]

    var overlayOriginX: Double
    var overlayOriginY: Double
    var clickThroughEnabled: Bool
    var overlayVisible: Bool
    var wanderingEnabled: Bool
    var textBubbleVisible: Bool
    var keysPerSecondVisible: Bool
    var launchAtLoginEnabled: Bool
    var bubbleTextColor: OverlayTextColor
    var typingIndicatorTextColor: OverlayTextColor
    var overlayScale: Double
    var stretchReminderMinutes: Int
    var sleepDelaySeconds: Int

    static let defaultValue = AppSettings(
        overlayOriginX: 80,
        overlayOriginY: 80,
        clickThroughEnabled: false,
        overlayVisible: true,
        wanderingEnabled: true,
        textBubbleVisible: true,
        keysPerSecondVisible: true,
        launchAtLoginEnabled: false,
        bubbleTextColor: .white,
        typingIndicatorTextColor: .white,
        overlayScale: 1.0,
        stretchReminderMinutes: 20,
        sleepDelaySeconds: 12
    )

    var clampedStretchReminderMinutes: Int {
        Self.reminderOptionsInMinutes.contains(stretchReminderMinutes)
            ? stretchReminderMinutes
            : Self.defaultValue.stretchReminderMinutes
    }

    var clampedSleepDelaySeconds: Int {
        Self.sleepDelayOptionsInSeconds.contains(sleepDelaySeconds)
            ? sleepDelaySeconds
            : Self.defaultValue.sleepDelaySeconds
    }

    var clampedOverlayScale: Double {
        Self.overlayScaleOptions.contains(overlayScale)
            ? overlayScale
            : Self.defaultValue.overlayScale
    }

    init(
        overlayOriginX: Double,
        overlayOriginY: Double,
        clickThroughEnabled: Bool,
        overlayVisible: Bool,
        wanderingEnabled: Bool,
        textBubbleVisible: Bool,
        keysPerSecondVisible: Bool,
        launchAtLoginEnabled: Bool,
        bubbleTextColor: OverlayTextColor,
        typingIndicatorTextColor: OverlayTextColor,
        overlayScale: Double,
        stretchReminderMinutes: Int,
        sleepDelaySeconds: Int
    ) {
        self.overlayOriginX = overlayOriginX
        self.overlayOriginY = overlayOriginY
        self.clickThroughEnabled = clickThroughEnabled
        self.overlayVisible = overlayVisible
        self.wanderingEnabled = wanderingEnabled
        self.textBubbleVisible = textBubbleVisible
        self.keysPerSecondVisible = keysPerSecondVisible
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.bubbleTextColor = bubbleTextColor
        self.typingIndicatorTextColor = typingIndicatorTextColor
        self.overlayScale = overlayScale
        self.stretchReminderMinutes = stretchReminderMinutes
        self.sleepDelaySeconds = sleepDelaySeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.defaultValue

        overlayOriginX = try container.decodeIfPresent(Double.self, forKey: .overlayOriginX) ?? defaults.overlayOriginX
        overlayOriginY = try container.decodeIfPresent(Double.self, forKey: .overlayOriginY) ?? defaults.overlayOriginY
        clickThroughEnabled = try container.decodeIfPresent(Bool.self, forKey: .clickThroughEnabled) ?? defaults.clickThroughEnabled
        overlayVisible = try container.decodeIfPresent(Bool.self, forKey: .overlayVisible) ?? defaults.overlayVisible
        wanderingEnabled = try container.decodeIfPresent(Bool.self, forKey: .wanderingEnabled) ?? defaults.wanderingEnabled
        textBubbleVisible = try container.decodeIfPresent(Bool.self, forKey: .textBubbleVisible) ?? defaults.textBubbleVisible
        keysPerSecondVisible = try container.decodeIfPresent(Bool.self, forKey: .keysPerSecondVisible) ?? defaults.keysPerSecondVisible
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? defaults.launchAtLoginEnabled
        bubbleTextColor = try container.decodeIfPresent(OverlayTextColor.self, forKey: .bubbleTextColor) ?? defaults.bubbleTextColor
        typingIndicatorTextColor = try container.decodeIfPresent(OverlayTextColor.self, forKey: .typingIndicatorTextColor) ?? defaults.typingIndicatorTextColor
        overlayScale = try container.decodeIfPresent(Double.self, forKey: .overlayScale) ?? defaults.overlayScale
        stretchReminderMinutes = try container.decodeIfPresent(Int.self, forKey: .stretchReminderMinutes) ?? defaults.stretchReminderMinutes
        sleepDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .sleepDelaySeconds) ?? defaults.sleepDelaySeconds
    }
}
