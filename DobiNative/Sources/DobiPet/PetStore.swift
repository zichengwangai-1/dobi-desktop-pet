import AppKit
import DobiCore

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
    private func persist() { defaults.set(try? JSONEncoder().encode(life), forKey: "life") }
    func savePosition(_ origin: NSPoint) {
        defaults.set(origin.x, forKey: "positionX"); defaults.set(origin.y, forKey: "positionY")
    }
    func position() -> NSPoint? {
        guard defaults.object(forKey: "positionX") != nil else { return nil }
        return NSPoint(x: defaults.double(forKey: "positionX"), y: defaults.double(forKey: "positionY"))
    }
}

enum Assets {
    static var root: URL { Bundle.main.resourceURL! }
    static func video(_ action: PetAction) -> URL {
        root.appendingPathComponent("Videos/\(action.rawValue).mov")
    }
}
