import AppKit

@MainActor
final class CatOverlayView: NSView {
    private enum EyeRendering {
        static let socketFillColor = NSColor(
            srgbRed: 0.97,
            green: 0.92,
            blue: 0.30,
            alpha: 1.0
        )
        static let typingReferenceSocketSize = NSSize(width: 27, height: 38)
        static let minimumPupilSize = NSSize(width: 4.5, height: 5.5)
        static let pupilWidthRatio: CGFloat = 0.30
        static let pupilHeightRatio: CGFloat = 0.42
        static let baseOverlaySize = NSSize(width: 180, height: 180)
        static let idleBasePupilSize = NSSize(width: 8.0, height: 8.8)
        static let closeCursorDeadZone: CGFloat = 10
        static let sharedGazeFalloff: CGFloat = 42
    }

    var onPet: (() -> Void)?
    var onDragChange: ((Bool) -> Void)?

    private var spriteVariant: CatSpriteVariant = .v2
    private var spriteCatalog = CatSpriteCatalog.loadDefault()
    private var visualState = CatVisualState.idle
    private var currentAnimationKey = CatMood.idle.rawValue
    private var currentFrameIndex = 0
    private var currentAnimation: CatSpriteAnimation?
    private var animationTimer: Timer?
    private var mouseDownLocation: NSPoint?
    private var isDraggingGesture = false
    private var showsTextBubble = true
    private var showsKeysPerSecond = true
    private var bubbleTextColor = NSColor.white
    private var typingIndicatorTextColor = NSColor.white
    private var cursorLocationInView: NSPoint?
    private var isHovering = false

    override var isOpaque: Bool {
        false
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAnimation(forKey: currentAnimationKey)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func render(_ state: CatVisualState) {
        let nextAnimationKey = spriteCatalog.animationKey(for: state)
        let animationChanged = nextAnimationKey != currentAnimationKey
        visualState = state

        if animationChanged {
            configureAnimation(forKey: nextAnimationKey)
        }

        needsDisplay = true
    }

    func setSpriteVariant(_ variant: CatSpriteVariant) {
        guard spriteVariant != variant else {
            return
        }

        spriteVariant = variant
        spriteCatalog = CatSpriteCatalog.load(variant: variant)
        configureAnimation(forKey: spriteCatalog.animationKey(for: visualState))
        needsDisplay = true
    }

    func setTextBubbleVisible(_ visible: Bool) {
        guard showsTextBubble != visible else {
            return
        }

        showsTextBubble = visible
        needsDisplay = true
    }

    func setKeysPerSecondVisible(_ visible: Bool) {
        guard showsKeysPerSecond != visible else {
            return
        }

        showsKeysPerSecond = visible
        needsDisplay = true
    }

    func setBubbleTextColor(_ color: NSColor) {
        let resolved = color.usingColorSpace(.sRGB) ?? color
        guard !bubbleTextColor.isEqual(resolved) else {
            return
        }

        bubbleTextColor = resolved
        needsDisplay = true
    }

    func setTypingIndicatorTextColor(_ color: NSColor) {
        let resolved = color.usingColorSpace(.sRGB) ?? color
        guard !typingIndicatorTextColor.isEqual(resolved) else {
            return
        }

        typingIndicatorTextColor = resolved
        needsDisplay = true
    }

    func updateCursor(locationInView: NSPoint?, isHovering: Bool) {
        let previousLocation = cursorLocationInView
        let previousHoverState = self.isHovering
        let locationChanged = {
            guard let previousLocation, let locationInView else {
                return (previousLocation == nil) != (locationInView == nil)
            }

            let deltaX = abs(previousLocation.x - locationInView.x)
            let deltaY = abs(previousLocation.y - locationInView.y)
            return deltaX > 1 || deltaY > 1
        }()

        cursorLocationInView = locationInView
        self.isHovering = isHovering

        guard locationChanged || previousHoverState != isHovering else {
            return
        }

        guard shouldRenderDynamicPupils,
              currentAnimation?.frames[currentFrameIndex].eyeSockets.isEmpty == false else {
            return
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.clear.setFill()
        dirtyRect.fill()

        drawMessageBubble()
        drawCat()
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = convert(event.locationInWindow, from: nil)
        isDraggingGesture = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownLocation else {
            return
        }

        let currentLocation = convert(event.locationInWindow, from: nil)
        let distance = hypot(currentLocation.x - mouseDownLocation.x, currentLocation.y - mouseDownLocation.y)

        guard distance >= 8, !isDraggingGesture else {
            return
        }

        isDraggingGesture = true
        onDragChange?(true)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownLocation = nil
            isDraggingGesture = false
        }

        guard let mouseDownLocation else {
            return
        }

        let mouseUpLocation = convert(event.locationInWindow, from: nil)
        let distance = hypot(mouseUpLocation.x - mouseDownLocation.x, mouseUpLocation.y - mouseDownLocation.y)

        if isDraggingGesture {
            onDragChange?(false)
            return
        }

        if distance < 6 {
            onPet?()
        }
    }

    private func drawMessageBubble() {
        guard showsTextBubble else {
            return
        }

        let bubbleRect = NSRect(x: 16, y: bounds.height - 48, width: bounds.width - 32, height: 30)
        let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: 10, yRadius: 10)

        NSColor(calibratedWhite: 0.10, alpha: 0.92).setFill()
        bubblePath.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let bubbleText = "\(visualState.mood.label)  \(visualState.message)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: bubbleTextColor,
            .paragraphStyle: paragraph
        ]

