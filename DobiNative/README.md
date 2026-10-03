# 杜宾 · macOS 桌宠

双击项目根目录的 **杜宾.app** 或 **启动杜宾.command**。运行时不需要 Flutter、Python、ffmpeg 或网络。

- 小狗始终播放动态视频。幼年随机散步、转圈；成年随机散步、犬吠动作。
- 单击幼犬播放坐下，单击成年犬播放犬吠并发声，完成后自动继续随机动作。
- 按住小狗拖动；透明空白区域的点击穿透到桌面。
- 右键小狗，选择「关闭杜宾」。菜单栏爪印也可以关闭、调整大小、静音或找回小狗。
- 首次启动满 72 小时自动成年，包括退出期间。年龄、大小、声音和位置在本机保存，重启不重置。成年后不会因为系统时间回退重新变成幼犬。

## 素材与透明背景

原始文件位于 `../杜宾：小狗动作画面/杜宾/`，它们是带黑色背景的 HEVC 视频，没有 Alpha 通道。
本版本通过 macOS Vision 对每帧做前景分割，保留深色毛发，将结果编码为 **ProRes 4444 / yuva444p10le / Alpha**。
应用直接解码真正的透明视频，透明窗口无背景、无阴影、无标题栏。切换动作时保留上一帧，避免空白闪烁。
源视频没有被修改。透明结果位于 `Resources/Videos/`，应用内包含相同视频。
由于原始素材已混合黑底，轮廓仍可能有少量分割误差；若以后提供原始透明导出，可以直接替换这五段文件。

## 开发

需要 macOS 14+、Xcode Command Line Tools。当前构建适用于 Apple Silicon。

```sh
./build.sh
CLANG_MODULE_CACHE_PATH=/tmp/dobi-swift-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/dobi-swift-cache \
  swift test --disable-sandbox --cache-path /tmp/dobi-spm-cache \
  --config-path /tmp/dobi-spm-config --security-path /tmp/dobi-spm-security
```

重新生成视频仅用于更换原始素材，需要 `ffmpeg`：

```sh
python3 Tools/prepare_assets.py
./build.sh
```

测试覆盖 72 小时成长边界、成年持久化、年龄对应互动、随机动作年龄隔离，以及拖动不触发点击。
原有 `dobipet/` Flutter 原型保留；本产品的可运行 macOS 版本位于 `DobiNative/`。
