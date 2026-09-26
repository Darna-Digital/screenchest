#!/usr/bin/env bash
# Builds build/ScreenChest.app from scratch: release binary via SwiftPM, the app
# icon compiled from Resources/ScreenChest.icon, Info.plist stamped with VERSION,
# the Sparkle framework, code signature.
#
#   scripts/build-app.sh                       # sign with "ScreenChest Dev" if present, else ad-hoc
#   SIGN_IDENTITY="My Cert" scripts/build-app.sh
#   SIGN_IDENTITY="Developer ID Application: …" scripts/build-app.sh   # notarizable (scripts/release.sh)
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

app_name="ScreenChest"
build_dir="$project_dir/build"
app="$build_dir/$app_name.app"
contents="$app/Contents"
icon_bundle="$project_dir/Resources/ScreenChest.icon"
icon_fallback_dir="$project_dir/Resources/icons"
icon_renderer="$project_dir/scripts/render-icon.swift"
icon_build="$build_dir/icon"
dev_identity="ScreenChest Dev"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"

resolve_sign_identity() {
  if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    echo "$SIGN_IDENTITY"
  elif security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$dev_identity\""; then
    echo "$dev_identity"
  else
    echo "-"
  fi
}

icon_sources_newer_than() {
  [[ -n "$(find "$icon_bundle" "$icon_fallback_dir" "$icon_renderer" "$0" -type f -newer "$1" -print -quit)" ]]
}

icon_is_current() {
  [[ -f "$icon_build/$app_name.icns" && -f "$icon_build/$app_name-dark.icns" ]] \
    && ! icon_sources_newer_than "$icon_build/$app_name.icns"
}

compile_icon() {
  xcrun actool "$1" \
    --compile "$2" \
    --platform macosx \
    --minimum-deployment-target 26.0 \
    --app-icon "$app_name" \
    --include-all-app-icons \
    --output-partial-info-plist "$icon_build/partial.plist" >/dev/null 2>&1
}

# macOS shows an Icon Composer icon's dark rendering only under the "Dark" icon
# style, not merely in dark mode, so DockIcon swaps in the dark .icns itself:
# the same bundle compiled again with its dark fills promoted to the default.
promote_dark_fills() {
  python3 - "$1" "$2" <<'PY'
import json, sys
def promote_dark(node):
    if isinstance(node, dict):
        fills = node.get("fill-specializations")
        if fills:
            dark = next((f for f in fills if f.get("appearance") == "dark"), None)
            if dark:
                node["fill-specializations"] = [{"value": dark["value"]}]
        for child in node.values():
            promote_dark(child)
    elif isinstance(node, list):
        for child in node:
            promote_dark(child)
icon = json.load(open(sys.argv[1]))
promote_dark(icon)
json.dump(icon, open(sys.argv[2], "w"), indent=2)
PY
}

svg_to_icns() {
  local iconset="$icon_build/iconset/$(basename "$2" .icns).iconset"
  mkdir -p "$iconset"
  for points in 16 32 128 256 512; do
    swift "$icon_renderer" "$1" "$iconset/icon_${points}x${points}.png" "$points"
    swift "$icon_renderer" "$1" "$iconset/icon_${points}x${points}@2x.png" "$((points * 2))"
  done
  iconutil --convert icns --output "$2" "$iconset"
}

compile_icons_with_actool() {
  local dark_source="$icon_build/dark-source/$app_name.icon"
  mkdir -p "$icon_build/light" "$icon_build/dark" "$dark_source"
  compile_icon "$icon_bundle" "$icon_build/light" || return 1
  cp -R "$icon_bundle/Assets" "$dark_source/"
  promote_dark_fills "$icon_bundle/icon.json" "$dark_source/icon.json"
  compile_icon "$dark_source" "$icon_build/dark"
  mv "$icon_build/light/$app_name.icns" "$icon_build/light/Assets.car" "$icon_build/"
  mv "$icon_build/dark/$app_name.icns" "$icon_build/$app_name-dark.icns"
}

render_icon() {
  if icon_is_current; then
    echo "→ app icon up to date"
    return
  fi
  echo "→ compiling app icon from ${icon_bundle#"$project_dir"/}"
  rm -rf "$build_dir/icon"
  mkdir -p "$icon_build"
  if ! compile_icons_with_actool; then
    echo "⚠ actool unavailable (it ships with Xcode); rendering the flat fallback icons"
    svg_to_icns "$icon_fallback_dir/screenchest-icon-light.svg" "$icon_build/$app_name.icns"
    svg_to_icns "$icon_fallback_dir/screenchest-icon-dark.svg" "$icon_build/$app_name-dark.icns"
  fi
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
  cp "$icon_build/$app_name.icns" "$icon_build/$app_name-dark.icns" "$contents/Resources/"
  if [[ -f "$icon_build/Assets.car" ]]; then
    cp "$icon_build/Assets.car" "$contents/Resources/"
  fi
  printf 'APPL????' > "$contents/PkgInfo"
  bundle_sparkle
  stamp_info_plist
}

bundle_sparkle() {
  mkdir -p "$contents/Frameworks"
  ditto ".build/release/Sparkle.framework" "$contents/Frameworks/Sparkle.framework"
  rm -rf "$contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" \
    "$contents/Frameworks/Sparkle.framework/XPCServices"
}

is_distribution_identity() {
  [[ "$1" == "Developer ID Application:"* ]]
}

stamp_info_plist() {
  /usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $version" \
    -c "Set :CFBundleVersion $version" \
    "$contents/Info.plist"
  if ! is_distribution_identity "$(resolve_sign_identity)"; then
    /usr/libexec/PlistBuddy -c "Set :SUEnableAutomaticChecks false" "$contents/Info.plist"
  fi
}

sign_bundle() {
  local identity sparkle
  identity="$(resolve_sign_identity)"
  sparkle="$contents/Frameworks/Sparkle.framework"
  echo "→ codesign ($identity)"
  sign "$identity" "$sparkle/Versions/B/Autoupdate"
  sign "$identity" "$sparkle/Versions/B/Updater.app"
  sign "$identity" "$sparkle"
  sign "$identity" "$app" --entitlements "$project_dir/Resources/ScreenChest.entitlements"
  if [[ "$identity" != "-" ]] && codesign -dv "$app" 2>&1 | grep -q "^Signature=adhoc"; then
    echo "✗ $app_name.app is ad-hoc signed though \"$identity\" was asked for." >&2
    exit 1
  fi
  if [[ "$identity" == "-" ]]; then
    echo "⚠ ad-hoc signed: the Screen Recording grant will not survive rebuilds."
    echo "  Run scripts/create-signing-identity.sh once to fix that."
  fi
}

sign() {
  local identity="$1" target="$2"
  shift 2
  local distribution_flags=()
  if is_distribution_identity "$identity"; then
    distribution_flags=(--options runtime --timestamp)
  fi
  codesign --force --sign "$identity" ${distribution_flags[@]+"${distribution_flags[@]}"} "$@" "$target"
}

mkdir -p "$build_dir"
render_icon
build_binary
assemble_bundle
sign_bundle
echo "✓ built ${app#"$project_dir"/} $version"
