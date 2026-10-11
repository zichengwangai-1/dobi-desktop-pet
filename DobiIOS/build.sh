#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
xcodebuild -project "$TASK_ROOT/DobiHome.xcodeproj" -target DobiHome \
  -parallelizeTargets -sdk iphoneos -configuration Release \
  SYMROOT="$TASK_ROOT/build" OBJROOT="$TASK_ROOT/.build/ios-objects" \
  CODE_SIGNING_ALLOWED=NO build
echo "已生成未签名 iPhone 应用：$TASK_ROOT/build/Release-iphoneos/DobiHome.app"
