import AppKit
import DobiCore

// Uptime avoids wall-clock changes affecting the five-minute inactivity rule.
final class IdlePoopController {
    private let playback: Playback
    private weak var petView: PetView?
    private let store: PetStore
    private let now: () -> TimeInterval
    private var timer: Timer?
    private(set) var session: IdlePoopSession
    let desktop: PoopDesktop

    init(playback: Playback, view: PetView, store: PetStore,
         interval: TimeInterval = 300, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) throws {
        self.playback = playback; self.petView = view; self.store = store; self.now = now
        session = IdlePoopSession(now: now(), hasPoop: store.poopPosition != nil, interval: interval)
        desktop = try PoopDesktop()
        desktop.onClear = { [weak self] in self?.clear() }
        playback.onPoopFinished = { [weak self] in self?.animationFinished() }
        view.onActivity = { [weak self] in self?.registerActivity() }
    }
    func start() {
        if let position = store.poopPosition {
            desktop.show(at: position)
            store.poopPosition = desktop.origin
        }
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    func registerActivity() { session.registerActivity(at: now()) }
    func tick() {
        guard let view = petView else { return }
        let canStart = !playback.isEating && !playback.isPooping && !view.pointerDown && !view.fileDragActive
            && !PetView.externalFileDragInProgress
        if session.beginIfDue(at: now(), canStart: canStart) { playback.poop() }
    }
    private func animationFinished() {
        guard session.phase == .animating, let petRect = petView?.window?.frame else { return }
        guard desktop.showRandomly(avoiding: petRect) else {
            session.clear(at: now())
            return
        }
        session.completeAnimation()
        store.poopPosition = desktop.origin
        print("event=poop_created position=\(desktop.origin ?? .zero)")
    }
    func clear() {
        desktop.dismiss()
        store.poopPosition = nil
        session.clear(at: now())
        print("event=poop_cleared")
    }
    func screensChanged() {
        desktop.keepOnScreen()
        if desktop.origin != nil { store.poopPosition = desktop.origin }
    }
    func stop() {
        timer?.invalidate(); timer = nil
        desktop.dismiss()
    }
}
