#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
export SUPERHOUND_APPLICATIONS_DIR="$fixture/Applications"
scripts/install.sh .build/Superhound.app
[[ -x "$SUPERHOUND_APPLICATIONS_DIR/Superhound.app/Contents/MacOS/Superhound" ]]
scripts/install.sh .build/Superhound.app
find "$SUPERHOUND_APPLICATIONS_DIR" -path '*/previous.app/Contents/Info.plist' | read -r backup
mv "$SUPERHOUND_APPLICATIONS_DIR/Superhound.app" "$fixture/valid.app"
mkdir -p "$SUPERHOUND_APPLICATIONS_DIR/Superhound.app/Contents"
cp "$fixture/valid.app/Contents/Info.plist" "$SUPERHOUND_APPLICATIONS_DIR/Superhound.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.example.unrelated' "$SUPERHOUND_APPLICATIONS_DIR/Superhound.app/Contents/Info.plist"
if scripts/install.sh .build/Superhound.app; then echo 'FAIL: replaced unrelated bundle'; exit 1; fi
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SUPERHOUND_APPLICATIONS_DIR/Superhound.app/Contents/Info.plist")" == com.example.unrelated ]]
rm -rf "$SUPERHOUND_APPLICATIONS_DIR/Superhound.app"
ln -s "$fixture/valid.app" "$SUPERHOUND_APPLICATIONS_DIR/Superhound.app"
if scripts/install.sh .build/Superhound.app; then echo 'FAIL: followed destination symlink'; exit 1; fi
[[ -L "$SUPERHOUND_APPLICATIONS_DIR/Superhound.app" ]]
echo 'PASS installer: install, upgrade backup, unrelated identity and symlink rejection'