        bubbleText.draw(
            in: bubbleRect.insetBy(dx: 8, dy: 7),
            withAttributes: attributes
        )
    }

    private func drawCat() {
        guard let frame = currentAnimation?.frames[currentFrameIndex] else {
            return
        }

        let availableRect = catAvailableRect()
        guard availableRect.width > 0, availableRect.height > 0 else {
            return
        }

        let drawRect = rectForCurrentFrame(frame, in: availableRect)
        let previousInterpolation = NSGraphicsContext.current?.imageInterpolation ?? .default
        NSGraphicsContext.current?.imageInterpolation = .none

        NSGraphicsContext.saveGraphicsState()

        if shouldMirrorCurrentFrame {
            let transform = NSAffineTransform()
            transform.translateX(by: drawRect.midX, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.translateX(by: -drawRect.midX, yBy: 0)
            transform.concat()
        }

        frame.image.draw(
            in: drawRect,
            from: frame.sourceRect,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: nil
        )

        NSGraphicsContext.restoreGraphicsState()
        drawPupils(for: frame, in: drawRect)
        NSGraphicsContext.current?.imageInterpolation = previousInterpolation
        drawFooterText()
    }

    private func drawPupils(for frame: CatSpriteFrame, in drawRect: NSRect) {
        guard shouldRenderDynamicPupils, !frame.eyeSockets.isEmpty else {
            return
        }

        let pupilColor = NSColor.black.withAlphaComponent(0.92)

        let socketRects = frame.eyeSockets.map {
            mapSourceRect(
                $0.rect,
                from: frame.sourceRect,
                to: drawRect,
                mirrored: shouldMirrorCurrentFrame
            )
        }
        let socketBackgroundRects = socketRects.compactMap { socketRect -> NSRect? in
            let insetX = min(
                max(0.5, socketRect.width * 0.08),
                max(0, (socketRect.width / 2.0) - 0.5)
            )
            let insetY = min(
                max(0.5, socketRect.height * 0.08),
                max(0, (socketRect.height / 2.0) - 0.5)
            )
            let insetRect = socketRect
                .insetBy(dx: insetX, dy: insetY)
                .standardized
                .integral

            guard
                insetRect.width.isFinite,
                insetRect.height.isFinite,
                insetRect.width >= 2,
                insetRect.height >= 2
            else {
                return nil
            }

            return insetRect
        }
        guard !socketBackgroundRects.isEmpty else {
            return
        }
        let scaleX = drawRect.width / max(frame.sourceRect.width, 1)
        let scaleY = drawRect.height / max(frame.sourceRect.height, 1)
        let preferredTypingPupilSize = NSSize(
            width: max(
                EyeRendering.minimumPupilSize.width,
                EyeRendering.typingReferenceSocketSize.width * scaleX * EyeRendering.pupilWidthRatio
            ),
            height: max(
                EyeRendering.minimumPupilSize.height,
                EyeRendering.typingReferenceSocketSize.height * scaleY * EyeRendering.pupilHeightRatio
            )
        )
        let availablePupilWidth = max(1, (socketBackgroundRects.map(\.width).min() ?? preferredTypingPupilSize.width) - 2)
        let availablePupilHeight = max(1, (socketBackgroundRects.map(\.height).min() ?? preferredTypingPupilSize.height) - 2)
        let typingPupilSize = NSSize(
            width: max(1, min(
                preferredTypingPupilSize.width,
                availablePupilWidth
            )),
            height: max(1, min(
                preferredTypingPupilSize.height,
                availablePupilHeight
            ))
        )
        let overlayScaleFactor = min(
            bounds.width / EyeRendering.baseOverlaySize.width,
            bounds.height / EyeRendering.baseOverlaySize.height
        )
        let usesCompactIdlePupils = visualState.mood == .idle || visualState.mood == .watching
        let sharedPupilSize = usesCompactIdlePupils
            ? NSSize(
                width: min(
                    availablePupilWidth,
                    max(1, EyeRendering.idleBasePupilSize.width * overlayScaleFactor)
                ),
                height: min(
                    availablePupilHeight,
                    max(1, EyeRendering.idleBasePupilSize.height * overlayScaleFactor)
                )
            )
            : typingPupilSize
        let sharedGazeVector = sharedPupilDirection(for: socketBackgroundRects)

        for socketBackgroundRect in socketBackgroundRects {
            let socketCornerRadiusX = safeCornerRadius(for: socketBackgroundRect.width, ratio: 0.18)
            let socketCornerRadiusY = safeCornerRadius(for: socketBackgroundRect.height, ratio: 0.18)
            let socketBackgroundPath = NSBezierPath(
                roundedRect: socketBackgroundRect,
                xRadius: socketCornerRadiusX,
                yRadius: socketCornerRadiusY
            )
            EyeRendering.socketFillColor.setFill()
            socketBackgroundPath.fill()

            let center = NSPoint(x: socketBackgroundRect.midX, y: socketBackgroundRect.midY)
            let localPupilSize = NSSize(
                width: min(sharedPupilSize.width, max(1, socketBackgroundRect.width - 1)),
                height: min(sharedPupilSize.height, max(1, socketBackgroundRect.height - 1))
            )
            let offset = pupilOffset(
                using: sharedGazeVector,
                socketRect: socketBackgroundRect,
                pupilSize: localPupilSize
            )
            let pupilRect = NSRect(
                x: center.x - (localPupilSize.width / 2.0) + offset.x,
                y: center.y - (localPupilSize.height / 2.0) + offset.y,
                width: localPupilSize.width,
                height: localPupilSize.height
            )
            .standardized
            .integral
            guard
                pupilRect.width.isFinite,
                pupilRect.height.isFinite,
                pupilRect.width >= 1,
                pupilRect.height >= 1
            else {
                continue
            }
            let pupilPath = NSBezierPath(
                roundedRect: pupilRect,
                xRadius: safeCornerRadius(for: pupilRect.width, ratio: 0.35),
                yRadius: safeCornerRadius(for: pupilRect.height, ratio: 0.35)
            )
            pupilColor.setFill()
            pupilPath.fill()
        }
    }

    private func sharedPupilDirection(for socketRects: [NSRect]) -> CGPoint {
        guard
            let cursorLocationInView,
            !socketRects.isEmpty
        else {
            return .zero
        }

        let averageCenter = socketRects.reduce(CGPoint.zero) { partial, rect in
            CGPoint(
                x: partial.x + rect.midX,
                y: partial.y + rect.midY
            )
        }
        let gazeCenter = CGPoint(
            x: averageCenter.x / CGFloat(socketRects.count),
            y: averageCenter.y / CGFloat(socketRects.count)
        )
        let eyeBounds = socketRects.dropFirst().reduce(socketRects[0]) { partial, rect in
            partial.union(rect)
        }
        let deltaX = cursorLocationInView.x - gazeCenter.x
        let deltaY = cursorLocationInView.y - gazeCenter.y
        let distance = hypot(deltaX, deltaY)
        let deadZone = max(
            EyeRendering.closeCursorDeadZone,
            min(eyeBounds.width, eyeBounds.height) * 0.18
        )

        guard distance > deadZone else {
            return .zero
        }

        let normalizedX = deltaX / max(distance, 0.001)
        let normalizedY = deltaY / max(distance, 0.001)
        let intensity = min(1, (distance - deadZone) / EyeRendering.sharedGazeFalloff)

        return CGPoint(
            x: normalizedX * intensity,
            y: normalizedY * intensity
        )
    }

    private func pupilOffset(using sharedGazeVector: CGPoint, socketRect: NSRect, pupilSize: NSSize) -> CGPoint {
        let horizontalTravel = max(0, (socketRect.width - pupilSize.width) / 2.0)
        let verticalTravel = max(0, (socketRect.height - pupilSize.height) / 2.0)
        let motionScale: CGFloat = (visualState.mood == .idle || visualState.mood == .watching) ? 0.88 : 0.64
        let maxHorizontalOffset = horizontalTravel * motionScale
        let maxVerticalOffset = verticalTravel * motionScale

        return CGPoint(
            x: max(-maxHorizontalOffset, min(maxHorizontalOffset, sharedGazeVector.x * maxHorizontalOffset)),
            y: max(-maxVerticalOffset, min(maxVerticalOffset, sharedGazeVector.y * maxVerticalOffset))
        )
    }

    private func safeCornerRadius(for dimension: CGFloat, ratio: CGFloat) -> CGFloat {
        guard dimension.isFinite, dimension > 1 else {
            return 0
        }

        return min(
            max(0, (dimension / 2.0) - 0.5),
            max(1, dimension * ratio)
        )
    }

    private func mapSourceRect(
        _ sourceRect: NSRect,
        from imageRect: NSRect,
        to destinationRect: NSRect,
        mirrored: Bool
    ) -> NSRect {
        let normalizedMinX = (sourceRect.minX - imageRect.minX) / imageRect.width
        let normalizedMaxX = (sourceRect.maxX - imageRect.minX) / imageRect.width
        let normalizedMinY = (sourceRect.minY - imageRect.minY) / imageRect.height
        let normalizedMaxY = (sourceRect.maxY - imageRect.minY) / imageRect.height

        // The sampled sprite coordinates come from top-left image space.
        let minY = destinationRect.maxY - (normalizedMaxY * destinationRect.height)
        let maxY = destinationRect.maxY - (normalizedMinY * destinationRect.height)

        let minX: CGFloat
        let maxX: CGFloat

        if mirrored {
            minX = destinationRect.maxX - (normalizedMaxX * destinationRect.width)
            maxX = destinationRect.maxX - (normalizedMinX * destinationRect.width)
        } else {
            minX = destinationRect.minX + (normalizedMinX * destinationRect.width)
            maxX = destinationRect.minX + (normalizedMaxX * destinationRect.width)
        }

        return NSRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private func drawFooterText() {
        guard showsKeysPerSecond else {
            return
        }

        let footer = "\(visualState.wordsPerMinute) WPM"
        let textColor = visualState.mood == .overheated
            ? NSColor.systemRed.withAlphaComponent(0.98)
            : typingIndicatorTextColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: textColor
        ]

        footer.draw(
            at: NSPoint(x: 16, y: 8),
            withAttributes: attributes
        )
    }

    private var shouldMirrorCurrentFrame: Bool {
        visualState.motion == .walkingLeft
    }

    private var shouldRenderDynamicPupils: Bool {
        switch currentAnimationKey {
        case CatMood.idle.rawValue, CatMood.watching.rawValue, "walking":
            return true
        default:
            return false
        }
    }

    private func catAvailableRect() -> NSRect {
        let horizontalInset: CGFloat = 10
        let topInset: CGFloat = 58
        let bottomInset: CGFloat = 28

        return NSRect(
            x: horizontalInset,
            y: bottomInset,
            width: bounds.width - (horizontalInset * 2),
            height: bounds.height - topInset - bottomInset
        )
    }

    private func rectForCurrentFrame(_ frame: CatSpriteFrame, in availableRect: NSRect) -> NSRect {
        let layoutWidth = max(1, frame.layoutRect.width)
        let layoutHeight = max(1, frame.layoutRect.height)
        let scale = min(availableRect.width / layoutWidth, availableRect.height / layoutHeight)
        let scaledLayoutWidth = layoutWidth * scale
        let contentOrigin = NSPoint(
            x: availableRect.midX - (scaledLayoutWidth / 2.0),
            y: availableRect.minY
        )

        return NSRect(
            x: contentOrigin.x - (frame.layoutRect.minX * scale),
            y: contentOrigin.y - (frame.layoutRect.minY * scale),
            width: frame.canvasSize.width * scale,
            height: frame.canvasSize.height * scale
        )
    }

    private func configureAnimation(forKey key: String) {
        let animation = spriteCatalog.animation(forKey: key)
        currentAnimation = animation
        currentAnimationKey = key
        currentFrameIndex = 0
        animationTimer?.invalidate()
        animationTimer = nil

        guard animation.frames.count > 1 else {
            return
        }

        animationTimer = Timer.scheduledTimer(
            timeInterval: max(0.08, 1.0 / animation.fps),
            target: self,
            selector: #selector(advanceAnimationFrame),
            userInfo: nil,
            repeats: true
        )
        animationTimer?.tolerance = 0.03
    }

    @objc private func advanceAnimationFrame() {
        guard let currentAnimation else {
            return
        }

        currentFrameIndex = (currentFrameIndex + 1) % currentAnimation.frames.count
        needsDisplay = true
    }
}
