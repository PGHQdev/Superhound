# Superhound

A native macOS launcher: one panel on a global shortcut that finds apps, files, emoji, and quick answers. Objective-C and AppKit, a C matcher, SQLite, FSEvents. Apple Silicon, macOS 15 or later. The only build dependency is the Apple Command Line Tools.

## Where the work is

- All code is on `main`, merged from `feat/first-search-prototype` on 2026-10-05.
- The installed app is `~/Applications/Superhound.app`, bundle ID `com.superhound.app`.

## Commands

| Command | Function |
|---|---|
| `scripts/build.sh [build number]` | Compiles and signs `.build/Superhound.app`. Also writes the bundle's `Info.plist`. |
| `scripts/test.sh` | Builds and runs the six Objective-C test suites with sanitizers. Run it before each commit. |
| `scripts/install.sh .build/Superhound.app` | Replaces the installed app. It refuses while Superhound is in operation, and it keeps the previous bundle. |
| `scripts/benchmark.sh` | Measures query time, memory, and catalog speed at 10,000 and 100,000 records. |
| `scripts/update-emoji.py` | Rebuilds `app/emoji.tsv` from Unicode data. The only script that uses the internet. |

To see a change in the live app: build with a build number one above the installed one, quit Superhound, install, then `open -g ~/Applications/Superhound.app`.

## Code

### `core/`: logic with no window code

| File | Function |
|---|---|
| `sh_match.c` | Matches one query word against one name. Ranks: 0 exact, 1 prefix, 2 word initials, 3 substring, 5 and 6 typing errors, 9 absent. |
| `SHSearchSnapshot.m` | The in-memory search list. Holds the ranking order (`rank:precedes:`), the empty-query app list, and `SHFold` (case, accent, and width folding). |
| `SHQueryController.m` | Runs searches off the main thread and drops results of an old query. |
| `SHUsage.m` | Learned ranking. Records which result the user opened for which query, in `usage.plist`. |
| `SHAnswer.m` | Quick answers: the arithmetic parser, percent rules, and the unit table. |
| `SHEmoji.m` | Emoji search by name and keyword over `app/emoji.tsv`. |
| `SHLibrary.m` | Owns the search locations: the fixed app folders, the user's folders, scans, overlap between folders, and snapshot publication. |
| `SHScanner.m` | Walks one folder and makes entries. Holds the skip rules (hidden items, packages, generated folders, online-only files). |
| `SHCatalog.m` | The SQLite cache of scanned entries. |
| `SHChangeMonitor.m` | FSEvents watcher. Reports the changed directories so the library lists only those; a dropped or root event requests a full rescan. |
| `SHMetrics.m` | Writes timing records to `performance.jsonl`. |

### `app/`: windows and macOS integration

| File | Function |
|---|---|
| `SHAppDelegate.m` | Start-up wiring, the menu bar item and its menu, Open at Login. |
| `SHSearchPanelController.m` | The search panel: field, result rows, row order (answer, chosen before, apps, emoji, files), keys, copy and open. |
| `SHSettingsController.m` | The Search Locations window and the shortcut recorder. |
| `SHHotKey.m` | Global shortcut registration. |
| `SHFolderAccess.m` | Security-scoped bookmarks for the user's folders. |
| `SHResultActions.m` | Opens a result or shows it in Finder. |
| `emoji.tsv` | Generated emoji data: emoji, name, keywords. Do not edit by hand. |

### `tests/` and `bench/`

| File | Covers |
|---|---|
| `tests/search.m` | Ranking, typing errors, learned ranking, the query controller |
| `tests/answer.m` | Calculator and unit conversion |
| `tests/emoji.m` | Emoji search |
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
| `performance.jsonl` | Timing records |

## Docs

| File | Content |
|---|---|
| `README.md` | Build, install, and use |
| `docs/prototype-validation.md` | Measured results and open acceptance checks for the prototype |
| `docs/superpowers/specs/2026-10-04-first-search-prototype-design.md` | The design of the first prototype |
| `docs/superpowers/plans/2026-10-04-first-search-prototype.md` | The implementation plan of the first prototype |
| `docs/early-planning-notes.md`, `docs/product.md`, `docs/architecture.md`, `docs/distribution.md`, `docs/validation.md`, `docs/decisions-and-research.md` | Early research and proposals from before the code existed. Not committed to git. Check them against the code before use. |
| `spikes/install-permissions/` (not committed to git) | The disposable install and folder-permission probe, with its findings |

## Conventions

- Match the dense one-line style of the current Objective-C files.
- The app makes no network request. Keep it offline.
- Add tests for changes to `core/`. The panel window has no automated test; state when a change was not seen on screen.
- One commit for each change, with a `feat:`, `fix:`, `perf:`, or `docs:` prefix.
