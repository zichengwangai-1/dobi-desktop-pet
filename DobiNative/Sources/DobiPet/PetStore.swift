import AppKit
import DobiCore

struct PoopRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var position: NSPoint
    var garden = FlowerGarden()

    init(id: UUID = UUID(), position: NSPoint, garden: FlowerGarden = FlowerGarden()) {
        self.id = id; self.position = position; self.garden = garden
    }
    private enum CodingKeys: String, CodingKey { case id, position, garden }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        position = try values.decode(NSPoint.self, forKey: .position)
        garden = try values.decodeIfPresent(FlowerGarden.self, forKey: .garden) ?? FlowerGarden()
    }
}

final class PetStore {
    private let defaults: UserDefaults
    private(set) var life: PetLife
    var soundEnabled: Bool {
        get { defaults.object(forKey: "soundEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "soundEnabled") }
    }
    var size: CGFloat {
        get { let value = defaults.double(forKey: "petSize"); return value >= 180 && value <= 420 ? value : 300 }
        set { defaults.set(newValue, forKey: "petSize") }
    }
    init() {
        defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "life"), let saved = try? JSONDecoder().decode(PetLife.self, from: data) {
            life = saved
        } else { life = PetLife(birthday: Date()) }
        persist()
    }
    func stage() -> PetStage {
        let wasGrown = life.hasGrown
        let stage = life.stage(at: Date())
        if wasGrown != life.hasGrown { persist() }
        return stage
    }
    func selectStage(_ stage: PetStage?) {
        life.selectStage(stage)
        _ = life.stage(at: Date())
        persist()
    }
    private func persist() { defaults.set(try? JSONEncoder().encode(life), forKey: "life") }
    func savePosition(_ origin: NSPoint) {
        defaults.set(origin.x, forKey: "positionX"); defaults.set(origin.y, forKey: "positionY")
    }
    func position() -> NSPoint? {
        guard defaults.object(forKey: "positionX") != nil else { return nil }
        return NSPoint(x: defaults.double(forKey: "positionX"), y: defaults.double(forKey: "positionY"))
    }
    var poops: [PoopRecord] {
        get {
            if let data = defaults.data(forKey: "poops"), let records = try? JSONDecoder().decode([PoopRecord].self, from: data) {
                return records.filter { $0.position.x.isFinite && $0.position.y.isFinite }
            }
            // Preserve the single poop saved by versions 1.3.0/1.3.1.
            guard defaults.object(forKey: "poopX") != nil else { return [] }
            let point = NSPoint(x: defaults.double(forKey: "poopX"), y: defaults.double(forKey: "poopY"))
            let records = point.x.isFinite && point.y.isFinite ? [PoopRecord(position: point)] : []
            self.poops = records
            return records
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: "poops")
            defaults.removeObject(forKey: "poopX"); defaults.removeObject(forKey: "poopY")
        }
    }
}

enum Assets {
    static var root: URL { Bundle.main.resourceURL! }
    static var poopImage: URL { root.appendingPathComponent("Images/poop.png") }
    static func video(_ action: PetAction) -> URL {
        root.appendingPathComponent("Videos/\(action.rawValue).mov")
    }
}
