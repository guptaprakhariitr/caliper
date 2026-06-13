#!/usr/bin/env bash
# Build + export a Mac App Store package for Caliper.
# Requires: full Xcode, xcodegen, an Apple Developer Program membership, and a
# signed-in account (Apple Distribution + Mac Installer Distribution certs).
#
#   export DEVELOPMENT_TEAM=ABCDE12345          # required (10-char Team ID)
#   export BUNDLE_ID=com.plainware.caliper       # optional (must match GoogleService-Info if Firebase is on)
#   Scripts/release-appstore.sh
#
# Output: build/Caliper.pkg  → upload with fastlane (Scripts: `fastlane mac upload`)
#         or Transporter / `xcrun altool --upload-app -f build/Caliper.pkg -t macos ...`
set -euo pipefail
cd "$(dirname "$0")/.."

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your 10-char Apple Team ID}"
BUNDLE_ID="${BUNDLE_ID:-com.plainware.caliper}"
SCHEME="Caliper"

command -v xcodebuild >/dev/null || { echo "❌ full Xcode required (xcodebuild not found)"; exit 1; }
command -v xcodegen   >/dev/null || { echo "❌ xcodegen required: brew install xcodegen"; exit 1; }

echo "==> Generating Xcode project (team $DEVELOPMENT_TEAM)"
DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" xcodegen generate

echo "==> Archiving"
rm -rf build/Caliper.xcarchive build/export
xcodebuild -project Caliper.xcodeproj -scheme "$SCHEME" -configuration Release \
  -archivePath build/Caliper.xcarchive archive \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"

echo "==> Exporting for App Store"
xcodebuild -exportArchive -archivePath build/Caliper.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions-appstore.plist

PKG=$(ls build/export/*.pkg 2>/dev/null | head -1 || true)
[ -n "$PKG" ] && cp "$PKG" build/Caliper.pkg && echo "✅ build/Caliper.pkg ready" || echo "⚠️  no .pkg produced — check signing"
echo "Next: upload with  fastlane mac upload   (or Transporter)."
