import WidgetKit

struct PetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PetEntry { .preview }
    func snapshot(for configuration: PetConfiguration, in context: Context) async -> PetEntry {
        if context.isPreview {
            var entry = PetEntry.preview; entry.age = configuration.age
            return entry
        }
        return load(configuration, at: Date())
    }
    func timeline(for configuration: PetConfiguration, in context: Context) async -> Timeline<PetEntry> {
        let now = Date()
        let first = load(configuration, at: now)
        guard !first.unavailable else {
            return Timeline(entries: [first], policy: .after(now.addingTimeInterval(900)))
        }
        var entries = [first]
        var projected = first.state
        // Project a six-hour timeline without writing future state to shared storage.
        // WidgetKit controls when entries become visible; this is not a background timer.
        for _ in 0..<72 {
            let next = projected.nextIdleDate
            projected.advance(to: next)
            entries.append(PetEntry(date: next, state: projected, age: configuration.age))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
    private func load(_ configuration: PetConfiguration, at date: Date) -> PetEntry {
        do {
            let state = try PetEnvironment.repository().snapshot(at: date)
            return PetEntry(date: date, state: state, age: configuration.age)
        } catch {
            return PetEntry(date: date, state: PetState(now: date), age: configuration.age, unavailable: true)
        }
    }
}
