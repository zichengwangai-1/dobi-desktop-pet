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
        session = IdlePoopSession(now: now(), interval: interval)
        desktop = try PoopDesktop()
        desktop.onClear = { [weak self] id in self?.clear(id) }
        playback.onPoopFinished = { [weak self] in self?.animationFinished() }
        view.onActivity = { [weak self] in self?.registerActivity() }
    }
    func start() {
        for record in store.poops { desktop.show(record) }
        persist()
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    func registerActivity() { session.registerActivity(at: now()) }
    @discardableResult
    func poopManually() -> Bool {
        registerActivity()
        session.requestManual()
        // Menu actions run while PetView is still handling rightMouseDown.
        startNext(canStart: !playback.isEating && !playback.isPooping)
        return true
    }
    private func startNext(canStart: Bool) {
        if session.beginIfDue(at: now(), canStart: canStart) { playback.poop() }
    }
    func tick() {
        guard let view = petView else { return }
        let canStart = !playback.isEating && !playback.isPooping && !view.pointerDown && !view.fileDragActive
            && !PetView.externalFileDragInProgress
        startNext(canStart: canStart)
    }
    private func animationFinished() {
        guard session.phase == .animating else { return }
        session.completeAnimation()
        if let petRect = petView?.window?.frame, let id = desktop.showRandomly(avoiding: petRect) {
            persist()
            print("event=poop_created id=\(id) count=\(desktop.records.count)")
        }
        // The timer starts queued demos after Playback has resumed ambient/eating.
    }
    func clear(_ id: UUID) {
        desktop.remove(id)
        persist()
        print("event=poop_cleared id=\(id) count=\(desktop.records.count)")
    }
    private func persist() { store.poops = desktop.records }
    func screensChanged() { desktop.keepOnScreen(); persist() }
    func stop() {
        timer?.invalidate(); timer = nil
        desktop.dismissAll()
    }
}
