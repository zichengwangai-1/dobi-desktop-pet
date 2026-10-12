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
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: domain)
        let adult = CommandLine.arguments.contains("--adult")
        let life = PetLife(birthday: adult ? Date(timeIntervalSinceNow: -259_201) : Date())
        defaults.set(try JSONEncoder().encode(life), forKey: "life")
        defaults.set(40.0, forKey: "poopX"); defaults.set(40.0, forKey: "poopY")
        let store = PetStore()
        let migrated = store.poops
        precondition(migrated.count == 1 && migrated[0].position == NSPoint(x: 40, y: 40))
        precondition(PetStore().poops == migrated && defaults.object(forKey: "poopX") == nil,
                     "Legacy poop migrates once and retains a stable identity")
        store.poops = []
        let panel = PetPanel(contentRect: NSRect(x: 100, y: 100, width: 300, height: 300),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        let view = PetView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        panel.contentView = view
        let playback = Playback(view: view, store: store)
        var clock: TimeInterval = 0
        let idle = try IdlePoopController(playback: playback, view: view, store: store, now: { clock })
        let productionCompletion = playback.onPoopFinished
        playback.onPoopFinished = {
            productionCompletion?()
            // Keep test piles from receiving real desktop clicks during validation.
            for record in idle.desktop.records { idle.desktop.panel(for: record.id)?.orderOut(nil) }
        }
        view.onInteract = { playback.interact() }
        playback.onFailure = { fatalError($0) }
        playback.startAmbient(); idle.start()
        clock = 299; idle.tick()
        precondition(!playback.isPooping)
        _ = view.accessibilityPerformPress()
        clock = 598.9; idle.tick()
        precondition(!playback.isPooping, "Clicking resets the five-minute inactivity deadline")
        clock = 599; idle.tick()
        precondition(playback.isPooping && idle.desktop.records.isEmpty)
        var timers: [Timer] = []
        let alphaCheck = Timer(timeInterval: 0.8, repeats: false) { _ in
            guard let contents = view.layer?.contents else { fatalError("No poop frame rendered") }
            let cg = contents as! CGImage
            var rgba = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            let context = CGContext(data: &rgba, width: cg.width, height: cg.height,
                                    bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            let alpha = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
            precondition(alpha.min() == 0 && alpha.max() == 255)
            print("PASS: actual poop animation rendered with alpha 0..255")
        }
        RunLoop.main.add(alphaCheck, forMode: .common); timers.append(alphaCheck)
        var step = 0
        var originals: [PoopRecord] = []
        let watch = Timer(timeInterval: 0.1, repeats: true) { _ in
            guard !playback.isPooping else { return }
            switch step {
            case 0:
                guard idle.desktop.records.count == 1 else { return }
                clock = 898.9; idle.tick()
                precondition(!playback.isPooping)
                clock = 899; idle.tick()
                precondition(playback.isPooping, "Another five idle minutes adds poop without cleaning")
                step = 1
            case 1:
                guard idle.desktop.records.count == 2 else { return }
                originals = idle.desktop.records
                let heldClick = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 150, y: 150),
                                                  modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
                                                  context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
                view.mouseDown(with: heldClick)
                for _ in 0..<3 { precondition(idle.poopManually(), "Every demo click must be accepted") }
                precondition(playback.isPooping && idle.session.pendingManualRequests == 2)
                view.mouseUp(with: heldClick)
                step = 2
            case 2:
                guard idle.desktop.records.count == 5 else { return }
                precondition(idle.session.pendingManualRequests == 0)
                for record in originals { precondition(idle.desktop.records.contains(record), "Earlier poop must remain") }
                let records = idle.desktop.records
                precondition(store.poops == records && Set(records.map(\.id)).count == 5)
                panel.setFrameOrigin(NSPoint(x: 400, y: 400))
                precondition(idle.desktop.records == records, "Poop cannot move with the dog")
                for record in records {
                    let poopPanel = idle.desktop.panel(for: record.id)!, poopView = idle.desktop.view(for: record.id)!
                    precondition(!poopPanel.isOpaque && !poopPanel.hasShadow && !poopView.isOpaque)
                    precondition(NSScreen.screens.contains { $0.visibleFrame.contains(poopPanel.frame) })
                    precondition(!poopView.containsOpaquePoint(NSPoint(x: 1, y: 1)))
                    precondition(poopView.containsOpaquePoint(NSPoint(x: poopView.poopRect.midX, y: poopView.poopRect.midY)))
                }
                func click(_ id: UUID, at point: NSPoint) {
                    let poopPanel = idle.desktop.panel(for: id)!, poopView = idle.desktop.view(for: id)!
                    for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
                        let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                                                      windowNumber: poopPanel.windowNumber, context: nil,
                                                      eventNumber: 0, clickCount: 1, pressure: 1)!
                        if type == .leftMouseDown { poopView.mouseDown(with: event) }
                        else { poopView.mouseUp(with: event) }
                    }
                }
                let removed = records[0].id
                click(removed, at: NSPoint(x: 1, y: 1))
                precondition(idle.desktop.records.count == 5, "Transparent pixels do not clear poop")
                let target = idle.desktop.view(for: removed)!
                click(removed, at: NSPoint(x: target.poopRect.midX, y: target.poopRect.midY))
                precondition(idle.desktop.records.count == 4 && idle.desktop.panel(for: removed) == nil)
                precondition(idle.desktop.records == records.filter { $0.id != removed }, "Only the clicked poop disappears")
                let saved = store.poops
                idle.stop()
                let restored = try! IdlePoopController(playback: playback, view: view, store: PetStore(), now: { clock })
                restored.start()
                precondition(restored.desktop.records == saved, "All poop positions and identities survive restart")
                for record in saved { _ = restored.desktop.view(for: record.id)!.accessibilityPerformPress() }
                precondition(restored.desktop.records.isEmpty && store.poops.isEmpty)
                clock = 1198.9; restored.tick()
                precondition(!playback.isPooping)
                clock = 1199; restored.tick()
                precondition(playback.isPooping, "Cleaning poop does not reset the pet inactivity timer")
                restored.stop(); playback.stop()
                defaults.removePersistentDomain(forName: domain)
                print("PASS: \(adult ? "adult" : "puppy") repeated automatic cycles, three queued demos, five accumulated transparent poop windows, individual mouse cleanup, collection persistence, legacy migration, and unchanged idle deadline")
                exit(0)
            default: break
            }
        }
        RunLoop.main.add(watch, forMode: .common); timers.append(watch)
        let timeout = Timer(timeInterval: 45, repeats: false) { _ in fatalError("Accumulation verification timed out") }
        RunLoop.main.add(timeout, forMode: .common); timers.append(timeout)
        app.run()
    }
}
