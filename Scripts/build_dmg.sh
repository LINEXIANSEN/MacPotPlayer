#!/usr/bin/env bash
# build_dmg.sh - 在 macOS 上将 MacPotPlayer.app 打包成 .dmg
# 用法: ./Scripts/build_dmg.sh [version]
set -euo pipefail

VERSION="${1:-1.0.0}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${PROJECT_ROOT}/build/Release/MacPotPlayer.app"
OUTPUT_DIR="${PROJECT_ROOT}/dist"

echo "=== MacPotPlayer DMG Builder ==="
echo "Version: ${VERSION}"
echo "Project: ${PROJECT_ROOT}"

# 检查 create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "Installing create-dmg..."
    brew install create-dmg
fi

# 确保 app 已构建
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App not found at ${APP_PATH}"
    echo "Run 'xcodegen generate && xcodebuild -scheme MacPotPlayer -configuration Release build' first."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
DMG_PATH="${OUTPUT_DIR}/MacPotPlayer_${VERSION}_macOS.dmg"

echo "Creating DMG..."
create-dmg \
    --volname "MacPotPlayer ${VERSION}" \
    --volicon "${PROJECT_ROOT}/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 100 \
    --app-drop-link 480 170 \
    --hide-extension "MacPotPlayer.app" \
    "$DMG_PATH" \
    "$APP_PATH"

echo ""
echo "✅ DMG created: ${DMG_PATH}"
ls -lh "$DMG_PATH"
