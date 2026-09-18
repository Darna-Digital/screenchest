#!/usr/bin/env bash
# Builds ScreenChest.app and installs it into /Applications (or $INSTALL_DIR),
# replacing any previous copy, then launches it. Safe to rerun at any time.
#
#   scripts/install.sh              # build, install, launch
#   scripts/install.sh --no-launch  # build and install only
#   INSTALL_DIR=~/Applications scripts/install.sh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_name="ScreenChest"
bundle_id="com.darnadigital.screenchest"
built_app="$project_dir/build/$app_name.app"
install_dir="${INSTALL_DIR:-/Applications}"
installed_app="$install_dir/$app_name.app"
launch=true

for arg in "$@"; do
  case "$arg" in
    --no-launch) launch=false ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

quit_running_app() {
  if pgrep -xq "$app_name"; then
    echo "→ quitting running $app_name"
    osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
    for _ in $(seq 1 50); do
      pgrep -xq "$app_name" || break
      sleep 0.1
    done
    pkill -x "$app_name" 2>/dev/null || true
  fi
}

install_bundle() {
  echo "→ installing to $installed_app"
  mkdir -p "$install_dir"
  rm -rf "$installed_app"
  ditto "$built_app" "$installed_app"
  touch "$installed_app"
}

"$project_dir/scripts/build-app.sh"
quit_running_app
install_bundle
echo "✓ installed $installed_app"

if $launch; then
  echo "→ launching"
  open "$installed_app"
fi
