#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/Build/Products/Release/YouTubeAudioDownloader.app"

xcodebuild \
  -project "$PROJECT_DIR/YouTubeAudioDownloader.xcodeproj" \
  -scheme YouTubeAudioDownloader \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build

codesign --force --deep --sign - "$APP_PATH"

echo "Built app:"
echo "$APP_PATH"
