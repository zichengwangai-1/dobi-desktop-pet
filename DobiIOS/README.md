# 杜宾 · iPhone 桌面交互小组件

只提供主屏幕小号、中号两种小组件，最低 iOS 17。安装时包含一个展示添加指引的轻量 App；日常喂食、摸摸和铲便便直接在桌面完成。

## 使用

- 点击小狗：幼年显示坐下姿势，成年显示犬吠姿势和文字反馈。
- 点击「喂食」：显示对应年龄的吃饭姿势，连续点击逐次记录。
- 点击便便或「铲便便」：每次清除一坨，其余保留。没有便便时禁用清理按钮。
- 长按小组件 →「编辑小组件」→「成长阶段」：选择幼年期、成年期或自动成长。自动模式从首次使用小组件起满 72 小时成年；手动模式只改变当前组件的形象，不改出生时间。
- 可以添加多个组件，共同照顾同一只狗；各组件可以选择不同年龄形象。所有数据保存于小组件扩展的本地容器，重启不丢失。

这不是跨 App 悬浮窗。小狗和便便的图片具有真实透明通道，但组件底板和配色仍由 iOS 外观模式控制。本版使用透明姿势图片和短暂过渡动画，不持续播放视频、不播放犬吠音频、不访问或删除手机文件。

空闲便便按每 5 分钟一个周期计算；iOS 决定小组件实际何时更新，因此不保证每 5 分钟准时出现在屏幕上。晚刷新的周期会补计，已有数量持续累积。摸摸、喂食重置空闲计时，铲便便不重置。便便在组件内展示和清理，不会出现在其他桌面位置。

## 装到自己的 iPhone

1. 用 Xcode 打开 `DobiHome.xcodeproj`。若 Xcode 提示缺少 iOS 平台，先在 Settings → Components 安装对应组件。
2. 在 Xcode → Settings → Accounts 登录自己的 Apple 账号。
3. 在两个 target（`DobiHome`、`DobiHomeWidget`）的 Signing & Capabilities 中选择相同 Team，保持 Automatically manage signing。若包名被占用，修改 `Configuration/Project.xcconfig` 的 `DOBI_BUNDLE_PREFIX` 为自己的唯一前缀。
4. 连接 iPhone，信任电脑，按 Xcode 指引开启开发者模式；选择手机作为运行设备，运行 `DobiHome`。
5. 回到 iPhone 主屏幕，长按空白处，打开添加小组件列表，搜索「杜宾」，添加小号或中号。

添加完成后，可以把杜宾的安装引导图标从主屏幕移到 App 资源库，桌面只留下小宠物组件。

本工程不需要 App Groups 权限。安装和长期使用的签名有效期以 Apple 账号及 Xcode 的实际提示为准。仓库中的构建产物未签名，不能直接发送到 iPhone 安装。

## 本地开发与验证

```sh
bash DobiIOS/build.sh
CLANG_MODULE_CACHE_PATH=/tmp/dobi-ios-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/dobi-ios-cache \
  swift test --package-path DobiIOS --disable-sandbox --cache-path /tmp/dobi-ios-spm \
  --config-path /tmp/dobi-ios-config --security-path /tmp/dobi-ios-security
python3 DobiIOS/Tools/render_previews.py
```

构建同时编译宿主 App、小组件扩展及 App Intents 元数据；输出在 `build/Release-iphoneos/DobiHome.app`。`Previews/` 是实际 SwiftUI 组件的 macOS 渲染结果，用于布局检查，不代表 iPhone WidgetKit 真机截图。

`Shared/Core/` 为可独立测试的成长、交互、空闲周期和持久化逻辑。读改写采用文件锁和原子替换，避免多个组件、快速连续点击丢更新。所有交互 Intent 保持 `openAppWhenRun = false`，不对快捷指令公开，默认在组件扩展内完成。宿主 App 没有宠物数据或养宠页面。

`PetProvider` 预生成六小时的时间线；未来条目只在内存投影，避免把未来的便便、成长提前写入本地。读取失败会显示重试提示，投喂失败会交给系统显示失败，不重置已有数据。

`Tools/prepare_assets.py` 从已有 macOS 透明视频导出六张姿势图，缩小原始透明便便图，并生成安装图标。它只用于更换素材，需要 ffmpeg。日常运行不依赖 ffmpeg、网络或 macOS 项目。

工程生成不依赖 XcodeGen。默认以普通 PNG 资源打包，便于只有 SDK、没有模拟器运行时的环境构建。安装完整 iOS 平台后，若准备 App Store 分发，执行 `python3 DobiIOS/Tools/generate_project.py --asset-catalog` 切换到包含 1024 图标的标准资产目录配置，再用 Xcode Archive 验证；本次不包含上架或上传。

## 真机检查清单

当前环境未安装 iPhone 模拟器，也未连接签名真机。上线前需要在手机上确认：添加两种尺寸、杀掉宿主 App 后仍可互动、快速连续投喂、单坨清理、编辑年龄、自动成长、多个组件同步、重启持久化、深色／着色／透明外观和大字体下的布局。WidgetKit 的显示调度与实际动画只以真机结果为准。
