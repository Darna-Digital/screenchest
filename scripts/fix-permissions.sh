#!/usr/bin/env bash
# Run this whenever macOS stops letting ScreenChest record.
#
# Screen Recording / Camera / Microphone grants are tied to the app's code
# signature. Ad-hoc signed builds get a new signature on every rebuild, so
# macOS forgets the grant each time. This script makes sure the bundle is
# signed with the stable "ScreenChest Dev" identity, clears any stale grants
# for the bundle id, relaunches the app and opens the Screen Recording pane
# so you can allow it once — after that it survives rebuilds.
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

bundle_id="com.darnadigital.screenchest"
app="$project_dir/build/ScreenChest.app"
identity="ScreenChest Dev"

echo "→ signing identity"
"$project_dir/scripts/create-signing-identity.sh" "$identity"

echo "→ rebuilding and signing ScreenChest.app"
make app

signature="$(codesign -dv "$app" 2>&1 | sed -n 's/^Signature=//p')"
if [[ "$signature" == "adhoc" ]]; then
  echo "✗ still ad-hoc signed — codesign could not use \"$identity\"."
  echo "  Open Keychain Access → login → My Certificates → \"$identity\" → Trust → Code Signing: Always Trust, then rerun."
  exit 1
fi

echo "→ clearing stale grants for $bundle_id"
for service in ScreenCapture Camera Microphone; do
  tccutil reset "$service" "$bundle_id" >/dev/null 2>&1 || true
done

echo "→ relaunching"
pkill -f "$app" 2>/dev/null || true
sleep 0.5
open "$app"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

cat <<MSG
✓ ScreenChest.app is signed with "$identity" and its old grants are cleared.
  In System Settings → Privacy & Security → Screen & System Audio Recording,
  turn ScreenChest on (add it with + from $app if it isn't listed), then
  pick "Quit & Reopen". Camera and microphone will prompt inside the app.
MSG
