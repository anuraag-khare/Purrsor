#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/PurrsorDerivedData}"
APP_BUNDLE_IDENTIFIER="${APP_BUNDLE_IDENTIFIER:-com.anuraagkhare.purrsor.dev}"

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

echo "Built app at:"
echo "$DERIVED_DATA_PATH/Build/Products/Debug/Purrsor.app"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Signing: ad hoc"
else
  echo "Signing identity: $SIGNING_IDENTITY"
fi
echo
echo "Open with:"
echo "open \"$DERIVED_DATA_PATH/Build/Products/Debug/Purrsor.app\""
