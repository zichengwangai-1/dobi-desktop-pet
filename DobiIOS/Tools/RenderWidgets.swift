import AppKit
import SwiftUI
import WidgetKit

// Render the actual SwiftUI component at iPhone widget sizes. This checks layout
// and assets; it does not substitute for testing WidgetKit on an iPhone.
@main
struct RenderWidgets {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in ["puppy_walk", "adult_walk", "puppy_sit", "adult_bark", "puppy_eat", "adult_eat", "poop"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
                  let data = try? Data(contentsOf: url),
                  let bitmap = NSBitmapImageRep(data: data) else { fatalError("Missing or invalid artwork: \(name)") }
            precondition(bitmap.hasAlpha, "Artwork must retain a transparent background: \(name)")
            let cg = bitmap.cgImage!
            var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            let context = CGContext(data: &pixels, width: cg.width, height: cg.height, bitsPerComponent: 8,
                                    bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
            precondition(alpha.min() == 0 && alpha.max()! > 240)
        }
        print("PASS: all seven bundled images decode with transparent pixels and visible foreground")
        let now = Date(timeIntervalSince1970: 1000)
        var eating = PetState(now: now)
        eating.perform(.feed, at: now)
        var poops = PetState(now: now)
        poops.advance(to: now.addingTimeInterval(900))
        let samples: [(String, WidgetFamily, CGFloat, PetEntry)] = [
            ("puppy-small", .systemSmall, 158, PetEntry(date: now, state: PetState(now: now), age: .puppy)),
            ("puppy-medium", .systemMedium, 338, PetEntry(date: now, state: PetState(now: now), age: .puppy)),
            ("adult-feeding", .systemMedium, 338, PetEntry(date: now, state: eating, age: .adult)),
            ("puppy-poop", .systemMedium, 338, PetEntry(date: now.addingTimeInterval(900), state: poops, age: .puppy)),
        ]
        for (name, family, width, entry) in samples {
            let view = PetWidgetView(entry: entry, previewFamily: family)
                .environment(\.colorScheme, .light).padding(16)
                .frame(width: width, height: 158).background(PetPalette.cream)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                fatalError("Widget view did not render")
            }
            try png.write(to: destination.appendingPathComponent("\(name).png"))
            print("Rendered \(name): \(image.width)x\(image.height)")
        }
    }
}
