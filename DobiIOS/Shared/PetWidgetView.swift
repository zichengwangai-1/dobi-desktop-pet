import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum PetArtwork {
    static func image(_ name: String) -> Image {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            #if canImport(UIKit)
            if let image = UIImage(contentsOfFile: url.path) { return Image(uiImage: image) }
            #else
            if let image = NSImage(contentsOf: url) { return Image(nsImage: image) }
            #endif
        }
        return Image(name, bundle: .main)
    }
}

enum PetPalette {
    static let ink = Color(red: 0.25, green: 0.22, blue: 0.18)
    static let moss = Color(red: 0.31, green: 0.40, blue: 0.29)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.92)
}

struct PetWidgetView: View {
    var entry: PetEntry
    var previewFamily: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            if entry.unavailable {
                VStack(spacing: 8) {
                    PetArtwork.image("puppy_walk").resizable().scaledToFit().frame(height: 70)
                    Text("暂时无法读取小狗状态，\n请稍后重试")
                        .font(.caption).multilineTextAlignment(.center)
                }
            } else if (previewFamily ?? family) == .systemSmall { small }
            else { medium }
        }
        .foregroundStyle(PetPalette.ink)
        .containerBackground(for: .widget) { PetPalette.cream }
    }
    private var small: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text("杜宾").font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
                stageTag
            }
            pet.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 8) {
                action(.feed, title: "喂食", symbol: "carrot.fill", compact: true)
                action(.clean, title: "铲便便", symbol: "sparkles", compact: true)
            }
        }
    }
    private var medium: some View {
        HStack(spacing: 10) {
            pet.frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("杜宾").font(.system(size: 19, weight: .semibold, design: .rounded))
                    Spacer(minLength: 4)
                    stageTag
                }
                Text(entry.message).font(.system(size: 12)).lineLimit(2).minimumScaleFactor(0.85)
                    .contentTransition(.opacity)
                Text("喂过 \(entry.state.foodCount) 次 · 摸过 \(entry.state.touchCount) 次")
                    .font(.system(size: 10)).foregroundStyle(PetPalette.ink.opacity(0.6)).lineLimit(1)
                HStack(spacing: 6) {
                    action(.feed, title: "喂食", symbol: "carrot.fill", compact: false)
                    action(.clean, title: "铲便便", symbol: "sparkles", compact: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var stageTag: some View {
        Text(entry.stageLabel).font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(PetPalette.moss.opacity(0.1), in: Capsule())
    }
    private var pet: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(intent: PetInteraction(.pet)) {
                GeometryReader { geometry in
                    PetArtwork.image(entry.imageName).resizable().scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .id(entry.imageName).transition(.opacity)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.stage == .puppy ? "摸摸幼年杜宾，让它坐下" : "摸摸成年杜宾，让它犬吠")
            .accessibilityValue(entry.message)
            .accessibilityIdentifier("pet.touch")
            if entry.state.poopCount > 0 {
                Button(intent: PetInteraction(.clean)) {
                    HStack(spacing: 0) {
                        PetArtwork.image("poop").resizable().scaledToFit().frame(width: 26, height: 26)
                        Text("\(entry.state.poopCount)").font(.system(size: 10, weight: .bold))
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .padding(.horizontal, 5).frame(minWidth: 44, minHeight: 44)
                    .background(PetPalette.cream.opacity(0.92), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("铲掉一坨便便")
                .accessibilityValue("剩余 \(entry.state.poopCount) 坨")
                .accessibilityIdentifier("pet.poop")
            }
        }
        .animation(.easeInOut(duration: 0.35), value: entry.imageName)
    }
    private func action(_ action: PetAction, title: String, symbol: String, compact: Bool) -> some View {
        Button(intent: PetInteraction(action)) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                if !compact { Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(action == .feed ? PetPalette.moss : PetPalette.moss.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(action == .feed ? Color.white : PetPalette.moss)
        }
        .buttonStyle(.plain)
        .disabled(action == .clean && entry.state.poopCount == 0)
        .opacity(action == .clean && entry.state.poopCount == 0 ? 0.5 : 1)
        .accessibilityLabel(title)
        .accessibilityValue(action == .clean ? "剩余 \(entry.state.poopCount) 坨，每次清理一坨" : "已喂食 \(entry.state.foodCount) 次")
        .accessibilityIdentifier("pet.\(action.rawValue)")
    }
}
