#!/usr/bin/env bash
# Build, launch, and keep ScreenChest.app current: every save under Sources/,
# Resources/ or to the package manifest rebuilds the bundle (make app) and
# replaces the running app. A failed build leaves the old app up, prints the
# compiler's errors here and waits for the next save.
#
# The tree is polled with `find -newer` once a second, so nothing beyond the
# toolchain is required. The app is relaunched by its bundle path, which is
# also how the cmux stop script finds it.
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

app="${project_dir}/build/ScreenChest.app"
stamp="${project_dir}/.build/watch.stamp"
watched=(Sources Resources Package.swift Makefile)

mkdir -p "${project_dir}/.build"

changed_since_stamp() {
  [[ -n "$(find "${watched[@]}" -type f -newer "$stamp" -print -quit 2>/dev/null)" ]]
}

wait_for_change() {
  until changed_since_stamp; do sleep 1; done
  sleep 0.3
}

relaunch() {
  pkill -f "$app" 2>/dev/null || true
  local i=0
  while pgrep -f "$app" >/dev/null 2>&1; do
    if [[ $i -ge 50 ]]; then pkill -9 -f "$app" 2>/dev/null || true; break; fi
    i=$((i + 1))
    sleep 0.1
  done
  open "$app"
}

build_and_relaunch() {
  touch "$stamp"
  if make app; then
    relaunch
    echo "✓ $(date +%H:%M:%S) ScreenChest.app relaunched — watching ${watched[*]}"
  else
    echo "✗ $(date +%H:%M:%S) build failed — the running app stays up; save again to retry"
  fi
}

build_and_relaunch
while true; do
  wait_for_change
  build_and_relaunch
done
