import Foundation

public enum PetStage: String, Codable, Sendable { case puppy, adult }
public enum AgeChoice: String, Codable, Sendable, CaseIterable { case automatic, puppy, adult }
public enum PetAction: String, Codable, Sendable, CaseIterable { case feed, pet, clean }

public struct PetState: Codable, Equatable, Sendable {
    public static let idleInterval: TimeInterval = 300
    public let birthday: Date
    public private(set) var naturallyGrown = false
    public private(set) var lastInteraction: Date
    public private(set) var idleCheckpoint: Date
    public private(set) var poopCount = 0
    public private(set) var foodCount = 0
    public private(set) var touchCount = 0
    public private(set) var lastAction: PetAction?
    public private(set) var lastActionDate: Date?

    public init(now: Date) {
        birthday = now; lastInteraction = now; idleCheckpoint = now
    }
    public var nextIdleDate: Date { max(lastInteraction, idleCheckpoint).addingTimeInterval(Self.idleInterval) }
    public mutating func advance(to now: Date) {
        if now.timeIntervalSince(birthday) >= 259_200 { naturallyGrown = true }
        let base = max(lastInteraction, idleCheckpoint)
        let elapsed = now.timeIntervalSince(base)
        guard elapsed.isFinite, elapsed >= Self.idleInterval else { return }
        let cycles = Int(min(floor(elapsed / Self.idleInterval), 1_000_000_000))
        poopCount += cycles
        idleCheckpoint = base.addingTimeInterval(Double(cycles) * Self.idleInterval)
    }
    public mutating func perform(_ action: PetAction, at now: Date) {
        advance(to: now)
        switch action {
        case .feed: foodCount += 1
        case .pet: touchCount += 1
        case .clean: poopCount = max(0, poopCount - 1)
        }
        lastAction = action; lastActionDate = now
        if action != .clean { lastInteraction = now; idleCheckpoint = now }
    }
    public func stage(for choice: AgeChoice) -> PetStage {
        switch choice {
        case .automatic: naturallyGrown ? .adult : .puppy
        case .puppy: .puppy
        case .adult: .adult
        }
    }
    public func imageName(for stage: PetStage, at now: Date) -> String {
        let prefix = stage.rawValue
        guard let date = lastActionDate, now.timeIntervalSince(date) >= 0,
              now.timeIntervalSince(date) < Self.idleInterval else { return "\(prefix)_walk" }
        switch lastAction {
        case .feed: return "\(prefix)_eat"
        case .pet: return stage == .puppy ? "puppy_sit" : "adult_bark"
        default: return "\(prefix)_walk"
        }
    }
    public func message(for stage: PetStage, at now: Date) -> String {
        if let date = lastActionDate, now.timeIntervalSince(date) >= 0,
           now.timeIntervalSince(date) < Self.idleInterval {
            switch lastAction {
            case .feed: return "吃饱啦，谢谢你"
            case .pet: return stage == .puppy ? "乖乖坐好，等你摸摸" : "汪！今天也陪着你"
            case .clean: return poopCount == 0 ? "干干净净，心情好好" : "谢谢你，还剩 \(poopCount) 坨"
            case nil: break
            }
        }
        return poopCount > 0 ? "有 \(poopCount) 坨便便等你铲" : "摸摸我吧，我在这儿"
    }
}
