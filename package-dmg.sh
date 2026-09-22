#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP_PATH="${1:-build/DuoFold.app}"
OUTPUT_PATH="${2:-build/release/DuoFold-0.1.0-local.dmg}"
BACKGROUND="Resources/Brand/DuoFold-dmg-background.png"
[[ -d "$APP_PATH" ]] || { echo "Missing app: $APP_PATH" >&2; exit 1; }
[[ -f "$BACKGROUND" ]] || { echo "Missing background: $BACKGROUND" >&2; exit 1; }

mkdir -p "$(dirname "$OUTPUT_PATH")"
WORK="$(mktemp -d /tmp/duofold-dmg.XXXXXX)"
RW="$WORK/DuoFold-rw.dmg"
MOUNT="/Volumes/DuoFold"
trap 'hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

hdiutil create -size 64m -fs HFS+ -volname DuoFold -layout SPUD -ov "$RW" >/dev/null
hdiutil attach "$RW" -nobrowse >/dev/null

ditto "$APP_PATH" "$MOUNT/DuoFold.app"
ln -s /Applications "$MOUNT/Applications"
mkdir -p "$MOUNT/.background"
cp "$BACKGROUND" "$MOUNT/.background/background.png"

for hidden in "$MOUNT/.background" "$MOUNT/.fseventsd" "$MOUNT/.Trashes"; do
  [[ -e "$hidden" ]] && SetFile -a V "$hidden" || true
done

osascript <<'APPLESCRIPT'
tell application "Finder"
  tell disk "DuoFold"
    open
    set theWindow to container window
    set current view of theWindow to icon view
    set toolbar visible of theWindow to false
    set statusbar visible of theWindow to false
    set bounds of theWindow to {120, 120, 1120, 770}
    set viewOptions to icon view options of theWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.png"
    set position of item "DuoFold.app" to {330, 315}
    set position of item "Applications" to {680, 315}
    close
    open
    update without registering applications
  end tell
end tell
APPLESCRIPT

sleep 2
rm -f "$OUTPUT_PATH"
hdiutil detach "$MOUNT" >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_PATH" >/dev/null
codesign --force --sign - "$OUTPUT_PATH" >/dev/null
codesign --verify --strict "$OUTPUT_PATH"
echo "created $OUTPUT_PATH"
