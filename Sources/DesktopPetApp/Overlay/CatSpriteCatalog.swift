import AppKit

enum CatSpriteVariant: Equatable {
    case v2

    var metadataResource: String {
        switch self {
        case .v2:
            return "cat-v2-animations"
        }
    }

    func resource(_ pose: String) -> String {
        switch self {
        case .v2:
            return "cat-v2-\(pose)"
        }
    }
}

struct CatSpriteCatalog {
    let animations: [String: CatSpriteAnimation]

    static func load(variant: CatSpriteVariant) -> CatSpriteCatalog {
        do {
            let metadata = try SpriteMetadataManifest(resource: variant.metadataResource)
            let layoutRect = metadata.layoutRect.nsRect

            let idleTracked = try SpriteSheet(resource: variant.resource("idle"))
                .fullFrame()
                .withLayout(
                    layoutRect: layoutRect,
                    eyeSockets: metadata.frame(named: variant.resource("idle")).eyeSockets
                )
            let blinkClosed = try SpriteSheet(resource: variant.resource("blink"))
                .fullFrame()
                .withLayout(
                    layoutRect: layoutRect,
                    eyeSockets: metadata.frame(named: variant.resource("blink")).eyeSockets
                )
            let typing = try SpriteSheet(resource: variant.resource("typing"))
                .fullFrame()
                .withLayout(
                    layoutRect: layoutRect,
                    eyeSockets: metadata.frame(named: variant.resource("typing")).eyeSockets
                )
            let petting = try SpriteSheet(resource: variant.resource("petting"))
                .fullFrame()
                .withLayout(
                    layoutRect: layoutRect,
                    eyeSockets: metadata.frame(named: variant.resource("petting")).eyeSockets
                )
            let stretch = try SpriteSheet(resource: variant.resource("stretch"))
                .fullFrame()
                .withLayout(
                    layoutRect: layoutRect,
                    eyeSockets: metadata.frame(named: variant.resource("stretch")).eyeSockets
                )
            let overheated = try SpriteSheet(resource: variant.resource("overheated"))
                .fullFrame()
                .withLayout(
                    layoutRect: layoutRect,
                    eyeSockets: metadata.frame(named: variant.resource("overheated")).eyeSockets
                )
            let idleLoop = blinkingLoop(idle: idleTracked, blink: blinkClosed)

            let animations: [String: CatSpriteAnimation] = [
                CatMood.idle.rawValue: CatSpriteAnimation(
                    fps: 6,
                    frames: idleLoop
                ),
                CatMood.watching.rawValue: CatSpriteAnimation(
                    fps: 6,
                    frames: idleLoop
                ),
                CatMood.dragging.rawValue: CatSpriteAnimation(
                    fps: 1,
                    frames: [stretch]
                ),
                CatMood.typing.rawValue: CatSpriteAnimation(
                    fps: 1,
                    frames: [typing]
                ),
                CatMood.excited.rawValue: CatSpriteAnimation(
                    fps: 1,
                    frames: [typing]
                ),
                CatMood.overheated.rawValue: CatSpriteAnimation(
                    fps: 1,
                    frames: [overheated]
                ),
                CatMood.petting.rawValue: CatSpriteAnimation(
                    fps: 1,
                    frames: [petting]
                ),
                CatMood.sleepy.rawValue: CatSpriteAnimation(
                    fps: 1,
                    frames: [blinkClosed]
                ),
                CatMood.reminding.rawValue: CatSpriteAnimation(
                    fps: 1,
                    frames: [stretch]
                ),
                "walking": CatSpriteAnimation(
                    fps: 1,
                    frames: [idleTracked]
                )
            ]

            return CatSpriteCatalog(animations: animations)
        } catch {
            fatalError("Failed to load cat sprite catalog: \(error)")
        }
    }

    static func loadDefault() -> CatSpriteCatalog {
        load(variant: .v2)
    }

    func animationKey(for visualState: CatVisualState) -> String {
        switch visualState.motion {
        case .walkingLeft, .walkingRight:
            return "walking"
        case .idle:
            return visualState.mood.rawValue
        }
    }

    func animation(forKey key: String) -> CatSpriteAnimation {
        animations[key] ?? animations[CatMood.idle.rawValue]!
    }

