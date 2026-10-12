import AppKit
import QuartzCore
import DobiCore

// Shared images, including real alpha masks, are decoded once for all piles/editors.
final class FlowerSprites {
    let images: [FlowerKind: PoopSprite]
    init(root: URL = Assets.root.appendingPathComponent("Images/Flowers")) throws {
        var loaded: [FlowerKind: PoopSprite] = [:]
        for kind in FlowerKind.allCases {
            let url = root.appendingPathComponent("\(kind.rawValue).png")
            guard let source = NSImage(contentsOf: url),
                  let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw NSError(domain: "DobiAssets", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "无法读取透明小花素材：\(kind.rawValue)"])
            }
            let sprite = PoopSprite(image: cg)
            guard sprite.alpha.min() == 0, (sprite.alpha.max() ?? 0) > 64 else {
                throw NSError(domain: "DobiAssets", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "小花素材缺少有效的透明背景：\(kind.rawValue)"])
            }
            loaded[kind] = sprite
        }
        images = loaded
    }
}

class FlowerCanvas: NSView {
    let sprite: PoopSprite
    let flowers: FlowerSprites
    private let poopLayer = CALayer()
    private var flowerLayers: [UUID: CALayer] = [:]
    private var compositeAlpha: [UInt8]?
    private(set) var garden = FlowerGarden()
    var onInsert: ((NSPoint) -> Void)?
    var isEditing = false
    override var isOpaque: Bool { false }
    // This identical aspect ratio is used by the desktop and the enlarged editor.
    var poopRect: NSRect {
        let width = min(bounds.width * 0.64, bounds.height * 0.76)
        let height = width * CGFloat(sprite.image.height) / CGFloat(sprite.image.width)
        return NSRect(x: (bounds.width - width) / 2, y: bounds.height * 0.14, width: width, height: height)
    }
    init(sprite: PoopSprite, flowers: FlowerSprites, frame: NSRect) {
        self.sprite = sprite; self.flowers = flowers
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque = false; layer?.backgroundColor = NSColor.clear.cgColor
        poopLayer.contents = sprite.image
        poopLayer.contentsGravity = .resize
        layer?.addSublayer(poopLayer)
        updateGarden(FlowerGarden())
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func layout() {
        super.layout()
        positionLayers()
    }
    func updateGarden(_ garden: FlowerGarden, animatedID: UUID? = nil) {
        self.garden = garden
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let ids = Set(garden.flowers.map(\.id))
        for id in Array(flowerLayers.keys) where !ids.contains(id) {
            flowerLayers.removeValue(forKey: id)?.removeFromSuperlayer()
        }
        for flower in garden.flowers where flowerLayers[flower.id] == nil {
            let node = CALayer()
            node.contents = flowers.images[flower.kind]?.image
            node.anchorPoint = CGPoint(x: 0.5, y: 0.14)
            node.contentsGravity = .resize
            node.isOpaque = false
            flowerLayers[flower.id] = node
            layer?.addSublayer(node)
        }
        positionLayers()
        CATransaction.commit()
        if let id = animatedID, let node = flowerLayers[id] {
            let pop = CAKeyframeAnimation(keyPath: "transform.scale")
            pop.values = [0.15, 1.08, 0.97, 1.0]
            pop.keyTimes = [0, 0.6, 0.82, 1]
            pop.duration = 0.36
            node.add(pop, forKey: "insert")
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.14
            node.add(fade, forKey: "appear")
        }
        needsDisplay = true
    }
    private func positionLayers() {
        compositeAlpha = nil
        CATransaction.begin(); CATransaction.setDisableActions(true)
        poopLayer.frame = poopRect
        for flower in garden.flowers {
            guard let node = flowerLayers[flower.id], let image = flowers.images[flower.kind]?.image else { continue }
            let height = poopRect.width * flower.length
            let width = height * CGFloat(image.width) / CGFloat(image.height)
            node.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            node.position = CGPoint(x: poopRect.minX + poopRect.width * flower.x,
                                    y: poopRect.minY + poopRect.height * flower.y)
            node.setAffineTransform(CGAffineTransform(rotationAngle: flower.angle))
            // Bury the bottom of the stem: the flower emerges exactly at the clicked point.
            let mask = node.mask ?? CALayer()
            mask.backgroundColor = NSColor.black.cgColor
            mask.frame = CGRect(x: 0, y: height * 0.14, width: width, height: height * 0.86)
            node.mask = mask
        }
        CATransaction.commit()
    }
    func containsPoopPoint(_ point: NSPoint) -> Bool { sprite.contains(point, in: poopRect) }
    func containsOpaquePoint(_ point: NSPoint) -> Bool {
        guard bounds.contains(point) else { return false }
        if garden.flowers.isEmpty { return containsPoopPoint(point) }
        let width = Int(bounds.width), height = Int(bounds.height)
        guard width > 0, height > 0, let layer else { return false }
        if compositeAlpha == nil {
            // Sample the final rendered sprite, including rotated/antialiased petals.
            // The small alpha-only cache is rebuilt only when this pile's artwork changes.
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            if let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                layer.render(in: context)
            }
            compositeAlpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        }
        let x = min(width - 1, Int(point.x)), y = height - 1 - min(height - 1, Int(point.y))
        return compositeAlpha![y * width + x] > 24
    }
    @discardableResult
    func insert(at point: NSPoint) -> Bool {
        // Transparent margins and existing petals cannot create floating flowers.
        guard isEditing, containsPoopPoint(point) else { return false }
        onInsert?(NSPoint(x: (point.x - poopRect.minX) / poopRect.width,
                          y: (point.y - poopRect.minY) / poopRect.height))
        return true
    }
    override func mouseDown(with event: NSEvent) { if isEditing { insert(at: convert(event.locationInWindow, from: nil)) } }
    override func resetCursorRects() { if isEditing { addCursorRect(poopRect, cursor: .crosshair) } }
}

extension PoopSprite {
    func contains(_ point: NSPoint, in rect: NSRect) -> Bool {
        guard rect.width > 0, rect.height > 0, rect.contains(point) else { return false }
        let x = Int((point.x - rect.minX) / rect.width * CGFloat(image.width))
        let y = image.height - 1 - Int((point.y - rect.minY) / rect.height * CGFloat(image.height))
        guard x >= 0, y >= 0, x < image.width, y < image.height else { return false }
        return alpha[y * image.width + x] > 24
    }
}
