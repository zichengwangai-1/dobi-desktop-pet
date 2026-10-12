import Foundation

public enum FlowerKind: String, Codable, CaseIterable {
    case daisy, pink, clover
}

public struct FlowerPlacement: Codable, Equatable, Identifiable {
    public let id: UUID
    public let x: Double
    public let y: Double
    public let kind: FlowerKind
    public let angle: Double
    public let length: Double

    fileprivate init(x: Double, y: Double, kind: FlowerKind, variation: Double, length: Double) {
        id = UUID(); self.x = x; self.y = y; self.kind = kind
        // Positive rotation tilts an upright stem to the left in AppKit coordinates.
        angle = (0.5 - x) * 1.8 + min(0.12, max(-0.12, variation))
        self.length = min(0.34, max(0.20, length))
    }

    public var isValid: Bool {
        x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
            && angle.isFinite && abs(angle) <= 1.02
            && length.isFinite && (0.20...0.34).contains(length)
    }
}

public struct FlowerGarden: Codable, Equatable {
    public private(set) var flowers: [FlowerPlacement] = []
    public init() {}
    private enum CodingKeys: String, CodingKey { case flowers }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let saved = try values.decodeIfPresent([FlowerPlacement].self, forKey: .flowers) ?? []
        var ids = Set<UUID>()
        flowers = saved.filter { $0.isValid && ids.insert($0.id).inserted }
    }
    @discardableResult
    public mutating func insert(x: Double, y: Double, kind: FlowerKind,
                                variation: Double = 0, length: Double = 0.26) -> FlowerPlacement? {
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y),
              variation.isFinite, length.isFinite else { return nil }
        let flower = FlowerPlacement(x: x, y: y, kind: kind, variation: variation, length: length)
        flowers.append(flower)
        return flower
    }
    public mutating func undo() { if !flowers.isEmpty { flowers.removeLast() } }
    public mutating func reset() { flowers.removeAll() }
}
