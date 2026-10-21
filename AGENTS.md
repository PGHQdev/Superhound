# Superhound

A native macOS launcher: one panel on a global shortcut that finds apps, files, emoji, and quick answers. Objective-C and AppKit, a C matcher, SQLite, FSEvents. Apple Silicon, macOS 15 or later. The only build dependency is the Apple Command Line Tools.

## Where the work is

- All code is on `main`, merged from `feat/first-search-prototype` on 2026-10-05.
- The installed app is `~/Applications/Superhound.app`, bundle ID `com.superhound.app`.

## Commands

| Command | Function |
|---|---|
| `scripts/build.sh [build number] [version]` | Compiles and signs `.build/Superhound.app` with the "Superhound" certificate from the keychain, or ad-hoc without it. Also writes the bundle's `Info.plist` and copies each `app/<locale>.lproj` folder. |
| `scripts/test.sh` | Builds and runs the eleven Objective-C test suites with sanitizers. Run it before each commit. |
| `scripts/install.sh .build/Superhound.app` | Replaces the installed app. It refuses while Superhound is in operation, and it keeps the previous bundle. |
| `scripts/release.sh <version> <build number>` | From a clean commit: runs the tests, builds with the certificate, makes `.build/release/<version>/Superhound.zip`, and prints its SHA-256, the publish commands, and the superhound-web release vars. It does not publish. |
| `scripts/benchmark.sh` | Measures query time, memory, and catalog speed at 10,000 and 100,000 records. |
| `python3 -I scripts/strings.py [--check]` | Writes `app/en.lproj` from the `NSLocalizedString` calls in `app/` and `core/` and from the permission text in `scripts/build.sh`. `--check` fails when `app/en.lproj` is out of date, or when a locale has a missing or extra key, other format specifiers, or a file that does not parse. `scripts/test.sh` runs the check first. |
| `scripts/update-emoji.py` | Rebuilds `app/emoji.tsv` from Unicode data. The only script that uses the internet. |

To see a change in the live app: build with a build number one above the installed one, quit Superhound, install, then `open -g ~/Applications/Superhound.app`.

## Code

### `core/`: logic with no window code

| File | Function |
|---|---|
| `sh_match.c` | Matches one query word against one name. Ranks: 0 exact, 1 prefix, 2 word initials or the start of a later word, 3 substring, 5 and 6 typing errors, 9 absent. |
| `SHSearchSnapshot.m` | The in-memory search list. Holds the ranking order (`rank:precedes:`; typing-error matches stay below exact matches, also when learned; a result opened for the exact query leads, then an app, settings pane, or command whose name or alias is the whole query, then other learned results), the empty-query app list, `SHCompletion` (the rest of a name after its typed start), and `SHFold` (case, accent, and width folding). |
| `SHQueryController.m` | Runs searches off the main thread and drops results of an old query. |
| `SHUsage.m` | Learned ranking. Records which result the user opened for which query, in `usage.plist`. |
| `SHAnswer.m` | Quick answers: the arithmetic parser, percent rules, the unit table, and colour values (hex, rgb, and hsl, each shown as another form; the panel draws a swatch and ⌘K copies each form). |
| `SHWeb.m` | The web search URL of each engine (Google by default, DuckDuckGo, Bing, Brave Search, Kagi), and web addresses typed in the search field: http and https URLs, localhost with a port, IPv4 addresses with or without one, and hosts with a common web ending (a list that leaves out file extensions such as .md and .sh). |
| `SHEmoji.m` | Emoji search by name and keyword over `app/emoji.tsv`. |
| `SHClipboard.m` | The clipboard history: the last 500 text copies, the skip rules for concealed and password copies, search, and `clipboard.plist`. |
| `SHLicense.m` | The license of this Mac: the device ID, the check of the token that superhound.app signed, and `license.plist`. |
| `SHUpdate.m` | Updates: the release file from `/api/latest`, the once-a-day rule, and the install of a downloaded zip (SHA-256, build number, signature check against a requirement, swap with a kept previous app). |
| `SHSpotlight.m` | The rules for Spotlight's ⌘Space entry (64) in AppleSymbolicHotKeys: on or off, a change of only its enabled flag, and when an uninstall gives ⌘Space back. |
| `SHCommands.m` | The system commands (Lock Screen, Sleep, Restart, Toggle Mute, Empty Trash, and others) as search entries. The name shows in the user's language; the alias keeps the English name. `SHLibrary` adds them to each snapshot. |
| `SHLibrary.m` | Owns the search locations: the fixed app folders, the user's folders, scans, overlap between folders, and snapshot publication. |
| `SHScanner.m` | Walks one folder and makes entries. Holds the skip rules (hidden items, packages, generated folders, online-only files) and the other names of built-in apps (older macOS names and Windows names, by bundle identifier), which go in the alias. |
| `SHCatalog.m` | The SQLite cache of scanned entries. |
| `SHChangeMonitor.m` | FSEvents watcher. Reports the changed directories so the library lists only those; a dropped or root event requests a full rescan. |
| `SHMetrics.m` | Writes timing records to `performance.jsonl`. |

