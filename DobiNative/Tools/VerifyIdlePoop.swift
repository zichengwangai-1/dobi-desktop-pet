import AppKit
import DobiCore

@main
struct VerifyIdlePoop {
    static func main() throws {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let domain = "com.dobipet.poop-validation"
        precondition(Bundle.main.bundleIdentifier == domain, "Use a separate validation app bundle")
        UserDefaults.standard.removePersistentDomain(forName: domain)
        let adult = CommandLine.arguments.contains("--adult")
        let life = PetLife(birthday: adult ? Date(timeIntervalSinceNow: -259_201) : Date())
        UserDefaults.standard.set(try JSONEncoder().encode(life), forKey: "life")
        let store = PetStore()
        let panel = PetPanel(contentRect: NSRect(x: 100, y: 100, width: 300, height: 300),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        let view = PetView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        panel.contentView = view
        let playback = Playback(view: view, store: store)
        var clock: TimeInterval = 0
        let idle = try IdlePoopController(playback: playback, view: view, store: store, now: { clock })
        view.onInteract = { playback.interact() }
        playback.onFailure = { fatalError($0) }
        playback.startAmbient()
        idle.start()
        clock = 299; idle.tick()
        precondition(!playback.isPooping, "No animation before five minutes")
        _ = view.accessibilityPerformPress()
        clock = 598.9; idle.tick()
        precondition(!playback.isPooping, "A pet click resets the inactivity deadline")
        clock = 599; idle.tick()
        precondition(playback.isPooping && idle.session.phase == .animating)
        precondition(idle.desktop.panel == nil, "Poop appears after the animation")
        var timers: [Timer] = []
        func after(_ seconds: TimeInterval, _ block: @escaping () -> Void) {
            let timer = Timer(timeInterval: seconds, repeats: false) { _ in block() }
            RunLoop.main.add(timer, forMode: .common)
            timers.append(timer)
        }
        after(0.8) {
            _ = view.accessibilityPerformPress()
            precondition(playback.isPooping, "A click cannot interrupt the poop animation")
            playback.feed()
            precondition(playback.isPooping && !playback.isEating, "Food waits until the animation finishes")
            guard let contents = view.layer?.contents else { fatalError("No real poop frame rendered") }
            let cg = contents as! CGImage
            var rgba = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            let context = CGContext(data: &rgba, width: cg.width, height: cg.height,
                                    bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            let alpha = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
            precondition(alpha.min() == 0 && alpha.max() == 255, "Rendered dog must retain real alpha")
            print("PASS: actual poop animation rendered with alpha 0..255")
        }
        let duration: TimeInterval = adult ? 152.0 / 30 : 121.0 / 30
        after(duration + 0.6) {
            precondition(!playback.isPooping && playback.isEating, "Queued food begins after pooping")
            precondition(idle.session.phase == .visible)
            guard let poopPanel = idle.desktop.panel, let poopView = idle.desktop.view else {
                fatalError("Poop never appeared")
            }
            precondition(!poopPanel.isOpaque && !poopPanel.hasShadow && !poopView.isOpaque)
            precondition(NSScreen.screens.contains { $0.visibleFrame.contains(poopPanel.frame) }, "Poop must remain on screen")
            precondition(!poopPanel.frame.intersects(panel.frame), "Random poop must not overlap the dog")
            precondition(!poopView.containsOpaquePoint(NSPoint(x: 1, y: 1)))
            precondition(poopView.containsOpaquePoint(NSPoint(x: 64, y: poopView.bounds.midY)))
            func click(_ point: NSPoint) {
                for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
                    let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                                                  windowNumber: poopPanel.windowNumber, context: nil,
                                                  eventNumber: 0, clickCount: 1, pressure: 1)!
                    if type == .leftMouseDown { poopView.mouseDown(with: event) }
                    else { poopView.mouseUp(with: event) }
                }
            }
            click(NSPoint(x: 1, y: 1))
            precondition(idle.desktop.panel != nil, "Transparent pixels cannot clear the poop")
            let position = idle.desktop.origin!
            panel.setFrameOrigin(NSPoint(x: 400, y: 400))
            precondition(idle.desktop.origin == position, "Poop stays put when the dog moves")
            clock = 2000; idle.tick()
            precondition(!playback.isPooping && idle.desktop.origin == position, "One uncleared poop only")
            idle.stop()
            let restored = try! IdlePoopController(playback: playback, view: view, store: PetStore(), now: { clock })
            restored.start()
            precondition(restored.session.phase == .visible && restored.desktop.origin == position,
                         "Poop position survives a restart")
            let restoredPanel = restored.desktop.panel!, restoredView = restored.desktop.view!
            let center = NSPoint(x: restoredView.bounds.midX, y: restoredView.bounds.midY)
            let down = NSEvent.mouseEvent(with: .leftMouseDown, location: center, modifierFlags: [], timestamp: 0,
                                         windowNumber: restoredPanel.windowNumber, context: nil,
                                         eventNumber: 1, clickCount: 1, pressure: 1)!
            let up = NSEvent.mouseEvent(with: .leftMouseUp, location: center, modifierFlags: [], timestamp: 0,
                                       windowNumber: restoredPanel.windowNumber, context: nil,
                                       eventNumber: 2, clickCount: 1, pressure: 1)!
            restoredView.mouseDown(with: down); restoredView.mouseUp(with: up)
            precondition(restored.desktop.panel == nil && store.poopPosition == nil && restored.session.phase == .waiting,
                         "Clicking poop clears the window and persisted state")
            clock += 299; restored.tick()
            precondition(!playback.isPooping, "Cleaning starts a fresh five-minute cycle")
            restored.stop()
            playback.stop()
            UserDefaults.standard.removePersistentDomain(forName: domain)
            print("PASS: \(adult ? "adult" : "puppy") five-minute inactivity, click reset, real alpha, queued feeding, random placement, persistence, fixed position, transparent hit testing, and click-to-clean")
            exit(0)
        }
        after(duration + 12) { fatalError("Native poop validation timed out") }
        app.run()
    }
}
