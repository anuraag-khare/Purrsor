#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/Build/Purrsor.app"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/PurrsorDebugDerivedData}"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/Purrsor.app"
APP_BUNDLE_IDENTIFIER="${APP_BUNDLE_IDENTIFIER:-com.anuraagkhare.purrsor.dev}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

cd "$ROOT_DIR"
xcodegen generate
xcodebuild \
  -project Purrsor.xcodeproj \
  -scheme Purrsor \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  PRODUCT_BUNDLE_IDENTIFIER="$APP_BUNDLE_IDENTIFIER" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  build

rm -rf "$APP_DIR"
mkdir -p "$(dirname "$APP_DIR")"
cp -R "$BUILT_APP_PATH" "$APP_DIR"

echo "Bundled app at: $APP_DIR"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Signing: ad hoc"
else
  echo "Signing identity: $SIGNING_IDENTITY"
fi
echo "Open with: open \"$APP_DIR\""
