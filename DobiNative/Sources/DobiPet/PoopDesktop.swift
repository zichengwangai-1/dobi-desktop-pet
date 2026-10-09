import AppKit

// All poop windows share one decoded image and alpha mask, even as piles accumulate.
final class PoopSprite {
    let image: CGImage
    let alpha: [UInt8]
    init(image: CGImage) {
        self.image = image
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(data: &rgba, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        alpha = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
    }
}

// The image keeps its real alpha, and only visible pixels receive clicks.
final class PoopView: NSView {
    var onClear: (() -> Void)?
    private let sprite: PoopSprite
    private var pointerDown = false
    override var isOpaque: Bool { false }

    init(sprite: PoopSprite, frame: NSRect) {
        self.sprite = sprite
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.contents = sprite.image
        layer?.contentsGravity = .resizeAspect
        toolTip = "点击铲掉这坨便便"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("便便，点击铲掉这一坨")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onClear?(); return true }
    func containsOpaquePoint(_ point: NSPoint) -> Bool {
        let image = sprite.image
        let scale = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
        guard scale > 0 else { return false }
        let left = (bounds.width - CGFloat(image.width) * scale) / 2
        let bottom = (bounds.height - CGFloat(image.height) * scale) / 2
        let x = Int(floor((point.x - left) / scale))
        let y = image.height - 1 - Int(floor((point.y - bottom) / scale))
        guard x >= 0 && y >= 0 && x < image.width && y < image.height else { return false }
        return sprite.alpha[y * image.width + x] > 24
    }
    func updateMouseRouting(at mouseLocation: NSPoint) {
        guard !pointerDown, let window else { return }
        let point = convert(window.convertPoint(fromScreen: mouseLocation), from: nil)
        window.ignoresMouseEvents = !containsOpaquePoint(point)
    }
    override func mouseDown(with event: NSEvent) {
        pointerDown = containsOpaquePoint(convert(event.locationInWindow, from: nil))
    }
    override func mouseUp(with event: NSEvent) {
        let shouldClear = pointerDown && containsOpaquePoint(convert(event.locationInWindow, from: nil))
        pointerDown = false
        if shouldClear { onClear?() }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

final class PoopDesktop {
    private struct Entry { let panel: PetPanel; let view: PoopView }
    private let sprite: PoopSprite
    private var entries: [UUID: Entry] = [:]
    private var timer: Timer?
    var onClear: ((UUID) -> Void)?
    var records: [PoopRecord] {
        entries.map { PoopRecord(id: $0.key, position: $0.value.panel.frame.origin) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
    func panel(for id: UUID) -> PetPanel? { entries[id]?.panel }
    func view(for id: UUID) -> PoopView? { entries[id]?.view }
    private var size: NSSize { NSSize(width: 128, height: 128 * CGFloat(sprite.image.height) / CGFloat(sprite.image.width)) }

    init(imageURL: URL = Assets.poopImage) throws {
        guard let source = NSImage(contentsOf: imageURL),
              let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "DobiAssets", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "无法读取透明便便图片"])
        }
        sprite = PoopSprite(image: cg)
    }
    @discardableResult
    func showRandomly(avoiding petRect: NSRect) -> UUID? {
        let screen = NSScreen.screens.max {
            $0.visibleFrame.intersection(petRect).size.area < $1.visibleFrame.intersection(petRect).size.area
        } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return nil }
        let safe = area.insetBy(dx: 16, dy: 16)
        var origin = safe.origin
        for _ in 0..<50 {
            origin = NSPoint(x: CGFloat.random(in: safe.minX...max(safe.minX, safe.maxX - size.width)),
                             y: CGFloat.random(in: safe.minY...max(safe.minY, safe.maxY - size.height)))
            if !NSRect(origin: origin, size: size).intersects(petRect.insetBy(dx: -16, dy: -16)) { break }
        }
        let record = PoopRecord(position: origin)
        show(record)
        return record.id
    }
    func show(_ record: PoopRecord) {
        guard entries[record.id] == nil else { return }
        let panel = PetPanel(contentRect: NSRect(origin: record.position, size: size),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "杜宾的便便"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        let view = PoopView(sprite: sprite, frame: NSRect(origin: .zero, size: size))
        view.onClear = { [weak self] in self?.onClear?(record.id) }
        panel.contentView = view
        entries[record.id] = Entry(panel: panel, view: view)
        keepOnScreen(panel)
        view.updateMouseRouting(at: NSEvent.mouseLocation)
        panel.orderFrontRegardless()
        if timer == nil {
            let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                guard let self else { return }
                let mouse = NSEvent.mouseLocation
                for entry in self.entries.values { entry.view.updateMouseRouting(at: mouse) }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }
    func keepOnScreen() { for entry in entries.values { keepOnScreen(entry.panel) } }
    private func keepOnScreen(_ panel: PetPanel) {
        let screen = NSScreen.screens.max {
            $0.visibleFrame.intersection(panel.frame).size.area < $1.visibleFrame.intersection(panel.frame).size.area
        } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: max(area.minX, min(panel.frame.minX, area.maxX - size.width)),
                                     y: max(area.minY, min(panel.frame.minY, area.maxY - size.height))))
    }
    func remove(_ id: UUID) {
        entries.removeValue(forKey: id)?.panel.close()
        if entries.isEmpty { timer?.invalidate(); timer = nil }
    }
    func dismissAll() {
        timer?.invalidate(); timer = nil
        for entry in entries.values { entry.panel.close() }
        entries.removeAll()
    }
}

private extension NSSize {
    var area: CGFloat { max(0, width) * max(0, height) }
}
