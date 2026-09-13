#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
for item in StarNetBin/starnet2 StarNetBin/StarNet2_weights.pt StarNetBin/lib; do
  test -e "$item" || { echo "Missing runtime dependency: $item; see StarNetBin/README.md"; exit 1; }
done
xcodebuild -project StarNetPro.xcodeproj -scheme StarNetPro -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO ARCHS=arm64 build
mkdir -p dist
cp -R build/Build/Products/Release/StarNetPro.app dist/
# Ad-hoc signing for local testing only; this is not Developer ID signing or notarization.
find dist/StarNetPro.app/Contents/Resources/StarNetBin -name '*.dylib' -exec codesign --force --sign - {} \;
codesign --force --sign - dist/StarNetPro.app/Contents/Resources/StarNetBin/starnet2
codesign --force --sign - dist/StarNetPro.app
codesign --verify --deep --strict dist/StarNetPro.app
ditto -c -k --keepParent dist/StarNetPro.app dist/StarNetPro-macOS-arm64-local-test.zip
