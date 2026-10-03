#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$TASK_ROOT/../杜宾.app"
export CLANG_MODULE_CACHE_PATH="$TASK_ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$CLANG_MODULE_CACHE_PATH"
cd "$TASK_ROOT"
swift build -c release --disable-sandbox --cache-path "$TASK_ROOT/.build/spm-cache" \
  --config-path "$TASK_ROOT/.build/spm-config" --security-path "$TASK_ROOT/.build/spm-security"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp .build/release/DobiPet "$APP_PATH/Contents/MacOS/DobiPet"
cp -R Resources/Videos "$APP_PATH/Contents/Resources/"
cp -R Resources/Sounds "$APP_PATH/Contents/Resources/"
if [ -f Resources/Dobi.icns ]; then cp Resources/Dobi.icns "$APP_PATH/Contents/Resources/"; fi
cp Info.plist "$APP_PATH/Contents/Info.plist"
codesign --force --sign - "$APP_PATH"
echo "已生成：$APP_PATH"