    private static func blinkingLoop(idle: CatSpriteFrame, blink: CatSpriteFrame) -> [CatSpriteFrame] {
        Array(repeating: idle, count: 12) + [blink, idle]
    }
}

struct CatSpriteAnimation {
    let fps: Double
    let frames: [CatSpriteFrame]
}

struct CatSpriteFrame {
    let image: NSImage
    let sourceRect: NSRect
    let canvasSize: NSSize
    let contentRect: NSRect
    let layoutRect: NSRect
    let eyeSockets: [CatEyeSocket]

    func withLayout(
        layoutRect: NSRect,
        eyeSockets: [CatEyeSocket]
    ) -> CatSpriteFrame {
        CatSpriteFrame(
            image: image,
            sourceRect: sourceRect,
            canvasSize: canvasSize,
            contentRect: contentRect,
            layoutRect: layoutRect,
            eyeSockets: eyeSockets
        )
    }
}

struct CatEyeSocket {
    let rect: NSRect
}

private struct SpriteSheet {
    let image: NSImage
    let bitmap: NSBitmapImageRep

    var size: NSSize {
        NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
    }

    init(resource: String) throws {
        guard let url = ResourceLocator.url(forResource: resource, withExtension: "png") else {
            throw SpriteSheetError.missingResource(resource)
        }

        guard
            let image = NSImage(contentsOf: url),
            let tiffRepresentation = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else {
            throw SpriteSheetError.invalidImage(resource)
        }

        self.image = image
        self.bitmap = bitmap
    }

    func fullFrame() -> CatSpriteFrame {
        let sourceRect = NSRect(origin: .zero, size: size)
        return CatSpriteFrame(
            image: image,
            sourceRect: sourceRect,
            canvasSize: sourceRect.size,
            contentRect: trimmedContentRect(in: sourceRect),
            layoutRect: trimmedContentRect(in: sourceRect),
            eyeSockets: []
        )
    }

    private func trimmedContentRect(in sourceRect: NSRect) -> NSRect {
        let minX = max(0, Int(sourceRect.minX.rounded(.down)))
        let minY = max(0, Int(sourceRect.minY.rounded(.down)))
        let maxX = min(bitmap.pixelsWide, Int(sourceRect.maxX.rounded(.up)))
        let maxY = min(bitmap.pixelsHigh, Int(sourceRect.maxY.rounded(.up)))

        var foundOpaquePixel = false
        var trimmedMinX = maxX
        var trimmedMinY = maxY
        var trimmedMaxX = minX
        var trimmedMaxY = minY

        for y in minY..<maxY {
            for x in minX..<maxX {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.02 else {
                    continue
                }

                foundOpaquePixel = true
                trimmedMinX = min(trimmedMinX, x)
                trimmedMinY = min(trimmedMinY, y)
                trimmedMaxX = max(trimmedMaxX, x)
                trimmedMaxY = max(trimmedMaxY, y)
            }
        }

        guard foundOpaquePixel else {
            return NSRect(origin: .zero, size: sourceRect.size)
        }

        return NSRect(
            x: CGFloat(trimmedMinX - minX),
            y: CGFloat(trimmedMinY - minY),
            width: CGFloat((trimmedMaxX - trimmedMinX) + 1),
            height: CGFloat((trimmedMaxY - trimmedMinY) + 1)
        )
    }

    enum SpriteSheetError: Error {
        case missingResource(String)
        case invalidImage(String)
    }
}

private struct SpriteMetadataManifest: Decodable {
    let layoutRect: SpriteRect
    let frames: [String: SpriteFrameMetadata]

    init(resource: String) throws {
        guard let url = ResourceLocator.url(forResource: resource, withExtension: "json") else {
            throw MetadataError.missingResource(resource)
        }

        let data = try Data(contentsOf: url)
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    func frame(named resource: String) throws -> SpriteFrameMetadata {
        guard let frame = frames[resource] else {
            throw MetadataError.missingFrame(resource)
        }

        return frame
    }

    enum MetadataError: Error {
        case missingResource(String)
        case missingFrame(String)
    }
}

private struct SpriteFrameMetadata: Decodable {
    let eyeSocketsTopLeft: [SpriteRect]

    var eyeSockets: [CatEyeSocket] {
        eyeSocketsTopLeft.map { CatEyeSocket(rect: $0.nsRect) }
    }
}

private struct SpriteRect: Decodable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    var nsRect: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}
