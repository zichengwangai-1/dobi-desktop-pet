import AppKit
import DobiCore

@main
struct VerifyStageSwitch {
    static func main() throws {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let domain = "com.dobipet.stage-validation"
        precondition(Bundle.main.bundleIdentifier == domain)
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: domain)
        defaults.set(try JSONEncoder().encode(PetLife(birthday: Date(timeIntervalSinceNow: -259_201))), forKey: "life")
        defaults.set(false, forKey: "soundEnabled")

        // Use the production menu and its target/actions, without opening a popup.
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        let menuView = app.windows.compactMap { $0.contentView as? PetView }.first!
        func choose(_ title: String) {
            let submenu = menuView.menuProvider!().item(withTitle: "成长阶段")!.submenu!
            let item = submenu.item(withTitle: title)!
            precondition(item.isEnabled && app.sendAction(item.action!, to: item.target, from: item))
            precondition(menuView.menuProvider!().item(withTitle: "成长阶段")!.submenu!.item(withTitle: title)!.state == .on)
        }
        choose("幼年期")
        precondition(PetStore().stage() == .puppy)
        precondition(menuView.menuProvider!().item(withTitle: "坐下") != nil)
        precondition(!menuView.menuProvider!().items.contains { $0.title.contains("再陪伴") })
        choose("成年期")
        precondition(PetStore().stage() == .adult)
        precondition(menuView.menuProvider!().item(withTitle: "犬吠") != nil)
        choose("自动成长（3 天）")
        precondition(PetStore().life.selectedStage == nil && PetStore().stage() == .adult)
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        for window in app.windows { window.orderOut(nil) }
        print("PASS: real context menu switches stages, updates interactions, checks selection, persists, restores automatic growth")

        let store = PetStore()
        store.selectStage(.puppy)
        let panel = PetPanel(contentRect: NSRect(x: 100, y: 100, width: 300, height: 300),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        let view = PetView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        panel.contentView = view
        let playback = Playback(view: view, store: store)
        let idle = try IdlePoopController(playback: playback, view: view, store: store, now: { 0 })
        let completion = playback.onPoopFinished
        playback.onPoopFinished = {
            completion?()
            for record in idle.desktop.records { idle.desktop.panel(for: record.id)?.orderOut(nil) }
        }
        playback.onFailure = { fatalError($0) }
        idle.start()
        playback.interact()
        precondition(playback.currentAction == .puppySit)
        store.selectStage(.adult); playback.refreshStage(); playback.interact()
        precondition(playback.currentAction == .adultBark)
        store.selectStage(.puppy); playback.refreshStage(); playback.feed(); playback.feed()
        precondition(playback.currentAction == .puppyEat)
        var timers: [Timer] = []
        func after(_ delay: TimeInterval, _ block: @escaping @MainActor () -> Void) {
            let timer = Timer(timeInterval: delay, repeats: false) { _ in MainActor.assumeIsolated { block() } }
            RunLoop.main.add(timer, forMode: .common); timers.append(timer)
        }
        func checkAlpha() {
            let cg = view.layer!.contents as! CGImage
            var rgba = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            let context = CGContext(data: &rgba, width: cg.width, height: cg.height, bitsPerComponent: 8,
                                    bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            let alpha = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
            precondition(alpha.min() == 0 && alpha.max() == 255)
        }
        after(0.6) {
            store.selectStage(.adult); playback.refreshStage()
            precondition(playback.isEating && playback.currentAction == .adultEat)
            precondition(PetStore().stage() == .adult)
        }
        after(1.2) { checkAlpha() }
        after(3.2) { precondition(playback.isEating, "Switching must preserve pending food") }
        var step = 0
        let watch = Timer(timeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated {
                switch step {
                case 0:
                    guard !playback.isEating else { return }
                    store.selectStage(.puppy); playback.refreshStage()
                    idle.poopManually(); idle.poopManually()
                    precondition(playback.currentAction == .puppyPoop && idle.session.pendingManualRequests == 1)
                    after(0.7) {
                        store.selectStage(.adult); playback.refreshStage()
                        precondition(playback.isPooping && playback.currentAction == .adultPoop)
                        playback.feed() // Deferred meal must survive switching during the poop animation.
                    }
                    after(1.3) { checkAlpha() }
                    step = 1
                case 1:
                    guard idle.desktop.records.count == 1 && playback.isEating else { return }
                    precondition(playback.currentAction == .adultEat)
                    store.selectStage(.puppy); playback.refreshStage()
                    precondition(playback.currentAction == .puppyEat)
                    step = 2
                case 2:
                    guard idle.desktop.records.count == 2 && !playback.isPooping else { return }
                    precondition(!playback.isEating && idle.session.pendingManualRequests == 0)
                    precondition([PetAction.puppyWalk, .puppySpin].contains(playback.currentAction!))
                    precondition(PetStore().stage() == .puppy && store.poops.count == 2)
                    idle.stop(); playback.stop()
                    defaults.removePersistentDomain(forName: domain)
                    print("PASS: stage-specific interactions, alpha 0..255, continuous meals, switched poop, deferred meal, queued poop, and ambient recovery")
                    exit(0)
                default: break
                }
            }
        }
        RunLoop.main.add(watch, forMode: .common); timers.append(watch)
        after(40) { fatalError("Stage switching verification timed out") }
        app.run()
    }
}
