import AppKit

@main
struct VerifyMouse {
    static func main() {
        _ = NSApplication.shared
        let panel = PetPanel(contentRect: NSRect(x: 100, y: 100, width: 300, height: 300),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let view = PetView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        panel.contentView = view
        var interactions = 0, drags = 0
        view.onInteract = { interactions += 1 }
        view.onDragEnd = { drags += 1 }
        func event(_ type: NSEvent.EventType, x: CGFloat, y: CGFloat) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: y), modifierFlags: [],
                              timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                              eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        view.mouseDown(with: event(.leftMouseDown, x: 150, y: 150))
        view.mouseDragged(with: event(.leftMouseDragged, x: 230, y: 200))
        precondition(panel.frame.origin == NSPoint(x: 180, y: 150), "Window must follow the held pointer")
        view.mouseUp(with: event(.leftMouseUp, x: 150, y: 150))
        precondition(drags == 1 && interactions == 0, "Drag release must never trigger sit/bark")
        view.mouseDown(with: event(.leftMouseDown, x: 150, y: 150))
        view.mouseUp(with: event(.leftMouseUp, x: 150, y: 150))
        precondition(interactions == 1, "Click must trigger exactly one interaction")
        precondition(!view.isOpaque, "Video view must be transparent")
        print("PASS: native mouse events move the window; dragging never interacts; clicking interacts once; video view is transparent.")
    }
}
