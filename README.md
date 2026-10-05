# Superhound

A native macOS search prototype for applications and filenames, with its own local catalog and a keyboard-driven AppKit panel.

**Status: locally usable prototype, not a public release.** Objective-C/AppKit, a C Unicode matcher, SQLite, and FSEvents; Apple Silicon on macOS 15+. See [measured results and remaining acceptance checks](docs/prototype-validation.md).

## Build and run

Apple Command Line Tools are the only build dependency. No package manager, network service, Spotlight index, or Developer ID certificate is required.

```sh
scripts/build.sh
scripts/test.sh
# Quit a running Superhound before replacing its bundle.
scripts/install.sh .build/Superhound.app
open ~/Applications/Superhound.app
```

The installer retains the previous bundle in a `.superhound-backup.*` directory under `~/Applications`. It refuses unrelated bundle identities, symlink destinations, and replacement while Superhound is running. For rollback, quit Superhound and pass the retained `previous.app` to `scripts/install.sh`.

## Use

- Type a calculation (`48*12`, `15% of 240`, `240 + 15%`) or a conversion (`5 km to mi`, `72f to c`) to see the answer in the first row; Return copies the number. Units cover length, weight, temperature, volume, data size, and time, all offline.
- Open **Search** from the magnifying-glass menu-bar icon. Type an app or filename, use arrows to select, Return to open, Command-Return to reveal in Finder, and Escape to dismiss.
- Add folders in **Search Locations…**. App directories are included automatically. No personal folders are selected automatically.
- Command-Space is the requested default. On the validation Mac, setup required both steps in **System Settings → Keyboard → Keyboard Shortcuts**: add an **App Shortcut** for **Superhound**, menu title **Search**, shortcut **⌘Space**; then disable Spotlight’s **Show Spotlight search**. Use **Retry** in Superhound and test from another app. Enabling the new shortcut does not replace or disable the existing Spotlight binding. To restore Spotlight later, quit Superhound and re-enable that shortcut.
- Selected folders reconcile automatically after changes; **Refresh Catalog** performs an immediate rescan. Coverage and access failures appear per location.

Only names and application metadata are indexed. Hidden descendants, package contents, non-local placeholders, and Superhound’s mutable data are skipped. Symbolic links are listed without traversal. Generated-directory exclusions can be switched off. Removing a location never deletes source files.

Settings/bookmarks, a rebuildable catalog, and the learned-ranking history (`usage.plist`: opened paths with the queries typed for them) live under `~/Library/Application Support/Superhound/`, separate from the disposable installation probe. Superhound registers itself to open at login on first launch; the menu item **Open at Login** turns this off. There is no updater, licensing, or cloud search in this slice.

## Verify and measure

```sh
scripts/test.sh        # critical core checks with AddressSanitizer/UndefinedBehaviorSanitizer
scripts/build.sh      # release build, -Wall -Wextra -Werror, ad-hoc signing verification
# Quit the resident prototype before installer tests.
tests/install.sh      # isolated temporary-directory installation and upgrade checks
scripts/benchmark.sh  # synthetic 10k/100k exhaustive queries; scan/SQLite measurements
.build/bench/search 100000 --check-memory    # reference snapshot memory budget
.build/bench/search 100000 --unique-parents  # less favorable directory layout
```

The benchmark uses 360 queries across exact/prefix, abbreviation, accent folding, Japanese, multi-term paths, substring, miss, and empty-input cases. It reports query percentiles separately from preparation/replacement time. It does not read user documents. Optional local UI timing instructions are in the validation report.

## Implementation

- `app/`: native search/settings windows, accessible controls, global shortcut, focus and open/reveal actions.
- `core/`: staged scanning, bookmark-aware root ownership, FSEvents debounce, atomic SQLite catalog, immutable snapshots, ranking and cancellation.
- `tests/`, `bench/`, `scripts/`: critical integration checks, reproducible measurements, local build/install.
- [Approved design](docs/superpowers/specs/2026-10-04-first-search-prototype-design.md) and [implementation plan](docs/superpowers/plans/2026-10-04-first-search-prototype.md).

The previous research and [installation probe](spikes/install-permissions/README.md) remain intact in the original repository. Product strategy, broader scope, distribution, and monetization research are in `docs/`; they are future work beyond this prototype.
