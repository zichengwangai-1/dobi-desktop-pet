import WidgetKit

struct PetEntry: TimelineEntry {
    var date: Date
    var state: PetState
    var age: AgeChoice
    var unavailable = false
    var stage: PetStage { state.stage(for: age) }
    var stageLabel: String { stage == .puppy ? "幼年期" : "成年期" }
    var message: String { state.message(for: stage, at: date) }
    var imageName: String { state.imageName(for: stage, at: date) }
    static var preview: Self { Self(date: Date(), state: PetState(now: Date()), age: .puppy) }
}
