#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -quiet -project StarNetPro.xcodeproj -scheme StarNetPro -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO ARCHS=arm64 clean build
mkdir -p dist
staging_dir="$(mktemp -d dist/StarNetPro-local.XXXXXX)"
cp -R build/Build/Products/Release/StarNetPro.app "$staging_dir/"
# Refuse accidental runtime bundling, including stale resources from an old build.
test ! -e "$staging_dir/StarNetPro.app/Contents/Resources/StarNetBin"
# Ad-hoc signing for local tests; not Developer ID signing or notarization.
codesign --force --sign - "$staging_dir/StarNetPro.app"
codesign --verify --deep --strict "$staging_dir/StarNetPro.app"
ditto -c -k --keepParent "$staging_dir/StarNetPro.app" dist/StarNetPro-macOS-arm64-local-test.zip
echo "Local test app: $staging_dir/StarNetPro.app"
