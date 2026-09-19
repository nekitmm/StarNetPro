#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -quiet -project StarNetPro.xcodeproj -scheme StarNetPro \
  -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath build \
  -only-testing:StarNetProTests CODE_SIGNING_ALLOWED=NO test
