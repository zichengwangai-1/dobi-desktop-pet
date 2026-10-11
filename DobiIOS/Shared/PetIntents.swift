import AppIntents
import WidgetKit

extension AgeChoice: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "成长阶段" }
    public static var caseDisplayRepresentations: [AgeChoice: DisplayRepresentation] {
        [.automatic: "自动成长（3 天）", .puppy: "幼年期", .adult: "成年期"]
    }
}

extension PetAction: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "和杜宾互动" }
    public static var caseDisplayRepresentations: [PetAction: DisplayRepresentation] {
        [.feed: "喂食", .pet: "摸摸", .clean: "铲便便"]
    }
}

struct PetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "杜宾的成长阶段" }
    static var description: IntentDescription { "选择幼年、成年，或陪伴三天自动长大。" }
    @Parameter(title: "成长阶段", default: .automatic)
    var age: AgeChoice
}

struct PetInteraction: AppIntent {
    static var title: LocalizedStringResource { "和杜宾互动" }
    static var description: IntentDescription { "直接在桌面喂食、摸摸或清理一坨便便。" }
    static var openAppWhenRun: Bool { false }
    static var isDiscoverable: Bool { false }
    @Parameter(title: "互动") var action: PetAction
    init() {}
    init(_ action: PetAction) { self.action = action }
    func perform() async throws -> some IntentResult {
        _ = try PetEnvironment.repository().perform(action, at: Date())
        WidgetCenter.shared.reloadTimelines(ofKind: PetEnvironment.widgetKind)
        return .result()
    }
}
