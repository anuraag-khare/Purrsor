#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/Build/Release/Purrsor.app"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/PurrsorReleaseDerivedData}"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/Purrsor.app"
APP_BUNDLE_IDENTIFIER="${APP_BUNDLE_IDENTIFIER:-com.anuraagkhare.purrsor}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

cd "$ROOT_DIR"
xcodegen generate
xcodebuild \
  -project Purrsor.xcodeproj \
  -scheme Purrsor \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  PRODUCT_BUNDLE_IDENTIFIER="$APP_BUNDLE_IDENTIFIER" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  build

rm -rf "$APP_DIR"
mkdir -p "$(dirname "$APP_DIR")"
cp -R "$BUILT_APP_PATH" "$APP_DIR"

echo "Built standalone app at:"
echo "$APP_DIR"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Signing: ad hoc"
else
  echo "Signing identity: $SIGNING_IDENTITY"
fi
echo
echo "Move it into Applications with:"
echo "cp -R \"$APP_DIR\" /Applications/"
