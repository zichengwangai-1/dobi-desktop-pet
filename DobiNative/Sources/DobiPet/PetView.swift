import AppKit
import DobiCore

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    var onInteract: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onFilesDropped: (([URL]) -> Void)?
    var menuProvider: (() -> NSMenu)?
    private var gesture = PointerGesture()
    private var anchor: NSPoint = .zero
    private var initialOrigin: NSPoint = .zero
    private(set) var pointerDown = false
    private(set) var fileDragActive = false
    static let fileReadingOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self], options: fileReadingOptions) as? [URL]) ?? []
    }
    static var externalFileDragInProgress: Bool {
        NSEvent.pressedMouseButtons & 1 != 0 &&
        NSPasteboard(name: .drag).canReadObject(forClasses: [NSURL.self], options: fileReadingOptions)
    }
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
        registerForDraggedTypes([.fileURL])
        toolTip = "拖文件给杜宾吃狗粮，文件会移入废纸篓；单击互动，按住拖动，右键关闭"
        setAccessibilityLabel("杜宾桌宠：拖文件喂食，单击互动，按住拖动，右键关闭")
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
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard onFilesDropped != nil, !Self.fileURLs(from: sender.draggingPasteboard).isEmpty else { return [] }
        fileDragActive = true
        window?.ignoresMouseEvents = false
        return acceptedOperation(sender)
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { fileDragActive = false }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onFilesDropped != nil && !Self.fileURLs(from: sender.draggingPasteboard).isEmpty
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { fileDragActive = false }
        let files = Self.fileURLs(from: sender.draggingPasteboard)
        guard !files.isEmpty, let onFilesDropped else { return false }
        onFilesDropped(files)
        return true
    }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { fileDragActive = false }
    private func acceptedOperation(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Finder provides move; other local file sources may offer copy only.
        for operation: NSDragOperation in [.move, .generic, .copy] {
            if sender.draggingSourceOperationMask.contains(operation) { return operation }
        }
        return []
    }
}
