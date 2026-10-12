import AppKit
import DobiCore

@main
struct VerifyFlowers {
    static func main() throws {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let domain = "com.dobipet.flowers-validation"
        precondition(Bundle.main.bundleIdentifier == domain)
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = PetStore()
        // The old array format has no garden field. Stable pile identities must survive.
        let id = UUID()
        let legacy = "[{\"id\":\"\(id)\",\"position\":[160,160]}]".data(using: .utf8)!
        defaults.set(legacy, forKey: "poops")
        precondition(store.poops.count == 1 && store.poops[0].id == id && store.poops[0].garden.flowers.isEmpty)
        let second = PoopRecord(position: NSPoint(x: 380, y: 160))
        let desktop = try PoopDesktop()
        desktop.onChange = { store.poops = desktop.records }
        desktop.onClear = { id in desktop.remove(id); store.poops = desktop.records }
        desktop.show(store.poops[0]); desktop.show(second)
        for record in desktop.records { desktop.panel(for: record.id)?.orderOut(nil) }
        store.poops = desktop.records
        let view = desktop.view(for: id)!
        let menu = view.makeContextMenu()
        precondition(menu.items.first?.title == "屎上雕花")
        let item = menu.items.first!
        precondition(app.sendAction(item.action!, to: item.target, from: item))
        let editor = desktop.editor!
        editor.window?.orderOut(nil)
        let canvas = editor.canvas
        canvas.layoutSubtreeIfNeeded()
        func button(_ name: String, in editor: FlowerEditor) -> NSButton {
            editor.window!.contentView!.subviews.compactMap { $0 as? NSButton }.first { $0.title == name }!
        }
        func click(_ x: Double, _ y: Double, on editor: FlowerEditor) {
            let canvas = editor.canvas
            let point = NSPoint(x: canvas.poopRect.minX + canvas.poopRect.width * x,
                                y: canvas.poopRect.minY + canvas.poopRect.height * y)
            precondition(canvas.containsPoopPoint(point))
            let event = NSEvent.mouseEvent(with: .leftMouseDown, location: canvas.convert(point, to: nil),
                                          modifierFlags: [], timestamp: 0, windowNumber: editor.window!.windowNumber,
                                          context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            canvas.mouseDown(with: event)
        }
        precondition(!canvas.insert(at: NSPoint(x: 1, y: 1)))
        click(0.27, 0.43, on: editor); click(0.5, 0.77, on: editor); click(0.73, 0.43, on: editor)
        precondition(editor.garden.flowers.count == 3)
        precondition(editor.garden.flowers[0].angle > 0 && editor.garden.flowers[2].angle < 0)
        precondition(editor.garden == desktop.view(for: id)!.garden)
        precondition(PetStore().poops == desktop.records)
        precondition(desktop.view(for: second.id)!.garden.flowers.isEmpty)
        button("撤回一朵", in: editor).performClick(nil)
        precondition(editor.garden.flowers.count == 2)
        button("重新插", in: editor).performClick(nil)
        precondition(editor.garden.flowers.isEmpty && !button("撤回一朵", in: editor).isEnabled)
        click(0.3, 0.46, on: editor); click(0.5, 0.79, on: editor); click(0.70, 0.46, on: editor)
        let artwork = editor.garden

        func render(_ view: NSView, to path: String) throws -> NSBitmapImageRep {
            view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            let width = Int(view.bounds.width), height = Int(view.bounds.height)
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
            context.clear(view.bounds)
            view.layer!.render(in: context)
            try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
            return rep
        }
        let preview = CommandLine.arguments.dropFirst().first ?? "/tmp/dobi-flower-editor.png"
        // The window has a deliberate cream workspace; only the sprites and desktop are transparent.
        let content = editor.window!.contentView!
        content.wantsLayer = true
        content.layer?.backgroundColor = editor.window!.backgroundColor.cgColor
        _ = try render(content, to: preview)
        let rep = try render(view, to: "/tmp/dobi-flower-desktop.png")
        precondition(!view.isOpaque && !desktop.panel(for: id)!.isOpaque && !desktop.panel(for: id)!.hasShadow)
        var transparent = 0, flowerPixels = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                let alpha = rep.colorAt(x: x, y: y)!.alphaComponent
                if alpha == 0 { transparent += 1 }
                let point = NSPoint(x: Double(x) + 0.5, y: Double(rep.pixelsHigh - 1 - y) + 0.5)
                if alpha > 0.20 && !view.poopRect.contains(point) && view.bounds.insetBy(dx: 1, dy: 1).contains(point) {
                    flowerPixels += 1
                    precondition(view.containsOpaquePoint(point), "Visible petals outside the poop must remain interactive")
                }
            }
        }
        precondition(transparent > rep.pixelsWide * rep.pixelsHigh / 2 && flowerPixels > 10)
        precondition(!view.containsOpaquePoint(NSPoint(x: 1, y: 1)))
        button("插好了", in: editor).performClick(nil)
        precondition(desktop.editor == nil && PetStore().poops.first { $0.id == id }!.garden == artwork)
        desktop.openEditor(for: id); desktop.editor!.window?.orderOut(nil)
        precondition(desktop.editor!.garden == artwork)
        desktop.openEditor(for: second.id); desktop.editor!.window?.orderOut(nil)
        precondition(desktop.editor!.garden.flowers.isEmpty)
        click(0.5, 0.5, on: desktop.editor!)
        desktop.dismissAll()
        let restarted = try PoopDesktop()
        for record in PetStore().poops { restarted.show(record); restarted.panel(for: record.id)?.orderOut(nil) }
        precondition(restarted.view(for: id)!.garden == artwork)
        precondition(restarted.view(for: second.id)!.garden.flowers.count == 1)
        restarted.onClear = { id in restarted.remove(id); store.poops = restarted.records }
        restarted.openEditor(for: id); restarted.editor!.window?.orderOut(nil)
        _ = restarted.view(for: id)!.accessibilityPerformPress()
        precondition(restarted.editor == nil && restarted.records.count == 1 && store.poops.count == 1)
        precondition(restarted.records[0].id == second.id && restarted.records[0].garden.flowers.count == 1)
        restarted.dismissAll()
        print("PASS: real context menu, mouse insertion, outward angles, undo/reset/finish, independent piles, legacy saves, restart, clear while editing, transparent petals and click-through")
        print("Preview: \(preview)")
    }
}
