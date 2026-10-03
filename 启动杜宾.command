#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
if [ ! -d "$TASK_ROOT/杜宾.app" ]; then "$TASK_ROOT/DobiNative/build.sh"; fi
open "$TASK_ROOT/杜宾.app"
