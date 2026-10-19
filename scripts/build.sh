#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then
  echo "Servono macOS e Xcode 15+ (SDK iOS 17+/macOS 14+)." >&2
  exit 1
fi
swift test
xcodebuild -project AnimeKodoku.xcodeproj -scheme AnimeKodoku -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/iOS CODE_SIGNING_ALLOWED=NO build
xcodebuild -project AnimeKodoku.xcodeproj -scheme AnimeKodoku-macOS -destination 'generic/platform=macOS' -derivedDataPath build/macOS CODE_SIGNING_ALLOWED=NO build
