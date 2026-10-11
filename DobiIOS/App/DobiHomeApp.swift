import SwiftUI
import WidgetKit

@main
struct DobiHomeApp: App {
    var body: some Scene {
        WindowGroup { SetupView() }
    }
}

struct SetupView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("把杜宾，\n带到你的桌面。")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("抬眼就能看见它，点一下就能陪陪它。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                PetWidgetView(entry: .preview, previewFamily: .systemMedium)
                    .frame(height: 155).padding(16)
                    .background(PetPalette.cream, in: RoundedRectangle(cornerRadius: 26))
                    .allowsHitTesting(false).accessibilityLabel("杜宾中号小组件效果示意")
                VStack(alignment: .leading, spacing: 20) {
                    step("1", title: "回到主屏幕", detail: "长按主屏幕空白处，进入桌面编辑。")
                    step("2", title: "添加「杜宾」", detail: "打开小组件列表，搜索杜宾，选择小号或中号。")
                    step("3", title: "开始一起生活", detail: "点小狗摸摸，点按钮喂食、铲便便。长按小组件，选择「编辑小组件」即可切换年龄。")
                }
                Text("添加后，日常互动直接在桌面完成。")
                    .font(.footnote).foregroundStyle(PetPalette.moss)
            }
            .padding(28).frame(maxWidth: 500, alignment: .leading)
        }
        .background(Color.white).foregroundStyle(PetPalette.ink)
        .task {
            WidgetCenter.shared.reloadTimelines(ofKind: PetEnvironment.widgetKind)
        }
    }
    private func step(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(width: 28, height: 28)
                .background(PetPalette.moss.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
