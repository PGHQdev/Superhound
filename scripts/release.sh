#!/bin/bash
# Builds a release from the current commit: the tests, a build signed with the "Superhound" certificate, Superhound.zip, and its SHA-256.
# Publishing stays manual; the script prints the commands and the superhound-web vars.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 2 && "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$2" =~ ^[1-9][0-9]{0,5}$ ]] || { echo 'Usage: release.sh <version, such as 0.2.0> <build number, above the last release>' >&2; exit 2; }
version="$1" build="$2"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo 'Commit the changes first. A release is built from a commit.' >&2; exit 1; }
# Without the certificate, the update check in the installed apps refuses the release, and macOS asks again for permissions.
security find-identity -p codesigning | grep -q '"Superhound"' || { echo 'The "Superhound" certificate is not in the keychain.' >&2; exit 1; }
scripts/test.sh
scripts/build.sh "$build" "$version"
codesign -d -r- .build/Superhound.app 2>&1 | grep -q 'certificate root' || { echo 'The build does not have the certificate signature.' >&2; exit 1; }
out=".build/release/$version"
rm -rf "$out"
mkdir -p "$out"
ditto -c -k --norsrc --noextattr --noacl --keepParent .build/Superhound.app "$out/Superhound.zip"
sha="$(shasum -a 256 "$out/Superhound.zip" | cut -d' ' -f1)"
cat <<EOF

Built $out/Superhound.zip
SHA-256 $sha

Publish:
  git tag v$version && git push origin main v$version
  gh release create v$version $out/Superhound.zip --title "Superhound $version" --notes-file <release notes file>

Then set these vars in superhound-web/wrangler.jsonc and deploy:
  "RELEASE_VERSION": "$version",
  "RELEASE_BUILD": "$build",
  "RELEASE_URL": "https://github.com/PGHQdev/Superhound/releases/download/v$version/Superhound.zip",
  "RELEASE_SHA256": "$sha",
  "RELEASE_NOTES_URL": "https://github.com/PGHQdev/Superhound/releases/tag/v$version"
EOF
