#!/bin/bash
#
# Build, notarize, and staple BirdoSaver.saver for distribution.
#
# One-time setup (create an app-specific password at appleid.apple.com):
#   xcrun notarytool store-credentials birdo-notary \
#     --apple-id <your-apple-id> --team-id 96VR936H35 --password <app-specific-password>
#
# Then each release:
#   ./release.sh
#
set -euo pipefail

PROFILE="${NOTARY_PROFILE:-birdo-notary}"
IDENTITY="Developer ID Application: Jeremy Beker (96VR936H35)"
PROJECT=birdo.xcodeproj
TARGET=birdoSaver
BUILD_DIR=build
SAVER="$BUILD_DIR/Release/BirdoSaver.saver"

cd "$(dirname "$0")"

if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "error: no notarization credentials under keychain profile '$PROFILE'." >&2
    echo "Run the store-credentials command in the header of this script first." >&2
    exit 1
fi

echo "==> Building $TARGET (Release)"
xcodebuild -project "$PROJECT" -target "$TARGET" -configuration Release build \
    -quiet \
    SYMROOT="$PWD/$BUILD_DIR" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="--timestamp"

VERSION=$(plutil -extract CFBundleShortVersionString raw "$SAVER/Contents/Info.plist")
ARTIFACT="$BUILD_DIR/BirdoSaver-$VERSION.zip"

echo "==> Submitting for notarization"
ditto -c -k --keepParent "$SAVER" "$BUILD_DIR/BirdoSaver-notarize.zip"
xcrun notarytool submit "$BUILD_DIR/BirdoSaver-notarize.zip" \
    --keychain-profile "$PROFILE" --wait
rm "$BUILD_DIR/BirdoSaver-notarize.zip"

echo "==> Stapling"
xcrun stapler staple "$SAVER"

echo "==> Verifying"
spctl -a -t install -vv "$SAVER"

ditto -c -k --keepParent "$SAVER" "$ARTIFACT"
echo
echo "Release artifact: $ARTIFACT"
echo "Recipients unzip and double-click the .saver to install."
