<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/media/logo-dark.png">
  <img src="docs/media/logo.png" width="128" alt="Superhound logo: a pharaoh hound head">
</picture>

# Superhound

A small, fast launcher for macOS.

Open apps and files, do quick math, and paste from your clipboard history, all from one search panel.

macOS 15 or later · Apple Silicon · Works offline

</div>

<br>

## What it does

| | Type | Return |
|---|---|---|
| **Apps and files** | `term`, `safari`, `notes.txt` | Opens it |
| **System Settings** | `storage` | Opens the pane |
| **Calculator** | `48*12`, `15% of 240`, `240 + 15%` | Copies the answer |
| **Units** | `5 km to mi`, `72f to c` | Copies the answer |
| **Emoji** | `fire`, `happy`, `japan` | Copies the emoji |
| **Commands** | `sleep`, `restart`, `mute`, `dark`, `empty trash`, `eject` | Runs it |
| **Clipboard history** | Press ⌥⌘V | Pastes it |

Search ignores case and accents, accepts small typing errors, and learns which results you open.

## Install

Paste this in Terminal:

```sh
curl -fsSL https://superhound.app/install | sh
```

The command downloads Superhound, checks the download against the published SHA-256, puts Superhound in `~/Applications`, and opens it.

A magnifying glass appears in the menu bar. Choose **Search** to open the panel. The same menu opens when you click the logo at the bottom of the panel. Superhound opens at login; turn this off with **Open at Login** in the same menu.

Superhound works fully without a license and shows an unlicensed reminder. A license is a one-time payment of $19 for 3 Macs at [superhound.app](https://superhound.app). To activate one, choose **Enter License…** in the same menu. To move a license to another Mac, choose **Deactivate License…** on the old Mac first.

### Updates

Superhound checks for a new version once a day. When there is one, the panel shows **Update to** and the menu shows **Update to…**. Superhound downloads the update, checks that it has the Superhound signature, and opens again. It keeps the previous version in `~/Applications/.superhound-backup.*`. To go back, quit Superhound and put that `previous.app` in place of `~/Applications/Superhound.app`.

To turn off the daily check, turn off **Check for Updates Automatically** in the menu. **Check for Updates…** checks at once.

### Build from source

You need the Apple Command Line Tools (`xcode-select --install`). Nothing else.

```sh
git clone https://github.com/PGHQdev/superhound.git
cd superhound
scripts/build.sh
scripts/install.sh .build/Superhound.app
open ~/Applications/Superhound.app
```

A build from source cannot update itself. To update it, pull the latest code, quit Superhound, and run the same build and install commands.

### Uninstall

1. If this Mac has a license, choose **Deactivate License…** to free the activation.
2. Quit Superhound.
3. Delete `~/Applications/Superhound.app` and `~/Library/Application Support/Superhound/`.

<details>
<summary><b>Open Superhound with ⌘Space</b></summary>

<br>

Spotlight uses ⌘Space, so macOS needs two changes in **System Settings → Keyboard → Keyboard Shortcuts**:

1. In **App Shortcuts**, add a shortcut for **Superhound** with the menu title `Search` and the keys ⌘Space.
2. In **Spotlight**, turn off **Show Spotlight search**.

Then open **Search Locations…** from the menu bar and click **Retry**. To get Spotlight back, quit Superhound and turn **Show Spotlight search** on again.

</details>

## Keys

| Key | Action |
|---|---|
| ⌘Space | Open Superhound (after the setup above) |
| ⌥⌘V | Open clipboard history |
| ↑ ↓ | Select a result |
| Return | Open, run, copy, or paste the result |
| ⌘Return | Show a file in Finder. In clipboard history: copy only |
| ⌘K | All actions: Open With, Quick Look, Copy Path, Move to Trash, and more |
| ⌘Y | Quick Look |
| ⇧⌘C | Copy path |
| Esc | Close |

Right-click a result to see the same actions as ⌘K. You can change both shortcuts in **Search Locations…**.

## Search locations

Superhound always searches your app folders. To search your own folders, add them in **Search Locations…**. No personal folder is added for you.

- Changes to files appear in a few seconds. **Refresh Catalog** scans everything now.
- Superhound reads names, never file contents.
- It skips hidden items, the inside of packages, online-only files, and generated folders such as `node_modules`. You can turn off the generated-folder rule.
- Removing a location never deletes files.

## Clipboard history

Superhound keeps the last 500 pieces of text you copy, newest first. Press ⌥⌘V, or choose **Clipboard History** in the menu bar, then type to filter. A normal search of 3 or more characters also shows up to 2 matching copies.

It does not keep:

- copies that password managers mark as private
- copies from Keychain Access and Passwords
- text longer than 100,000 characters

**Clear Clipboard History** in the menu bar deletes it all.

## Permissions

| Permission | When macOS asks | Without it |
|---|---|---|
| Accessibility | When you paste from clipboard history | Return copies the text, and you paste it yourself |
| Automation for Finder, System Events, or the login window | The first use of a command such as Empty Trash or Restart | That command does not run |

A build from source has a local signature, so macOS can ask for Accessibility again after you install a new build. If paste stops working, remove Superhound in **System Settings → Privacy & Security → Accessibility** and add it again.

Restart, Shut Down, and Log Out show the macOS confirmation first. Empty Trash asks first. Lock Screen uses a private macOS call that a later macOS can break.

## Privacy

Superhound works offline. Once a day it asks superhound.app for the latest version; this request carries no license key and no device ID, and **Check for Updates Automatically** turns it off. A build from source does not check. To activate a license, it sends the license key and a one-way device ID to superhound.app. All of its data stays in `~/Library/Application Support/Superhound/`:

| File | Content |
|---|---|
| `folders.plist` | Your search locations |
| `catalog.sqlite` | The list of indexed names. Safe to delete; Superhound builds it again. |
| `usage.plist` | The results you opened and what you typed for them |
| `clipboard.plist` | Your clipboard history, readable only by your macOS user |
| `license.plist` | Your license key and this Mac's activation, readable only by your macOS user |
| `performance.jsonl` | Timing records |

## Performance

Measured on an Apple M1 with macOS 15.

| Measure | Result |
|---|---|
| App size | 900 KiB |
| Memory after launch | 28 to 42 MiB over 20 minutes |
| Search across 100,000 items | 9.6 ms median, 20.3 ms at the 95th percentile |

The search time comes from a synthetic benchmark. The methods and all results are in [docs/prototype-validation.md](docs/prototype-validation.md).

## Development

Superhound is written in Objective-C and C with AppKit, SQLite, and FSEvents. It has no third-party dependencies.

```sh
scripts/test.sh       # nine test suites with AddressSanitizer and UndefinedBehaviorSanitizer
scripts/benchmark.sh  # search and catalog speed at 10,000 and 100,000 items
tests/install.sh      # installer checks; quit Superhound first
```

| Folder | Content |
|---|---|
| `core/` | Search, ranking, scanning, the catalog, calculator, emoji, and clipboard history. No window code. |
| `app/` | The panel, the settings window, shortcuts, and macOS actions |
| `tests/` | Test suites for `core/` and the installer |
| `bench/` | Benchmark programs |
| `scripts/` | Build, test, install, release, and benchmark |

[AGENTS.md](AGENTS.md) describes each file. The first design and plan are in [docs/superpowers](docs/superpowers).

## Status

Superhound is an early version.

## License

Copyright (C) 2026 PGHQdev. Superhound is free software under the GNU Affero General Public License, version 3. See [LICENSE](LICENSE).
