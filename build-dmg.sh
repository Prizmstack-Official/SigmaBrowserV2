#!/usr/bin/env bash
#
# build-dmg.sh — Build an unsigned Noriq.dmg from the Nook Xcode project.
#
# Usage:
#   ./build-dmg.sh            # Apple Silicon only (default)
#   ./build-dmg.sh universal  # Universal binary (arm64 + x86_64)
#
# The resulting .dmg lands in the repo root.
# Since it's unsigned, right-click → Open on first launch,
# or allow it via System Settings → Privacy & Security.

set -euo pipefail

SCHEME="Nook"
CONFIGURATION="Release"
BUILD_DIR="build"
APP_NAME="Noriq"
ARCH_MODE="${1:-arm64}"

# Resolve architectures
if [[ "$ARCH_MODE" == "universal" ]]; then
  ARCH_FLAGS=( -arch arm64 -arch x86_64 )
  echo "→ Building universal binary (arm64 + x86_64)"
else
  ARCH_FLAGS=( -arch arm64 )
  echo "→ Building for Apple Silicon (arm64)"
fi

# Clean previous artifacts
rm -rf "$BUILD_DIR" "${APP_NAME}.app" "${APP_NAME}.dmg"

# Build without code signing
echo "→ Building ${APP_NAME}.app (${CONFIGURATION})..."
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  "${ARCH_FLAGS[@]}" \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  | tail -5

# Locate the built .app
APP_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "✗ Build failed — ${APP_PATH} not found."
  echo "  Check xcodebuild output above for errors."
  exit 1
fi

# Copy .app to repo root for DMG packaging
cp -R "$APP_PATH" "./${APP_NAME}.app"

# Create the .dmg
echo "→ Creating ${APP_NAME}.dmg..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "${APP_NAME}.app" \
  -ov -format UDZO \
  "${APP_NAME}.dmg"

# Cleanup intermediate .app copy
rm -rf "${APP_NAME}.app"

DMG_SIZE=$(du -h "${APP_NAME}.dmg" | cut -f1)
echo ""
echo "✓ ${APP_NAME}.dmg (${DMG_SIZE}) is ready."
echo "  Install: open ${APP_NAME}.dmg → drag to Applications"
echo "  First launch: right-click → Open (bypasses Gatekeeper)"
