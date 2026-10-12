import AppKit
import DobiCore

final class FlowerEditor: NSWindowController, NSWindowDelegate {
    let canvas: FlowerCanvas
    private(set) var garden: FlowerGarden
    var onChange: ((FlowerGarden) -> Void)?
    var onClose: (() -> Void)?
    private let countLabel = NSTextField(labelWithString: "")
    private let undoButton = NSButton(title: "撤回一朵", target: nil, action: nil)
    private let resetButton = NSButton(title: "重新插", target: nil, action: nil)
    private var pendingKind: FlowerKind?

    init(sprite: PoopSprite, flowers: FlowerSprites, garden: FlowerGarden) {
        self.garden = garden
        canvas = FlowerCanvas(sprite: sprite, flowers: flowers, frame: NSRect(x: 0, y: 0, width: 660, height: 400))
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 660, height: 560),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "屎上雕花"
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.93, alpha: 1)
        window.appearance = NSAppearance(named: .aqua)
        super.init(window: window)
        window.delegate = self
        window.center()
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 660, height: 560))
        content.wantsLayer = true
        content.layer?.backgroundColor = window.backgroundColor.cgColor
        window.contentView = content
        let title = NSTextField(labelWithString: "屎上雕花")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.textColor = NSColor(calibratedRed: 0.28, green: 0.36, blue: 0.23, alpha: 1)
        title.frame = NSRect(x: 28, y: 508, width: 300, height: 32)
        content.addSubview(title)
        let subtitle = NSTextField(labelWithString: "点一下便便，插一朵小花。随便插，都是艺术。")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 28, y: 480, width: 600, height: 22)
        content.addSubview(subtitle)
        canvas.frame.origin = NSPoint(x: 0, y: 80)
        canvas.isEditing = true
        canvas.setAccessibilityElement(true)
        canvas.setAccessibilityRole(.image)
        canvas.setAccessibilityLabel("便便插花画布，点击便便表面插花")
        content.addSubview(canvas)
        canvas.onInsert = { [weak self] point in self?.plant(at: point) }
        countLabel.frame = NSRect(x: 28, y: 48, width: 580, height: 22)
        countLabel.font = .systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabelColor
        content.addSubview(countLabel)
        undoButton.target = self; undoButton.action = #selector(undoFlower)
        undoButton.frame = NSRect(x: 24, y: 12, width: 108, height: 32)
        undoButton.bezelStyle = .rounded
        undoButton.keyEquivalent = "z"; undoButton.keyEquivalentModifierMask = .command
        content.addSubview(undoButton)
        resetButton.target = self; resetButton.action = #selector(resetFlowers)
        resetButton.frame = NSRect(x: 140, y: 12, width: 96, height: 32)
        resetButton.bezelStyle = .rounded
        content.addSubview(resetButton)
        let finish = NSButton(title: "插好了", target: self, action: #selector(finishFlowers))
        finish.frame = NSRect(x: 524, y: 12, width: 108, height: 32)
        finish.bezelStyle = .rounded
        finish.keyEquivalent = "\r"
        content.addSubview(finish)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func present() { showWindow(nil); NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil) }
    private func plant(at point: NSPoint) {
        // Avoid consecutive duplicates without making the user choose tools.
        let choices = FlowerKind.allCases.filter { $0 != pendingKind }
        let kind = choices.randomElement() ?? .daisy
        pendingKind = kind
        if let flower = garden.insert(x: point.x, y: point.y, kind: kind,
                                      variation: Double.random(in: -0.10...0.10),
                                      length: Double.random(in: 0.22...0.34)) {
            refresh(animatedID: flower.id)
            onChange?(garden)
        }
    }
    private func refresh(animatedID: UUID? = nil) {
        canvas.updateGarden(garden, animatedID: animatedID)
        let count = garden.flowers.count
        countLabel.stringValue = count == 0 ? "没有标准答案，也不用赶时间。" : "已插入 \(count) 朵 · 这坨，有自己的花期。"
        undoButton.isEnabled = count > 0; resetButton.isEnabled = count > 0
    }
    @objc func undoFlower() { garden.undo(); refresh(); onChange?(garden) }
    @objc func resetFlowers() { garden.reset(); refresh(); onChange?(garden) }
    @objc func finishFlowers() { close() }
    func windowWillClose(_ notification: Notification) { onClose?() }
}
