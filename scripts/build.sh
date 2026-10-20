#!/bin/bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { echo 'Requires Apple Silicon macOS 15+.' >&2; exit 1; }
version="${1:-1}"
[[ $# -le 1 && "$version" =~ ^[1-9][0-9]{0,5}$ ]] || { echo 'Usage: build.sh [positive build number, 1–6 digits]' >&2; exit 2; }
mkdir -p .build
stage="$(mktemp -d .build/stage.XXXXXX)"
trap 'rm -rf -- "$stage"' EXIT
bundle="$stage/Superhound.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp app/emoji.tsv "$bundle/Contents/Resources/emoji.tsv"
cp app/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.superhound.app</string>
<key>CFBundleName</key><string>Superhound</string>
<key>CFBundleExecutable</key><string>Superhound</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>$version</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Superhound sends Empty Trash to Finder, Dark Mode to System Events, and Sleep, Restart, Shut Down, and Log Out to the login window.</string>
<key>NSHumanReadableCopyright</key><string>Superhound local prototype</string>
</dict></plist>
PLIST
/usr/bin/time -lp xcrun clang -arch arm64 -fobjc-arc -fmodules -O2 -Wall -Wextra -Werror \
 -mmacosx-version-min=15.0 -fmodules-cache-path=.build/module-cache -Iapp -Icore \
 app/*.m core/*.m core/*.c -framework AppKit -framework Carbon -framework CoreAudio -framework CoreServices -framework CoreText -framework Quartz -framework ServiceManagement -lsqlite3 \
 -o "$bundle/Contents/MacOS/Superhound" 2> "$stage/build-metrics.txt" || { cat "$stage/build-metrics.txt" >&2; exit 1; }
plutil -lint "$bundle/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$bundle"
codesign --verify --strict "$bundle"
# Only replace this script's build output after successful compile/signing.
if [[ -e .build/Superhound.app ]]; then mv .build/Superhound.app "$stage/previous.app"; fi
mv "$bundle" .build/Superhound.app
cp "$stage/build-metrics.txt" .build/build-metrics.txt
cat .build/build-metrics.txt
echo "Built: $(pwd)/.build/Superhound.app"
