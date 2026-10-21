<div align="center">

<a href="https://superhound.app"><img src="docs/media/banner.png" alt="Superhound: the ultrafast Spotlight alternative for Mac. 10 ms for 100k items, under 45 MB of RAM when idle, native, 1 MB app." width="100%"></a>

<br>

[![Latest release](https://img.shields.io/github/v/release/PGHQdev/Superhound?style=flat-square&label=release&color=0071e3)](https://github.com/PGHQdev/Superhound/releases/latest)
[![macOS 15 or later](https://img.shields.io/badge/macOS-15%2B-111111?style=flat-square&logo=apple)](#-install)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-native-111111?style=flat-square)](#-install)
[![Works offline](https://img.shields.io/badge/works-offline-34c759?style=flat-square)](#-privacy)
[![Native Objective-C and C](https://img.shields.io/badge/native-Objective--C%20%26%20C-438eff?style=flat-square)](#-why-superhound)
[![RAM consumption less than 45 MB when idle](https://img.shields.io/badge/RAM%20when%20idle-%3C%2045%20MB-34c759?style=flat-square)](#-why-superhound)
[![Free to evaluate, license $10 at launch](https://img.shields.io/badge/free%20to%20evaluate-%2410%20at%20launch-ff9500?style=flat-square)](https://superhound.app)
[![License: AGPL-3.0](https://img.shields.io/github/license/PGHQdev/Superhound?style=flat-square&color=555555)](LICENSE)

### The ultrafast Spotlight alternative for your Mac

Open any app, even with a typo. Find your files. Get back anything you copied.

**[Install](#-install)** · **[Website](https://superhound.app)** · **[Docs](https://superhound.app/docs)** · **[Releases](https://github.com/PGHQdev/Superhound/releases)** · **[Get a license](https://superhound.app/buy)**

</div>

<br>

## 👀 See it work

| Open an app with a typo | Find a file | Get back what you copied |
|---|---|---|
| <img src="https://superhound.app/screenshots/typos.webp" alt="Type safri and Safari is the top result" width="100%"> | <img src="https://superhound.app/screenshots/search.webp" alt="Type term: Terminal, then files with their folders" width="100%"> | <img src="https://superhound.app/screenshots/clipboard.webp" alt="Clipboard history with the source app and time of each copy" width="100%"> |
| Type `safri`, press Return. Safari opens. | Type part of a name. Each file shows its folder. | Press ⌥⌘V, find the text, press Return to paste it. |

<div align="center">

<a href="https://www.producthunt.com/products/superhound?embed=true&amp;utm_source=badge-featured&amp;utm_medium=badge&amp;utm_campaign=badge-superhound" target="_blank" rel="noopener noreferrer"><picture><source media="(prefers-color-scheme: dark)" srcset="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1287375&amp;theme=dark&amp;t=1792555482711"><img alt="Superhound - Spotlight, but it actually finds things | Product Hunt" width="250" height="54" src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1287375&amp;theme=light&amp;t=1792555482711"></picture></a>

</div>

<br>

## ✨ Why Superhound

| | |
|---|---|
| ⚡ **Ultrafast** | Ranks 100,000 names in about 10 ms. Results are on screen about 23 ms after a key press. |
| 🛠️ **Native** | Objective-C and C on AppKit, with a search matcher in C. No Electron, no web views, no third-party dependencies. |
| 🪶 **Light** | RAM consumption less than 45 MB when idle. About 1 MB on disk. Under 0.2% CPU when idle. |
| 🔒 **Private** | Works offline. Reads file names, never file contents. No account, no tracking. |
| 🧠 **Smart** | Forgives typos, ignores accents, and learns which results you open. |
| 💸 **Fair** | Free to evaluate, with every feature and no time limit. License price: $10 once at launch (regular price $15), for 3 Macs. No subscription. |

## 🔎 What you can do

| | Type | Press Return to |
|---|---|---|
| 🚀 **Open apps and files** | `term`, `safri`, `notes.txt` | Open it |
| ⚙️ **Go to System Settings** | `storage`, `displays` | Open the pane |
| 🧮 **Calculate** | `48*12`, `15% of 240`, `240 + 15%` | Copy the answer |
| 📏 **Convert units** | `5 km to mi`, `72f to c` | Copy the answer |
| 🎨 **Convert colours** | `#ff5733`, `rgb(255 87 51)`, `hsl(11 100% 60%)` | Copy it as hex or rgb; ⌘K has every form |
| 🌐 **Open websites** | `github.com`, `localhost:3000` | Open it in your browser |
| 🔍 **Search the web** | Anything, in the last row | Search it with Google, or the engine you choose in **Settings…** |
| 😀 **Find emoji** | `fire`, `happy`, `japan` | Copy the emoji |
| 💤 **Run commands** | `sleep`, `restart`, `mute`, `dark`, `empty trash` | Run it |
| 📋 **Paste from clipboard history** | Press ⌥⌘V | Paste it |

## 📦 Install

You need a Mac with Apple Silicon and macOS 15 or later. Paste this in Terminal (**Applications → Utilities → Terminal**) and press Return:

```sh
curl -fsSL https://superhound.app/install | sh
```

The command downloads Superhound, checks it against the published SHA-256 checksum, puts it in `~/Applications`, and opens it. It does not ask for your password. [Read the script](https://superhound.app/install) before you run it.

When it is done, Terminal shows **Superhound is installed.**, a hound appears in your menu bar, and a Welcome window helps you choose a shortcut, add your folders, and try a first search. At first, Superhound searches apps only; it finds your files after you add their folders.

Superhound is free to evaluate, with every feature and no time limit. The panel shows **Activate license**, and a reminder every tenth time you open it. License price: **$10 once at launch** (regular price $15), **for 3 Macs**, with a 14-day refund, at [superhound.app](https://superhound.app/buy). To activate, choose **Enter License…** from the menu bar.

<details>
<summary><b>What the install script checks, and why Terminal</b></summary>

<br>

1. The Mac has Apple Silicon and macOS 15 or later.
2. The download matches the SHA-256 checksum published with the release. This shows that you got the published file.
3. The app's code signature is intact (`codesign --verify --strict`).

If a check fails, the script stops before it changes anything.

The checksum is not an Apple check. Superhound is signed with its own certificate, and Apple has not notarized it. macOS blocks an app like this when a browser downloads it, but not when curl does. That is why the install runs in Terminal.

</details>

<details>
<summary><b>If the install fails</b></summary>

<br>

| Terminal shows | Do this |
|---|---|
| `needs a Mac with Apple Silicon` or `needs macOS 15 or later` | Superhound cannot run on this Mac. |
| `the download does not match the published checksum` | Run the command again. If it fails again, write to support@superhound.app. |
| `quit Superhound, then run this command again` | Choose **Quit Superhound** from the hound in the menu bar, then run the command again. |

If your files do not show up, add their folders in **Settings…** and click **Allow** when macOS asks.

</details>

> [!TIP]
> Want Superhound on ⌘Space? See [Open Superhound with ⌘Space](#open-superhound-with-space).

## ⌨️ Keys

| Key | Action |
|---|---|
| ⌘Space | Open Superhound (after the [setup](#open-superhound-with-space)) |
| ⌥⌘V | Open clipboard history |
| ↑ ↓ | Select a result |
| Return | Open, run, copy, or paste the result |
| ⌘Return | Show a file in Finder. In clipboard history: copy only |
| ⌘K | All actions: Open With, Quick Look, Copy Path, Move to Trash, and more |
| ⌘Y | Quick Look |
| ⇧⌘C | Copy path |
| Tab or → | Keep the completion of the top result. Turn on **Complete the top result as you type** in **Settings…** first; it is off by default. |
| Esc | Close |

Right-click a result for the same actions as ⌘K. Click the logo at the bottom of the panel for the menu.

## 🔒 Privacy

Superhound works offline. It makes only two kinds of network request:

- **A daily update check.** It carries no license key and no device ID. Turn it off with **Check for Updates Automatically**.
- **License activation.** It sends your license key and a one-way device ID to superhound.app, once.

Web addresses and web searches open in your browser, which loads the page. Superhound itself sends nothing for them.

Superhound reads file names, never file contents. All its data stays on your Mac in `~/Library/Application Support/Superhound/`.

## ❓ FAQ

<details>
<summary><b>Is Superhound a Spotlight alternative?</b></summary>

<br>

Yes. Superhound opens apps, files, and System Settings panes like Spotlight, and it adds a calculator, unit conversion, emoji search, system commands, and a clipboard history. You can put it on ⌘Space in place of Spotlight.

</details>

<details>
<summary><b>How much does it cost?</b></summary>

<br>

Superhound is free to evaluate, with every feature and no time limit. It shows a reminder every tenth time you open the panel. License price: $10 once at launch (regular price $15), for 3 Macs. Refunds are open for 14 days, for any reason.

</details>

<details>
<summary><b>Does Spotlight still work?</b></summary>

<br>

Yes. Superhound changes Spotlight only if you turn on **Use ⌘Space in place of Spotlight**. Turning it off, or **Uninstall Superhound…**, gives ⌘Space back.

</details>

<details>
<summary><b>How do I get help?</b></summary>

<br>

Write to support@superhound.app, or read the [docs](https://superhound.app/docs). Bugs and ideas are welcome in [GitHub issues](https://github.com/PGHQdev/Superhound/issues).

</details>

<details>
<summary><b>Which Macs does it run on?</b></summary>

<br>

Macs with Apple Silicon (M1 or later) and macOS 15 or later.

</details>

<details>
<summary><b>Is it open source?</b></summary>

<br>

Yes. The full source is here under the AGPL-3.0 license. You can [build it yourself](#build-from-source).

</details>

<details>
<summary><b>Is it finished?</b></summary>

<br>

Superhound is an early version. It checks for updates once a day, and you install one with a click.

</details>

## 📖 Guide

<details id="open-superhound-with-space">
<summary><b>Open Superhound with ⌘Space</b></summary>

<br>

Open **Settings…** from the menu bar and turn on **Use ⌘Space in place of Spotlight**. Superhound turns off Spotlight's ⌘Space shortcut and takes ⌘Space.

To give ⌘Space back to Spotlight, turn the switch off. Superhound then moves to ⌥Space, or keeps its keys when ⌥Space is in use.

</details>

<details>
<summary><b>Search your folders</b></summary>

<br>

Superhound always searches your app folders. To search your own folders, add them in **Settings…**. No personal folder is added for you.

- Changes to files appear in a few seconds. **Refresh Catalog** scans everything now.
- It skips hidden items, the inside of packages, online-only files, and generated folders such as `node_modules`. You can turn off the generated-folder rule.
- Removing a location never deletes files.

You can change both shortcuts in **Settings…**.

</details>

<details>
<summary><b>Clipboard history</b></summary>

<br>

Superhound keeps the last 500 pieces of text you copy, newest first. Press ⌥⌘V, or choose **Clipboard History** in the menu bar, then type to filter. A normal search of 3 or more characters also shows up to 2 matching copies.

It does not keep:

- copies that password managers mark as private
- copies from Keychain Access and Passwords
- text longer than 100,000 characters

**Clear Clipboard History** in the menu bar deletes it all.

</details>

<details>
<summary><b>Licenses</b></summary>

<br>

To activate, click **Activate license** at the bottom of the panel, or choose **Enter License…** in the menu bar. To move a license to another Mac, choose **Deactivate License…** on the old Mac first. To get your key again, go to [superhound.app/license](https://superhound.app/license).

</details>

<details>
<summary><b>Updates</b></summary>

<br>

Superhound checks for a new version once a day. When there is one, the panel shows **Update to** and the menu shows **Update to…**. Superhound downloads the update, checks that it has the Superhound signature, and opens again. It keeps the previous version in `~/Applications/.superhound-backup.*`. To go back, quit Superhound and put that `previous.app` in place of `~/Applications/Superhound.app`.

To turn off the daily check, turn off **Check for Updates Automatically** in the menu. **Check for Updates…** checks at once.

</details>

<details>
<summary><b>Permissions</b></summary>

<br>

| Permission | When macOS asks | Without it |
|---|---|---|
| Accessibility | When you paste from clipboard history | Return copies the text, and you paste it yourself |
| Automation for Finder, System Events, or the login window | The first use of a command such as Empty Trash or Restart | That command does not run |

Restart, Shut Down, and Log Out show the macOS confirmation first. Empty Trash asks first. Lock Screen uses a private macOS call that a later macOS can break.

</details>

<details>
<summary><b>Your data</b></summary>

<br>

| File | Content |
|---|---|
| `folders.plist` | Your search locations |
| `catalog.sqlite` | The list of indexed names. Safe to delete; Superhound builds it again. |
| `usage.plist` | The results you opened and what you typed for them |
| `clipboard.plist` | Your clipboard history, readable only by your macOS user |
| `license.plist` | Your license key and this Mac's activation, readable only by your macOS user |
| `performance.jsonl` | Timing records |

</details>

<details>
<summary><b>Uninstall</b></summary>

<br>

Choose **Uninstall Superhound…** in the menu bar. Superhound frees this Mac's license activation, gives ⌘Space back to Spotlight if it took it, deletes its settings and data, and moves itself to the Trash.

If the app does not open, paste this in Terminal. It does the same:

```sh
curl -fsSL https://superhound.app/uninstall | sh
```

If you dragged Superhound to the Trash, Spotlight's ⌘Space stays off. Run the command above, or turn on **Show Spotlight search** in **System Settings → Keyboard → Keyboard Shortcuts → Spotlight**.

</details>

## 🛠️ For developers

<details id="build-from-source">
<summary><b>Build from source</b></summary>

<br>

You need the Apple Command Line Tools (`xcode-select --install`). Nothing else.

```sh
git clone https://github.com/PGHQdev/superhound.git
cd superhound
scripts/build.sh
scripts/install.sh .build/Superhound.app
open ~/Applications/Superhound.app
```

A build from source cannot update itself. To update it, pull the latest code, quit Superhound, and run the same build and install commands. It has a local signature, so macOS can ask for Accessibility again after you install a new build. If paste stops working, remove Superhound in **System Settings → Privacy & Security → Accessibility** and add it again.

</details>

<details>
<summary><b>Performance</b></summary>

<br>

Measured on an Apple M1 with macOS 15.

| Measure | Result |
|---|---|
| App size | 1.0 MB (983 KiB); the program itself is 464 KB |
| RAM consumption when idle | 32 to 38 MB from 1 to 8.5 minutes after launch; 28 to 42 MiB (29 to 44 MB) over 20 minutes in an earlier build. The launch scan peaks higher, at 74 MB. |
| CPU when idle | 0.14% of one core over 120 seconds, panel closed |
| Ranking time across 100,000 names | 9.6 ms median, 20.3 ms at the 95th percentile |
| Key press to results on screen | 22.55 ms median over 127 searches, with 47,121 items |

The ranking time is the search code alone, in a synthetic benchmark that `scripts/benchmark.sh` runs. The key press time adds drawing the panel; it comes from daily use of an earlier build with `measurePerformance` on.

</details>

<details>
<summary><b>Code and tests</b></summary>

<br>

Superhound is written in Objective-C and C with AppKit, SQLite, and FSEvents. It has no third-party dependencies.

```sh
scripts/test.sh       # eleven test suites with AddressSanitizer and UndefinedBehaviorSanitizer
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

[AGENTS.md](AGENTS.md) describes each file.

</details>

## 📄 License

Copyright (C) 2026 PGHQdev. Superhound is free software under the GNU Affero General Public License, version 3. See [LICENSE](LICENSE).

<div align="center">

<br>

**[superhound.app](https://superhound.app)** · Made for the Mac 🐕

</div>
