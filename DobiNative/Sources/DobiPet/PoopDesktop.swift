import AppKit

// The image keeps its real alpha, and only visible pixels receive clicks.
final class PoopView: NSView {
    var onClear: (() -> Void)?
    private let image: CGImage
    private let pixels: [UInt8]
    private var pointerDown = false
    override var isOpaque: Bool { false }

    init(image: CGImage, frame: NSRect) {
        self.image = image
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(data: &rgba, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        pixels = rgba
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.contents = image
        layer?.contentsGravity = .resizeAspect
        toolTip = "点击铲掉便便"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("便便，点击铲掉")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onClear?(); return true }
    func containsOpaquePoint(_ point: NSPoint) -> Bool {
        let scale = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
        guard scale > 0 else { return false }
        let left = (bounds.width - CGFloat(image.width) * scale) / 2
        let bottom = (bounds.height - CGFloat(image.height) * scale) / 2
        let x = Int(floor((point.x - left) / scale))
        let y = image.height - 1 - Int(floor((point.y - bottom) / scale))
        guard x >= 0 && y >= 0 && x < image.width && y < image.height else { return false }
        return pixels[(y * image.width + x) * 4 + 3] > 24
    }
    func updateMouseRouting() {
        guard !pointerDown, let window else { return }
        let point = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
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
    private let image: CGImage
    private(set) var panel: PetPanel?
    private(set) var view: PoopView?
    private var timer: Timer?
    var onClear: (() -> Void)?
    var origin: NSPoint? { panel?.frame.origin }
    private var size: NSSize { NSSize(width: 128, height: 128 * CGFloat(image.height) / CGFloat(image.width)) }

    init(imageURL: URL = Assets.poopImage) throws {
        guard let source = NSImage(contentsOf: imageURL),
              let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "DobiAssets", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "无法读取透明便便图片"])
        }
        image = cg
    }
    @discardableResult
    func showRandomly(avoiding petRect: NSRect) -> Bool {
        let screen = NSScreen.screens.max {
            $0.visibleFrame.intersection(petRect).size.area < $1.visibleFrame.intersection(petRect).size.area
        } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return false }
        let safe = area.insetBy(dx: 16, dy: 16)
        var origin = safe.origin
        for _ in 0..<50 {
            origin = NSPoint(x: CGFloat.random(in: safe.minX...max(safe.minX, safe.maxX - size.width)),
                             y: CGFloat.random(in: safe.minY...max(safe.minY, safe.maxY - size.height)))
            if !NSRect(origin: origin, size: size).intersects(petRect.insetBy(dx: -16, dy: -16)) { break }
        }
        show(at: origin)
        return true
    }
    func show(at origin: NSPoint) {
        dismiss()
        let panel = PetPanel(contentRect: NSRect(origin: origin, size: size),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "杜宾的便便"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        let view = PoopView(image: image, frame: NSRect(origin: .zero, size: size))
        view.onClear = { [weak self] in self?.onClear?() }
        panel.contentView = view
        self.panel = panel; self.view = view
        keepOnScreen()
        view.updateMouseRouting()
        panel.orderFrontRegardless()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.view?.updateMouseRouting() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    func keepOnScreen() {
        guard let panel else { return }
        let screen = NSScreen.screens.max {
            $0.visibleFrame.intersection(panel.frame).size.area < $1.visibleFrame.intersection(panel.frame).size.area
        } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: max(area.minX, min(panel.frame.minX, area.maxX - size.width)),
                                     y: max(area.minY, min(panel.frame.minY, area.maxY - size.height))))
    }
    func dismiss() {
        timer?.invalidate(); timer = nil
        panel?.close(); panel = nil; view = nil
    }
}

private extension NSSize {
    var area: CGFloat { max(0, width) * max(0, height) }
}
