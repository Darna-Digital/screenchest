#!/usr/bin/env bash
# Turns a Developer ID–signed ScreenChest.app (scripts/build-app.sh) into the
# notarized, stapled disk image a release ships. Prints the image's path on
# stdout; everything else goes to stderr.
#
#   SIGN_IDENTITY="Developer ID Application: …" \
#   APPLE_API_KEY_PATH=AuthKey_XXXX.p8 APPLE_API_KEY_ID=XXXX APPLE_API_ISSUER=<uuid> \
#   scripts/release.sh build/ScreenChest.app build/dist
set -euo pipefail

app="${1:?usage: release.sh <ScreenChest.app> <out-dir>}"
out_dir="${2:?usage: release.sh <ScreenChest.app> <out-dir>}"
: "${SIGN_IDENTITY:?}" "${APPLE_API_KEY_PATH:?}" "${APPLE_API_KEY_ID:?}" "${APPLE_API_ISSUER:?}"

version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app}/Contents/Info.plist")"
arch="$(lipo -archs "${app}/Contents/MacOS/ScreenChest")"
if [[ "$arch" == *" "* ]]; then arch="universal"; fi
dmg="${out_dir}/ScreenChest-${version}-${arch}.dmg"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$out_dir"

# notarytool can exit non-zero on a rejection, and the reason is only in the
# submission's log, so the status is read from its JSON instead.
notarize() {
  local submission="$1" status id result
  result="$(xcrun notarytool submit "$submission" \
    --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" \
    --wait --output-format json)" || true
  status="$(plutil -extract status raw -o - - <<<"$result" 2>/dev/null || echo unknown)"
  id="$(plutil -extract id raw -o - - <<<"$result" 2>/dev/null || echo "")"
  echo "notarization of ${submission##*/}: ${status} ${id}" >&2
  if [[ "$status" != "Accepted" ]]; then
    echo "$result" >&2
    if [[ -n "$id" ]]; then
      xcrun notarytool log "$id" \
        --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" >&2 || true
    fi
    exit 1
  fi
}

ditto -c -k --keepParent "$app" "${work}/ScreenChest.zip"
notarize "${work}/ScreenChest.zip"
xcrun stapler staple "$app" >&2

mkdir -p "${work}/image"
ditto "$app" "${work}/image/ScreenChest.app"
ln -s /Applications "${work}/image/Applications"
hdiutil create -volname "ScreenChest" -srcfolder "${work}/image" -fs HFS+ -format UDZO -ov "$dmg" >&2
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$dmg"
notarize "$dmg"
xcrun stapler staple "$dmg" >&2

spctl --assess --type execute --verbose "$app" >&2
spctl --assess --type open --context context:primary-signature --verbose "$dmg" >&2

echo "$dmg"
