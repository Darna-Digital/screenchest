#!/usr/bin/env bash
# Builds build/ScreenChest.app from scratch: release binary via SwiftPM, the app
# icon rendered from Resources/AppIcon/AppIcon.svg, Info.plist, code signature.
#
#   scripts/build-app.sh                       # sign with "ScreenChest Dev" if present, else ad-hoc
#   SIGN_IDENTITY="My Cert" scripts/build-app.sh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

app_name="ScreenChest"
build_dir="$project_dir/build"
app="$build_dir/$app_name.app"
contents="$app/Contents"
icon_svg="$project_dir/Resources/AppIcon/AppIcon.svg"
icon_renderer="$project_dir/scripts/render-icon.swift"
iconset="$build_dir/AppIcon.iconset"
icns="$build_dir/AppIcon.icns"
dev_identity="ScreenChest Dev"

resolve_sign_identity() {
  if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    echo "$SIGN_IDENTITY"
  elif security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$dev_identity\""; then
    echo "$dev_identity"
  else
    echo "-"
  fi
}

icon_is_current() {
  [[ -f "$icns" && "$icns" -nt "$icon_svg" && "$icns" -nt "$icon_renderer" ]]
}

render_icon() {
  if icon_is_current; then
    echo "→ app icon up to date"
    return
  fi
  echo "→ rendering app icon from ${icon_svg#"$project_dir"/}"
  rm -rf "$iconset"
  mkdir -p "$iconset"
  for points in 16 32 128 256 512; do
    swift "$icon_renderer" "$icon_svg" "$iconset/icon_${points}x${points}.png" "$points"
    swift "$icon_renderer" "$icon_svg" "$iconset/icon_${points}x${points}@2x.png" "$((points * 2))"
  done
  iconutil --convert icns --output "$icns" "$iconset"
  rm -rf "$iconset"
}

build_binary() {
  echo "→ swift build -c release"
  swift build -c release
}

assemble_bundle() {
  echo "→ assembling ${app#"$project_dir"/}"
  rm -rf "$app"
  mkdir -p "$contents/MacOS" "$contents/Resources"
  cp ".build/release/$app_name" "$contents/MacOS/$app_name"
  cp "Resources/Info.plist" "$contents/Info.plist"
  cp "$icns" "$contents/Resources/AppIcon.icns"
  printf 'APPL????' > "$contents/PkgInfo"
}

sign_bundle() {
  local identity
  identity="$(resolve_sign_identity)"
  echo "→ codesign ($identity)"
  codesign --force --sign "$identity" "$app"
  if [[ "$identity" == "-" ]]; then
    echo "⚠ ad-hoc signed: the Screen Recording grant will not survive rebuilds."
    echo "  Run scripts/create-signing-identity.sh once to fix that."
  fi
}

mkdir -p "$build_dir"
render_icon
build_binary
assemble_bundle
sign_bundle
echo "✓ built ${app#"$project_dir"/}"
