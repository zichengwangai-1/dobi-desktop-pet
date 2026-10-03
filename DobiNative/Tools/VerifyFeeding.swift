import AppKit
import DobiCore

// A native drag-protocol fixture. The view, pasteboard, file service, decoder,
// video queue, and layer all use the actual production implementation.
final class FileDrop: NSObject, NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    var draggingDestinationWindow: NSWindow? = nil
    var draggingSourceOperationMask: NSDragOperation = .move
    var draggingLocation: NSPoint = .zero
    var draggedImageLocation: NSPoint = .zero
    var draggedImage: NSImage? = nil
    var draggingSource: Any? = nil
    var draggingSequenceNumber: Int = 1
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight = .none
    init(files: [URL]) {
        draggingPasteboard = NSPasteboard.withUniqueName()
        super.init()
        draggingPasteboard.writeObjects(files.map { $0 as NSURL })
    }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions,
                                for view: NSView?, classes classArray: [AnyClass],
                                searchOptions: [NSPasteboard.ReadingOptionKey: Any],
                                using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}

@main
struct VerifyFeeding {
    static func main() throws {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let manager = FileManager.default
        let fixture = manager.temporaryDirectory.appendingPathComponent("dobi-drop-\(UUID().uuidString)")
        try manager.createDirectory(at: fixture, withIntermediateDirectories: true)
        let a = fixture.appendingPathComponent("meal-a.txt"), b = fixture.appendingPathComponent("meal-b.txt")
        try Data("disposable integration fixture".utf8).write(to: a)
        try Data("disposable integration fixture".utf8).write(to: b)
        let panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        let view = PetView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        panel.contentView = view
        let playback = Playback(view: view, store: PetStore())
        var results: [FileFeedingResult] = []
        view.onFilesDropped = { files in
            let result = FileFeedingService().consume(files)
            precondition(result.failures.isEmpty, "Test file could not be moved to Trash")
            results.append(result)
            if !result.trashed.isEmpty { playback.feed() }
        }
        view.onInteract = { playback.interact() }
        playback.onFailure = { fatalError($0) }
        let dropA = FileDrop(files: [a]), dropB = FileDrop(files: [b])
        let invalid = FileDrop(files: [])
        invalid.draggingPasteboard.setString("ordinary text", forType: .string)
        precondition(!view.prepareForDragOperation(invalid) && !view.performDragOperation(invalid), "Non-files must be rejected")
        precondition(view.draggingEntered(dropA) == .move && view.fileDragActive)
        precondition(view.prepareForDragOperation(dropA) && view.performDragOperation(dropA))
        precondition(!manager.fileExists(atPath: a.path) && playback.isEating)
        var timers: [Timer] = []
        func after(_ seconds: TimeInterval, _ block: @escaping () -> Void) {
            let timer = Timer(timeInterval: seconds, repeats: false) { _ in block() }
            RunLoop.main.add(timer, forMode: .common)
            timers.append(timer)
        }
        after(0.7) {
            precondition(view.draggingEntered(dropB) == .move)
            precondition(view.performDragOperation(dropB))
            precondition(!manager.fileExists(atPath: b.path) && playback.isEating)
            _ = view.accessibilityPerformPress()
            precondition(playback.isEating, "Clicks must not interrupt continuous eating")
            guard let contents = view.layer?.contents else { fatalError("No eating frame rendered") }
            let image = contents as! CGImage
            let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
            try! png.write(to: fixture.appendingPathComponent("eating-frame.png"))
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = CGContext(data: &pixels, width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width*4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
            precondition(alpha.min() == 0 && alpha.max() == 255, "Actual eating layer must preserve alpha")
            print("PASS: eating frame rendered with alpha 0..255")
        }
        after(2.4) {
            precondition(playback.isEating, "Second drop must extend eating past the first cycle")
            precondition(playback.renderedFrames > 45, "Eating must remain animated")
        }
        after(4.7) {
            precondition(!playback.isEating, "Ambient playback must resume after food stops")
            precondition(playback.renderedFrames > 100)
            for result in results {
                for entry in result.trashed { try! manager.moveItem(at: entry.trash, to: entry.original) }
            }
            playback.stop()
            for drop in [dropA, dropB, invalid] { drop.draggingPasteboard.releaseGlobally() }
            try! manager.removeItem(at: fixture)
            print("PASS: native file drops trash both fixtures, extend eating without restarting, ignore clicks while eating, and resume ambient playback")
            exit(0)
        }
        app.run()
    }
}
