import AppKit
import DobiCore

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    var onInteract: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var menuProvider: (() -> NSMenu)?
    private var gesture = PointerGesture()
    private var anchor: NSPoint = .zero
    private var initialOrigin: NSPoint = .zero
    private(set) var pointerDown = false
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onInteract?(); return true }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.contentsGravity = .resizeAspect
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        setAccessibilityElement(true)
        setAccessibilityLabel("杜宾桌宠：单击互动，按住拖动，右键关闭")
        setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func mouseDown(with event: NSEvent) {
        pointerDown = true
        anchor = window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
        initialOrigin = window?.frame.origin ?? .zero
        gesture.begin(at: anchor)
    }
    override func mouseDragged(with event: NSEvent) {
        let point = window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
        if gesture.move(to: point) {
            window?.setFrameOrigin(NSPoint(x: initialOrigin.x + point.x - anchor.x,
                                          y: initialOrigin.y + point.y - anchor.y))
        }
    }
    override func mouseUp(with event: NSEvent) {
        pointerDown = false
        if gesture.shouldInteract { onInteract?() } else { onDragEnd?() }
    }
    override func rightMouseDown(with event: NSEvent) {
        pointerDown = true
        defer { pointerDown = false }
        if let menu = menuProvider?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}
