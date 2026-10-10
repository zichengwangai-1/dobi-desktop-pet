import Foundation
import CoreGraphics

public enum PetStage: String, Codable { case puppy, adult }
public struct PetLife: Codable {
    public let birthday: Date
    public private(set) var hasGrown: Bool
    public private(set) var selectedStage: PetStage?
    public init(birthday: Date, hasGrown: Bool = false) {
        self.birthday = birthday
        self.hasGrown = hasGrown
    }
    public mutating func stage(at date: Date) -> PetStage {
        if date.timeIntervalSince(birthday) >= 259_200 { hasGrown = true }
        return selectedStage ?? (hasGrown ? .adult : .puppy)
    }
    public mutating func selectStage(_ stage: PetStage?) { selectedStage = stage }
    public func remaining(at date: Date) -> TimeInterval {
        hasGrown ? 0 : max(0, 259_200 - date.timeIntervalSince(birthday))
    }
}

public enum PetAction: String, CaseIterable {
    case puppyWalk = "puppy_walk", puppySpin = "puppy_spin", puppySit = "puppy_sit"
    case adultWalk = "adult_walk", adultBark = "adult_bark"
    case puppyEat = "puppy_eat", adultEat = "adult_eat"
    case puppyPoop = "puppy_poop", adultPoop = "adult_poop"
    public static func pooping(for stage: PetStage) -> PetAction {
        stage == .puppy ? .puppyPoop : .adultPoop
    }
    public static func eating(for stage: PetStage) -> PetAction {
        stage == .puppy ? .puppyEat : .adultEat
    }
    public static func interaction(for stage: PetStage) -> PetAction {
        stage == .puppy ? .puppySit : .adultBark
    }
    public static func ambient(for stage: PetStage, excluding previous: PetAction? = nil) -> PetAction {
        let choices: [PetAction] = stage == .puppy ? [.puppyWalk, .puppySpin] : [.adultWalk, .adultBark]
        return choices.filter { $0 != previous }.randomElement() ?? choices[0]
    }
}

public struct PointerGesture {
    private var origin: CGPoint = .zero
    public private(set) var isDragging = false
    public init() {}
    public mutating func begin(at point: CGPoint) { origin = point; isDragging = false }
    public mutating func move(to point: CGPoint) -> Bool {
        if hypot(point.x - origin.x, point.y - origin.y) >= 4 { isDragging = true }
        return isDragging
    }
    public var shouldInteract: Bool { !isDragging }
}
