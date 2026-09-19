#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project StarNetPro.xcodeproj -scheme StarNetPro -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO ARCHS=arm64 build
mkdir -p dist
cp -R build/Build/Products/Release/StarNetPro.app dist/
# Refuse accidental runtime bundling, including stale resources from an old build.
if [ -e dist/StarNetPro.app/Contents/Resources/StarNetBin ]; then
  echo "Stale bundled engine found. Clean the Xcode build and remove dist/StarNetPro.app, then rebuild." >&2
  exit 1
fi
# Ad-hoc signing for local testing only; this is not Developer ID signing or notarization.
codesign --force --sign - dist/StarNetPro.app
codesign --verify --deep --strict dist/StarNetPro.app
ditto -c -k --keepParent dist/StarNetPro.app dist/StarNetPro-macOS-arm64-local-test.zip
