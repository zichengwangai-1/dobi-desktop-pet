import SwiftUI
import WidgetKit

@main
struct DobiHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: PetEnvironment.widgetKind, intent: PetConfiguration.self, provider: PetProvider()) { entry in
            PetWidgetView(entry: entry)
        }
        .configurationDisplayName("杜宾 · 桌面小宠物")
        .description("摸摸、喂食、铲便便。长按编辑小组件可切换幼年期或成年期。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .disfavoredLocations([.standBy], for: [.systemSmall])
    }
}
