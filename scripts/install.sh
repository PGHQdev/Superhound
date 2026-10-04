#!/bin/bash
# Local-only installation. Prior bundles are retained for rollback.
set -euo pipefail
umask 077
[[ $# == 1 ]] || { echo 'Usage: install.sh /path/to/Superhound.app' >&2; exit 2; }
source_app="$(cd -- "$1" && pwd -P)"
apps_dir="${SUPERHOUND_APPLICATIONS_DIR:-$HOME/Applications}"
destination="$apps_dir/Superhound.app"
read_id() { /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist"; }
[[ "$(read_id "$source_app")" == com.superhound.app ]] || { echo 'Unexpected source bundle identity.' >&2; exit 1; }
codesign --verify --strict "$source_app"
[[ -x "$source_app/Contents/MacOS/Superhound" ]] || { echo 'Missing Superhound executable.' >&2; exit 1; }
processes="$(/bin/ps -axo comm=)" || { echo 'Cannot inspect running applications; installation stopped.' >&2; exit 1; }
if printf '%s\n' "$processes" | /usr/bin/grep -E '(^|/)Superhound$' >/dev/null; then echo 'Quit Superhound before installing an update.' >&2; exit 1; fi
mkdir -p "$apps_dir"
[[ ! -L "$destination" ]] || { echo 'Refusing a symlink destination.' >&2; exit 1; }
if [[ -e "$destination" ]]; then [[ "$(read_id "$destination")" == com.superhound.app ]] || { echo 'Refusing to replace an unrelated application.' >&2; exit 1; }; fi
stage="$(mktemp -d "$apps_dir/.superhound-stage.XXXXXX")"
backup=''
installed=0
cleanup() {
 code=$?
 if [[ $code != 0 && -n "$backup" && -d "$backup/previous.app" ]]; then
  if [[ $installed == 1 && -d "$destination" ]]; then mv "$destination" "$stage/failed.app"; fi
  if [[ ! -e "$destination" ]]; then mv "$backup/previous.app" "$destination" || echo "Restore manually: $backup/previous.app" >&2; fi
 fi
 rm -rf -- "$stage"
 exit "$code"
}
trap cleanup EXIT
ditto "$source_app" "$stage/new.app"
codesign --verify --strict "$stage/new.app"
if [[ -e "$destination" ]]; then backup="$(mktemp -d "$apps_dir/.superhound-backup.XXXXXX")"; mv "$destination" "$backup/previous.app"; fi
mv "$stage/new.app" "$destination"
installed=1
codesign --verify --strict "$destination"
echo "Installed: $destination"
if [[ -n "$backup" ]]; then echo "Previous bundle: $backup/previous.app"; fi
