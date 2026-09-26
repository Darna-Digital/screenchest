#!/usr/bin/env bash
# Writes the Sparkle feed for one release to stdout: an appcast.xml naming the
# disk image scripts/release.sh made, signed with the EdDSA key whose public
# half is Info.plist's SUPublicEDKey. Without SPARKLE_PRIVATE_KEY the key is
# read from the "screenchest" account in the login keychain.
#
#   SPARKLE_PRIVATE_KEY=… scripts/appcast.sh <dmg> <release-notes.md> <download-url>
set -euo pipefail

dmg="${1:?usage: appcast.sh <dmg> <release-notes.md> <download-url>}"
notes="${2:?usage: appcast.sh <dmg> <release-notes.md> <download-url>}"
url="${3:?usage: appcast.sh <dmg> <release-notes.md> <download-url>}"

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
sign_update="${project_dir}/.build/artifacts/sparkle/Sparkle/bin/sign_update"
version="$(tr -d '[:space:]' < "${project_dir}/VERSION")"
minimum_system="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "${project_dir}/Resources/Info.plist")"

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  signature="$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$sign_update" --ed-key-file - -p "$dmg")"
else
  signature="$("$sign_update" --account screenchest -p "$dmg")"
fi
length="$(stat -f %z "$dmg")"
description="$(sed 's/]]>/]]]]><![CDATA[>/g' "$notes")"

cat <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>ScreenChest</title>
    <item>
      <title>ScreenChest ${version}</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>${version}</sparkle:version>
      <sparkle:shortVersionString>${version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${minimum_system}</sparkle:minimumSystemVersion>
      <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
      <description sparkle:format="markdown"><![CDATA[
${description}
]]></description>
      <enclosure url="${url}" type="application/octet-stream" length="${length}" sparkle:edSignature="${signature}"/>
    </item>
  </channel>
</rss>
XML
