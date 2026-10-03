import AppKit
import DobiCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PetStore()
    private var panel: PetPanel!
    private var petView: PetView!
    private var playback: Playback!
    private var statusItem: NSStatusItem!
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let missing = PetAction.allCases.filter { !FileManager.default.fileExists(atPath: Assets.video($0).path) }
        guard missing.isEmpty else { showFailure("缺少视频素材：\(missing.map(\.rawValue).joined(separator: "、"))"); return }
        let size = store.size
        panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "杜宾桌宠"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        petView = PetView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        panel.contentView = petView
        petView.onInteract = { [weak self] in self?.playback.interact() }
        petView.onDragEnd = { [weak self] in
            guard let self else { return }
            self.keepOnScreen(); self.store.savePosition(self.panel.frame.origin)
            print("event=drag position=\(self.panel.frame.origin)")
        }
        petView.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        placePet()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "杜宾桌宠")
        statusItem.button?.target = self; statusItem.button?.action = #selector(openStatusMenu)
        statusItem.button?.toolTip = "杜宾 · 点击小狗互动，右键关闭"
        playback = Playback(view: petView, store: store)
        playback.onFailure = { [weak self] message in self?.showFailure(message) }
        panel.orderFrontRegardless()
        playback.startAmbient()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in self?.keepOnScreen() }
        print("event=launch stage=\(store.stage().rawValue) birthday=\(store.life.birthday.timeIntervalSince1970)")
    }
    private func placePet() {
        if let origin = store.position() { panel.setFrameOrigin(origin); keepOnScreen() }
        else { centerPet() }
    }
    @objc private func centerPet() {
        guard let screen = NSScreen.main else { return }
        let area = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: area.maxX - panel.frame.width - 60, y: area.minY + 35))
        store.savePosition(panel.frame.origin)
        panel.orderFrontRegardless()
    }
    private func keepOnScreen() {
        let rect = panel.frame
        let screen = NSScreen.screens.max { a, b in
            a.visibleFrame.intersection(rect).area < b.visibleFrame.intersection(rect).area
        } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: max(area.minX, min(rect.minX, area.maxX - rect.width)),
                                     y: max(area.minY, min(rect.minY, area.maxY - rect.height))))
    }
    @objc private func openStatusMenu() {
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let stage = store.stage()
        menu.addItem(withTitle: stage == .puppy ? "杜宾 · 幼年期" : "杜宾 · 成年期", action: nil, keyEquivalent: "")
        if stage == .puppy {
            let hours = Int(ceil(store.life.remaining(at: Date()) / 3600))
            menu.addItem(withTitle: "再陪伴 \(hours) 小时，长大成为成年犬", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        let interact = menu.addItem(withTitle: stage == .puppy ? "坐下" : "犬吠", action: #selector(interact), keyEquivalent: "")
        interact.target = self
        let sizes = NSMenu()
        for (title, value) in [("小 · 220", 220), ("中 · 300", 300), ("大 · 380", 380)] {
            let item = sizes.addItem(withTitle: title, action: #selector(resizePet(_:)), keyEquivalent: "")
            item.tag = value; item.target = self
            item.state = Int(store.size) == value ? .on : .off
        }
        let sizeMenu = menu.addItem(withTitle: "小狗大小", action: nil, keyEquivalent: "")
        sizeMenu.submenu = sizes
        let sound = menu.addItem(withTitle: "犬吠声音", action: #selector(toggleSound), keyEquivalent: "")
        sound.target = self; sound.state = store.soundEnabled ? .on : .off
        let center = menu.addItem(withTitle: "找回小狗", action: #selector(centerPet), keyEquivalent: "")
        center.target = self
        menu.addItem(.separator())
        let close = menu.addItem(withTitle: "关闭杜宾", action: #selector(quit), keyEquivalent: "q")
        close.target = self
        return menu
    }
    @objc private func interact() { playback.interact() }
    @objc private func toggleSound() { store.soundEnabled.toggle() }
    @objc private func resizePet(_ sender: NSMenuItem) {
        let size = CGFloat(sender.tag)
        store.size = size
        var frame = panel.frame
        frame.origin.x += (frame.width - size) / 2
        frame.size = NSSize(width: size, height: size)
        panel.setFrame(frame, display: true)
        petView.frame = NSRect(origin: .zero, size: frame.size)
        keepOnScreen(); store.savePosition(panel.frame.origin)
    }
    @objc private func quit() { NSApp.terminate(nil) }
    private func showFailure(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "杜宾暂时无法播放"
        alert.informativeText = message
        alert.runModal(); NSApp.terminate(nil)
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let panel { store.savePosition(panel.frame.origin) }
        playback?.stop()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
}
private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