### `app/`: windows and macOS integration

| File | Function |
|---|---|
| `SHAppDelegate.m` | Start-up wiring, the menu bar item and its menu, Open at Login, the pasteboard check twice a second for the clipboard history, the license, update, and About menu items, Uninstall Superhound… (frees the activation, gives ⌘Space back to Spotlight when Superhound took it, removes the login item, the data, the defaults, the app, and its kept previous versions), and `superhound://` links. |
| `SHSearchPanelController.m` | The search panel and its clipboard history mode: the dark blurred borderless window, 600 pt wide, with a height that follows the rows (it grows at once and shrinks after 0.15 s); the shared columns (16 pt margin, 28 pt icon column, text at x 52); field (Return during a search opens the result when it arrives; Escape closes Quick Look before the panel; inline completion of the top result, off by default with defaults key `inlineCompletion`, where Tab or → keeps it, a deletion, a cut, another caret move, or a click in the field removes it, and `query` is the typed text without it), the label band ("Suggested", errors, no matches, indexing note), one-line app rows and two-line file rows with folder context, row order (web address unless a result has the typed text as its name or file name, answer, chosen before, apps, settings panes, and commands, emoji, clipboard items, files, and the web search in the last row), keys, the action menu (⌘K and right-click), Quick Look, copy and open, the footer (key hints, the Update to and Activate license links, the logo and name, which open the menu bar menu), and the license reminder on every tenth opening (`unlicensedOpens` in the defaults). |
| `SHSettingsController.m` | The Settings window (⌘,): the search locations with the item counts, the two shortcut recorders, the switch Use ⌘Space in place of Spotlight, the web search engine (defaults key `searchEngine`; the engines are in `SHWeb.m`), the switch Complete the top result as you type, and the Language menu (System Default or one of the seven languages, written as `AppleLanguages` in the app's defaults, the value the macOS per-app language setting uses; a change offers to relaunch with the macOS alert text). |
| `SHHotKey.m` | Global shortcut registration, one object for each shortcut. It refuses the other shortcut's keys, and it keeps the previous keys when new keys fail to register. It also reads and writes Spotlight's ⌘Space shortcut in `com.apple.symbolichotkeys`, with a private call that applies the change at once. |
| `SHFolderAccess.m` | Security-scoped bookmarks for the user's folders. |
| `SHActivation.m` | Activation and deactivation requests to superhound.app, the license key window, and `superhound://activate?key=` links. The defaults key `licenseServer` points it at a local test server. |
| `SHUpdater.m` | The daily update check, Check for Updates…, the download, and the relaunch (`SHRelaunch`, also used after a language change). An update must meet the running app's designated requirement, so only a build signed with the "Superhound" certificate can update. Defaults keys: `updateCheckAutomatically`, `updateCheckedAt`; `licenseServer` also points it at a local test server. |
| `SHResultActions.m` | Opens a result, opens a web address in the default browser, opens a result with another app, shows it in Finder, moves it to the Trash, runs the system commands, and pastes with a ⌘V key press. |
| `emoji.tsv` | Generated emoji data: emoji, name, keywords. Do not edit by hand. |
| `en.lproj/`, `<locale>.lproj/` | `Localizable.strings` (the English text is the key) and `InfoPlist.strings` (the permission text). `scripts/strings.py` writes `en.lproj`; do not edit it by hand. The other locales are translations: ja, de, fr, es, zh-Hans, pt-BR. |
| `AppIcon.icns` | The app icon, made from `docs/media/superhound.png` |
| `LogoTemplate.png` | The 36 px template logo for the panel footer, made from `docs/media/logo.png` |

### `tests/` and `bench/`

| File | Covers |
|---|---|
| `tests/search.m` | Ranking, typing errors, learned ranking, completion, the query controller |
| `tests/answer.m` | Calculator, unit conversion, and colours |
| `tests/web.m` | Web addresses, the text that must not give one, and web search URLs |
| `tests/emoji.m` | Emoji search |
| `tests/clipboard.m` | Clipboard history rules, search, limits, and its file |
| `tests/license.m` | Device ID, token checks with a WebCrypto test token, and the license file |
| `tests/spotlight.m` | The Spotlight shortcut entry rules |
| `tests/update.m` | The release file, the daily rule, and installs of signed test bundles, with each failure case |
| `tests/catalog.m` | Scanner rules and the SQLite cache |
| `tests/library.m` | Search locations with live file changes |
| `tests/snapshot-equivalence.m` | 40 result sets compared with `snapshot-equivalence.expected`. A ranking change needs a reviewed update of that file. |
| `tests/install.sh` | The install script. `scripts/test.sh` does not run it; run it by itself. |
| `bench/` | Programs used by `scripts/benchmark.sh` |

## User data

All in `~/Library/Application Support/Superhound/`:

| File | Content |
|---|---|
| `folders.plist` | The user's search locations and their bookmarks |
| `catalog.sqlite` | The scan cache; safe to delete, the app rebuilds it |
| `usage.plist` | Learned ranking history: opened paths and their queries |
| `clipboard.plist` | Clipboard history: copied text, its time, and the source app. Private; do not print it. |
| `license.plist` | The license key and the activation token for this Mac. Private; do not print it. |
| `performance.jsonl` | Timing records |

## Docs

All of `docs/` other than `docs/media/` is local: `.gitignore` excludes it, and the files are not on GitHub.

| File | Content |
|---|---|
| `README.md` | Build, install, and use |
| `docs/media/` | The only folder of `docs/` in git. The logo: `superhound.png` (the original), `logo.png` and `logo-dark.png` (for the README in light and dark mode) |
| `docs/prototype-validation.md` | Measured results and open acceptance checks for the prototype |
| `docs/superpowers/specs/2026-10-04-first-search-prototype-design.md` | The design of the first prototype |
| `docs/superpowers/plans/2026-10-04-first-search-prototype.md` | The implementation plan of the first prototype |
| `docs/early-planning-notes.md`, `docs/product.md`, `docs/architecture.md`, `docs/distribution.md`, `docs/validation.md`, `docs/decisions-and-research.md` | Early research and proposals from before the code existed. Check them against the code before use. |
| `spikes/install-permissions/` (not committed to git) | The disposable install and folder-permission probe, with its findings |

## Conventions

- Keep `docs/` out of git, other than `docs/media/`. `.gitignore` excludes the rest.
- Match the dense one-line style of the current Objective-C files.
- Wrap user-visible text in `NSLocalizedString` with the English text as key, and give a comment when a short word, a format argument, or the length is not clear. Run `python3 -I scripts/strings.py` after a text change. Text that the code compares stays a fixed English value; show its translation separately, as `SHLibrary` does with a root's `state` and `label`.
- The app makes two kinds of network request: license activation and deactivation in `SHActivation.m`, and the daily update check and download in `SHUpdater.m`. Neither sends personal data other than the license key and device ID at activation. Keep everything else offline.
- The private signing key for activation tokens is `~/.config/superhound/license-signing-key.jwk`. Never print it or copy it into a repository.
- The code signing certificate is "Superhound" in the login keychain (self-signed, until 2046), with copies in `~/.config/superhound/codesign-key.pem` and `codesign-cert.pem`. Never print the key or copy it into a repository. A different certificate makes macOS ask every user again for the Documents and Accessibility permissions.
- Add tests for changes to `core/`. The panel window has no automated test; state when a change was not seen on screen.
- Do not take full-screen captures to check the app. The screen shows the user's private windows. Ask the user to look instead.
- One commit for each change, with a `feat:`, `fix:`, `perf:`, or `docs:` prefix.
- In a `/harness` run, commit a step only after the `verifier` passes it.
